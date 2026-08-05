{ config, lib, pkgs, ... }:
  {
    services.searx = {
      enable = true;
      redisCreateLocally = true;

      settings.server = {
        bind_address = "127.0.0.1";
        port = 8080;
        secret_key = "$SEARX_SECRET_KEY";  # substituted from environmentFile at activation
        limiter = false;                   # fine for single-user/local; set true + rely on redis if exposing publicly
      };

       settings.search = {
         formats = [ "html" "json" ];
       };

      environmentFile = "/etc/nixos/secrets/searx-env";
  };
}
