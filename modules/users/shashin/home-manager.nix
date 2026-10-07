# Home Manager wiring for shashin, as a NixOS module: a host that imports
# `flake.modules.nixos.home-shashin` gets HM managing the shashin account
# with the flake.modules.homeManager.shashin configuration.
{ inputs, ... }:
{
  # Home Manager
  flake-file.inputs.home-manager = {
    url = "github:nix-community/home-manager";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.home-shashin = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.users.shashin.imports = [ inputs.self.modules.homeManager.shashin ];
  };
}
