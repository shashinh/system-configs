# Media keys: playerctld remembers which MPRIS player was used last, so the
# playerctl binds in dotfiles/niri (XF86AudioPlay and friends) act on that
# player instead of on whichever one happens to be listed first (a Firefox
# tab with media, KDE Connect's proxy for the phone, ...).
{
  flake.modules.homeManager.shashin =
    { ... }:
    {
      services.playerctld.enable = true;
    };
}
