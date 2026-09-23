---
name: dendritic-module
description: Use when adding or changing features, hosts, users, flake inputs, or home-manager config in this dendritic NixOS flake — covers the file templates, wiring rules, and the verification ritual that keeps changes safe on these production machines.
---

# Extending this dendritic NixOS config

## Invariants — internalize before editing

1. **`flake.nix` is generated.** Never edit it. Inputs are declared as
   `flake-file.inputs.<name>` inside the module that uses the input;
   `nix run .#write-flake` regenerates `flake.nix` from them.
2. **Every `*.nix` under `modules/` is auto-imported** as a flake-parts
   module (import-tree). There is no import list to update — creating the
   file is the wiring. Corollary: never put a non-flake-parts-module `.nix`
   file under `modules/`; prefix a path component with `_` to exclude it.
3. **Configuration merges into names**: `flake.modules.nixos.<name>` /
   `flake.modules.homeManager.<name>` are deferred modules; any number of
   files may define the same name. A name does nothing until imported via
   `inputs.self.modules.<class>.<name>`. Importing = enabling; do not add
   `mkEnableOption` gates.
4. **No specialArgs.** Need a flake input inside NixOS/HM config? Take
   `inputs` at the flake-parts layer and close over it:
   ```nix
   { inputs, ... }:
   { flake.modules.nixos.pc = { pkgs, ... }: { /* use inputs.… here */ }; }
   ```
5. These configure **live production machines**. Never run
   `nix flake update`. Never commit an unverified change.

## Recipes

### Shared PC feature (both hosts)

Create `modules/pc/<feature>.nix`:

```nix
{
  flake.modules.nixos.pc = { pkgs, ... }: {
    services.foo.enable = true;
  };
}
```

Done — both hosts import `pc`. Omit the `{ pkgs, ... }:` function layer when
the body needs no module args.

### Host-specific feature

Create `modules/hosts/<host>/<feature>.nix` merging into
`flake.modules.nixos.<host>`. Same shape as above. Non-Nix assets
(keyboard layouts, notes) can sit in the same directory; reference them
with relative paths (`builtins.readFile ./file.kbd`).

### Home-manager feature (user shashin)

Create `modules/users/shashin/home/<feature>.nix`:

```nix
{
  flake.modules.homeManager.shashin = { pkgs, ... }: {
    programs.foo.enable = true;
  };
}
```

Only nostromo wires HM in (via `flake.modules.nixos.home-shashin`). To give
serenity HM too, add `inputs.self.modules.nixos.home-shashin` to serenity's
`host.nix` imports — one line.

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
2. `nix run .#write-flake` — regenerates `flake.nix`.
3. `nix flake lock` — locks the new input.
4. `git diff flake.lock` must show **added nodes only**; if an existing
   node changed, an input URL/follows string was altered — fix it.

Identical declarations in several files merge fine (see
claude-code-statusline, declared in both `pc/packages.nix` and
`home/essentials.nix`).

### New host

1. `mkdir modules/hosts/<name>`; copy an existing `host.nix` as a template:
   identity (`networking.hostName`, `system.stateVersion` = the release
   being installed), aspect imports (`pc`, `shashin`, hardware profile),
   and the output wiring (`flake.nixosConfigurations.<name> = …`).
2. Add sibling `disko.nix` and `hardware.nix` for its disks and hardware
   scan.
3. Declare any new inputs (e.g. a nixos-hardware profile) in `host.nix`.

### Wire a currently-unwired module

`flake.modules.nixos.power-profile`, `flake.modules.homeManager.htop` and
`flake.modules.homeManager.firefox` exist but nothing imports them.
- power-profile → add `inputs.self.modules.nixos.power-profile` to a host's
  imports.
- htop → add `inputs.self.modules.homeManager.htop` to
  `home-manager.users.shashin.imports` in
  `modules/users/shashin/home-manager.nix`.
- firefox → additionally requires a `nur` flake input first (see the header
  comment in `modules/users/shashin/firefox.nix`); it still consumes
  `inputs` as a module argument, so convert it to the closure style when
  wiring.

## Verification ritual

Run after every change, before committing:

```bash
nix flake check --no-build
nix eval .#nixosConfigurations.serenity.config.system.build.toplevel.drvPath
nix eval .#nixosConfigurations.nostromo.config.system.build.toplevel.drvPath
```

- A refactor that should not change behavior must leave both drvPaths
  unchanged. If a drvPath changed unexpectedly, diff with
  `nix run nixpkgs#nix-diff -- <old.drv> <new.drv>`; pure reorderings of
  list options can be confirmed with `tools/drv-equiv.sh <old> <new>`.
- A change that should alter behavior: eyeball the nix-diff output and
  confirm only the intended units/packages moved.
- Deploy with `sudo nixos-rebuild switch --flake .#<host>` (or `test`
  first for risky changes).

## Sharp edges

- **List option order follows the module graph**, not file order. Splitting
  or moving files can reorder `environment.systemPackages`,
  `fonts.packages`, `extraGroups`, etc. This is semantically harmless
  (same multiset) but changes drvPaths; pin with `lib.mkOrder` only if
  order genuinely matters.
- **Wrapping an existing plain module file**: the binding needs a
  terminating semicolon —
  `{ flake.modules.nixos.x = { … }: { … }; }` — easy to drop when pasting
  a whole file as the value.
- **A module defining the same attrset key twice** (`flake.modules.nixos.pc`
  twice in one file) is a Nix syntax error; put `imports` and config inside
  a single deferred module instead.
- **`nixpkgs.hostPlatform` and the `system` argument** are both set on
  purpose (hardware.nix mkDefault + the host.nix wiring); leave that
  arrangement alone.
- The serenity fonts quirk is intentional: `fontconfig.defaultFonts` names
  JetBrainsMono Nerd Font, which serenity's `fonts.packages` does not
  install. Fixing it changes serenity's closure — do it deliberately, not
  as a side effect.
