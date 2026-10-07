# Disko: makes `disko.devices` a valid NixOS option and wires
# fileSystems/LUKS from each host's disko layout file.
{ inputs, ... }:
{
  # Declarative disk partitioning — replaces manual parted/mkfs commands.
  flake-file.inputs.disko = {
    url = "github:nix-community/disko";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.pc = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
