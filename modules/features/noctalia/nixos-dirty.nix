# nixos-dirty: a Noctalia bar dot that shows uncommitted changes in this repo,
# with a panel to review, commit and push them. Own plugin, own flake:
# github:shashinh/git-status-noctalia-plugin.
#
# The plugin's home-manager module links the package into
# ~/.local/share/noctalia/plugins/nixos-dirty, Noctalia's implicit "local"
# plugin source. That root is always scanned, so no [[plugins.source]] entry
# is needed. An explicit source list would replace the default official and
# community sources.
#
# Installing is not enabling. The rest of the wiring is in the vendored config:
#   plugins.toml            "shashinh/nixos-dirty" in [plugins].enabled and
#                           repo_path under [plugin_settings."shashinh/nixos-dirty"]
#   bar.toml                [widget.nixos_dirty] plus its place in the end list
#   hosts/<host>/host.toml  the same place, wherever a host overrides `end`
{ inputs, ... }:
{
  flake-file.inputs.nixos-dirty = {
    url = "github:shashinh/git-status-noctalia-plugin";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.homeManager.noctalia = {
    imports = [ inputs.nixos-dirty.homeModules.default ];
    programs.noctalia-nixos-dirty.enable = true;
  };
}
