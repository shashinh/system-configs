# Impermanence: the module is imported so the `environment.persistence`
# option exists, but no persistence is declared yet — the disko layouts
# (@persist, @root-blank) are staged for it, and the wipe-root initrd
# service in pc/boot.nix stays commented out until it is activated.
{ inputs, ... }:
{
  flake.modules.nixos.pc = {
    imports = [ inputs.impermanence.nixosModules.impermanence ];

    # /persist must be available before activation scripts run so that
    # NetworkManager connections, SSH host keys, and secrets are in place.
    fileSystems."/persist".neededForBoot = true;

    # /var/log is also mounted early to capture boot-time logs.
    fileSystems."/var/log".neededForBoot = true;
  };
}
