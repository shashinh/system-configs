---
name: nixos-config
description: Use when the user asks to look at, investigate, edit, extend or rebuild their "nixos config", "system config", "flake", "host config", or a specific host (nostromo, serenity) — or when adding/changing features, hosts, users, flake inputs, home-manager config or secrets in ~/system-configs. Locates the dendritic flake-parts repo and gives the file templates, wiring rules and verification ritual that keep changes safe on these production machines.
---

# NixOS config (dendritic flake-parts)

## Locate and orient

- The repo is `~/system-configs` and **its root is the flake root**. There is no
  `nixos-config/` subdirectory; that layout only exists on the legacy `main`
  branch.
- Work happens on branch **`dendritic`**. Check `git -C ~/system-configs branch
  --show-current` before editing, and never commit to `main`.
- `/etc/nixos` should be a symlink to the repo root. If it is
  (`readlink -f /etc/nixos`), `sudo nixos-rebuild switch` works from anywhere.
- This machine's config: `hostname` → `modules/hosts/<hostname>/host.nix`. That
  file is the composition root. Its `imports` list names every aspect and
  feature the host gets, and it wires `flake.nixosConfigurations.<hostname>`.
  Confirm the name there rather than assuming the directory matches.
- `README.md` has the layout map. `INSTALL.md` is the bare-metal runbook.
  `docs/secrets.md` and `.sops.yaml` cover secrets.

| Host | Hardware | Desktop | home-manager |
|---|---|---|---|
| nostromo | Framework 13, AMD 7040 | niri + Noctalia (greetd) | yes (`home-shashin`) |
| serenity | Framework Desktop, AI Max+ 395 | niri + Noctalia (greetd) | yes (`home-shashin`) |

## Invariants: internalize before editing

1. **`flake.nix` is generated.** Never edit it. Inputs are declared as
   `flake-file.inputs.<name>` inside the module that uses the input;
   `nix run .#write-flake` regenerates `flake.nix` from them.
2. **Every `*.nix` under `modules/` is auto-imported** as a flake-parts
   module (import-tree). There is no import list to update: creating the
   file is the wiring. So never put a `.nix` file that isn't a flake-parts
   module under `modules/`. Prefix a path component with `_` to exclude it.
3. **Configuration merges into names.** `flake.modules.nixos.<name>` and
   `flake.modules.homeManager.<name>` are deferred modules, and any number of
   files may define the same name. A name does nothing until it is imported via
   `inputs.self.modules.<class>.<name>`. Importing is enabling, so don't add
   `mkEnableOption` gates.
4. **No specialArgs.** If NixOS/HM config needs a flake input, take
   `inputs` at the flake-parts layer and close over it:
   ```nix
   { inputs, ... }:
   { flake.modules.nixos.pc = { pkgs, ... }: { /* use inputs.… here */ }; }
   ```
5. These configure **live production machines**:
   - Never run a bare `nix flake update`. Update a single input
     (`nix flake update <input>`) only when the owner asks for that input.
   - Never commit a change you haven't verified.
   - Don't run `sudo nixos-rebuild`. Give the owner the command.
     `nixos-rebuild build` / `nix build` need no root and are fine for checking.

## Recipes

### Baseline feature (every host, unconditionally)

Create `modules/pc/<feature>.nix`:

```nix
{
  flake.modules.nixos.pc = { pkgs, ... }: {
    services.foo.enable = true;
  };
}
```

That's all: both hosts import `pc`. Omit the `{ pkgs, ... }:` function layer when
the body needs no module args.

### Optional feature (host chooses)

Create `modules/features/<name>.nix` (or `modules/features/<name>/*.nix`
for a multi-file feature) defining its own name:

```nix
{
  flake.modules.nixos.<name> = { pkgs, ... }: {
    services.foo.enable = true;
  };
}
```

Then add `<name>` to the `imports = with inputs.self.modules.nixos; [ … ]`
list in each `modules/hosts/<host>/host.nix` that wants it. A feature that
needs a flake input declares it in the same file and imports the input's
module itself (see `modules/features/noctalia/system.nix`). Moving a
feature between hosts means editing two import lists. The file never moves.

