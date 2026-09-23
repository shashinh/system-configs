# Gaming stack: Steam and friends, emulators, controller/mouse tooling.
{
  flake.modules.nixos.gaming =
    { lib, pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
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
      ];

      #ratbagd -- logitech G series mice config tool service
      services.ratbagd.enable = true;

      # optimized driver for Xbox One controller
      hardware.xpadneo.enable = true;
    };
}
