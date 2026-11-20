# DEVELOPER (minimal)
#
# A baseline toolchain for the languages the Neovim LSP setup covers
# (modules/users/shashin/home/neovim.nix). The language servers live in
# Neovim's own PATH; this feature adds the compilers and build tools they
# expect to find on the system PATH.
#
#   Rust     cargo, rustc, rustfmt, clippy. RUST_SRC_PATH points
#            rust-analyzer at the std sources so it can resolve std items.
#   C/C++    gcc, make, cmake, gdb. bear wraps a build (`bear -- make`) to
#            write the compile_commands.json clangd reads for include paths
#            and flags.
#   Python   python3
#   Java     temurin-bin is the JDK (javac). It's the same Temurin release
#            as pc's temurin-jre-bin, so the duplicate `java` is harmless.
#   Nix      nixfmt, the formatter nixd calls.
#
# A project that pins its own toolchain (a flake devShell, `nix develop`)
# takes precedence over these inside that shell.
{
  flake.modules.nixos.developer =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        # Rust
        cargo
        rustc
        rustfmt
        clippy

        # C / C++
        gcc
        gnumake
        cmake
        gdb
        bear

        # Python
        python3

        # Java
        temurin-bin

        # Nix
        nixfmt
      ];

      environment.variables.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
    };
}
