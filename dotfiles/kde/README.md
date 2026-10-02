# dotfiles/kde — KDE Plasma 6 user configuration backup (serenity)

Snapshot of serenity's KDE Plasma user configuration, taken 2026-10-01 just
before the host moved to niri + Noctalia. It exists so that the `plasma`
feature can bring the desktop back as it was in an emergency.

## What is here

- `.config/`: the KDE rc files (kdeglobals, kwinrc, kwinrulesrc,
  kglobalshortcutsrc, the plasma panel layout, plasmashellrc, power, lock
  screen, input, dolphin/kate/konsole/okular/spectacle/etc. settings),
  `kdedefaults/`, `kate/` (external tools, LSP), and the GTK colour files
  KDE's GTK sync wrote (`gtk-{3,4}.0/colors.css`, `window_decorations.css`).
- `.local/share/`: `kwin/scripts/` (krohnkite tiling, dynamic_workspaces),
  `plasma/plasmoids/` (gnome-pager, panelspacer.extended, kvitals,
  windowtitle.Fork), the "Nothing" look-and-feel, desktop theme and aurorae
  window decoration, `color-schemes/` (Nordic, Nothing, Sweet), `kscreen/`,
  `plasma-systemmonitor/` pages and konsole bookmarks.

Text files only (about 1.7 MB). Nothing here is a secret; review before
adding anything (see the skill, "Before committing").

## Deliberately excluded

| Item | Why | How to get it back |
|---|---|---|
| `*.svgz`, `*.png`, `*.jpg`, `*.mo` inside the themes and plasmoids | binary; bloats the repo | the "Nothing" look-and-feel / desktop theme / aurorae theme from the KDE store (`Nothing` by its author, via Get New Stuff) or the plasmoid repos; the metadata here still selects them |
| `~/.local/share/wallpapers/Nothing{1,2,3}` (5 MB) | media | ships with the Nothing theme; `plasmarc` also points at `~/Pictures/wp12481712-dark-space-4k-wallpapers.jpg` |
| `~/.icons/WhiteSur-cursors` | 3.5 MB binary | `pkgs.whitesur-cursors`, installed by `modules/features/plasma/system.nix` |
| `~/.config/kdeconnect/` | device certificate + private key | re-pair devices |
| `~/.local/share/kwalletd`, `kwalletrc` passwords | secrets | re-enter |
| `~/.local/share/plasma-vault`, `plasmavaultrc` | encrypted vault + its config | vault metadata lives in `~/.local/share/plasma-vault` (not deleted by the migration) |
| `krdpserverrc` | points at RDP certificates | regenerate in System Settings → Remote Desktop |
| `mimeapps.list`, `gtk-{3,4}.0/settings.ini`, `gtk.css`, `.gtkrc-2.0` | owned by home-manager (default-apps.nix, gtk.nix) | HM writes its own; KDE's GTK sync will fight it (known limitation) |
| baloo index, klipper history, kactivitymanagerd, `session/`, `kconf_updaterc`, `katemetainfos`, `kactivitymanagerd-statsrc` | caches and session state | rebuilt by KDE |

## Revert recipe (emergency)

1. In `modules/hosts/serenity/host.nix`, replace `greetd niri noctalia` in
   the imports with `plasma` (keep `home-shashin`; `thunar` and
   `claude-skills` can stay). The plasma feature and greetd are mutually
   exclusive.
2. `nix flake check --no-build`, `nixos-rebuild build --flake ~/system-configs#serenity`,
   `nvd diff /run/current-system ./result`.
3. `sudo nixos-rebuild boot --flake ~/system-configs#serenity` and reboot;
   the Plasma login manager replaces tuigreet.
4. On first activation `modules/features/plasma/dotfiles.nix` copies this
   tree into `$HOME` **only where a file is absent** (`cp -Rn`). Files that
   still exist from the Plasma days are left alone.
5. Known limitation: home-manager keeps owning `~/.config/mimeapps.list` and
   the GTK `settings.ini`/`gtk.css`, so Plasma's own GTK theme sync and
   default-app changes made in System Settings will not stick. Either live
   with the Noctalia-era GTK look, or disable `gtk.enable` /
   `xdg.mimeApps.enable` for serenity with `lib.mkForce false` in
   `modules/hosts/serenity/home.nix`.
