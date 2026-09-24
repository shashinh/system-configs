# The wallhaven plugin's API key, delivered into noctalia's user config layer.
#
# Noctalia merges every *.toml in ~/.config/noctalia alphabetically, so a file
# that contains nothing but the plugin's settings composes with the rest of the
# hand-written config. That file carries a credential, so it is rendered from
# an encrypted secret at activation instead of being committed.
#
# The rendered file reaches ~/.config/noctalia via the home-manager module in
# dotfiles.nix, which system.nix wires in for the whole feature.
{

  flake.modules.nixos.noctalia =
    { config, ... }:
    {
      sops.secrets."noctalia/wallhaven_api_key".sopsFile = ../../../secrets/common.yaml;

      # Rendered at activation into /run/secrets/rendered/ (tmpfs). The store
      # only ever sees the placeholder, never the key.
      sops.templates."noctalia-wallhaven.toml" = {
        owner = "shashin";
        content = ''
          [plugin_settings."noctalia/wallhaven"]
          api_key = "${config.sops.placeholder."noctalia/wallhaven_api_key"}"
          browser_open_near_click = true
        '';
      };

    };

  # Link the rendered file into the noctalia config directory. The symlink is
  # created by home-manager as the user, so nothing root-owned ends up in
  # ~/.config; the target is recreated on every activation and on login
  # (sops-nix's user service).
  flake.modules.homeManager.noctalia =
    { config, ... }:
    {
      xdg.configFile."noctalia/wallhaven.toml".source =
        config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/noctalia-wallhaven.toml";
    };
}
