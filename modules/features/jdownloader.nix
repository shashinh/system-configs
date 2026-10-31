# JDownloader, installed from flathub via nix-flatpak. App data lives in
# ~/.var/app/org.jdownloader.JDownloader and isn't touched by this module.
{ inputs, ... }:
{
  flake-file.inputs.nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

  flake.modules.nixos.jdownloader = {
    imports = [ inputs.nix-flatpak.nixosModules.nix-flatpak ];

    services.flatpak = {
      packages = [ "org.jdownloader.JDownloader" ];

      # niri doesn't reparent windows; without this Swing draws a blank window.
      overrides.settings."org.jdownloader.JDownloader".Environment._JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };
}
