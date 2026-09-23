# serenity — Framework Desktop (AMD AI Max+ 395), Plasma 6 desktop.
# Fragments across the tree merge into `flake.modules.nixos.serenity`;
# this file aggregates them and wires the nixosConfigurations output.
{ inputs, ... }:
{
  flake.modules.nixos.serenity = {
    imports = [
      # Hardware profile: AMD Strix Halo quirks, firmware, kernel params.
      inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
      inputs.disko.nixosModules.disko
      inputs.lanzaboote.nixosModules.lanzaboote
      inputs.impermanence.nixosModules.impermanence
      ../../_legacy/serenity/disko.nix
      ../../_legacy/serenity/hardware-configuration.nix
      inputs.self.modules.nixos.pc
      ../../_legacy/serenity/configuration.nix
    ];
  };

  flake.nixosConfigurations.serenity = inputs.nixpkgs.lib.nixosSystem {
    # Deliberately the legacy calling convention (positional `system`,
    # not nixpkgs.hostPlatform) — reproduces the original evaluation.
    system = "x86_64-linux";
    # TRANSITIONAL (refactor phase 1-3): legacy modules still take `inputs`
    # as a module argument. Removed in phase 4.
    specialArgs = { inherit inputs; };
    modules = [ inputs.self.modules.nixos.serenity ];
  };
}
