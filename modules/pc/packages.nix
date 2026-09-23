# Baseline package set shared by every PC.
{ inputs, ... }:
{
  # Custom Claude Code status line.
  flake-file.inputs.claude-code-statusline = {
    url = "github:shashinh/claude-code-statusline";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.pc =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        # Fetch
        fastfetch

        # Version control
        git

        # Connectivity
        tailscale
        #mullvad-vpn
        ungoogled-chromium

        # Editors
        vim
        neovim

        # IDEs
        vscode

        # Productivity
        tmux
        zotero
        obsidian
        claude-code
        inputs.claude-code-statusline.packages.${pkgs.system}.default
        opencode
        onedrivegui
        libreoffice

        # Communicators
        #signal-desktop
        slack
        zoom-us

        # Secure Boot key management
        sbctl
        # TPM tools
        tpm2-tools
        tpm2-tss

        # Basic utilities
        gdu
        wget
        curl
        htop
        (btop.override { rocmSupport = true; })
        pciutils # lspci
        usbutils # lsusb
        lshw
        nvme-cli # NVMe SSD tools (health, firmware)
        btrfs-progs # btrfs subvolume / scrub / balance commands
        stow
        cifs-utils
        unrar
        lm_sensors
        temurin-jre-bin
        tldr
        piper
        libratbag
        kdePackages.koko
        kdePackages.kcalc
        kdePackages.plasma-browser-integration
        kdePackages.kdenlive
        kdePackages.plasma-vault
        kdePackages.keditbookmarks
        kde-rounded-corners
        zip
        amdgpu_top
        lact
        jq
        qbittorrent
        #bitwarden-desktop
        powertop

        # Framework
        framework-tool

        # Media
        vlc
        mpv
        gimp
        spotify
        stremio-linux-shell
        picard
      ];
    };
}
