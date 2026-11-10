# restic backup of ~/Documents to a removable, LUKS-encrypted USB drive.
#
# The drive is mounted by udisks when it is unlocked from the desktop, at
# /run/media/shashin/<filesystem UUID>. The host sets that path through
# `features.backup.drive` (see modules/hosts/<host>/backup.nix); the
# repository lives at <drive>/restic/<hostname>, so several hosts can share
# one drive without sharing a repository.
#
# When a backup runs:
#   - whenever the drive's mount unit becomes active (unlock + mount), and
#   - daily at ~20:00 via a timer; a run missed while asleep/off catches up.
# A run without the drive mounted is skipped by ExecCondition, which systemd
# records as a skip, not a failure. Every run, including skips, is logged:
#   journalctl -u restic-backups-documents
#
# Each run: backup -> forget/prune (7 daily, 4 weekly, 12 monthly) -> check
# (repository structure and index; no full data read). Desktop notifications
# report start, finish (with a summary), failure and skip.
#
# The repository password is a sops secret in secrets/<hostname>.yaml under
# restic/documents_password. Manual access, as shashin, without sudo:
#   restic-documents snapshots
#   restic-documents restore latest --target /tmp/restore
{
  flake.modules.nixos.backup =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      cfg = config.features.backup;
      user = "shashin";
      unit = "restic-backups-documents";
      mountUnit = "${utils.escapeSystemdPath cfg.drive}.mount";
      restic = lib.getExe config.services.restic.backups.documents.package;

      # Deliver a notification to the user's graphical session. The service is
      # a system unit, so it has no session bus of its own; it uses the user's
      # bus socket directly. Without a session (logged out), it does nothing.
      notify = pkgs.writeShellApplication {
        name = "backup-notify";
        runtimeInputs = [ pkgs.libnotify ];
        text = ''
          urgency=$1 summary=$2 body=$3
          bus="/run/user/$(id -u)/bus"
          [ -S "$bus" ] || exit 0
          DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
            notify-send --app-name=Backup --icon=drive-harddisk \
            --urgency="$urgency" "$summary" "$body" || true
        '';
      };

      driveMounted = pkgs.writeShellApplication {
        name = "backup-drive-mounted";
        runtimeInputs = [
          pkgs.util-linux
          notify
        ];
        text = ''
          if mountpoint -q ${lib.escapeShellArg cfg.drive}; then
            exit 0
          fi
          echo "backup drive not mounted at ${cfg.drive}; skipping"
          backup-notify normal "Backup skipped" "The backup drive is not plugged in."
          exit 1
        '';
      };

      # ExecStopPost: runs after success and failure alike. systemd reports the
      # outcome in $SERVICE_RESULT ("exec-condition" for a skipped run).
      report = pkgs.writeShellApplication {
        name = "backup-report";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          notify
        ];
        text = ''
          case "''${SERVICE_RESULT:-}" in
            success)
              summary=$(${restic} snapshots latest --json --no-lock | jq -r '.[0].summary')
              new=$(jq -r '.files_new' <<<"$summary")
              changed=$(jq -r '.files_changed' <<<"$summary")
              added=$(numfmt --to=iec --suffix=B "$(jq -r '.data_added' <<<"$summary")")
              start=$(date -d "$(jq -r '.backup_start' <<<"$summary")" +%s)
              end=$(date -d "$(jq -r '.backup_end' <<<"$summary")" +%s)
              backup-notify normal "Backup complete" \
                "$new new, $changed changed, $added added in $((end - start))s"
              ;;
            exec-condition) ;;
            *)
              backup-notify critical "Backup failed" \
                "Result: ''${SERVICE_RESULT:-unknown}. See journalctl -u ${unit}"
              ;;
          esac
        '';
      };
    in
    {
      options.features.backup.drive = lib.mkOption {
        type = lib.types.str;
        example = "/run/media/shashin/dedc07a4-2d42-4315-982d-e0509b939f69";
        description = "Mount point of the backup drive.";
      };

      config = {
        sops.secrets."restic/documents_password" = {
          sopsFile = ../../secrets + "/${config.networking.hostName}.yaml";
          owner = user;
        };

        services.restic.backups.documents = {
          inherit user;
          repository = "${cfg.drive}/restic/${config.networking.hostName}";
          passwordFile = config.sops.secrets."restic/documents_password".path;
          initialize = true;
          paths = [ "/home/${user}/Documents" ];
          exclude = [
            "node_modules"
            "__pycache__"
            ".cache"
            ".direnv"
            "*.tmp"
            "~$*" # Microsoft Office lock files
            ".~lock.*#" # LibreOffice lock files
            "result" # nix build output symlinks
            "result-*"
          ];
          extraBackupArgs = [ "--exclude-caches" ];
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 12"
          ];
          runCheck = true;
          inhibitsSleep = true;
          timerConfig = {
            OnCalendar = "20:00";
            RandomizedDelaySec = "30min";
            Persistent = true;
          };
          backupPrepareCommand = ''
            ${lib.getExe notify} low "Backup started" "Backing up ~/Documents; keep the drive plugged in."
          '';
          backupCleanupCommand = lib.getExe report;
        };

        # inhibitsSleep wraps restic in systemd-inhibit. The service runs as
        # the user but outside any login session, where polkit's default for
        # blocking sleep is "authenticate", which a service cannot do. Allow
        # exactly that action for the backup user.
        security.polkit.extraConfig = ''
          polkit.addRule(function (action, subject) {
            if (action.id == "org.freedesktop.login1.inhibit-block-sleep" &&
                subject.user == "${user}") {
              return polkit.Result.YES;
            }
          });
        '';

        systemd.services.${unit} = {
          # Start when the drive is mounted, in addition to the timer.
          wantedBy = [ mountUnit ];
          # The repository is local; the module's network-online dependency
          # would only delay a run.
          wants = lib.mkForce [ ];
          after = lib.mkForce [ mountUnit ];
          serviceConfig.ExecCondition = lib.getExe driveMounted;
        };
      };
    };
}
