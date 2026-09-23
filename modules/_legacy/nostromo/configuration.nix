# ─── NOSTROMO — SYSTEM CONFIGURATION (host-specific residue) ────────────────
# Framework 13 AMD 7840
# NixOS with niri + Noctalia (KDE Plasma removed 2026-08-27)
# greetd + tuigreet, lanzaboote secure boot, TPM2+PIN LUKS unlock
# Shared PC baseline lives in modules/pc/.
# ─────────────────────────────────────────────────────────────────────────────

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./niri.nix
    ./kanata.nix
    # ./power-profile.nix
  ];

  # ===========================================================================
  # HARDWARE (host-specific)
  # ===========================================================================

  hardware.i2c.enable = true;

  #QMK support
  hardware.keyboard.qmk.enable = true;

  # ===========================================================================
  # NETWORKING
  # ===========================================================================

  networking.hostName = "nostromo";

  # ===========================================================================
  # DISPLAY MANAGER
  # ===========================================================================

  # tuigreet as greeter
  environment.etc."tuigreet/config.toml".source =
    (pkgs.formats.toml { }).generate "tuigreet-config.toml" {
      display.show_time = true;
      # display.greeting = "";
      # display.align_greeting = "center";
      remember = {
        username = true;
        session = true;
      };
      session = {
        # only list the Wayland sessions, edit if X11 is required
        sessions_dirs = [ "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions" ];
        xsessions_dirs = [ ];
      };
    };

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session.command = "${lib.getExe pkgs.tuigreet} --config /etc/tuigreet/config.toml";
  };

  # ===========================================================================
  # NOCTALIA
  # ===========================================================================
  # Quickshell-based desktop shell (bar, launcher, notifications, control
  # center). Required services (NetworkManager, Bluetooth, UPower,
  # power-profiles-daemon) are already enabled in the pc baseline, so
  # recommendedServices is left off rather than re-asserting them opaquely.

  programs.noctalia.enable = true;

  # Xfconf: lets Thunar persist per-folder view settings (list/icon/compact).
  programs.xfconf.enable = true;

  # ===========================================================================
  # REMOVABLE MEDIA / TRASH
  # ===========================================================================
  # Thunar (GTK/gio-based) needs gvfs for the trash:// backend — without it,
  # deletes bypass Trash entirely and are permanent. Plasma pulled this in
  # transitively via services.desktopManager.plasma6.enable; removing Plasma
  # dropped it silently, same as the fonts.packages gap noted above.
  #
  # udisks2 is already forced on by services.fwupd.enable (pc baseline,
  # needed for disk firmware updates), but it's enabled explicitly here too
  # so the desktop's dependency on it isn't implicit.
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  # ===========================================================================
  # SECRETS
  # ===========================================================================
  # Standalone GNOME Keyring (Secret Service D-Bus API), for Chromium/
  # Electron apps' libsecret backend now that KDE's kwalletd6 is gone. Just
  # the daemon + PAM auto-unlock wiring; no GNOME desktop required.
  # Consumer: home-manager's signal-desktop-libsecret wrapper.
  services.gnome.gnome-keyring.enable = true;

  # ===========================================================================
  # SWAP
  # ===========================================================================
  # zram is RAM-backed and fast, so the kernel should reach for it much more
  # eagerly than it would for disk-backed swap (default swappiness = 60).
  boot.kernel.sysctl."vm.swappiness" = 150;

  # ===========================================================================
  # FINGERPRINT READER
  # ===========================================================================

  services.fprintd.enable = true;

  # security.pam.services.*.fprintAuth defaults to services.fprintd.enable for
  # every PAM service, which wires the reader into "login" (and therefore
  # greetd, which substacks login) even though the reader never matches at
  # the greeter — each boot ate a flat 30s PAM timeout before falling back
  # to password. Disable it there; sudo keeps the default (true).
  security.pam.services.login.fprintAuth = false;

  # ===========================================================================
  # USER ACCOUNT (host-specific groups)
  # ===========================================================================

  users.users.shashin.extraGroups = [ "i2c" ];

  # ===========================================================================
  # VIRTUALISATION / CONTAINERS
  # ===========================================================================
  # Rootless Podman (no persistent root daemon, unlike Docker).
  virtualisation.podman.enable = true;

  # ===========================================================================
  # SYSTEM PACKAGES
  # ===========================================================================
  # Only system-wide tools go here. Per-user packages belong in Home Manager
  # (a future addition) or in users.users.shashin.packages.

  environment.systemPackages = with pkgs; [
    # Wayland utilities
    wl-clipboard         # wl-copy / wl-paste
    xdg-utils            # xdg-open etc.
    evtest

    ddcutil
    nwg-look
    adw-gtk3
    papirus-icon-theme
    udiskie

    kdePackages.okular
  ];

  # ===========================================================================
  # FONTS
  # ===========================================================================

  # noto-fonts/-color-emoji and nerd-fonts.jetbrains-mono used to arrive
  # transitively via services.desktopManager.plasma6.enable (its module
  # adds fonts.packages = [ cfg.notoPackage pkgs.hack-font ]), so the
  # fontconfig defaultFonts silently resolved even though nothing
  # here installed them explicitly. Removing KDE dropped that and every
  # default fell back to DejaVu — now installed explicitly instead.
  fonts.packages =  with pkgs; [
  	font-awesome
  	nerd-fonts.fira-code
	  nerd-fonts.droid-sans-mono
  	nerd-fonts.jetbrains-mono
  	noto-fonts
  	noto-fonts-color-emoji
  ];

  # ===========================================================================
  # STATE VERSION
  # ===========================================================================
  # This records the NixOS release at which this system was FIRST installed.
  # It controls defaults for stateful data (file locations, DB schemas, etc.).
  # DO NOT change this after the initial install — it is not a "keep up to date"
  # setting. Read the docs before changing it.
  system.stateVersion = "26.05";

  # ===========================================================================
  # PRINTING (CUPS)
  # ===========================================================================
  # CS department network printer at UT Austin, GDC, 5S (printserv-auth.cs.utexas.edu).
  # `services.printing.enable` installs and runs CUPS itself; the printer
  # below is registered declaratively via a oneshot systemd service that runs
  # the department's `lpadmin` setup command on every boot (idempotent).
  #
  # `printer` / `user` below are placeholders — fill in before this takes
  # effect. There's no password to configure here: registering the queue
  # doesn't require auth, and per-job auth happens interactively at print
  # time (see NOTE below), handled by the print dialog or a secret store —
  # not by lpadmin or this config.
  #
  # NOTE — printing workflow (per CS IT instructions):
  #   1. When selecting this printer to print, you'll be prompted for a
  #      username/password. Click "Cancel".
  #   2. Click "Print".
  #   3. You'll be prompted again — this time enter your CS username and
  #      password. Some desktop environments offer a checkbox to save it.
  #   4. Repeat steps 1-3 for every print job (unless the password was saved).
  #
  # If `-m everywhere` fails with "Unable to create PPD: No IPP attributes.",
  # drop the `-m everywhere` line below.

  services.printing.enable = true;

  systemd.services.setup-cs-printer = {
    description = "Register CS department network printer with CUPS";
    wantedBy = [ "multi-user.target" ];
    wants    = [ "cups.service" ];
    after    = [ "cups.service" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script =
      let
        printer = "pr-5s"; # e.g. "sequoia-color" -- printer name on printserv-auth.cs.utexas.edu
        user    = "shashin"; # your CS username (see printing workflow note above)
      in ''
        ${pkgs.cups}/bin/lpadmin -p ${printer} -U ${user} \
          -v ipps://printserv-auth.cs.utexas.edu:631/printers/${printer} \
          -E \
          -o APOptionalDuplexer=True \
          -o printer-error-policy=abort-job
      '';
  };
 }
