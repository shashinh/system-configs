# Project layout, tests, Nix packaging, deployment

Templates use the placeholder plugin `me/hello` in directory `hello/`.

## Repository layout (own repo, one plugin)

```
hello/                    the plugin, installed as-is; name = id part after "/"
  plugin.toml
  service.luau            thin entry: wires the real host into lib/
  bar.luau
  panel.luau
  lib/
    paths.luau            external executables (see Nix section)
    parse.luau            pure: text in, tables out
    view.luau             pure: state -> colour / tooltip / label decisions
    service_core.luau     the loop, with host and modules injected
  translations/en.json
tests/
  run.luau  testlib.luau  fake_noctalia.luau  *_test.luau
package.nix  flake.nix  nix/hm-module.nix
README.md  LICENSE
```

Keep the plugin in a subdirectory so tests and Nix files never ship inside it.
If the license is not MIT, set `license` in the manifest and ship a `LICENSE`.

## Testable structure

The host's `require` and the `luau` CLI's `require` follow different rules
(the host wants `./x.luau` with the extension; the CLI resolves `./x` without).
A module that requires a sibling therefore loads in one and not the other. So:

- `lib/` modules contain no `require` calls and never touch the global
  `noctalia`. They receive `host` (the `noctalia` table) and their sibling
  modules as arguments.
- Entry scripts are the only place that calls `require` and passes the real
  `noctalia` in. Keep them too thin to need tests.
- Tests require modules without the extension:
  `require("../hello/lib/parse")`.

```lua
-- hello/service.luau
--!nonstrict
local core = require("./lib/service_core.luau")
local runtime = core.start(noctalia, {
  parse = require("./lib/parse.luau"),
  paths = require("./lib/paths.luau"),
})
noctalia.setUpdateInterval(core.TICK_MS)
function update()
  runtime.tick()
end
```

`tests/fake_noctalia.luau` is a scriptable host: `nowMs` returns a settable
clock; `runAsync` queues `{ argv, cb, timeout }` so a test completes each
command when and how it chooses; `runStream` records the command and exposes
`onLine` so the test can feed lines; `state.set/get/watch` are implemented
in-memory and record what was published; `getConfig`, `getSetting`,
`expandPath`, `fileInfo`, `log` are table-backed. That makes debounce,
coalescing, timeout, restart and "stop cancels work" behaviour testable
without a shell.

`tests/testlib.luau` needs only `test(name, fn)`, `eq`, `deepEq` and a `run()`
that prints `ok` / `FAIL` per case and calls `error` on any failure so the
process exits non-zero.

```sh
luau tests/run.luau
find hello -name '*.luau' -print0 | xargs -0 luau-compile --null   # syntax check
```

`luau` is `pkgs.luau` (`nix shell nixpkgs#luau`). Type annotations in `lib/`
are fine; they compile away.

## Nix packaging

Noctalia loads a plugin from any directory whose immediate subdirectories hold
a `plugin.toml`, and follows symlinks, so a store path works unchanged.

**External commands.** A Nix-installed plugin should not depend on the user's
`PATH`. Route every executable through one module with placeholders that the
package substitutes, falling back to `PATH` for a plain checkout:

```lua
-- hello/lib/paths.luau
--!nonstrict
local function pick(substituted, fallback)
  if string.sub(substituted, 1, 1) == "@" then
    return fallback
  end
  return substituted
end

return {
  jq = pick("@jq@", "jq"),
}
```

```nix
# package.nix
{ lib, stdenvNoCC, jq }:
let
  manifest = lib.importTOML ./hello/plugin.toml;
in
stdenvNoCC.mkDerivation {
  pname = "noctalia-plugin-hello";
  inherit (manifest) version;          # single source of truth for the version
  src = lib.fileset.toSource { root = ./.; fileset = ./hello; };
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    dest=$out/share/noctalia/plugins/hello
    mkdir -p "$dest"
    cp -r hello/. "$dest/"
    substituteInPlace "$dest/lib/paths.luau" --replace-fail '@jq@' '${lib.getExe jq}'
    runHook postInstall
  '';
  passthru.pluginDir = "share/noctalia/plugins/hello";
  meta = {
    description = "…";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
```

