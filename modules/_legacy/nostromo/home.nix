{ config, pkgs, inputs, ... } :

let
  # signal-desktop's .desktop file just execs `signal-desktop %U`, so any
  # app launcher (Noctalia's included) runs it with no flags — Chromium's
  # desktop-environment auto-detection for its libsecret backend then
  # depends on XDG_CURRENT_DESKTOP being propagated to the child process,
  # which isn't reliable across launchers. Forcing
  # --password-store=gnome-libsecret sidesteps auto-detection entirely, so
  # Signal always talks to the standalone GNOME Keyring daemon
  # (services.gnome.gnome-keyring.enable in configuration.nix; no GNOME
  # desktop required — it implements the same Secret Service D-Bus API).
  # Confirmed via ~/.config/Signal/config.json: without the flag, Signal
  # falls back to storing its SQLCipher key in plaintext ("key"); with it,
  # the key is wrapped by the keyring ("encryptedKey").
  signal-desktop-libsecret = pkgs.symlinkJoin {
    name = "signal-desktop";
    paths = [ pkgs.signal-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/signal-desktop --add-flags "--password-store=gnome-libsecret"
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
    xfce.thunar-archive-plugin # adds "Compress..."/"Extract..." to Thunar's
                                # context menu; shells out to an archive
                                # manager below rather than doing it itself
    xarchiver # lightweight archive manager the plugin above drives; uses
              # zip/unrar (already installed) as backends

    # Communicators
    signal-desktop-libsecret
    slack
    zoom-us

    # Basic utilities
    gdu
    stow
    unrar
    tldr
    zip
    jq

    qbittorrent

    # Media
    vlc
    mpv
    gimp
    spotify
    stremio-linux-shell
    picard
    playerctl
    loupe # image viewer — GTK4/libadwaita handles niri's fractional
          # output scaling correctly, unlike imv which drew its own
          # cursor at nominal size and looked tiny under scale != 1
  ];
}
