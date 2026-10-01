# Agent skills vendored under skills/, bundled into one package so hosts can
# install them like any other software. Layout of the output:
#   $out/share/claude/skills/<name>/SKILL.md (+ any supporting files)
# Every directory under skills/ is included; the claude-skills feature
# (modules/features/claude-skills.nix) links them into ~/.claude/skills/.
{
  perSystem =
    { pkgs, ... }:
    {
      packages.claude-skills = pkgs.runCommandLocal "claude-skills" { } ''
        mkdir -p $out/share/claude/skills
        cp -r ${../../skills}/. $out/share/claude/skills/
      '';
    };
}
