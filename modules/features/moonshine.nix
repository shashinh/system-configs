# Moonshine — self-hosted game streaming (Moonlight/GameStream protocol).
#
# Streams Steam Big Picture and PCSX2 (whole-library big-picture UI plus one
# entry per PS2 title) to Moonlight clients. Assumes the gaming feature
# (steam, pcsx2) and a PS2 library under /data/Games/PS2 with covers in
# ~/.config/PCSX2/covers, so only serenity imports it today.
#
# The firewall interfaces are hardware-bound and set host-side
# (modules/hosts/serenity/moonshine.nix): never expose these ports to the
# internet.
#
# Settings are rendered to a TOML file in the Nix store and passed to
# moonshine; it does NOT read ~/.config/moonshine/config.toml. Anything unset
# uses moonshine's defaults (see moonshine-core/src/config.rs). Leaving
# `application` empty falls back to a Steam entry at /usr/bin/steam, which
# doesn't exist here. Commands use Nix store paths since the service PATH is
# minimal.
{
  flake.modules.nixos.moonshine =
    { lib, pkgs, ... }:
    let
      steam = lib.getExe pkgs.steam;
      pcsx2 = lib.getExe' pkgs.pcsx2 "pcsx2-qt";
      ps2Dir = "/data/Games/PS2";
      pcsx2Config = "/home/shashin/.config/PCSX2";
      ps2Covers = "${pcsx2Config}/covers";

      # PCSX2 binds pads by SDL slot. At the desk the pad is SDL-1, but in a
      # stream moonshine's virtual pad is the only one, so it's SDL-0. Rumble
      # can't use duplicate bindings (PCSX2 reads only the first motor
      # binding), so swap the slot in PCSX2.ini and all input profiles for the
      # duration of the stream: `stream` before PCSX2 starts (ExecStartPre),
      # `desk` after the session ends, even on crash (ExecStopPost). Settings
      # changed mid-stream are kept since only the slot is rewritten.
      pcsx2PadSwap = pkgs.writeShellApplication {
        name = "pcsx2-pad-swap";
        runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.gnused ];
        text = ''
          cd ${pcsx2Config} || exit 1
          marker=.moonshine-stream-bindings
          files=(inis/PCSX2.ini)
          for f in inputprofiles/*.ini; do
            if [ -f "$f" ]; then files+=("$f"); fi
          done

          case "''${1:-}" in
            stream)
              if [ -e "$marker" ]; then exit 0; fi
              # Swapping back would be ambiguous if SDL-0 is already in use.
              if grep -q 'SDL-0/' "''${files[@]}"; then
                echo "pcsx2-pad-swap: SDL-0 bindings already present, not swapping" >&2
                exit 0
              fi
              sed -i 's|SDL-1/|SDL-0/|g' "''${files[@]}"
              touch "$marker"
              ;;
            desk)
              if [ ! -e "$marker" ]; then exit 0; fi
              sed -i 's|SDL-0/|SDL-1/|g' "''${files[@]}"
              rm -f "$marker"
              ;;
            *)
              echo "usage: pcsx2-pad-swap stream|desk" >&2
              exit 2
              ;;
          esac
        '';
      };
      pcsx2Hooks = {
        pre_command = [ [ (lib.getExe pcsx2PadSwap) "stream" ] ];
        post_command = [ [ (lib.getExe pcsx2PadSwap) "desk" ] ];
      };

      # PCSX2 library (GameList RecursivePaths in ~/.config/PCSX2/inis/PCSX2.ini).
      # Serial = cover name in ps2Covers; titles from PCSX2's game list.
      ps2Games = [
        { title = "Devil May Cry";                                serial = "SLUS-20216"; file = "SLUS-20216 (1.10).iso"; }
        { title = "Echo Night - Beyond";                          serial = "SLUS-20928"; file = "SLUS-20928 (1.02).iso"; }
        { title = "Fatal Frame";                                  serial = "SLUS-20388"; file = "SLUS-20388 (1.20).iso"; }
        { title = "Forbidden Siren";                              serial = "SCES-51920"; file = "Forbidden Siren (Europe).iso"; }
        { title = "God of War";                                   serial = "SCUS-97399"; file = "God of War.iso"; }
        { title = "God of War II";                                serial = "SCUS-97481"; file = "God of War II.iso"; }
        { title = "Grand Theft Auto - San Andreas";               serial = "SLUS-20946"; file = "Grand Theft Auto - San Andreas (USA, Canada) (v3.00).iso"; }
        { title = "Need for Speed - Hot Pursuit 2";               serial = "SLUS-20362"; file = "Need for Speed - Hot Pursuit 2 (USA).iso"; }
        { title = "Need for Speed - Most Wanted [Black Edition]"; serial = "SLUS-21351"; file = "Need for Speed - Most Wanted - Black Edition (USA).iso"; }
        { title = "Need for Speed - Underground 2";               serial = "SLUS-21065"; file = "Need for Speed - Underground 2 (USA, Canada).iso"; }
        { title = "Resident Evil - CODE Veronica X";              serial = "SLUS-20184"; file = "Resident Evil - Code - Veronica X (USA).iso"; }
        { title = "Silent Hill - Shattered Memories";             serial = "SLUS-21899"; file = "SLUS-21899 (1.00).iso"; }
        { title = "Sly Cooper and the Thievius Raccoonus";        serial = "SCUS-97198"; file = "SCUS-97198 (1.00).iso"; }
      ];

      # -batch: quit PCSX2 (and end the stream) when the game shuts down.
      # -nogui: boot straight into the game without the library window.
      ps2App = game: pcsx2Hooks // {
        inherit (game) title;
        boxart = "${ps2Covers}/${game.serial}.jpg";
        command = [ pcsx2 "-batch" "-nogui" "-fullscreen" "--" "${ps2Dir}/${game.file}" ];
        stderr = "journal"; # journalctl --user -u moonshine-session.service
      };
    in
    {
      services.moonshine = {
        enable = true;
        package = pkgs.moonshine;
        user = "shashin";

        settings = {
          application = [
            {
              title = "Steam";
              command = [ steam "steam://open/bigpicture" ];
            }
            (pcsx2Hooks // {
              # PCSX2's controller-driven fullscreen UI over the whole library, so
              # games added to ps2Dir are playable without editing this list.
              title = "PCSX2";
              boxart = "${pkgs.pcsx2}/share/PCSX2/resources/icons/AppIconLarge.png";
              command = [ pcsx2 "-bigpicture" "-fullscreen" ];
              stderr = "journal";
            })
          ] ++ map ps2App ps2Games;

          application_scanner = [
            {
              type = "steam";
              library = "$HOME/.local/share/Steam";
              command = [ steam "-bigpicture" "steam://rungameid/{game_id}" ];
            }
          ];
        };
      };
    };
}
