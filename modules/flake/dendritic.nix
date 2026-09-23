# Core dendritic wiring: every *.nix file under modules/ is a flake-parts
# module, auto-imported by the import-tree call in flake.nix. This module
# provides the two framework pieces the pattern rests on:
#   - flake-parts' `modules` flake module, which declares the
#     `flake.modules.<class>.<name>` option namespace (deferred modules,
#     merged across files)
#   - flake-file, which generates flake.nix from `flake-file.inputs`
#     declarations placed next to the modules that use each input
#     (regenerate with `nix run .#write-flake`)
{ inputs, ... }:
{
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.flake-file.flakeModules.default
  ];

  flake-file.description = "A collection of Nix configs";

  flake-file.inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-file.url = "github:vic/flake-file";
    import-tree.url = "github:vic/import-tree";
  };

  flake-file.outputs = ''
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules)
  '';

  systems = [ "x86_64-linux" ];
}
