# `claude-utns`: the system Claude Code binary pointed at the lab's Claude
# gateway instead of the default Anthropic endpoint. Plain `claude` is left
# untouched.
#
# Everything lab-specific (API key, endpoint, gateway host, and the gateway's
# private root CA) lives in secrets/utns.yaml. At activation sops-nix renders
# an env file into /run/secrets/rendered/ (tmpfs, readable only by shashin);
# the wrapper sources it and execs claude. The store only ever sees
# placeholders.
{
  flake.modules.nixos.pc =
    { config, pkgs, ... }:
    let
      sopsFile = ../../secrets/utns.yaml;
      ph = config.sops.placeholder;
      envFile = config.sops.templates."claude-utns.env".path;

      claude-utns = pkgs.writeShellScriptBin "claude-utns" ''
        if [ ! -r ${envFile} ]; then
          echo "claude-utns: ${envFile} is missing or unreadable (sops activation failed?)" >&2
          exit 1
        fi
        set -a
        . ${envFile}
        set +a
        exec ${pkgs.claude-code}/bin/claude "$@"
      '';
    in
    {
      sops.secrets = {
        "utns/api_key" = { inherit sopsFile; };
        "utns/base_url" = { inherit sopsFile; };
        "utns/host" = { inherit sopsFile; };
        # Public certificate, but kept with the rest so the repo carries no
        # lab infrastructure details. Must be readable by the user's node.
        "utns/ca_cert" = {
          inherit sopsFile;
          owner = "shashin";
        };
      };

      sops.templates."claude-utns.env" = {
        owner = "shashin";
        mode = "0400";
        content = ''
          ANTHROPIC_API_KEY='${ph."utns/api_key"}'
          ANTHROPIC_BASE_URL='${ph."utns/base_url"}'
          NO_PROXY='${ph."utns/host"}'
          NODE_EXTRA_CA_CERTS='${config.sops.secrets."utns/ca_cert".path}'
        '';
      };

      environment.systemPackages = [ claude-utns ];
    };
}
