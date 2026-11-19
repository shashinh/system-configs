# Rootless podman for containerised benchmark harnesses (Harbor /
# Terminal-Bench, driven from ~/Projects/serenity-localai-overhaul).
#
# Rootless image storage goes to /data/containers/<user> instead of
# ~/.local/share/containers: task images are large and re-downloadable, so
# they stay off the home volume. Hosts importing this need a /data mount.
#
# docker-compose is on PATH because Harbor's podman environment drives
# `podman compose`, which prefers docker-compose over podman-compose (the
# latter lacks `cp`).
{
  flake.modules.nixos.podman =
    { pkgs, ... }:
    {
      virtualisation.podman.enable = true;

      # Only the rootless image store moves; rootful storage and the rootless
      # runroot keep their defaults.
      virtualisation.containers.storage.rootless.settings.storage.graphroot =
        "/data/containers/$USER/storage";

      # No tmpfiles rule for that path: /data is user-owned, so podman creates
      # the directory itself, and systemd-tmpfiles refuses to manage a
      # root-owned directory beneath a user-owned parent ("unsafe path
      # transition").

      environment.systemPackages = [ pkgs.docker-compose ];
    };
}
