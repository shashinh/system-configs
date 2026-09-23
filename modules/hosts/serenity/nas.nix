# CIFS mount of the home NAS.
{
  flake.modules.nixos.serenity = {
    # Ensure the mount point exists
    system.activationScripts.makeNasDir = "mkdir -p /mnt/nas/optiprox-share";

    fileSystems."/mnt/nas/optiprox-share" = {
      device = "//192.168.0.62/optiprox-share";
      fsType = "cifs";
      options = [
        "username=shashin"
        "uid=1000"
        "gid=1000"
        "credentials=/home/shashin/.smb/creds"
        "noauto"
        "x-systemd.automount" # Optional: mounts automatically when accessed
        "x-systemd.idle-timeout=60" # Optional: unmounts after 60s of inactivity
      ];
    };
  };
}