Existing feature names: plasma, greetd, niri, noctalia, thunar, gaming,
fingerprint, printing, lact, nas, llama-swap, open-webui, searxng,
claude-skills. Dependencies: llama-swap depends on lact's group. plasma and
greetd are mutually exclusive, because both claim the display manager
   (plasma is dormant: the KDE revert for serenity, see dotfiles/kde/README.md). niri,
noctalia and claude-skills need home-manager on the host (see next).

### Feature with a home-manager half

A NixOS feature can ship user-side config by defining
`flake.modules.homeManager.<name>` and delivering it from its NixOS half:

```nix
{ inputs, ... }:
{
  flake.modules.nixos.<name> = {
    home-manager.sharedModules = [ inputs.self.modules.homeManager.<name> ];
  };
  flake.modules.homeManager.<name> = { ... }: { /* user config */ };
}
```

`home-manager.sharedModules` exists only on hosts that import
`home-shashin`. Importing such a feature elsewhere fails at eval with
"The option `home-manager' does not exist".

### Configure a feature differently per host

Per-host deltas never go inside the feature file, and never branch on
`networking.hostName`. Create a host-side fragment,
`modules/hosts/<host>/<feature>.nix`, merging into the HOST's name:

```nix
{
  flake.modules.nixos.serenity =
    { lib, ... }:
    {
      programs.noctalia.settings.something = "…";      # attrsets/lists merge additively
      services.foo.scalar = lib.mkForce "…";           # scalars the feature sets need mkForce
    };
}
```

Escalation ladder:

1. Additive merge, which covers most cases for free.
2. `lib.mkForce` on the host side. Or change the feature's value to
   `lib.mkDefault` when it is genuinely a tunable default. That is
   eval-neutral while only one definition exists; verify with the drvPath
   ritual.
3. Declare a proper option inside the feature's deferred module
   (`options.features.<name>.<knob> = lib.mkOption { … }`) and have hosts
   set it. Use this when the knob has no existing NixOS option.

### Per-host override of shared config (the rule)

Shared values live in `pc`, a feature, or `homeManager.shashin`; with no
host-specific config a host looks and behaves like the other. A host
overrides in its own files only (`modules/hosts/<host>/*.nix`), never by
editing the shared module:

- NixOS options: additive merge for lists/attrsets, `lib.mkForce` for
  scalars (previous recipe).
- home-manager options: the same, through
  `home-manager.users.shashin.<option> = lib.mkForce …;` in a
  `flake.modules.nixos.<host>` fragment (see
  `modules/hosts/serenity/home.nix`: GTK dpi, a disabled shared file).
- App config files: a per-host fragment under
  `dotfiles/<app>/hosts/<hostname>/`, linked by hostname (niri: `host.kdl`,
  `noctalia.kdl`; Noctalia: `host.toml`, which only holds keys the shared
  layer does not set). To keep a shared file off one host:
  `xdg.configFile."<app>/<file>".enable = lib.mkForce false;` host-side.
- Noctalia GUI changes go to `~/.local/state/noctalia/settings.toml`,
  machine-local by construction; they never reach the shared files.

### Split an app's dotfile into shared + per-host parts

When a config file is mostly portable but has a machine-specific section
(display layout, device paths), don't fork the whole file per host. Split it
using the *application's own* include mechanism, and let home-manager pick
the per-host half by hostname:

```
dotfiles/<app>/.config/<app>/config         shared; contains `include "host.conf"`
dotfiles/<app>/hosts/<hostname>/host.conf   per-host fragment
```

```nix
flake.modules.homeManager.<app> = { config, osConfig, ... }:
  let src = "${config.dotfiles.repoPath}/dotfiles/<app>"; in {
    xdg.configFile."<app>/config".source =
      config.lib.file.mkOutOfStoreSymlink "${src}/.config/<app>/config";
    xdg.configFile."<app>/host.conf".source =
      config.lib.file.mkOutOfStoreSymlink "${src}/hosts/${osConfig.networking.hostName}/host.conf";
  };
```

`osConfig` is the enclosing NixOS config. It's available because home-manager
runs as a NixOS module here. `modules/features/niri/dotfiles.nix` is the
working example.

**Verify two things before relying on this.** Both depend on the app, and
both fail silently and fatally when wrong:

1. **Include resolution.** Does the app resolve a relative include against
   the directory of the config file it was *given*, or against the symlink's
   *target*? If the latter, the include looks inside the repo and the scheme
   collapses. To test it, put a deliberately broken fragment next to the real
   file in the repo and a valid one next to the symlink, then see which one the
   app's validator complains about. niri resolves against the symlink's
   directory, so the scheme works there.