`--replace-fail` makes a renamed placeholder a build error instead of a silent
`PATH` fallback. Leave helpers that must come from the session (for example
`ssh` using the user's agent) on `PATH` and say so in the README.

**home-manager module.** Install into the implicit local source. Do not emit a
`[[plugins.source]]`: an explicit source array replaces the built-in official
and community sources.

```nix
# nix/hm-module.nix
self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.noctalia-hello;
in
{
  options.programs.noctalia-hello = {
    enable = lib.mkEnableOption "the hello Noctalia plugin";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  };
  config = lib.mkIf cfg.enable {
    xdg.dataFile."noctalia/plugins/hello".source = "${cfg.package}/${cfg.package.pluginDir}";
  };
}
```

**flake.nix** exposes `packages.default`, `homeModules.default = import
./nix/hm-module.nix self`, a dev shell with `luau` and the runtime tools, and
checks so `nix flake check` is the single gate:

```nix
checks = forAllSystems (pkgs:
  let
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [ ./hello ./tests ];
    };
    manifest = lib.importTOML ./hello/plugin.toml;
    translations = lib.importJSON ./hello/translations/en.json;
    settings = (manifest.setting or [ ])
      ++ lib.concatMap (e: e.setting or [ ]) ((manifest.widget or [ ]) ++ (manifest.panel or [ ]));
    resolves = key: lib.hasAttrByPath (lib.splitString "." key) translations;
  in
  {
    package = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
    luau = pkgs.runCommandLocal "hello-luau" { nativeBuildInputs = [ pkgs.luau ]; } ''
      cd ${src}
      luau tests/run.luau
      find hello -name '*.luau' -print0 | xargs -0 luau-compile --null
      touch $out
    '';
    manifest =
      assert builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" manifest.version != null;
      assert lib.all (s: resolves s.label_key && (!(s ? description_key) || resolves s.description_key)) settings;
      pkgs.runCommandLocal "hello-manifest" { } "touch $out";
  });
```

A flake only sees tracked files: `git add` new files before `nix build` or
`nix flake check`.

**Live-testing the built package**

```sh
nix build -o /tmp/hello-result
ln -sfn /tmp/hello-result/share/noctalia/plugins/hello ~/.local/share/noctalia/plugins/hello
noctalia msg config-reload
grep "loaded plugin 'me/hello'" ~/.cache/noctalia/noctalia.log | tail -1   # confirm the store path
```

A rebuild changes the store path behind the symlink without Noctalia noticing;
reload and re-check the logged path every time.

## Deploying through the owner's NixOS config

Load the `nixos-config` skill and follow its invariants and verification
ritual. For a plugin in its own flake:

1. Push the plugin repository first: the system flake cannot lock an input
   that is not on the remote. Before that, verify locally with
   `--override-input <name> path:<checkout>`.
2. Add a file under `modules/features/noctalia/` that declares the input and
   enables the module for the existing `noctalia` home-manager name:

   ```nix
   { inputs, ... }:
   {
     flake-file.inputs.hello = {
       url = "github:me/hello-noctalia-plugin";
       inputs.nixpkgs.follows = "nixpkgs";
     };
     flake.modules.homeManager.noctalia = {
       imports = [ inputs.hello.homeModules.default ];
       programs.noctalia-hello.enable = true;
     };
   }
   ```

   Then `nix run .#write-flake`, `nix flake lock`, and confirm the lock diff
   only adds the new input. A later plugin release is
   `nix flake update <name>` for that one input.
3. Enable and place it in the vendored Noctalia config under
   `dotfiles/noctalia/`. Because arrays replace wholesale, add the id to
   **every** `[plugins] enabled` list that can win on a host (the shared
   `plugins.toml` and any per-host file that defines its own list), and place
   the widget in each host's effective bar list. Then check the machine-local
   `~/.local/state/noctalia/settings.toml` for GUI overrides of the same
   arrays (SKILL.md section 7).
4. Remove the dev symlink at `~/.local/share/noctalia/plugins/<plugin>` before
   the owner rebuilds: home-manager refuses to replace an unmanaged file there.
   Tell the owner the widget is gone until they switch.
5. Build a host toplevel and confirm the plugin directory appears in the
   home-manager files before committing.
