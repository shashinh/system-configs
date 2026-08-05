{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Fetch
    fastfetch

    # Version control
    git

    # Connectivity
    tailscale
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
    opencode
    onedrivegui
    libreoffice-qt

    # Communicators
    signal-desktop
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
    pciutils     # lspci
    usbutils     # lsusb
    lshw
    nvme-cli     # NVMe SSD tools (health, firmware)
    btrfs-progs  # btrfs subvolume / scrub / balance commands
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
    jq
    qbittorrent
    bitwarden-desktop

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

  services = {
    # Allow firmware updates (LVFS/fwupd) — Framework ships BIOS updates here.
    fwupd.enable = true;

    # D-Bus message bus (required by most desktop apps).
    dbus.enable = true;

    # Power management.
    power-profiles-daemon.enable = true;

    # Bluetooth.
    blueman.enable = true;

    # tailscale
    tailscale.enable = true;

    openssh.enable = true;

    #flatpak
    flatpak.enable = true;
   };

  hardware.bluetooth = {
    enable      = true;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "dual";
        JustWorksRepairing = "confirm";
      };
    };
  };

  programs = {
    # Git global config (minimal — user-level config belongs in Home Manager).
    git.enable = true;

    # dconf is required by GNOME/GTK apps and some KDE settings.
    dconf.enable = true;
  
    firefox = {
      enable = true;
      nativeMessagingHosts.packages = [ pkgs.kdePackages.plasma-browser-integration ];
    };

    kdeconnect.enable = true;
  };

}
