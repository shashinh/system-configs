# serenity — Framework Desktop (AMD AI Max+ 395), Plasma 6 desktop.
# Sibling files in this directory (and nothing else) merge into
# `flake.modules.nixos.serenity`; this file adds the host identity and
# wires the nixosConfigurations output.
{ inputs, ... }:
{
  # Hardware-specific tweaks (Framework Desktop AI Max+ 395). Also declared
  # by nostromo's host.nix; identical declarations merge.
  flake-file.inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

  flake.modules.nixos.serenity = {
    imports = [
      # Hardware profile: AMD Strix Halo quirks, firmware, kernel params.
      inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
      inputs.self.modules.nixos.pc
      inputs.self.modules.nixos.shashin
    ];

    networking.hostName = "serenity";

    # This records the NixOS release at which this system was FIRST installed.
    # It controls defaults for stateful data (file locations, DB schemas, etc.).
    # DO NOT change this after the initial install — it is not a "keep up to
    # date" setting. Read the docs before changing it.
    system.stateVersion = "25.11";
  };

  flake.nixosConfigurations.serenity = inputs.nixpkgs.lib.nixosSystem {
    # Deliberately the legacy calling convention (positional `system`,
    # not nixpkgs.hostPlatform) — reproduces the original evaluation.
    system = "x86_64-linux";
    modules = [ inputs.self.modules.nixos.serenity ];
  };
}