2. **Missing-include behaviour.** For niri, a missing include is a *fatal
   parse error* that takes down the whole config, so every host importing
   the feature must have its `hosts/<hostname>/` files. Check what your app
   does and note it in the module header.

### Hardware-bound config

Create `modules/hosts/<host>/<file>.nix` merging into
`flake.modules.nixos.<host>`. Use it for things that are meaningless on another
machine: disk layout, hardware scan, device-path-specific remaps. Non-Nix
assets (keyboard layouts, notes) can sit in the same directory. Reference
them with relative paths (`builtins.readFile ./file.kbd`).

### Home-manager config (user shashin)

Create `modules/users/shashin/home/<feature>.nix`:

```nix
{
  flake.modules.homeManager.shashin = { pkgs, ... }: {
    programs.foo.enable = true;
  };
}
```

Only hosts importing `flake.modules.nixos.home-shashin` get it, and today
that is only nostromo. `homeManager.shashin` was grown on nostromo, so audit it
before giving it to another host: it includes GTK theming and mime defaults.

### Secrets (sops-nix)

Never interpolate a secret value into Nix. Consume a *path*:

```nix
flake.modules.nixos.<feature> = { config, ... }: {
  sops.secrets."group/name" = { sopsFile = ../../secrets/common.yaml; owner = "shashin"; };
  # use config.sops.secrets."group/name".path
  # or, for a whole file with the value inline:
  # sops.templates."x.toml".content = ''key = "${config.sops.placeholder."group/name"}"'';
};
```

Recipients live in `.sops.yaml`. A new recipient needs
`sops updatekeys secrets/common.yaml`. Get a host's age key by reading its
`/etc/ssh/ssh_host_ed25519_key.pub`, never via `ssh-keyscan` (Tailscale SSH
serves a different key). Live example:
`modules/features/noctalia/wallhaven-secret.nix`.

### Package, and Claude Code skills

Repo-local packages are `perSystem.packages.<name>` in `modules/packages/`.
Consume one from a deferred module as
`inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.<name>`.

Agent skills live in `skills/<name>/SKILL.md`. The `claude-skills` package
bundles every directory under `skills/`, and the `claude-skills` feature links
each one into `~/.claude/skills/<name>/` on rebuild. To ship a new skill,
add its directory and rebuild; no Nix change is needed. Edits to a skill
take effect only after a rebuild, because the installed copy is in the store.

### New flake input

1. In the module that uses it, add:
   ```nix
   { inputs, ... }:
   {
     flake-file.inputs.foo = {
       url = "github:owner/foo";
       inputs.nixpkgs.follows = "nixpkgs";   # when foo has a nixpkgs input
     };
     flake.modules.nixos.pc = { ... use inputs.foo ... };
   }
   ```
2. Run `nix run .#write-flake` to regenerate `flake.nix`.
3. Run `nix flake lock` to lock the new input.
4. `git diff flake.lock` must show **added nodes only**. If an existing
   node changed, an input URL/follows string was altered. Fix it.

Identical declarations in several files merge fine. For example,
claude-code-statusline is declared in both `pc/packages.nix` and
`home/essentials.nix`.

### New host

1. `mkdir modules/hosts/<name>` and copy an existing `host.nix` as a template.
   It needs: identity (`networking.hostName`, and `system.stateVersion` set to
   the release being installed), aspect imports (`pc`, `shashin`, the hardware
   profile), and the output wiring (`flake.nixosConfigurations.<name> = …`).
2. Add sibling `disko.nix` and `hardware.nix` for its disks and hardware
   scan.
3. Declare any new inputs (e.g. a nixos-hardware profile) in `host.nix`.
4. Add the host's SSH host key to `.sops.yaml` and run `updatekeys`, or its
   activation cannot decrypt secrets.

### Wire a currently-unwired module

`flake.modules.nixos.power-profile`, `flake.modules.homeManager.htop` and
`flake.modules.homeManager.firefox` exist, but nothing imports them.

- power-profile: add `power-profile` to a host's imports.
- htop: add `inputs.self.modules.homeManager.htop` to
  `home-manager.users.shashin.imports` in
  `modules/users/shashin/home-manager.nix`.
