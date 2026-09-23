{ pkgs, ... }:

# KDE's PowerDevil auto-switches the power-profiles-daemon profile on AC
# plug/unplug; Noctalia has no equivalent (it only offers a manual toggle
# widget backed by the same daemon). This replicates that behavior directly
# against power-profiles-daemon via udev, but only when PowerDevil isn't the
# one already doing it — PowerDevil (org_kde_powerdevil) reacts to the same
# AC event through the same daemon, so running both in a Plasma session
# would race them against each other over the same D-Bus call.
let
  script = pkgs.writeShellScript "power-profile-auto" ''
    set -euo pipefail
    if ${pkgs.procps}/bin/pgrep -x org_kde_powerdevil >/dev/null; then
      exit 0
    fi
    if [ "$(cat /sys/class/power_supply/ACAD/online)" = "1" ]; then
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance
    else
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
    fi
  '';
in
{
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="ACAD", ACTION=="change", RUN+="${script}"
  '';

  # Apply the correct profile at boot too, since udev won't fire again for
  # the adapter state that was already true before the daemon started.
  systemd.services.power-profile-auto = {
    description = "Set power profile based on AC adapter state at boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "power-profiles-daemon.service" ];
    requires = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${script}";
    };
  };
}
