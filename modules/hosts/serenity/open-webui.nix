# Host side of the open-webui feature: publish it to the tailnet via
# `tailscale serve`, so it is reachable at https://serenity.<tailnet>.ts.net/
# with a Tailscale-issued cert. open-webui itself stays bound to loopback and
# the firewall stays shut; tailscaled does the proxying.
#
# Serve config persists in tailscaled's state, so this unit just reasserts
# it on boot / rebuild. (services.tailscale.serve is for svc: Tailscale
# Services, which need admin-console setup and tagged nodes; not used here.)
#
# Type=simple, not oneshot: switch-to-configuration waits on a oneshot, so a
# down/logged-out tailscale used to fail activation. Now the start returns
# immediately and the script waits in the background until tailscale is up.
{
  flake.modules.nixos.serenity =
    { config, ... }:
    let
      tailscale = "${config.services.tailscale.package}/bin/tailscale";
    in
    {
      systemd.services.tailscale-serve-open-webui = {
        description = "Expose open-webui on the tailnet via tailscale serve";
        after = [ "tailscaled.service" "open-webui.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        script = ''
          # `tailscale status` exits non-zero while stopped / logged out.
          until ${tailscale} status --peers=false >/dev/null 2>&1; do sleep 5; done
          exec ${tailscale} serve --bg --https=443 http://127.0.0.1:${toString config.services.open-webui.port}
        '';
        serviceConfig = {
          Type = "simple";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = 5;
          # "-": tailscale being down at stop time must not fail the unit.
          ExecStop = "-${tailscale} serve --https=443 off";
        };
      };
    };
}
