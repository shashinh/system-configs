# CIFS mount of the home NAS.
{
  flake.modules.nixos.nas = {
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
        # Any stat() of the mount point fires the automount, and gvfs/Thunar
        # probe every fstab mount on launch and navigation. With the NAS
        # offline each probe blocked ~6s on EHOSTUNREACH. Hide it from gvfs
        # (the path still mounts on demand via Ctrl+L / cd) and cap the hang.
        "x-gvfs-hide"
        "x-systemd.mount-timeout=5s"
        "nofail"
        "_netdev"
      ];
    };
  };
}
