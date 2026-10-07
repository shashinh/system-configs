# Where this repo is checked out on the machine.
#
# Out-of-store symlinks point at a working checkout rather than the Nix store,
# so the files stay editable in place (by you, and by apps that rewrite their
# own config) and show up as a dirty tree to commit. That requires knowing the
# checkout path at eval time, which is what this option carries.
{
  flake.modules.homeManager.shashin =
    { config, lib, ... }:
    {
      options.dotfiles.repoPath = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/system-configs";
        example = "/home/shashin/src/system-configs";
        description = ''
          Absolute path to this repo's checkout, used as the target of
          out-of-store dotfile symlinks. Override per host if a machine keeps
          the checkout somewhere else. The path must exist at activation time,
          or the resulting symlinks dangle.
        '';
      };
    };
}
