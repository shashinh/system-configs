# LACT — Linux GPU Config and Monitoring Tool (lactd service).
{
  flake.modules.nixos.serenity = {
    users.groups.lact-gpu-monitoring = { };
    services.lact.enable = true;
    # IMPORTANT
    # don't know how to do this declaratively yet, but to ensure llama-swap can access the lactd
    # socket, go to /etc/lact/config.yml and change "admin_group" to "lact-gpu-monitoring"

    #systemd.services.llama-swap = {
    #  after = [ "lactd.service" ];
    #  wants = [ "lactd.service" ];
    #};

    users.users.shashin.extraGroups = [ "lact-gpu-monitoring" ];
  };
}
