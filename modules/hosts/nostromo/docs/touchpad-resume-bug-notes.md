# Touchpad going haywire after suspend/resume (Framework 13 AMD 7840U / nostromo)

## Symptoms

Intermittently, after resuming from suspend (observed trigger: lock screen →
display timeout → close lid to suspend without unlocking → reopen lid),
the built-in touchpad misbehaves for anywhere from a few seconds to a few
minutes, then spontaneously returns to normal with no action needed:

- The cursor is visible and still warps to the center of the focused window
  (niri's configured behavior), but moving a finger on the touchpad does
  **not** move it.
- Physical clicks (tap-to-click / hardware click) **do** register.
- While a right-click context menu is open, the cursor **can** be moved.
- Three-finger swipes (niri: switch workspace/column) register as
  two-finger swipes (scroll).
- Four-finger swipes (niri: open overview) register as three-finger swipes.

## Hardware identified

```
$ grep -A15 Touchpad /proc/bus/input/devices
I: Bus=0018 Vendor=093a Product=0274 Version=0100
N: Name="PIXA3854:00 093A:0274 Touchpad"
P: Phys=i2c-PIXA3854:00
S: Sysfs=/devices/platform/AMDI0010:03/i2c-1/i2c-PIXA3854:00/0018:093A:0274.0004/input/input9
```

- Touchpad: PixArt **PIXA3854** (`093A:0274`), the stock touchpad on the
  Framework 13 AMD (7840U).
- Bus path: I2C-HID, via `i2c_hid_acpi` → `i2c_hid` → `hid-multitouch`.
- Currently bound driver instance: `0018:093A:0274.0004`
  (`/sys/bus/hid/drivers/hid-multitouch/0018:093A:0274.0004`).
- This machine has **no S3/deep sleep** — only `s2idle`
  (`cat /sys/power/mem_sleep` → `[s2idle]`). This is an AMD platform/firmware
  choice (Low Power S0 Idle FADT flag on Renoir-through-Phoenix chips), not
  something fixable via kernel params. See `suspend-verification-notes.md`
  for background. This matters because `s2idle` depends on every device
  driver's runtime-PM resume path reinitializing correctly, unlike S3.

## What was checked locally

- `journalctl -k -b 0`, filtered to every `PM: suspend entry` / `PM: suspend
  exit` window in the current boot, including the resume that reproduced the
  bug (2026-08-31, suspend 17:01:46 → resume 18:47:44 — niri's own log
  confirms a lock/unlock cycle right at that resume, matching the reported
  trigger).
- In **every** resume window, across the whole boot, the i2c-hid touchpad
  logs nothing at all — no error, no reinit message — unlike `amdgpu`,
  `iwlwifi`, or USB devices, which log extensively on resume. This is
  consistent with a *silent* firmware/report-mode desync rather than a
  crashed or errored driver (so there's nothing to grep for after the fact;
  it would need to be caught live).
- Noctalia's idle chain (`~/.local/state/noctalia/settings.toml`): lock at
  300s → screen-off at 330s → auto-suspend-on-idle disabled. So in the
  reported scenario, suspend was triggered by the lid switch via
  `systemd-logind`, on top of an already-locked, already-screen-off session
  — not by Noctalia's idle daemon itself.
- No niri/libinput touchpad config exists in this repo or in
  `~/.config/niri/config.kdl` beyond defaults (`tap` enabled) — this isn't a
  config-induced issue on the niri/libinput side.

## Root cause (well-documented elsewhere, not yet caught live on this machine)

The PIXA3854 exposes **two HID report collections**: a full Precision
Touchpad (PTP/multitouch) collection, and a legacy "Mouse" collection kept
around for BIOS/pre-boot compatibility. Normally only the PTP collection is
active. There's a documented class of bug — reported against this exact
touchpad family on Framework 12 and Framework 13 AMD — where, on resume from
`s2idle`, the device briefly renegotiates in the wrong mode and the legacy
Mouse collection ends up active instead of (or alongside) the PTP one:

- **Clicks still work**, because the Mouse collection reports buttons fine.
- **Motion is broken/erratic**, because on at least one documented PIXA3854
  case, the legacy collection has a firmware bug where relative X/Y are
  declared unsigned (0–255) instead of signed, so negative deltas wrap into
  huge positive values.
- **Gesture finger-count is off by one** (3→2, 4→3), because libinput's
  gesture recognizer counts simultaneous touch contacts from the PTP report;
  a touchpad stuck partway into the legacy/degraded mode under-reports one
  contact, undercounting every multi-finger gesture by exactly one.
- **Self-recovery with no action** matches multiple reports of the device
  eventually renegotiating back into full PTP mode on its own after enough
  HID traffic/interrupts occur.

**Confidence:** This is a strong circumstantial match (right hardware
family, right driver class, and the full symptom cluster — click-works /
motion-broken / gesture-off-by-one / self-heals) but it has **not** been
directly confirmed on this machine — the touchpad doesn't log anything when
it happens, so nothing in the journal proves the mechanism after the fact.
The most detailed community root-cause writeup (link #2 below) is explicitly
flagged by its author as AI-assisted debugging, not independently verified
by kernel maintainers.

## Why it's intermittent, not deterministic

Given this is tied to specific hardware, it's fair to ask why it wouldn't
reproduce every single resume. The intermittency is itself evidence for the
race-condition theory above, not against it:

- The community writeup attributes this to **insufficient delay after the
  `SET_POWER_ON` command** before the host renegotiates the HID report mode
  — i.e. a race between the I2C controller resuming and the touchpad's own
  firmware finishing its internal boot sequence. Races resolve differently
  run to run depending on sub-millisecond timing, not fixed logic. The
  Framework 13 AMD community thread quantifies this directly: reporters see
  it on roughly **1 in 10 resumes**.
- **Shared I2C bus contention**: the touchpad shares its `AMDI0010` I2C
  controller with the ambient-light sensor hub (`hid_sensor_hub`, present in
  `lsmod`). If the sensor hub is probing/resuming at the same moment, it can
  shift exactly when the touchpad's power-on command lands relative to when
  its firmware is ready — pure timing jitter, unrelated to the touchpad
  itself.
- **Suspend depth/duration varies cycle to cycle.** Most resumes in this
  boot's journal took tens of seconds to over an hour, but one was only
  **3 seconds** (`13:13:13` suspend → `13:13:16` resume). `s2idle` doesn't
  guarantee the same actual hardware residency (S0i3) every time — a
  shallower/shorter suspend gives the touchpad firmware less time to fully
  reset, plausibly changing whether it resumes in the right mode.
- **The self-healing behavior argues against deterministic logic.** A fixed
  descriptor-parsing bug wouldn't spontaneously correct itself without an
  external nudge. Recovering on its own after a variable delay — driven by
  however many HID interrupts happen to arrive — is itself a signature of a
  race that eventually resolves correctly, not a static logic error.

## Why this didn't occur under 2+ years of Arch + KDE

Reasonable to ask: if this is tied to specific hardware, shouldn't it have
shown up on this same machine long before now? A few facts from this repo's
own history reframe the question — this isn't "2+ years unchanged, then
suddenly broke," it's a full-stack migration that happened within the last
month:

- This NixOS install started **2026-08-04** (`migrate+init` commit).
- niri + Noctalia were set up **2026-08-18** — roughly two weeks before this
  bug was investigated.
- The BIOS is version **03.18, dated 2026-01-08** (`/sys/class/dmi/id/bios_version`,
  `bios_date`) — notably recent relative to a 2+-year-old install. Whether
  this was flashed as part of the migration is unconfirmed — worth checking,
  since Framework's BIOS/EC updates for the 7040 series have repeatedly
  touched S0i3/sleep-path behavior in their changelogs, and EC firmware is a
  plausible independent cause of a shift in touchpad init timing, unrelated
  to distro or compositor entirely.

So effectively every layer changed at once: distro (Arch → NixOS),
compositor (KDE/KWin → niri), idle/lock/suspend stack (PowerDevil → Noctalia
idle daemon + `systemd-logind` lid handling), possibly the kernel version,
and possibly firmware. That makes a single root cause hard to isolate — but
it is **not** accurate to conclude that KDE's more tightly-synchronized
resume orchestration was itself the primary reason this stayed latent.
Reference #3 below (`touchpad-doesnt-work-when-resuming-from-sleep`)
explicitly reports the same bug occurring under **Windows 11** on this same
hardware family. Windows' Modern Standby (S0ix) orchestration is, if
anything, more tightly integrated than any Linux desktop's idle/lock/suspend
stack — so if the bug still surfaces there, orchestration-tightness cannot
be the root cause. The root cause remains the kernel/firmware-level I2C-HID
resume race described above, which is orthogonal to desktop environment or
OS. What plausibly differs across environments is *exposure* to that
pre-existing race, not its existence:

1. **Idle/suspend orchestration is architecturally different now, and that
   plausibly shifts exposure to the race window — it does not create it.**
   KDE's PowerDevil handles idle-dim → lock → suspend as one internally
   coordinated policy. Here, Noctalia's idle daemon (lock at 300s,
   screen-off at 330s) is a *separate* process from `systemd-logind`, which
   is what actually acts on the lid switch. The observed trigger — lock,
   wait for screen-off, *then* close the lid — stacks two independently-
   timed subsystems on top of each other before the actual `suspend()`
   call. If KDE more often went straight from an open lid to a lid-close
   suspend (without first idling out through a separate daemon), that's a
   materially different event sequence leading into suspend — enough to
   shift the odds of landing in the race's failure window on any given
   resume (see "Why it's intermittent" above), without implying KDE's
   orchestration made the underlying firmware race not exist.
2. **It may have been happening under KDE too, just unnoticed.** The
   touchpad's I2C-HID resume glitch is at the kernel/firmware layer —
   compositor-agnostic in principle. But niri exposes native 3-/4-finger
   swipe gestures directly, and those are core navigation now. A silent,
   self-healing glitch that manifests as "gestures feel a bit off for a few
   seconds" is far easier to miss if the old setup didn't rely on
   multi-finger swipes as heavily, or didn't surface them the same way
   (unconfirmed whether the old KDE session was X11 or Wayland — X11
   sessions typically don't expose native multi-finger gesture recognition
   without an add-on daemon).
3. **Kernel version.** NixOS tracks `linuxPackages_latest`
   (`hosts/nostromo/configuration.nix`), which may be ahead of whatever
   kernel Arch had settled into. There are documented kernel-version-
   specific regressions in this bug class elsewhere (e.g. a related
   touchscreen regression reported as introduced at 6.10) — plausible but
   unverified here, since the prior Arch kernel version isn't known.

The BIOS/EC update is the most concrete unconfirmed lead — if it was
flashed around the migration, that plus the idle-chain architecture change
are the two most likely explanations for a genuine behavior change. The
distro/compositor switch itself is probably not the root cause, but is a
plausible reason the issue is being *noticed* now rather than before.

## References

Framework community threads (closest match first):

1. Framework 12 + Omarchy Quattro dead touchpad after hibernation / reboot
   (root-cause writeup: legacy Mouse HID collection activating instead of
   PTP, unbind/rebind workaround, systemd-sleep hook) —
   https://community.frame.work/t/framework-12-omarchy-quattro-dead-touchpad-after-hibernation-reboot/84334
2. Framework Laptop 12 — after hibernate the pointer only moves down and
   right (touchpad stuck in mouse mode, PIXA3854 093A:0239) —
   https://community.frame.work/t/framework-laptop-12-after-hibernate-the-pointer-only-moves-down-and-right-touchpad-stuck-in-mouse-mode-pixa3854-093a-0239/84327
3. Touchpad doesn't work when resuming from sleep (Framework 13 AMD
   7040-series, ~1-in-10 resumes) —
   https://community.frame.work/t/touchpad-doesnt-work-when-resuming-from-sleep/72721
