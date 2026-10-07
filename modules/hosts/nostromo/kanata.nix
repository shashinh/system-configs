{
  flake.modules.nixos.nostromo =
    { ... }:

{
  services.kanata = {
    enable = true;
    keyboards.fw13 = {
      # AT Translated Set 2 keyboard, i8042/serio0 — the laptop's built-in
      # keyboard. No by-id link exists for it (that's USB-only); by-path is
      # stable here since it's derived from the platform bus, not USB
      # enumeration order. Restricting to this device keeps the remap off
      # any external keyboard (e.g. Keychron Q10) plugged in over USB.
      devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
      # process-unmapped-keys lives here, not in kanata-fw13.kbd's `config`:
      # the module generates its own defcfg from devices/extraDefCfg and
      # appends `config` after it, so a second defcfg in the file errors
      # with "Only one defcfg is allowed".
      extraDefCfg = "process-unmapped-keys yes";
      config = builtins.readFile ./kanata-fw13.kbd;
    };
  };
}
;
}
