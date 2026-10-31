{
  flake.modules.nixos.pc = {
    nix = {
      settings = {
        # Enable the `nix` CLI and flakes (both are experimental but stable in
        # practice; required for this entire configuration to work).
        experimental-features = [
          "nix-command"
          "flakes"
        ];

        # Deduplicate identical files in the Nix store (saves disk space).
        auto-optimise-store = true;

        # Trusted users can add binary caches without sudo.
        trusted-users = [
          "root"
          "shashin"
        ];
      };

      # Weekly garbage collection: delete generations older than 30 days.
      # This prevents the Nix store from growing unboundedly.
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    };

    # Allow installing packages with non-free licenses (e.g. some firmware,
    # CUDA, Steam). This does NOT install anything; it just allows it.
    nixpkgs.config.allowUnfree = true;

    # zotero 10 needs Gecko 140, and nixpkgs ships it as this prebuilt Firefox
    # ESR, EOL since 2026-10-13. Bump the version when a lock update asks for
    # it; drop this once nixpkgs moves zotero to Gecko 153.
    nixpkgs.config.permittedInsecurePackages = [
      "firefox-esr-140-bin-unwrapped-140.17.0esr"
    ];
  };
}
