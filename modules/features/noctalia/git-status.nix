# git-status: a Noctalia bar dot showing a repository's git status, with a
# panel to review, commit, pull and push. Own plugin, own flake:
# github:shashinh/git-status-noctalia-plugin. Here it runs in its NixOS
# configuration mode, which watches /etc/nixos (this checkout).
#
# The plugin's home-manager module links the package into
# ~/.local/share/noctalia/plugins/git-status, Noctalia's implicit "local"
# plugin source. That root is always scanned, so no [[plugins.source]] entry
# is needed. An explicit source list would replace the default official and
# community sources.
#
# Installed and enabled on every host importing `noctalia`. The rest of the
# wiring is in the vendored config:
#   plugins.toml               "shashinh/git-status" in [plugins].enabled, and
#                              nixos_mode = true under its plugin_settings
#   hosts/serenity/host.toml   also in that host's own [plugins].enabled
#                              (it overrides plugins.toml), plus
#                              [widget.git_status] and its place in `end`
# nostromo's bar does not place it; add it from the bar editor if wanted.
{ inputs, ... }:
{
  flake-file.inputs.git-status = {
    url = "github:shashinh/git-status-noctalia-plugin";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.homeManager.noctalia = {
    imports = [ inputs.git-status.homeModules.default ];
    programs.noctalia-git-status.enable = true;
  };
}
