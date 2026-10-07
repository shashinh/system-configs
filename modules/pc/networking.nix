# NetworkManager + firewall baseline. networking.hostName is per-host.
{
  flake.modules.nixos.pc = {
    networking = {
      networkmanager.enable = true;
      # Firewall is enabled by default; open ports here as needed later.
      firewall.enable = true;
    };
  };
}
