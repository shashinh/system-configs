{ config, pkgs, inputs, ... } :

{
  home.username = "shashin";
  home.homeDirectory = "/home/shashin";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  imports = [
    ./home/htop.nix
  ];

  home.packages = with pkgs; [
    # Fetch
    fastfetch

    # Browser
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
    libreoffice-qt

    # Communicators
    signal-desktop
    slack
    zoom-us
    #bitwarden-desktop

    # Basic utilities
    gdu
    #htop
    (btop.override { rocmSupport = true; })
    stow
    unrar
    tldr
    zip
    jq

    kdePackages.koko
    kdePackages.kcalc
    kdePackages.kdenlive
    kdePackages.plasma-vault
    kdePackages.keditbookmarks

    qbittorrent

    # Media
    vlc
    mpv
    gimp
    spotify
    stremio-linux-shell
    picard
  ];
}
