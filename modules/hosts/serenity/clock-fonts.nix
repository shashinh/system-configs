# Tall, condensed face for the stacked clock in serenity's vertical Noctalia
# bar (dotfiles/noctalia/hosts/serenity/host.toml, [widget.clock]).
{
  flake.modules.nixos.serenity =
    { pkgs, ... }:
    {
      fonts.packages = [
        (pkgs.google-fonts.override { fonts = [ "BigShouldersDisplay" ]; })
      ];
    };
}
