# Installs the claude-skills package (modules/packages/claude-skills.nix) into
# each home-manager user's ~/.claude/skills/, one directory per skill, so
# Claude Code picks them up as user-level skills on every rebuild.
#
# Requires the host to enable home-manager (import `home-shashin`).
#
# Files are linked individually (recursive), so ~/.claude/skills itself stays
# a real directory that Claude Code can keep writing its own skills into.
{ inputs, ... }:
{
  flake.modules.nixos.claude-skills = {
    home-manager.sharedModules = [ inputs.self.modules.homeManager.claude-skills ];
  };

  flake.modules.homeManager.claude-skills =
    { lib, pkgs, ... }:
    let
      pkg = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.claude-skills;
      # Skill names, read from the source tree at eval time (no IFD).
      names = lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir ../../skills));
    in
    {
      home.file = lib.listToAttrs (
        map (n: {
          name = ".claude/skills/${n}";
          value = {
            source = "${pkg}/share/claude/skills/${n}";
            recursive = true;
          };
        }) names
      );
    };
}
