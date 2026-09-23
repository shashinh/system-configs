# Disko: makes `disko.devices` a valid NixOS option and wires
# fileSystems/LUKS from each host's disko layout file.
{ inputs, ... }:
{
  flake.modules.nixos.pc = {
    imports = [ inputs.disko.nixosModules.disko ];
  };
}
