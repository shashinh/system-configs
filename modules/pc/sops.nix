# Secret management with sops-nix.
#
# Trust model: each host decrypts with its own SSH host key, converted to an
# age identity at activation time. Nothing to provision — the host key already
# exists after an install, and the private key never leaves the machine.
# Humans decrypt/edit with their personal SSH key (see .sops.yaml and
# docs/secrets.md).
#
# Secrets never enter the Nix store. They are decrypted at activation into
# /run/secrets (tmpfs, root-owned) and exposed to consumers by path:
#   - config.sops.secrets.<name>.path      — a decrypted value in a file
#   - config.sops.templates.<name>.path    — a whole file rendered from a
#     template, with config.sops.placeholder.<name> substituted at activation
# The template *with placeholders* is what lands in the store; the substituted
# result never does.
{ inputs, ... }:
{
  flake-file.inputs.sops-nix = {
    url = "github:Mic92/sops-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.pc =
    { pkgs, ... }:
    {
      imports = [ inputs.sops-nix.nixosModules.sops ];

      # Decrypt with this host's ed25519 SSH host key. Set explicitly rather
      # than relying on the default (which is derived from
      # services.openssh.hostKeys) so that turning openssh off can't silently
      # leave a host unable to decrypt.
      sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      # age only — don't try to import RSA host keys as GPG keys.
      sops.gnupg.sshKeyPaths = [ ];

      # Tooling for managing secrets by hand.
      environment.systemPackages = with pkgs; [
        sops
        age
        ssh-to-age
      ];
    };
}
