# nostromo — Framework 13 (AMD 7040), niri + Noctalia laptop.
# Sibling files (hardware-bound config) merge into
# `flake.modules.nixos.nostromo`; reusable behavior comes from the
# features imported below. This file adds the host identity and wires
# the nixosConfigurations output.
{ inputs, ... }:
{
  # Hardware-specific tweaks (Framework 13 AMD 7040). Also declared by
  # serenity's host.nix; identical declarations merge.
  flake-file.inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

  flake.modules.nixos.nostromo = {
    imports = with inputs.self.modules.nixos; [
      # Hardware profile: Framework 13 AMD 7040 quirks, firmware, kernel params.
      inputs.nixos-hardware.nixosModules.framework-13-7040-amd
      pc
      shashin
      home-shashin
      # Features (modules/features/) — importing is what enables them.
      greetd
      niri
      noctalia
      fingerprint
      printing
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
    modules = [ inputs.self.modules.nixos.nostromo ];
  };
}
