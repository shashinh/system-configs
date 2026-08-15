{
  description = "A collection of Nix configs";

  # ─── INPUTS ─────────────────────────────────────────────────────────────────
  # Each input is an external dependency your config pulls in.
  # `inputs.nixpkgs.follows = "nixpkgs"` means a sub-dependency reuses YOUR
  # nixpkgs pin instead of fetching its own, keeping everything in sync.
  inputs = {
    # nixos-unstable gives us the latest kernel (6.13+) for Strix Halo support.
    # Switch to "github:NixOS/nixpkgs/nixos-25.11" once you want a stable channel.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Hardware-specific tweaks for the Framework Desktop AI Max+ 395.
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Declarative disk partitioning — replaces manual parted/mkfs commands.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secure Boot via signed Unified Kernel Images.
    # Replaces systemd-boot after keys are enrolled (see INSTALL.md Phase 7).
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative opt-in persistence — used later to finish impermanence setup.
    impermanence.url = "github:nix-community/impermanence";

    # Custom Claude Code status line.
    claude-code-statusline = {
      url = "github:shashinh/claude-code-statusline";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ─── OUTPUTS ────────────────────────────────────────────────────────────────
  # `outputs` is a function that receives all the resolved inputs and returns
  # the things this flake provides. For a NixOS config the only thing we need
  # is `nixosConfigurations`.
  outputs = { self, nixpkgs, nixos-hardware, disko, lanzaboote, impermanence, ... } @ inputs:
  {
    nixosConfigurations.serenity = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      # `specialArgs` lets every module receive `inputs` as a function argument.
      # This is how configuration.nix can reference lanzaboote.nixosModules, etc.
      specialArgs = { inherit inputs; };

      modules = [
        # ── Hardware profile ──────────────────────────────────────────────────
        # Configures AMD Strix Halo quirks, firmware, kernel params, etc.
        nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series

        # ── Disko ─────────────────────────────────────────────────────────────
        # Makes `disko.devices` a valid NixOS option and wires fileSystems/LUKS.
        disko.nixosModules.disko

        # ── Lanzaboote ────────────────────────────────────────────────────────
        # The module is imported now so the option exists; it is DISABLED in
        # configuration.nix until Phase 7 of the install guide.
        lanzaboote.nixosModules.lanzaboote

        # ── Impermanence ──────────────────────────────────────────────────────
        # Module imported now; activated later when you enable impermanence.
        impermanence.nixosModules.impermanence

        # ── Host-specific config ───────────────────────────────────────────────
        ./hosts/serenity/disko.nix
        ./hosts/serenity/hardware-configuration.nix  # generated during install
        ./hosts/pc-common.nix
        ./hosts/serenity/configuration.nix

      ];
    };

    nixosConfigurations.nostromo = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      # `specialArgs` lets every module receive `inputs` as a function argument.
      # This is how configuration.nix can reference lanzaboote.nixosModules, etc.
      specialArgs = { inherit inputs; };

      modules = [
        # ── Hardware profile ──────────────────────────────────────────────────
        # Configures Framework 13 AMD 7040 series quirks, firmware, kernel params, etc.
        nixos-hardware.nixosModules.framework-13-7040-amd

        # ── Disko ─────────────────────────────────────────────────────────────
        # Makes `disko.devices` a valid NixOS option and wires fileSystems/LUKS.
        disko.nixosModules.disko

        # ── Lanzaboote ────────────────────────────────────────────────────────
        # The module is imported now so the option exists; it is DISABLED in
        # configuration.nix until Phase 7 of the install guide.
        lanzaboote.nixosModules.lanzaboote

        # ── Impermanence ──────────────────────────────────────────────────────
        # Module imported now; activated later when you enable impermanence.
        impermanence.nixosModules.impermanence

        # ── Host-specific config ───────────────────────────────────────────────
        ./hosts/nostromo/disko.nix
        ./hosts/nostromo/hardware-configuration.nix  # generated during install
        ./hosts/pc-common.nix
        ./hosts/nostromo/configuration.nix
      ];
    };
  };
}
