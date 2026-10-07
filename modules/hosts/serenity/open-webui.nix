# Host side of the open-webui feature: publish it to the tailnet via
# `tailscale serve`, so it is reachable at https://serenity.<tailnet>.ts.net/
# with a Tailscale-issued cert. open-webui itself stays bound to loopback and
# the firewall stays shut; tailscaled does the proxying.
#
# Serve config persists in tailscaled's state, so this oneshot just reasserts
# it on boot / rebuild. (services.tailscale.serve is for svc: Tailscale
# Services, which need admin-console setup and tagged nodes; not used here.)
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
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${tailscale} serve --bg --https=443 http://127.0.0.1:${toString config.services.open-webui.port}";
          # tailscaled may not be logged in yet right after boot.
          Restart = "on-failure";
          RestartSec = 5;
          ExecStop = "${tailscale} serve --https=443 off";
        };
      };
    };
}
