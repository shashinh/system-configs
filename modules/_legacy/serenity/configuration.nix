# ─── SERENITY — SYSTEM CONFIGURATION (host-specific residue) ────────────────
# Framework Desktop AI Max+ 395
# NixOS with KDE Plasma 6
# Plasma Login Manager, lanzaboote secure boot, TPM2+PIN LUKS unlock
# Shared PC baseline lives in modules/pc/.
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
  # BOOT (host-specific)
  # ===========================================================================

  # from
  #		https://www.jeffgeerling.com/blog/2025/increasing-vram-allocation-on-amd-ai-apus-under-linux/
  #		https://community.frame.work/t/updated-commands-to-increase-max-unified-memory-usage-on-framework-desktop-under-fedora-43/78460
  #   to check, after reboot:
  # sudo dmesg | grep "amdgpu.*memory"
  boot.kernelParams = [
    "ttm.pages_limit=27648000"
    "ttm.page_pool_size=27648000"
  ];

  # ===========================================================================
  # FILESYSTEMS (host-specific)
  # ===========================================================================

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
  # NETWORKING
  # ===========================================================================

  networking.hostName = "serenity";

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

  services.desktopManager.plasma6.enable = true;

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
  # USER ACCOUNT (host-specific groups)
  # ===========================================================================

  users.users.shashin.extraGroups = [ "lact-gpu-monitoring" ];

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

  # ===========================================================================
  # SERVICES
  # ===========================================================================

  #ratbagd -- logitech G series mice config tool service
  services.ratbagd.enable = true;

  # optimized driver for Xbox One controller
  hardware.xpadneo.enable = true;

  # ===========================================================================
  # STATE VERSION
  # ===========================================================================
  # This records the NixOS release at which this system was FIRST installed.
  # It controls defaults for stateful data (file locations, DB schemas, etc.).
  # DO NOT change this after the initial install — it is not a "keep up to date"
  # setting. Read the docs before changing it.
  system.stateVersion = "25.11";

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
