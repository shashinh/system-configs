# The backup drive for the `backup` feature: a 128 GB LUKS-encrypted USB
# stick (LUKS f51f8a07-…, ext4 dedc07a4-…). udisks mounts it by the ext4
# UUID because the filesystem has no label; labelling it would change the
# mount point.
{
  flake.modules.nixos.nostromo.features.backup.drive =
    "/run/media/shashin/dedc07a4-2d42-4315-982d-e0509b939f69";
}