4. Trackpad sometimes stops responding after waking from sleep (Framework
   Laptop 12) —
   https://community.frame.work/t/trackpad-sometimes-stops-responding-after-waking-from-sleep/71804
5. Issues with touchpad/cursor and framework 12 —
   https://community.frame.work/t/issues-with-touchpad-cursor-and-framework-12/83347
6. Sleep and Touchpad Not Responding? (older Framework 13 thread, same
   pattern across generations) —
   https://community.frame.work/t/sleep-and-touchpad-not-responding/4928

Broader i2c-hid / PTP resume bug class (non-Framework-specific,
corroborating the general mechanism):

7. Arch Linux Forums — Unresponsive touchpad due to i2c_designware and
   i2c_hid_acpi —
   https://bbs.archlinux.org/viewtopic.php?id=295939
8. Ubuntu Launchpad Bug #1842532 — Touchpad stops working after resuming
   from s2idle —
   https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1842532
9. LKML — HID: i2c-hid: Delayed i2c resume wakeup for 0x0d42 Goodix
   touchpad (kernel patch for a different vendor showing the same
   "insufficient delay after resume → wrong mode" pattern) —
   https://lkml.rescloud.iu.edu/2410.3/05561.html

## Live diagnostic (not yet run)

Before committing to the declarative fix below, the theory can be confirmed
next time the bug is observed, with no config changes, by unbinding and
rebinding the `hid-multitouch` driver for this device:

