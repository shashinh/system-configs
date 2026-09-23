# Baseline system services shared by every PC.
{
  flake.modules.nixos.pc = {
    services = {
      # Allow firmware updates (LVFS/fwupd) — Framework ships BIOS updates here.
      fwupd.enable = true;

      # D-Bus message bus (required by most desktop apps).
      dbus.enable = true;

      # Power management.
      power-profiles-daemon.enable = true;

      # Battery/AC state over D-Bus (upowerd). Currently on only as a side
      # effect of plasma6.enable; set explicitly so it doesn't depend on
      # Plasma staying enabled.
      upower.enable = true;

      # tailscale
      tailscale.enable = true;

      openssh.enable = true;

      #flatpak
      flatpak.enable = true;
    };
  };
}
