{ config, pkgs, inputs, ... } :

let
  # Chromium's (and so Signal's) keyring backend auto-detection keys off
  # XDG_CURRENT_DESKTOP, which is "niri" here, not KDE — so it silently
  # falls back to the weak "basic" store and can't decrypt data that was
  # encrypted under kwalletd6 while logged in under Plasma. Forcing the
  # backend explicitly makes it consistent across both sessions; kwalletd6
  # itself is DE-agnostic (a D-Bus-activatable service, already present
  # from services.desktopManager.plasma6.enable in configuration.nix) so it
  # unlocks the same way (via kwallet-pam at login) under niri too.
  #
  # This ties Signal's local database encryption to KDE staying installed
  # (kwalletd6 comes from Plasma). If KDE is ever fully removed from this
  # machine, switch --password-store here to "gnome-libsecret" (backed by
  # the standalone gnome-keyring package + its PAM module — no GNOME
  # desktop required) instead of falling back to "basic", which is
  # unencrypted in practice (Chromium's basic backend uses a fixed,
  # publicly-known key on Linux). Either backend switch requires Signal to
  # be re-linked as a new device, since the existing key doesn't migrate
  # between backends.
  signal-desktop-kwallet = pkgs.symlinkJoin {
    name = "signal-desktop";
    paths = [ pkgs.signal-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/signal-desktop --add-flags "--password-store=kwallet6"
    '';
  };
in

{
  home.username = "shashin";
  home.homeDirectory = "/home/shashin";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  imports = [
    ./home/bash.nix
    ./home/btop.nix
    ./home/default-apps.nix
    ./home/desktop-entries.nix
    ./home/git.nix
    ./home/gtk.nix
    ./home/kitty.nix
    ./home/neovim.nix
    ./home/tmux.nix
    ./home/vscode.nix
    ./home/yazi.nix
  ];

  home.packages = with pkgs; [
    # Fetch
    fastfetch

    # Browser
    ungoogled-chromium

    # Editors
    vim

    # Productivity
    zotero
    obsidian
    claude-code
    inputs.claude-code-statusline.packages.${pkgs.system}.default
    opencode
    onedrivegui
    libreoffice
    thunar
    tumbler # thumbnailer daemon Thunar talks to over D-Bus; registers its
            # own dbus-activated service, so no extra wiring needed here

    # Communicators
    signal-desktop-kwallet
    slack
    zoom-us

    # Basic utilities
    gdu
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
    playerctl
  ];
}
