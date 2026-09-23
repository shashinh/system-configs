# nostromo — Framework 13 (AMD 7040), niri + Noctalia laptop.
# Sibling files in this directory (and nothing else) merge into
# `flake.modules.nixos.nostromo`; this file adds the host identity and
# wires the nixosConfigurations output.
# (flake.modules.nixos.power-profile is defined next to this host but
# deliberately not imported anywhere.)
{ inputs, ... }:
{
  flake.modules.nixos.nostromo = {
    imports = [
      # Hardware profile: Framework 13 AMD 7040 quirks, firmware, kernel params.
      inputs.nixos-hardware.nixosModules.framework-13-7040-amd
      inputs.noctalia.nixosModules.default
      inputs.self.modules.nixos.pc
      inputs.self.modules.nixos.shashin
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # TRANSITIONAL: dropped in phase 3 when home modules close over inputs.
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.shashin = ../../_legacy/nostromo/home.nix;
      }
    ];

    networking.hostName = "nostromo";

    # This records the NixOS release at which this system was FIRST installed.
    # It controls defaults for stateful data (file locations, DB schemas, etc.).
    # DO NOT change this after the initial install — it is not a "keep up to
    # date" setting. Read the docs before changing it.
    system.stateVersion = "26.05";
  };

  flake.nixosConfigurations.nostromo = inputs.nixpkgs.lib.nixosSystem {
    # Deliberately the legacy calling convention (positional `system`,
    # not nixpkgs.hostPlatform) — reproduces the original evaluation.
    system = "x86_64-linux";
    # TRANSITIONAL (refactor phase 1-3): removed in phase 4.
    specialArgs = { inherit inputs; };
    modules = [ inputs.self.modules.nixos.nostromo ];
  };
}
