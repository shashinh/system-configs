# TEXLIVE (minimal)
#
#   scheme-basic   latex, pdflatex, base fonts (Computer Modern)
#   amsmath        align, cases, \tfrac, \eqref
#   amsfonts       amssymb (\le, \ge, blackboard bold)
#   pgf            tikz, for the timing diagrams
#   latexmk        the build driver build.sh calls
#
# No TS1 (textcomp) fonts: write \textdegree-style symbols in math mode,
# and keep the template's `\renewcommand{\labelitemi}{$\bullet$}`.
# Add a collection here only when a new \usepackage needs it, and add
# the same name to the `combine` list in build.sh.
{
  flake.modules.nixos.texlive =
    { pkgs, ... }:
    {
      environment.systemPackages = [
        (pkgs.texlive.combine {
          inherit (pkgs.texlive)
            scheme-basic
            amsmath
            amsfonts
            pgf
            latexmk
            ;
        })
      ];
    };
}
