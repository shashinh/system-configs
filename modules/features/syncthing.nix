# Syncthing: keeps /data/sync identical on every host that imports this
# feature. Runs as shashin, so synced files are owned by the user.
#
# Opting a host in:
#   1. Import `syncthing` in modules/hosts/<host>/host.nix. The host needs a
#      /data mount (serenity: data drive; nostromo: @data subvolume).
#   2. Rebuild, then read its device ID: `syncthing --device-id`
#      (or `syncthing cli show system | jq -r .myID`).
#   3. Put the ID in `registry` below and rebuild every peer.
# A registry entry with an empty id is skipped, so step 1 can land first.
#
# Device IDs are public identifiers (a hash of each device's TLS cert), not
# secrets. The cert/key live in the service's config dir under ~shashin, so a
# reinstall generates a new ID that must be pasted here again.
#
# Non-NixOS peers (Android, the NAS) join by adding a registry entry: they
# are not hosts here, so they never match networking.hostName and are always
# treated as peers.
#
# Addresses: each peer is dialed at its Tailscale MagicDNS name first, so sync
# goes over the tailnet from anywhere. LAN discovery is broadcast and doesn't
# cross tailscale0, and global discovery announces the public NAT address, so
# without these the off-LAN path would be NAT traversal or a public relay.
# "dynamic" keeps those as the fallback.
#
# overrideDevices/overrideFolders make this file the source of truth: devices
# or folders added in the GUI (http://127.0.0.1:8384) are dropped on restart.
{
  flake.modules.nixos.syncthing =
    { config, lib, pkgs, ... }:
    let
      tailnet = host: [
        "tcp://${host}:22000"
        "quic://${host}:22000"
        "dynamic"
      ];

      registry = {
        serenity = {
          id = "";
          addresses = tailnet "serenity";
        };
        nostromo = {
          id = "LEKICCE-TFTN53T-6TERRBA-QOYOVN3-RHXBKIT-57DJQHK-2Q6EFWP-6TEKTQF";
          addresses = tailnet "nostromo";
        };
      };

      peers = lib.filterAttrs (
        name: dev: name != config.networking.hostName && dev.id != ""
      ) registry;
    in
    {
      services.syncthing = {
        enable = true;
        user = "shashin";
        group = "users";
        dataDir = "/home/shashin";
        # 22000/tcp+udp (sync), 21027/udp (LAN discovery).
        openDefaultPorts = true;
        overrideDevices = true;
        overrideFolders = true;

        settings = {
          options.urAccepted = -1; # no usage-reporting prompt

          devices = lib.mapAttrs (_: dev: { inherit (dev) id addresses; }) peers;

          folders.shared = {
            id = "shared"; # peers match on this, not on the path
            path = "/data/sync";
            devices = lib.attrNames peers;
            # Deletes and edits propagate. Keep replaced/deleted files for 30
            # days in /data/sync/.stversions. Not a backup.
            versioning = {
              type = "staggered";
              params.maxAge = toString (30 * 24 * 3600);
            };
            # Pause instead of filling the disk.
            minDiskFree = {
              value = 5;
              unit = "%";
            };
          };
        };
      };

      # Never run against the bare mountpoint: if /data failed to mount
      # (nostromo's is nofail), Syncthing would see an empty folder and
      # could propagate that as deletions. Without the mount it doesn't start.
      systemd.services.syncthing.unitConfig.RequiresMountsFor = [ "/data/sync" ];

      # Create the folder after /data is mounted, as root ("+" skips the
      # unit's User= and sandbox), since shashin can't mkdir in a root-owned
      # /data (nostromo). Not a tmpfiles rule: on switch that ran before the
      # new /data mount and created the directory underneath it. `install -d`
      # leaves existing contents alone.
      systemd.services.syncthing.serviceConfig.ExecStartPre = [
        "+${pkgs.coreutils}/bin/install -d -o shashin -g users -m 0755 /data/sync"
      ];
    };
}
