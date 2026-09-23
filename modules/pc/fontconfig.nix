# Default font families. fonts.packages is deliberately per-host:
# nostromo installs the fonts these names resolve to; serenity's package
# list omits nerd-fonts.jetbrains-mono (pre-existing quirk, preserved —
# its monospace default silently falls back).
{
  flake.modules.nixos.pc = {
    fonts.fontconfig = {
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
      enable = true;
    };
  };
}