```bash
echo 0018:093A:0274.0004 | sudo tee /sys/bus/hid/drivers/hid-multitouch/unbind
echo 0018:093A:0274.0004 | sudo tee /sys/bus/hid/drivers/hid-multitouch/bind
```

If the touchpad immediately snaps back to normal, that confirms the
"wrong HID collection bound" theory and validates the fix below. (The
device instance ID `093A:0274.0004` should be re-checked at the time —
`ls /sys/bus/hid/drivers/hid-multitouch/` — since it's not guaranteed
stable across boots.)

## Proposed declarative fix (not yet applied)

Add a `systemd-sleep` hook, declared in NixOS, that unbinds and rebinds the
touchpad's `hid-multitouch` driver instance on every resume — forcing it to
renegotiate its HID report descriptor and land back on the correct PTP
collection, rather than waiting for it to self-heal.

`systemd-sleep` hooks are invoked with `$1` = `pre`/`post` and `$2` =
`suspend`/`hibernate`/etc., so the script only acts on `post suspend`. The
touchpad's vendor/product ID (`093A:0274`) is stable across boots even
though the trailing `.0004` instance suffix may not be, so the script
should glob-match rather than hardcode the full ID.

```nix
# hosts/nostromo/touchpad-resume-fix.nix
{ pkgs, ... }:

let
  script = pkgs.writeShellScript "touchpad-resume-rebind" ''
    set -euo pipefail
    [ "$1" = "post" ] || exit 0

    for dev in /sys/bus/hid/drivers/hid-multitouch/0018:093A:0274.*; do
      [ -e "$dev" ] || continue
      id="$(basename "$dev")"
      echo "$id" > /sys/bus/hid/drivers/hid-multitouch/unbind
      echo "$id" > /sys/bus/hid/drivers/hid-multitouch/bind
    done
  '';
in
{
  environment.etc."systemd/system-sleep/touchpad-resume-rebind" = {
    source = script;
    mode = "0755";
  };
}
```

Then import it from `configuration.nix` alongside the existing
`./niri.nix` import.

Caveats to weigh before applying:

- This is a workaround for a suspected firmware/driver quirk, not a real
  fix — if the root-cause theory above is wrong, this hook is a no-op at
  best and could introduce a brief touchpad hiccup on every single resume
  (unbind/bind takes it offline for a moment) even on resumes that weren't
  going to hit the bug.
- Worth trying the live diagnostic above first, ideally while the bug is
  actively happening, to confirm the mechanism before making this
  permanent and unconditional on every resume.
- If confirmed, consider scoping it tighter (e.g. only rebind if the
  Mouse collection is detected as active) rather than unconditionally
  rebinding on every resume — not implemented here pending confirmation.
