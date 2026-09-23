# Verifying lid-close suspend actually works (Framework 13 AMD 7840U / nostromo)

## Logs to check

After closing the lid, waiting, and reopening it, check these two logs for that
time window.

**1. Did logind register the lid event and act on it?**

```bash
journalctl -b -u systemd-logind --no-pager | tail -50
```

Look for a sequence like:

```
Lid closed.
Suspending...
Lid opened.
Operation 'suspend' finished.
```

If you see `Lid closed.` with no `Suspending...` right after, something (an
inhibitor) is blocking suspend — check with:

```bash
systemd-inhibit --list
```

`Operation 'suspend' finished` only means the operation completed without
erroring — it doesn't by itself prove real hardware suspend happened (see
below).

**2. Did the kernel actually enter/exit a sleep state?**

```bash
journalctl -k -b --since "<lid-close-time>" --until "<lid-open-time>" | grep -i suspend
```

You want to see both bracketing the window:

```
PM: suspend entry (s2idle)
...
PM: suspend exit
```

If the gap between `entry` and `exit` is only a few seconds, that's often just
how long you took to reopen the lid — not evidence of a problem. But if there's
an unusually long gap (10+ seconds) between `entry` and the `Suspending
console(s)` line that follows it, that's the kernel freezing
tasks/devices before actually sleeping — worth investigating if it's the
*bulk* of your test window, since it means the machine spent most of the test
preparing to sleep rather than actually asleep.

**3. Sanity-check elapsed time:**

```bash
journalctl -b -u systemd-suspend.service --no-pager
```

This unit's start/stop timestamps show how long the machine was actually
asleep. ~0s means it isn't really suspending.

## For a real power-savings test (not just "does it suspend")

A 15-30 second lid-close/open test mostly just exercises the suspend/resume
*path* — it doesn't tell you much about power draw while genuinely asleep.
For that:

```bash
# close the lid, walk away for 10+ minutes, then reopen, then:
journalctl -k -b --since "-15m" | grep -i suspend
```

Compare battery percentage before/after with:

```bash
upower -i /org/freedesktop/UPower/devices/battery_BAT0
```

## s2idle vs. deep sleep on this hardware

```bash
cat /sys/power/mem_sleep
```

This machine only offers `s2idle` (suspend-to-idle) — no `deep` (S3,
suspend-to-RAM) option, and there is nothing to configure to change that.

**Why:** starting with AMD Renoir-generation Ryzen mobile chips (through
Cezanne, Rembrandt, and this machine's Phoenix/7840U), the platform firmware
sets the ACPI FADT "Low Power S0 Idle" flag, which tells Linux the platform
doesn't implement S3 at all — this is a firmware/platform design choice (AMD's
S0i3 "Modern Standby"-style architecture), not a missing kernel driver or a
BIOS setting to find. Framework's AMD BIOS doesn't expose an S3 toggle either,
consistent with the reference platform. Forcing `mem_sleep_default=deep` via a
kernel param on this class of hardware is not a validated path — it's
generally ignored or produces a suspend that fails to resume.

**What actually matters for battery life here:** `s2idle` alone doesn't
guarantee good power savings — the OS can walk through the software suspend
steps while the SoC still fails to drop into its lowest hardware power state
(S0i3) if some driver/device holds a wakeup reference. AMD ships a diagnostic
for this specifically:

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/superm1/s2idle.git
cd s2idle
sudo python3 s2idle.py
```

(or `amd-s2idle` if packaged) — it suspends the machine, wakes it, and reports
whether the SoC actually reached deep S0i3 residency, which is a much better
signal for real power savings than journal timestamps alone.
