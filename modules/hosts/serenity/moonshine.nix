# Host side of the moonshine feature: which interfaces get the
# Moonlight/GameStream ports (plus mDNS) opened. Wi-Fi, ethernet, and
# Tailscale on this machine. Never expose these to the internet.
{
  flake.modules.nixos.serenity = {
    services.moonshine.firewallInterfaces = [ "wlp192s0" "enp191s0" "tailscale0" ];
  };
}
