# NixOS status page: regenerated on every switch, opened from the launcher
# ("NixOS Status") or with `nixos-status` in a terminal.
#
# The module comes from the standalone nixos-status flake
# (https://github.com/shashinh/nixos-status). Passing `self` and `inputs`
# lets it name the flake input each package came from and list the inputs
# table from flake.lock; without them it still works with nixpkgs only.
#
# State lives in /var/lib/nixos-status. If impermanence is ever activated,
# add that directory to the persisted set or the history and the
# previous-version diff reset on every boot.
{ inputs, ... }:
{
  flake-file.inputs.nixos-status = {
    url = "github:shashinh/nixos-status";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.pc = {
    imports = [ inputs.nixos-status.nixosModules.default ];

    services.nixos-status = {
      enable = true;
      flake = inputs.self;
      inherit inputs;
    };
  };
}
