# zram creates a compressed in-RAM swap device — no disk space used.
# algorithm = zstd gives the best compression/speed ratio.
# memoryPercent = 50 means zram can use up to half of physical RAM.
# With 128 GB RAM, that's 64 GB of compressed swap — far more than you
# will ever need. Lower this to 25 if you prefer a conservative setting.
#
# There is NO disko configuration for zram. This NixOS option is all you need.
# (nostromo additionally raises vm.swappiness for zram in its own module.)
{
  flake.modules.nixos.pc = {
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };
  };
}
