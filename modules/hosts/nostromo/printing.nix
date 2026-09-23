# PRINTING (CUPS)
# CS department network printer at UT Austin, GDC, 5S (printserv-auth.cs.utexas.edu).
# `services.printing.enable` installs and runs CUPS itself; the printer
# below is registered declaratively via a oneshot systemd service that runs
# the department's `lpadmin` setup command on every boot (idempotent).
#
# `printer` / `user` below are placeholders — fill in before this takes
# effect. There's no password to configure here: registering the queue
# doesn't require auth, and per-job auth happens interactively at print
# time (see NOTE below), handled by the print dialog or a secret store —
# not by lpadmin or this config.
#
# NOTE — printing workflow (per CS IT instructions):
#   1. When selecting this printer to print, you'll be prompted for a
#      username/password. Click "Cancel".
#   2. Click "Print".
#   3. You'll be prompted again — this time enter your CS username and
#      password. Some desktop environments offer a checkbox to save it.
#   4. Repeat steps 1-3 for every print job (unless the password was saved).
#
# If `-m everywhere` fails with "Unable to create PPD: No IPP attributes.",
# drop the `-m everywhere` line below.
{
  flake.modules.nixos.nostromo =
    { pkgs, ... }:
    {
      services.printing.enable = true;

      systemd.services.setup-cs-printer = {
        description = "Register CS department network printer with CUPS";
        wantedBy = [ "multi-user.target" ];
        wants = [ "cups.service" ];
        after = [ "cups.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script =
          let
            printer = "pr-5s"; # e.g. "sequoia-color" -- printer name on printserv-auth.cs.utexas.edu
            user = "shashin"; # your CS username (see printing workflow note above)
          in
          ''
            ${pkgs.cups}/bin/lpadmin -p ${printer} -U ${user} \
              -v ipps://printserv-auth.cs.utexas.edu:631/printers/${printer} \
              -E \
              -o APOptionalDuplexer=True \
              -o printer-error-policy=abort-job
          '';
      };
    };
}
