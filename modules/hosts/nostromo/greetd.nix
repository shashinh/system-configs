# greetd + tuigreet as the display manager.
{
  flake.modules.nixos.nostromo =
    { config, lib, pkgs, ... }:
    {
      # tuigreet as greeter
      environment.etc."tuigreet/config.toml".source =
        (pkgs.formats.toml { }).generate "tuigreet-config.toml" {
          display.show_time = true;
          # display.greeting = "";
          # display.align_greeting = "center";
          remember = {
            username = true;
            session = true;
          };
          session = {
            # only list the Wayland sessions, edit if X11 is required
            sessions_dirs = [ "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions" ];
            xsessions_dirs = [ ];
          };
        };

      services.greetd = {
        enable = true;
        useTextGreeter = true;
        settings.default_session.command = "${lib.getExe pkgs.tuigreet} --config /etc/tuigreet/config.toml";
      };
    };
}
