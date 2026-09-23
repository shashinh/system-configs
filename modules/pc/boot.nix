# Boot chain shared by every PC: latest kernel, systemd initrd (required
# for TPM2 LUKS unlock), systemd-boot for initial installs, lanzaboote
# Secure Boot once keys are enrolled (INSTALL.md Phase 7).
{ inputs, ... }:
{
  # Secure Boot via signed Unified Kernel Images.
  # Replaces systemd-boot after keys are enrolled (see INSTALL.md Phase 7).
  flake-file.inputs.lanzaboote = {
    url = "github:nix-community/lanzaboote";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.pc =
    { lib, pkgs, ... }:
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      boot = {

        # ── Kernel ──────────────────────────────────────────────────────────
        # linuxPackages_latest has the latest stable kernel.
        # The nixos-hardware module may override this — that's fine, it picks
        # the best option for the chip.
        kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

        kernelModules = [ "kvm-amd" ];

        # Filesystems the initrd and kernel need to know about.
        supportedFilesystems = [ "btrfs" ];

        # ── initrd ──────────────────────────────────────────────────────────
        initrd = {
          availableKernelModules = [
            "nvme"
            "xhci_pci"
            "thunderbolt"
            "usb_storage"
            "sd_mod"
          ];

          kernelModules = [ "amdgpu" ];

          # systemd-based initrd is REQUIRED for TPM2 LUKS unlock via
          # systemd-cryptenroll. It replaces the older scripted (busybox) initrd.
          systemd.enable = true;

          # ── Impermanence: wipe / on boot ──────────────────────────────────
          # This service restores @root from @root-blank before / is mounted,
          # giving you a clean slate on every boot.
          #
          # DISABLED until you are ready to enable full impermanence.
          # To enable: uncomment the block below, then `nixos-rebuild switch`.
          # Prerequisites: @root-blank must exist (created by disko postCreateHook).
          #
          # systemd.services.wipe-root = {
          #   description   = "Restore BTRFS @root to blank snapshot";
          #   wantedBy      = [ "initrd.target" ];
          #   requires      = [ "systemd-cryptsetup@cryptroot.service" ];
          #   after         = [ "systemd-cryptsetup@cryptroot.service" ];
          #   before        = [ "sysroot.mount" ];
          #   unitConfig.DefaultDependencies = "no";
          #   serviceConfig = {
          #     Type = "oneshot";
          #     ExecStart = pkgs.writeShellScript "wipe-root" ''
          #       mkdir -p /mnt
          #       mount -t btrfs -o subvol=/ /dev/mapper/cryptroot /mnt
          #       trap 'umount /mnt' EXIT
          #
          #       if [ ! -d /mnt/@root-blank ]; then
          #         echo "ERROR: @root-blank not found — aborting wipe!" >&2
          #         exit 1
          #       fi
          #
          #       # Delete nested subvolumes of @root first, then @root itself.
          #       btrfs subvolume list -o /mnt/@root \
          #         | awk '{print $NF}' \
          #         | while read sv; do
          #             echo "Deleting nested subvolume: $sv"
          #             btrfs subvolume delete "/mnt/$sv"
          #           done
          #
          #       echo "Deleting @root..."
          #       btrfs subvolume delete /mnt/@root
          #
          #       echo "Restoring @root from @root-blank..."
          #       btrfs subvolume snapshot /mnt/@root-blank /mnt/@root
          #     '';
          #   };
          # };
        };

        # ── Bootloader ──────────────────────────────────────────────────────
        loader = {
          # systemd-boot is used for the INITIAL install.
          # After enrolling Secure Boot keys (Phase 7 of INSTALL.md),
          # you disable this and enable lanzaboote below.
          systemd-boot = {
            enable = lib.mkDefault false;
            configurationLimit = 10; # keep 10 boot entries on the ESP
            editor = false; # disables boot-time kernel param editing (security)
          };

          efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot";
          };
        };

        # ── Lanzaboote (Secure Boot) ────────────────────────────────────────
        # Enabled after Phase 7 of INSTALL.md (sbctl key enrollment);
        # lanzaboote mkForces systemd-boot off automatically.
        # Verify with: sbctl verify && sbctl status
        lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl"; # symlinked to /persist on serenity ("not yet" on nostromo); survives future impermanence wipe
        };

      };

      # LVFS/fwupd firmware updates and this Secure Boot + TPM setup:
      # - Secure Boot itself (PK/KEK/db in NVRAM) is normally untouched by a BIOS
      #   update — lanzaboote's signing key stays enrolled. Rare exception: some
      #   vendor updates reset Secure Boot to Setup Mode / factory keys, and LVFS
      #   also ships UEFI dbx (revocation list) updates that intentionally modify
      #   the Secure Boot database. Run `sbctl status` after any fwupd update.
      # - TPM+PIN LUKS unlock (see INSTALL.md Phase 7, `--tpm2-pcrs=0+7`) WILL
      #   break on a firmware update: PCR 0 measures firmware code, so it changes
      #   on every flash. Expect "cryptroot: No key available" on next boot —
      #   unlock with the LUKS passphrase, then re-enroll TPM on both drives (see
      #   INSTALL.md Troubleshooting). Consider dropping PCR 0 (use `--tpm2-pcrs=7`
      #   only) to avoid this churn, at the cost of no longer detecting firmware
      #   tampering via PCR — PCR 7 alone still catches Secure Boot being
      #   disabled or the key database changing, which is the main threat model.
    };
}
