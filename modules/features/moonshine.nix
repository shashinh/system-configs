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
# Stream from a wired link. A 4K60 stream (~100 Mbit/s, bursty per frame)
# from serenity's Wi-Fi froze or blacked out the picture and flooded the LAN
# as the client kept requesting keyframes; the same stream over Ethernet is
# clean (2026-10-02).
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

      # PCSX2 binds pads by SDL player id: the first free slot, counting only
      # gamepads SDL accepts. The only pad present is SDL-0 both at the desk
      # (Xbox pad over USB) and in a stream (moonshine's virtual pad), so the
      # bindings in PCSX2.ini and the input profiles stay on SDL-0 and need no
      # per-session rewriting. A second pad present at launch, such as the
      # physical pad joining serenity over Bluetooth mid-stream, takes the
      # next free slot instead and is simply unbound.

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
      ps2App = game: {
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
            {
              # PCSX2's controller-driven fullscreen UI over the whole library, so
              # games added to ps2Dir are playable without editing this list.
              title = "PCSX2";
              boxart = "${pkgs.pcsx2}/share/PCSX2/resources/icons/AppIconLarge.png";
              command = [ pcsx2 "-bigpicture" "-fullscreen" ];
              stderr = "journal";
            }
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
