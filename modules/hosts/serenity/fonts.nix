# serenity's installed fonts. Note: the shared fontconfig defaults name
# "JetBrainsMono Nerd Font", which this list does not install — a
# pre-existing quirk preserved as-is (monospace silently falls back).
{
  flake.modules.nixos.serenity =
    { pkgs, ... }:
    {
      fonts.packages = with pkgs; [
        font-awesome
        nerd-fonts.fira-code
        nerd-fonts.droid-sans-mono
      ];
    };
}
