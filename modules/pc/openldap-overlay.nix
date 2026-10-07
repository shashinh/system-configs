# TODO: check if this has been resolved.
# temporary fix - https://github.com/NixOS/nixpkgs/issues/514113#issuecomment-4338976393
{
  flake.modules.nixos.pc = {
    nixpkgs.overlays = [
      (_: prev: {
        openldap = prev.openldap.overrideAttrs {
          doCheck = !prev.stdenv.hostPlatform.isi686;
        };
      })
    ];
  };
}
