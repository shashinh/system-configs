# TPM2 support — used by systemd-cryptenroll to seal LUKS keys.
{
  flake.modules.nixos.pc = {
    security.tpm2 = {
      enable = true;
      pkcs11.enable = true; # exposes TPM as a PKCS#11 device
      tctiEnvironment.enable = true; # sets TCTI env vars for TPM tools
    };
  };
}
