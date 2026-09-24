# Thunar file manager, with its archive plugin actually functional.
#
# Two separate NixOS gotchas are handled here.
#
# 1. PLUGIN DISCOVERY. Thunar loads plugins only from its own lib/thunarx-3
#    directory, fixed at build time, and thunarx offers no environment
#    variable to extend that path. A plugin installed as its own package
#    therefore lands in a store path Thunar never reads and silently does
#    nothing. The NixOS module is the only correct route: it rebuilds Thunar
#    with the plugins merged in
#        finalPackage = package.override { thunarPlugins = plugins; }
#    Consequently Thunar must NOT also be in home.packages — that unwrapped
#    copy shadows this one in PATH and has no plugins.
#
# 2. THE ARCHIVE BACKEND. thunar-archive-plugin does not compress anything
#    itself, and does not use zip/unzip. It scans its own
#    libexec/thunar-archive-plugin/*.tap helper scripts and runs the first one
#    whose matching binary is on PATH. Version 0.6.0 ships helpers for exactly
#    three managers — ark, engrampa, file-roller (plus aliases) — and notably
#    NO xarchiver.tap. With only xarchiver installed the menu entries appear
#    but fail with "a suitable application was not found". file-roller is the
#    GTK one, so it matches Thunar; ark would drag in KDE.
#
# Enabling this also turns on programs.xfconf, which Thunar uses to persist
# per-folder view settings.
{
  flake.modules.nixos.thunar =
    { pkgs, ... }:
    {
      programs.thunar = {
        enable = true;
        plugins = with pkgs; [
          thunar-archive-plugin # "Extract Here" / "Create Archive" entries
        ];
      };

      # The backend the archive plugin actually drives (see note 2 above).
      environment.systemPackages = [ pkgs.file-roller ];
    };
}
