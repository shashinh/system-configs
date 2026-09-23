# Fingerprint reader.
{
  flake.modules.nixos.fingerprint = {
    services.fprintd.enable = true;

    # security.pam.services.*.fprintAuth defaults to services.fprintd.enable for
    # every PAM service, which wires the reader into "login" (and therefore
    # greetd, which substacks login) even though the reader never matches at
    # the greeter — each boot ate a flat 30s PAM timeout before falling back
    # to password. Disable it there; sudo keeps the default (true).
    security.pam.services.login.fprintAuth = false;
  };
}
