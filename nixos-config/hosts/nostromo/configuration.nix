# ─── NOSTROMO — SYSTEM CONFIGURATION ────────────────────────────────────────
# Framework 13 AMD 7840
# NixOS with KDE Plasma 6
# Plasma Login Manager, lanzaboote secure boot, TPM2+PIN LUKS unlock
# ─────────────────────────────────────────────────────────────────────────────

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./plasma-xdg-fix.nix
  ];

  # ===========================================================================
  # BOOT
  # ===========================================================================

  boot = {

    # ── Kernel ────────────────────────────────────────────────────────────────
    # linuxPackages_latest has the latest stable kernel.
    # The nixos-hardware module may override this — that's fine, it picks the best option for the chip.
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    kernelModules = [ "kvm-amd" ];

    # Filesystems the initrd and kernel need to know about.
    supportedFilesystems = [ "btrfs" ];

    # ── initrd ────────────────────────────────────────────────────────────────
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

      # ── Impermanence: wipe / on boot ──────────────────────────────────────
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

    # ── Bootloader ────────────────────────────────────────────────────────────
    loader = {
      # systemd-boot is used for the INITIAL install.
      # After enrolling Secure Boot keys (Phase 7 of INSTALL.md),
      # you will disable this and enable lanzaboote below.
      systemd-boot = {
        enable        = lib.mkDefault false;
        configurationLimit = 10;    # keep 10 boot entries on the ESP
        editor         = false;     # disables boot-time kernel param editing (security)
      };

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint     = "/boot";
      };
    };

    # ── Lanzaboote (Secure Boot) ──────────────────────────────────────────────
    # DISABLED until Phase 7 of INSTALL.md (after sbctl key enrollment).
    # To enable:
    #   1. Complete Phase 7 (enroll keys, set UEFI to user mode).
    #   2. Comment out `boot.loader.systemd-boot.enable` above (or the mkDefault
    #      line; lanzaboote will mkForce it off automatically).
    #   3. Uncomment the block below.
    #   4. Run: sudo nixos-rebuild switch
    #   5. Reboot and verify: sbctl verify && sbctl status
    #
     lanzaboote = {
       enable    = true;
       pkiBundle = "/var/lib/sbctl";  # (not yet) symlinked to /persist, survives future impermanence wipe
     };

  };

  # ===========================================================================
  # FILESYSTEMS (extra options not covered by disko)
  # ===========================================================================

  # /persist must be available before activation scripts run so that
  # NetworkManager connections, SSH host keys, and secrets are in place.
  fileSystems."/persist".neededForBoot = true;

  # /var/log is also mounted early to capture boot-time logs.
  fileSystems."/var/log".neededForBoot = true;

  # ===========================================================================
  # HARDWARE
  # ===========================================================================

  hardware = {
    # Loads non-free firmware blobs (WiFi, Bluetooth, AMD GPU microcode).
    enableRedistributableFirmware = true;

    # The nixos-hardware module enables most of this; these are belt-and-
    # suspenders settings.
    amdgpu = {
      opencl.enable   = true;   # OpenCL compute (needed for some apps)
	    # flake check warned below is not needed
      # amdvlk.enable   = false;  # use Mesa RADV (better for games/Wayland)
    };

    # Mesa OpenGL/Vulkan + 32-bit compatibility (Steam, Wine).
    graphics = {
      enable      = true;
      enable32Bit = true;
    };

    # CPU microcode updates (applied at boot, before userspace starts).
    cpu.amd.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;
  };

  # TPM2 support — used by systemd-cryptenroll to seal LUKS keys.
  security.tpm2 = {
    enable               = true;
    pkcs11.enable        = true;   # exposes TPM as a PKCS#11 device
    tctiEnvironment.enable = true; # sets TCTI env vars for TPM tools
  };

  # ===========================================================================
  # NETWORKING
  # ===========================================================================

  networking = {
    hostName       = "nostromo";
    networkmanager.enable = true;
    # Firewall is enabled by default; open ports here as needed later.
    firewall.enable = true;
  };

  # ===========================================================================
  # TIME AND LOCALE
  # ===========================================================================

  time.timeZone = "America/Chicago";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    # Keep all LC_ variables consistent.
    extraLocaleSettings = {
      LC_ADDRESS        = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT    = "en_US.UTF-8";
      LC_MONETARY       = "en_US.UTF-8";
      LC_NAME           = "en_US.UTF-8";
      LC_NUMERIC        = "en_US.UTF-8";
      LC_PAPER          = "en_US.UTF-8";
      LC_TELEPHONE      = "en_US.UTF-8";
      LC_TIME           = "en_US.UTF-8";
    };
  };

  console.keyMap = "us";

  # ===========================================================================
  # DISPLAY MANAGER
  # ===========================================================================

  services.displayManager.plasma-login-manager = {
    enable = true;
    package = pkgs.kdePackages.plasma-login-manager;
  };
  
  # ===========================================================================
  # DESKTOP ENVIRONMENTS
  # ===========================================================================

  xdg.portal = {
    enable = true;
  };

  services.desktopManager.plasma6.enable = true;

  # ===========================================================================
  # AUDIO (PipeWire)
  # ===========================================================================

  services.pipewire = {
    enable            = true;
    alsa.enable       = true;
    alsa.support32Bit = true;  # 32-bit apps (Wine, Steam)
    pulse.enable      = true;  # PulseAudio compatibility layer
    jack.enable       = true;  # JACK compatibility (audio production)
  };

  # RealtimeKit — lets PipeWire get real-time scheduling priority.
  security.rtkit.enable = true;

  # ===========================================================================
  # SWAP: ZRAM
  # ===========================================================================
  # zram creates a compressed in-RAM swap device — no disk space used.
  # algorithm = zstd gives the best compression/speed ratio.
  # memoryPercent = 50 means zram can use up to half of physical RAM.
  # With 128 GB RAM, that's 64 GB of compressed swap — far more than you
  # will ever need. Lower this to 25 if you prefer a conservative setting.
  #
  # There is NO disko configuration for zram. This NixOS option is all you need.
  zramSwap = {
    enable        = true;
    algorithm     = "zstd";
    memoryPercent = 50;
  };

  # zram is RAM-backed and fast, so the kernel should reach for it much more
  # eagerly than it would for disk-backed swap (default swappiness = 60).
  boot.kernel.sysctl."vm.swappiness" = 150;

  # ===========================================================================
  # FINGERPRINT READER
  # ===========================================================================

  services.fprintd.enable = true;

  # security.pam.services.*.fprintAuth defaults to services.fprintd.enable for
  # every PAM service, which wires the reader into "login" (and therefore
  # plasmalogin, which substacks login) even though KDE's own Settings says
  # fingerprint login isn't supported. In practice the reader never matches at
  # the greeter and each boot eats a flat 30s PAM timeout before falling back
  # to password. Disable it there; sudo keeps the default (true).
  security.pam.services.login.fprintAuth = false;

  # ===========================================================================
  # MULLVAD VPN
  # ===========================================================================

  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.gui.enable = true;

  # ===========================================================================
  # SECURITY
  # ===========================================================================

  security.polkit.enable = true;

  # Allow users in the `wheel` group to use sudo.
  security.sudo.wheelNeedsPassword = true;

  # ===========================================================================
  # USER ACCOUNT
  # ===========================================================================

  users.users.shashin = {
    isNormalUser = true;
    description  = "Shashin Halalingaiah";
    extraGroups  = [
      "wheel"           # sudo access
      "networkmanager"  # manage WiFi/Ethernet without sudo
      "video"           # GPU/display access
      "audio"           # audio devices
      "input"           # input devices (needed by some Wayland compositors)
      "tss"             # TPM access (tpm2-tools)
    ];
    # Shell defaults to bash. Change to pkgs.fish or pkgs.zsh here if you prefer.
    shell = pkgs.bash;
  };

  # ===========================================================================
  # SYSTEM PACKAGES
  # ===========================================================================
  # Only system-wide tools go here. Per-user packages belong in Home Manager
  # (a future addition) or in users.users.shashin.packages.

  environment.systemPackages = with pkgs; [
    # Wayland utilities
    wl-clipboard         # wl-copy / wl-paste
    xdg-utils            # xdg-open etc.
  ];

  # ===========================================================================
  # FONTS
  # ===========================================================================

  fonts.packages =  with pkgs; [
  	font-awesome
  	nerd-fonts.fira-code
	  nerd-fonts.droid-sans-mono
  ];

  fonts.fontconfig = {
  	defaultFonts = {
	    monospace  = [ "JetBrainsMono Nerd Font" ];
	    sansSerif  = [ "Noto Sans" ];
	    serif      = [ "Noto Serif" ];
	    emoji      = [ "Noto Color Emoji" ];
  	};
	enable = true;
  };

  # ===========================================================================
  # PROGRAMS
  # ===========================================================================

  # moved to pc-common.nix

  # ===========================================================================
  # NIX SETTINGS
  # ===========================================================================

  nix = {
    settings = {
      # Enable the `nix` CLI and flakes (both are experimental but stable in
      # practice; required for this entire configuration to work).
      experimental-features = [ "nix-command" "flakes" ];

      # Deduplicate identical files in the Nix store (saves disk space).
      auto-optimise-store = true;

      # Trusted users can add binary caches without sudo.
      trusted-users = [ "root" "shashin" ];
    };

    # Weekly garbage collection: delete generations older than 30 days.
    # This prevents the Nix store from growing unboundedly.
    gc = {
      automatic = true;
      dates     = "weekly";
      options   = "--delete-older-than 30d";
    };
  };

  # Allow installing packages with non-free licenses (e.g. some firmware,
  # CUDA, Steam). This does NOT install anything; it just allows it.
  nixpkgs.config.allowUnfree = true;

  # ===========================================================================
  # STATE VERSION
  # ===========================================================================
  # This records the NixOS release at which this system was FIRST installed.
  # It controls defaults for stateful data (file locations, DB schemas, etc.).
  # DO NOT change this after the initial install — it is not a "keep up to date"
  # setting. Read the docs before changing it.
  system.stateVersion = "26.05";


 # TODO: check if this has been resolved.
 # temporary fix - https://github.com/NixOS/nixpkgs/issues/514113#issuecomment-4338976393
   nixpkgs.overlays = [
     (_: prev: {
       openldap = prev.openldap.overrideAttrs {
 	doCheck = !prev.stdenv.hostPlatform.isi686;
       };
     })
   ];
 }