- firefox: also needs a `nur` flake input first (see the header comment
  in `modules/users/shashin/firefox.nix`). It still takes `inputs` as a
  module argument, so convert it to the closure style when wiring.

## Before committing

Every commit is reviewed for secrets before it is made. `system-configs` is a
public repo; a leaked value cannot be unpublished.

1. Stage only the intended files (`git add <paths>`), then read every hunk of
   `git diff --cached`.
2. Grep the added lines and justify every hit:

   ```bash
   git diff --cached -U0 | grep -E "^\+" | grep -v "^+++" \
     | grep -niE "age1|AGE-SECRET|PRIVATE KEY|api_key|token|passw|secret|sk-[A-Za-z0-9]{8}"
   ```

   Known non-secrets: `sk-local` and the `local-llama-swap` dummy token
   (llama-swap has no auth), the `$SEARX_SECRET_KEY` placeholder, sops
   placeholders (`config.sops.placeholder.*`), age *public* keys in
   `.sops.yaml`, and the NAS address and credentials *path* in `nas.nix`.
3. When vendoring files an application wrote (dotfiles, exported configs),
   also grep the staged tree for `password`, `token`, `Certificate`, `key=`,
   and never add key material, wallets, certificates, device pairings
   (`kdeconnect/`), clipboard history or caches.
4. A secret value goes in `secrets/*.yaml` via sops (see Secrets); the
   operator-only notes stay in the private workspace, not here.
5. `nix flake check --no-build` and the verification ritual below must have
   passed on the exact tree being committed.

## Verification ritual

Run this after every change, before committing:

```bash
nix flake check --no-build
nix eval --raw .#nixosConfigurations.serenity.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.nostromo.config.system.build.toplevel.drvPath
```

- A refactor that should not change behavior must leave both drvPaths
  unchanged. If one changed unexpectedly, diff with
  `nix run nixpkgs#nix-diff -- <old.drv> <new.drv>`. Confirm pure reorderings
  of list options with `tools/drv-equiv.sh <old> <new>`.
- For a change that should alter behavior, check the nix-diff output (or
  `nixos-rebuild build` followed by `nix run nixpkgs#nvd -- diff
  /run/current-system ./result`) and confirm that only the intended units and
  packages moved. A change to one host must leave the other host's drvPath
  alone unless it touched `pc` or a shared feature.
- To check a home-manager file lands where intended without switching, build
  the toplevel and inspect
  `result/etc/profiles/per-user/shashin` or the `home-manager-files`
  derivation of `config.home-manager.users.shashin.home-files`.
- Deploy (the owner runs it): `sudo nixos-rebuild switch --flake
  ~/system-configs#<host>`. Use `test` first for risky changes. If a switch
  leaves the system generation unchanged, home-manager does not re-run. Use
  `sudo systemctl restart home-manager-shashin.service` instead.

## Sharp edges

- **List option order follows the module graph**, not file order. Splitting
  or moving files can reorder `environment.systemPackages`,
  `fonts.packages`, `extraGroups`, etc. The reordering is harmless (same
  multiset) but changes drvPaths. Pin with `lib.mkOrder` only if order
  genuinely matters.
- **Wrapping an existing plain module file**: the binding needs a
  terminating semicolon
  (`{ flake.modules.nixos.x = { … }: { … }; }`), which is easy to drop when
  pasting a whole file as the value.
- **A module defining the same attrset key twice** (`flake.modules.nixos.pc`
  twice in one file) is a Nix syntax error. Put `imports` and config inside
  a single deferred module instead.
- **`nixpkgs.hostPlatform` and the `system` argument** are both set on
  purpose (hardware.nix mkDefault plus the host.nix wiring). Leave that
  arrangement alone.
- **home-manager and existing files.** HM refuses to overwrite a differing
  unmanaged file ("would be clobbered"), and *silently skips* one whose
  content is identical. Move hand-made files aside before HM takes them
  over, and read the `checkLinkTargets` output, not just the exit status.
- **New files must be `git add`ed** before `nix eval`/`build`. A flake only
  sees tracked files.
- Fonts are shared (`modules/pc/fonts.nix`) since 2026-10-01; both hosts
  install everything `fontconfig.defaultFonts` names. The old serenity quirk
  (JetBrainsMono named but not installed) is gone.
