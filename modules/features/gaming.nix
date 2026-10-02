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
        # rpcs3's recording_settings_dialog.cpp still reads directly, so it stays
        # pinned to ffmpeg_7 until patched upstream.
        # pcsx2 needs no override anymore: nixpkgs pins it to ffmpeg_8 itself
        # (the argument was renamed ffmpeg -> ffmpeg_8), and ffmpeg 8 still has
        # pix_fmts (pcsx2 upstream fix pending: PCSX2/pcsx2#14831).
        pcsx2
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
