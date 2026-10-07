# Audio via PipeWire.
{
  flake.modules.nixos.pc = {
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true; # 32-bit apps (Wine, Steam)
      pulse.enable = true; # PulseAudio compatibility layer
      jack.enable = true; # JACK compatibility (audio production)
    };

    # RealtimeKit — lets PipeWire get real-time scheduling priority.
    security.rtkit.enable = true;
  };
}
