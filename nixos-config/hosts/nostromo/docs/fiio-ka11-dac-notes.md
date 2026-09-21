# FiiO KA11 USB DAC — verification notes (nostromo)

Context: FiiO KA11 USB-C dongle DAC (`2972:0081`), driven by PipeWire 1.6.8 /
WirePlumber via `services.pipewire` in `hosts/nostromo/configuration.nix`.
Kernel 7.1.8, `snd-usb-audio`.

**Verified against live state on 2026-09-16, with Spotify playing.** Nothing in
this repo sets any PipeWire property — every value below is a stock
PipeWire/NixOS default. No config change has been made; this doc is the
findings, not a record of a fix.

## Summary

The device is working. The signal path is 32-bit, async, hardware-volume, and
xrun-free. The one real gap is that PipeWire is pinned to 48 kHz and therefore
resamples all 44.1 kHz content. **The audible impact of that is almost
certainly nil** — see "Why this matters less than it looks" below before
changing anything.

## What was verified good

| Check | Live result |
|---|---|
| Driver binding | `snd-usb-audio` on interfaces 1 and 2 |
| USB link speed | High Speed, 480M (`usb-0000:c1:00.3-2`) |
| Bit depth | `S32_LE` — Altset 3, the deepest format the device offers |
| Sync mode | ASYNC, dedicated feedback endpoint `0x84`, 16.16 format |
| Packet interval | 125 µs |
| Xruns on the DAC node | 0 (`pw-top` node 82, `ERR` column) |
| Volume path | Hardware — see below |

**Volume is done in hardware, which is correct and worth not breaking.** The
ALSA `PCM Playback Volume` control carries the attenuation
(`channelVolumes 0.008`); PipeWire applies only a −0.94 dB software trim
(`softVolumes 0.897`). Confirmed via `pw-dump 79`. If you ever see
`softVolumes` doing the heavy lifting instead, something has pushed the device
onto software volume and that *is* worth chasing.

The KA11 advertises, per `/proc/asound/KA11/stream0`:

```
Rates: 44100, 48000, 88200, 96000, 176400, 192000, 352800, 384000
Altset 1  S16_LE    Altset 2  S24_3LE
Altset 3  S32_LE    Altset 4  DSD_U32_BE  (DSD raw: DOP=0, bitrev=0)
```

Note the firmware does expose a raw-DSD altset. Untested here; PipeWire will
not use it.

## The finding: sample rate is pinned to 48 kHz

```
$ pw-metadata -n settings
clock.rate          = 48000
clock.allowed-rates = [ 48000 ]
```

That is PipeWire's shipped default, unmodified — the upstream config has both
lines commented out at `share/pipewire/pipewire.conf:44-45`. The effect is that
the DAC will *never* leave 48 kHz, so everything in the 44.1 kHz family gets
sample-rate converted. Caught live in `pw-top`:

```
R  70  8192  44100 ... F32LE 2 44100  + spotify                 <- source
R  82  2048  48000 ... S32LE 2 48000    alsa_output...KA11...   <- DAC
```

44.1 → 48 kHz is a 147:160 ratio, so this is true interpolation (reconstruct
the waveform, re-measure at new time positions), not sample dropping. PipeWire
uses a windowed-sinc polyphase filter for it.

`resample.quality` is also at its default of **4** on a 0–14 scale — commented
out in every shipped config (`client.conf:101`, `pipewire-pulse.conf:85`).
Quality 4 is chosen to be cheap; 10+ is where the filter becomes effectively
unmeasurable.

## Why this matters less than it looks

**Spotify is lossy.** The codec artifacts in a decoded Ogg Vorbis/AAC stream
are orders of magnitude larger than anything a quality-4 sinc resampler adds.
For the current actual use of this machine, fixing the rate pinning buys
nothing audible.

No artifact measurements were taken on this machine, and none are quoted here.
The only claim being made is the ordering: **codec loss ≫ resampler loss.**

It starts to matter if:

1. Lossless sources get added (local FLAC, Qobuz, Tidal). The codec floor
   disappears and the resampler becomes the weakest link.
2. You want the 32-bit path to actually be earning its keep rather than
   carrying upsampled 16-bit lossy.
3. You want a bit-perfect chain on principle. Legitimate preference — just not
   an audibility claim.
4. You want the KA11's rate-indicator LED to reflect the true source rate. It
   currently can never leave its 48 kHz state.

## Blocker: the sink may never suspend

**Read this before applying the `allowed-rates` fix below — it may be a
complete no-op on this machine.**

PipeWire can only change a device's sample rate when the device **suspends**.
The Noctalia spectrum visualizer holds a permanent capture link on the KA11's
monitor ports:

```
$ pw-link -l
alsa_output.usb-FIIO_FIIO_KA11-01.analog-stereo:monitor_FL
  |-> .noctalia-wrapped:input_FL
alsa_output.usb-FIIO_FIIO_KA11-01.analog-stereo:monitor_FR
  |-> .noctalia-wrapped:input_FR
```

A permanently-attached monitor capture can keep the sink from ever going idle.
If `allowed-rates` is added and the rate stays stuck at 48000, this is why —
don't go looking for a second bug. Either close the visualizer, or adjust the
suspend behaviour for that node, before concluding the setting is broken.

Separately, that visualizer node is accumulating xruns (`ERR 64` on node 65).
It is a monitor-capture stream and is **not** in the playback path, so it is
not degrading audio. Don't misattribute a playback problem to it.

## Recommendations, in priority order

### 1. Raise resampler quality (works unconditionally)

The cheaper and more reliably effective knob. No dependency on suspend
behaviour, doesn't fight the visualizer, trivial CPU cost.

```nix
services.pipewire.extraConfig.client."10-resample" = {
  "stream.properties"."resample.quality" = 10;
};
```

### 2. Allow native rates (conditional on the blocker above)

```nix
services.pipewire.extraConfig.pipewire."92-allowed-rates" = {
  "context.properties" = {
    "default.clock.allowed-rates" =
      [ 44100 48000 88200 96000 176400 192000 352800 384000 ];
  };
};
```

`services.pipewire.extraConfig.pipewire` was confirmed to evaluate on this
flake's nixpkgs pin (`nixos-unstable`) — `nix eval` returns
`attribute set of (JSON value)`.

Rate switching only happens when the device is idle, so after applying this,
stop all playback or `systemctl --user restart pipewire` before testing.

### 3. Do nothing

Defensible. The current path is 32-bit, async, hardware-volume and glitch-free,
and the only content being played is lossy anyway.

## Re-verifying later

```bash
cat /proc/asound/KA11/stream0                    # device capabilities + live altset
cat /proc/asound/KA11/pcm0p/sub0/hw_params       # negotiated format and rate
pw-metadata -n settings | grep -i 'rate\|resample'
timeout 4 pw-top -b -n 3                         # per-node rate, format, xruns
pw-link -l | grep -i monitor                     # what is holding the sink busy
pw-dump 79 | grep -i 'channelVolumes\|softVolumes'
```

`hw_params` only exists while the device is actively playing. If it is absent,
the DAC is idle, not broken.

## Related

- `hosts/nostromo/docs/powertop-notes.md` — explains why
  `snd_hda_intel power_save` is deliberately left at `10`. That tunable is for
  the *internal* HD-Audio codecs (cards 0 and 1), not this USB DAC, which is
  unaffected by it.
