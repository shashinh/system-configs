# serenity — Framework Desktop (AMD AI Max+ 395), Plasma 6 desktop.
# Sibling files (hardware-bound config) merge into
# `flake.modules.nixos.serenity`; reusable behavior comes from the
# features imported below. This file adds the host identity and wires
# the nixosConfigurations output.
{ inputs, ... }:
{
  # Hardware-specific tweaks (Framework Desktop AI Max+ 395). Also declared
  # by nostromo's host.nix; identical declarations merge.
  flake-file.inputs.nixos-hardware.url = "github:NixOS/nixos-hardware/master";

  flake.modules.nixos.serenity = {
    imports = with inputs.self.modules.nixos; [
      # Hardware profile: AMD Strix Halo quirks, firmware, kernel params.
      inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
      pc
      shashin
      # Features (modules/features/) — importing is what enables them.
      plasma
      gaming
      lact
      nas
      llama-swap
      open-webui
      searxng
    ];

    networking.hostName = "serenity";

    # No fingerprint hardware on this desktop.
    services.fprintd.enable = false;

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
