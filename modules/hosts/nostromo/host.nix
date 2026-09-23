# nostromo — Framework 13 (AMD 7040), niri + Noctalia laptop.
# Fragments across the tree merge into `flake.modules.nixos.nostromo`;
# this file aggregates them and wires the nixosConfigurations output.
{ inputs, ... }:
{
  flake.modules.nixos.nostromo = {
    imports = [
      # Hardware profile: Framework 13 AMD 7040 quirks, firmware, kernel params.
      inputs.nixos-hardware.nixosModules.framework-13-7040-amd
      inputs.noctalia.nixosModules.default
      ../../_legacy/nostromo/disko.nix
      ../../_legacy/nostromo/hardware-configuration.nix
      inputs.self.modules.nixos.pc
      inputs.self.modules.nixos.shashin
      ../../_legacy/nostromo/configuration.nix
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # TRANSITIONAL: dropped in phase 3 when home modules close over inputs.
        home-manager.extraSpecialArgs = { inherit inputs; };
        home-manager.users.shashin = ../../_legacy/nostromo/home.nix;
      }
    ];
  };

  flake.nixosConfigurations.nostromo = inputs.nixpkgs.lib.nixosSystem {
    # Deliberately the legacy calling convention (positional `system`,
    # not nixpkgs.hostPlatform) — reproduces the original evaluation.
    system = "x86_64-linux";
    # TRANSITIONAL (refactor phase 1-3): legacy modules still take `inputs`
    # as a module argument. Removed in phase 4.
    specialArgs = { inherit inputs; };
    modules = [ inputs.self.modules.nixos.nostromo ];
  };
}
