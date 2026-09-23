# ─── SERENITY — SYSTEM CONFIGURATION ────────────────────────────────────────
# Framework Desktop AI Max+ 395
# NixOS with KDE Plasma 6
# Plasma Login Manager, lanzaboote secure boot, TPM2+PIN LUKS unlock
# ─────────────────────────────────────────────────────────────────────────────

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
  # ===========================================================================
  # Local Inference Setup
  # ===========================================================================
    ./llama-swap.nix
    ./open-webui.nix
    ./searxng.nix
  ];

  # ===========================================================================
  # BOOT
  # ===========================================================================

  boot = {

    # ── Kernel ────────────────────────────────────────────────────────────────
    # linuxPackages_latest has the latest stable kernel, which has the
    # best support for AMD Strix Halo (AI Max+ 395). The nixos-hardware module
    # may override this — that's fine, it picks the best option for the chip.
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    kernelModules = [ "kvm-amd" ];

    # Filesystems the initrd and kernel need to know about.
    supportedFilesystems = [ "btrfs" ];

    # from
    #		https://www.jeffgeerling.com/blog/2025/increasing-vram-allocation-on-amd-ai-apus-under-linux/
    #		https://community.frame.work/t/updated-commands-to-increase-max-unified-memory-usage-on-framework-desktop-under-fedora-43/78460
    #   to check, after reboot:
    # sudo dmesg | grep "amdgpu.*memory"
    kernelParams = [ 
	  "ttm.pages_limit=27648000" 
	  "ttm.page_pool_size=27648000" 
    ];

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
       pkiBundle = "/var/lib/sbctl";  # symlinked to /persist, survives future impermanence wipe
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

  # ===========================================================================
  # FILESYSTEMS (extra options not covered by disko)
  # ===========================================================================

  # /persist must be available before activation scripts run so that
  # NetworkManager connections, SSH host keys, and secrets are in place.
  fileSystems."/persist".neededForBoot = true;

  # /var/log is also mounted early to capture boot-time logs.
  fileSystems."/var/log".neededForBoot = true;

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
    hostName       = "serenity";
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

  # ===========================================================================
  # FINGERPRINT READER
  # ===========================================================================

  services.fprintd.enable = false;

  # Wire fingerprint into PAM so you can use it instead of a password for
  # sudo and login. SDDM fingerprint support is limited on Wayland;
  # see INSTALL.md notes on enrolling prints after first boot.
#   security.pam.services = {
#     login.fprintAuth = true;
#     sudo.fprintAuth  = true;
#     # Uncomment once you have confirmed fprintd detects your reader:
#     # polkit-1.fprintAuth = true;
#   };

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
      "lact-gpu-monitoring"
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

    # Gaming
    steam
    lutris
    steamtinkerlaunch
    mangohud
    # ffmpeg 9.0 (nixpkgs default) removed AVCodec.pix_fmts/sample_fmts, which
    # pcsx2 2.6.3's GSCapture.cpp and rpcs3's recording_settings_dialog.cpp
    # still read directly (pcsx2 upstream fix pending: PCSX2/pcsx2#14831).
    # Pin both to ffmpeg_7 until they're patched upstream.
    (pkgs.pcsx2.override { ffmpeg = pkgs.ffmpeg_7; })
    ((pkgs.rpcs3.override { ffmpeg = pkgs.ffmpeg_7; }).overrideAttrs (prev: {
      cmakeFlags = prev.cmakeFlags ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" false) ];
    }))
    ppsspp

    # Inference
    (llama-cpp.override 
      {
        # rocmSupport = true; 
        vulkanSupport = true;
      })
    python3Packages.huggingface-hub
    claude-code
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
  # SERVICES
  # ===========================================================================

  #ratbagd -- logitech G series mice config tool service
  services.ratbagd.enable = true;

  # optimized driver for Xbox One controller
  hardware.xpadneo.enable = true;

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
  system.stateVersion = "25.11";


 # TODO: check if this has been resolved.
 # temporary fix - https://github.com/NixOS/nixpkgs/issues/514113#issuecomment-4338976393
   nixpkgs.overlays = [
     (_: prev: {
       openldap = prev.openldap.overrideAttrs {
 	doCheck = !prev.stdenv.hostPlatform.isi686;
       };
     })
   ];

 environment.sessionVariables.LLM_MODELS_DIR = "/data/models";

  # ===========================================================================
  # LACTD service -- service for LACT - Linux GPU Config and Monitoring Tool
  # ===========================================================================
 
  users.groups.lact-gpu-monitoring = {};
  services.lact.enable = true;
  # IMPORTANT
  # don't know how to do this declaratively yet, but to ensure llama-swap can access the lactd
  # socket, go to /etc/lact/config.yml and change "admin_group" to "lact-gpu-monitoring"

   #systemd.services.llama-swap = {
   #  after = [ "lactd.service" ];
   #  wants = [ "lactd.service" ];
   #};
 }
