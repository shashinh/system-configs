{ config, lib, pkgs, ... }:
let
  searxSecretFile = "/persist/secrets/searx-env";
in
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

      # Lives on the @persist subvolume (survives impermanence wipes / reinstalls),
      # not in the repo or /etc/nixos. Root-only; auto-generated on first boot
      # if missing (see systemd.services.searx-secret-init below).
      environmentFile = searxSecretFile;
  };

  # Generates /persist/secrets/searx-env on first boot (or after a reinstall
  # where @persist was recreated) so the searx service never fails to start
  # for want of a secret someone forgot to seed by hand. No-op once the file
  # exists — the key's only purpose is signing local cookies/CSRF tokens, so
  # a freshly-generated value is always fine.
  #
  # `before`/`requiredBy` on this unit only set Before= on itself; systemd
  # still needs something to actually pull it into the boot transaction and
  # needs searx-init to depend on it, hence the explicit wiring on both ends.
  systemd.services.searx-secret-init = {
    description = "Generate SearXNG secret key if missing";
    wantedBy = [ "multi-user.target" ];
    before = [ "searx-init.service" ];
    unitConfig.ConditionPathExists = "!${searxSecretFile}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      install -d -m 700 "$(dirname ${searxSecretFile})"
      echo "SEARX_SECRET_KEY=$(${lib.getExe' pkgs.openssl "openssl"} rand -hex 32)" > ${searxSecretFile}
      chmod 600 ${searxSecretFile}
    '';
  };

  systemd.services.searx-init = {
    after = [ "searx-secret-init.service" ];
    requires = [ "searx-secret-init.service" ];
  };
}
