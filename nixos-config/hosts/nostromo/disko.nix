# ─── DISKO DISK LAYOUT FOR NOSTROMO ─────────────────────────────────────────
#
# Primary SSD  (1 TB)  /dev/nvme0n1  ← UPDATE if lsblk shows otherwise
#   Part 1: ESP  2 GiB  FAT32  mounted at /boot
#           Holds lanzaboote-signed UKIs for every NixOS generation.
#           2 GiB is generous: each UKI ≈ 80-150 MB, so 10+ generations fit.
#   Part 2: LUKS2 (cryptroot) → BTRFS "nixos"
#           Subvolumes:
#             @root      /             ← wiped on boot once impermanence is on
#             @home      /home         ← persists across reboots always
#             @nix       /nix          ← the Nix store; never wiped
#             @persist   /persist      ← explicit persistent state
#             @log       /var/log      ← logs survive reboots
#             @snapshots /.snapshots   ← BTRFS snapshot target
#           postCreateHook creates @root-blank so the wipe service has a target.
#
# Singular LUKS device:
#   - LUKS2 format with argon2id PBKDF (required by systemd-cryptenroll/TPM)
#   - allowDiscards = true (SSD TRIM; acceptable trade-off for a home desktop)
#   - After install: enroll both to TPM2+PIN via systemd-cryptenroll (Phase 8)
#
# ─────────────────────────────────────────────────────────────────────────────
#
# !! BEFORE RUNNING DISKO !!
# Verify device names with:   lsblk -d -o NAME,SIZE,MODEL
# Update the `device` fields below to match your actual drives.
#
# ─────────────────────────────────────────────────────────────────────────────

{ ... }:

{
  disko.devices = {
    disk = {

      # ── PRIMARY: 1 TB system drive ─────────────────────────────────────────
      primary = {
        type   = "disk";
        device = "/dev/nvme0n1";   # ← VERIFY with lsblk before running disko

        content = {
          type = "gpt";

          partitions = {

            # EFI System Partition ─────────────────────────────────────────────
            ESP = {
              label    = "ESP";
              size     = "2G";
              type     = "EF00";       # EFI System partition type GUID
              content  = {
                type         = "filesystem";
                format       = "vfat";
                mountpoint   = "/boot";
                mountOptions = [ "defaults" "umask=0077" ];
              };
            };

            # Encrypted system partition ────────────────────────────────────
            luks_system = {
              label = "nixos-luks";
              size  = "100%";
              content = {
                type = "luks";
                name = "cryptroot";        # becomes /dev/mapper/cryptroot

                # Extra cryptsetup format arguments.
                # --type luks2      : explicit LUKS2 (required for systemd-cryptenroll / TPM)
                # --pbkdf argon2id  : modern PBKDF (required for TPM enrollment)
                # --iter-time 3000  : 3-second KDF work factor (strong passphrase hashing)
                extraFormatArgs = [
                  "--type"      "luks2"
                  "--pbkdf"     "argon2id"
                  "--iter-time" "3000"
                ];

                # These map to boot.initrd.luks.devices.cryptroot.* in NixOS.
                settings = {
                  allowDiscards = true;   # enable TRIM on the SSD
                };

                content = {
                  type      = "btrfs";
                  extraArgs = [ "-L" "nixos" "-f" ];    # label the pool "nixos"

                  subvolumes = {
                    # Root — intentionally wiped on each boot once you enable
                    # impermanence. Keep clean: NixOS writes here at activation,
                    # your personal data lives in @home and @persist.
                    "@root" = {
                      mountpoint   = "/";
                      mountOptions = [ "compress=zstd" "noatime" "space_cache=v2" ];
                    };

                    # Home — always persists; your user files live here.
                    "@home" = {
                      mountpoint   = "/home";
                      mountOptions = [ "compress=zstd" "noatime" "space_cache=v2" ];
                    };

                    # Nix store — large, never wiped.
                    "@nix" = {
                      mountpoint   = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" "space_cache=v2" ];
                    };

                    # Explicit persistence — SSH host keys, secrets, machine ID,
                    # NetworkManager connections, and anything else you declare
                    # via environment.persistence in the future go here.
                    "@persist" = {
                      mountpoint   = "/persist";
                      mountOptions = [ "compress=zstd" "noatime" "space_cache=v2" ];
                    };

                    # Logs — survives reboots so you can diagnose past crashes.
                    "@log" = {
                      mountpoint   = "/var/log";
                      mountOptions = [ "compress=zstd" "noatime" "space_cache=v2" ];
                    };

                    # Snapshot target — used by snapper or manual btrfs snapshots.
                    "@snapshots" = {
                      mountpoint   = "/.snapshots";
                      mountOptions = [ "compress=zstd" "noatime" "space_cache=v2" ];
                    };
                  };

                  # Create a read-only blank snapshot of @root immediately after
                  # formatting. The impermanence wipe service (in configuration.nix)
                  # restores @root from this snapshot at every boot once enabled.
                  postCreateHook = ''
                    MNTPOINT=$(mktemp -d)
                    mount -t btrfs -o subvol=/ /dev/mapper/cryptroot "$MNTPOINT"
                    trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                    echo "Creating @root-blank read-only snapshot..."
                    btrfs subvolume snapshot -r "$MNTPOINT/@root" "$MNTPOINT/@root-blank"
                    echo "Done. Snapshot @root-blank created."
                  '';
                };
              };
            };
          };
        };
      };
    };
  };
}
