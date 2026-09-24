# Noctalia — Quickshell-based desktop shell (bar, launcher, notifications,
# control center) and the desktop services the niri+Noctalia session needs.
# Required services (NetworkManager, Bluetooth, UPower,
# power-profiles-daemon) are already enabled in the pc baseline, so
# recommendedServices is left off rather than re-asserting them opaquely.
{ inputs, ... }:
{
  # Noctalia — Quickshell-based desktop shell.
  flake-file.inputs.noctalia = {
    url = "github:noctalia-dev/noctalia";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.noctalia = {
    imports = [ inputs.noctalia.nixosModules.default ];

    # Deliver the home-manager half of this feature (dotfiles.nix, and the
    # sops-rendered plugin settings in wallhaven-secret.nix) to every HM user
    # on the host. This is the single wiring point for the user-side config —
    # keep it here, not in a sibling that a future cleanup might delete.
    #
    # Requires the host to enable home-manager (import `home-shashin`).
    home-manager.sharedModules = [ inputs.self.modules.homeManager.noctalia ];

    programs.noctalia.enable = true;

    # Xfconf: lets Thunar persist per-folder view settings (list/icon/compact).
    programs.xfconf.enable = true;

    # ── Removable media / trash ─────────────────────────────────────────────
    # Thunar (GTK/gio-based) needs gvfs for the trash:// backend — without it,
    # deletes bypass Trash entirely and are permanent. Plasma pulled this in
    # transitively via services.desktopManager.plasma6.enable; removing Plasma
    # dropped it silently, same as the fonts.packages gap noted in fonts.nix.
    #
    # udisks2 is already forced on by services.fwupd.enable (pc baseline,
    # needed for disk firmware updates), but it's enabled explicitly here too
    # so the desktop's dependency on it isn't implicit.
    services.gvfs.enable = true;
    services.udisks2.enable = true;

    # ── Secrets ─────────────────────────────────────────────────────────────
    # Standalone GNOME Keyring (Secret Service D-Bus API), for Chromium/
    # Electron apps' libsecret backend now that KDE's kwalletd6 is gone. Just
    # the daemon + PAM auto-unlock wiring; no GNOME desktop required.
    # Consumer: home-manager's signal-desktop-libsecret wrapper.
    services.gnome.gnome-keyring.enable = true;
  };
}
