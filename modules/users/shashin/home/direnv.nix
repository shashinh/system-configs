# direnv: per-directory environments. Its main use here is entering a
# project's `nix develop` shell automatically when cd-ing into a repo whose
# .envrc says `use flake`. nix-direnv replaces direnv's stock nix support:
# it caches the evaluated shell environment and registers it as a GC root,
# so re-entering a directory is instant and `nix-collect-garbage` does not
# delete the toolchain underneath an open project.
#
# Shell hooks for bash and zsh are installed by home-manager because both
# shells are enabled in bash.nix and zsh.nix (enable*Integration default on).
# A new .envrc is inert until approved once with `direnv allow`.
{
  flake.modules.homeManager.shashin =
    { ... }:
    {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };
}
