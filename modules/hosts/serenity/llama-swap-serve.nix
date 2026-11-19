# Publish the llama-swap API to the tailnet via `tailscale serve` on 8443
# (443 belongs to open-webui), so it is reachable at
# https://serenity.<tailnet>.ts.net:8443/v1/... with a Tailscale-issued cert.
# llama-swap stays bound to loopback and the firewall stays shut.
#
# Same Type=simple reassertion trick as tailscale-serve-open-webui: a
# down/logged-out tailscale must not fail activation.
#
# Note: this exposes the whole llama-swap API (every model), not just
# qwen3.8-flash-next-Q4-gufo. llama-swap has no auth, so the trust boundary
# is the tailnet + Tailscale ACLs.
{
  flake.modules.nixos.serenity =
    { config, ... }:
    let
      tailscale = "${config.services.tailscale.package}/bin/tailscale";
    in
    {
      systemd.services.tailscale-serve-llama-swap = {
        description = "Expose llama-swap on the tailnet via tailscale serve";
        after = [ "tailscaled.service" "llama-swap.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        script = ''
          until ${tailscale} status --peers=false >/dev/null 2>&1; do sleep 5; done
          exec ${tailscale} serve --bg --https=8443 http://127.0.0.1:${toString config.services.llama-swap.port}
        '';
        serviceConfig = {
          Type = "simple";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = 5;
          ExecStop = "-${tailscale} serve --https=8443 off";
        };
      };
    };
}
