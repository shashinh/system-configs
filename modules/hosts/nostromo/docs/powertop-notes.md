# powertop tuning notes (Framework 13 AMD / nostromo)

Context: `powertop` (in `hosts/pc-common.nix`) is used to inspect power
tunables. Hardware: AMD Phoenix (Ryzen 7840U), Intel AX210 Wi-Fi, WD PC SN740
NVMe. PowerTOP 2.15, kernel 7.1.8, `amd-pstate-epp`, `power-profiles-daemon`
(no TLP).

**Verified against live state on 2026-09-15.** Nothing in this repo currently
writes any powertop tunable — every value below is a stock kernel/NixOS
default.

## Current state of each "Bad" item

### Already fine, ignore

**NMI watchdog** — powertop now reports this **Good**.
`kernel.nmi_watchdog` is already `0` on this kernel build, and nothing in
`/etc/sysctl.d` or the repo sets it. The `kernel.nmi_watchdog = 0` sysctl the
earlier version of this doc recommended is a no-op; don't add it.
(`kernel.watchdog` / `kernel.soft_watchdog` are still `1` — that's the soft
lockup detector, a different thing, and is cheap.)

**Enable Audio codec power management** — reported **Bad**, but it's a false
positive. PowerTOP 2.15 does a literal string compare of
`/sys/module/snd_hda_intel/parameters/power_save` against `"1"`. The live
value is `10` with `power_save_controller=Y`, i.e. codec runtime PM is
*already enabled* with a 10-second idle timeout; it just isn't the exact
string powertop wants.

Accepting powertop's fix sets it to `1`. On the ALC269-class codec in this
machine that's the classic cause of an audible pop/click when audio starts and
the first ~200ms of a sound being clipped, because the codec re-powers on
every short gap. **Leave it at 10.** If anything, raise it; never lower it.

### Safe to flip, but they save nothing

All the AMD Phoenix entries: *Dummy Host Bridge*, *Dummy Function*, *Data
Fabric Function 0–7*, *Root Complex*, *IOMMU*, *FCH LPC Bridge*, *FCH SMBus
Controller*, *CCP/PSP 3.0*.

These are internal chipset plumbing, not peripherals. Checked live: every one
of them either has **no driver bound at all** (Data Fabric, Dummy Host Bridge,
Root Complex, IOMMU, LPC) or a driver with no runtime-PM callbacks
(`piix4_smbus`, `k10temp`, `ccp`). `pci_pm_runtime_suspend()` returns
`-ENOSYS` when the bound driver has no `runtime_suspend`, so setting
`power/control=auto` on these changes a string in sysfs, flips powertop's
display to Good, and suspends nothing.

So: zero instability risk, and also **zero power saving**. Flip them only if
you want a clean powertop screen. This is the honest reason to skip the udev
rule entirely.

### Leave alone — real risk, no upside

**`[AMD/ATI] Phoenix1` (`c1:00.0`, `1002:15bf`) — the integrated GPU.**
Currently `power/control=on`. This is the display engine, not a discrete GPU
that can be powered off while something else drives the panel. amdgpu only
arms runtime PM for dGPU/PRIME/BOCO configurations; on an APU it deliberately
runs in `RUNPM_NONE`. Forcing `auto` here is the entry on this list most
likely to produce a black screen or a hung compositor, for no measurable gain.

Note this device is vendor `0x1002` (ATI), **not** `0x1022` (AMD) — so a
blanket `ATTR{vendor}=="0x1022"` udev rule does not touch it. Good.

### Worth testing individually

**NVMe runtime PM — WD PC SN740 (`15b7:5017`, `02:00.0`).**
Note: this is an SN740 (OEM drive), not the SN770 an earlier version of this
doc claimed. Runtime PM plus APST is generally fine on modern kernels, but
this exact family has a history of deep-power-state trouble on Framework
hardware — symptoms are I/O stalls of a few seconds, or
`nvme nvme0: I/O tag ... timeout, aborting` in the kernel log. The standard
mitigation is capping the deepest state via
`nvme_core.default_ps_max_latency_us=` on the kernel command line rather than
disabling runtime PM.

**Wi-Fi runtime PM — Intel AX210 (`8086:2725`, `01:00.0`).**
`iwlwifi` handles this well now, but latency spikes and reconnects are still
reported. Separately: `/sys/module/iwlwifi/parameters/power_save` is `N` —
that's the *radio's* 802.11 power save (PS-Poll), a different knob from PCI
runtime PM, and NetworkManager may override it per-connection anyway. Don't
conflate the two.

### Durability tradeoff, not a stability one

**VM writeback timeout** (`vm.dirty_writeback_centisecs`) — live value `500`
(the 5s default). Controls how often dirty pages are flushed to disk. Raising
it lets the CPU and SSD coalesce writes and idle longer.

Safe for the system; the cost is that more unsaved data sits in RAM, so an
unclean shutdown or power loss loses more. `1500` is the usual sweet spot;
powertop's own auto-tune also picks 1500. Going to 6000+ is not worth it on a
laptop that suspends rather than shuts down.

## Do not use `powerManagement.powertop.enable`

NixOS offers `powerManagement.powertop.enable = true`, which runs
`powertop --auto-tune` at boot. It flips **every** tunable indiscriminately —
including the iGPU, NVMe, Wi-Fi, and audio `power_save=1`. Given that the only
items with real savings here are also the only items with real risk, that
option buys the risk and almost none of the benefit. Configure selectively
instead.

## If you do want to persist something

```nix
# The only line here with a measurable effect.
boot.kernel.sysctl."vm.dirty_writeback_centisecs" = 1500;

services.udev.extraRules = ''
  # Cosmetic only: AMD chipset plumbing (0x1022). These devices have no
  # runtime-PM-capable driver, so this saves no power — it only quiets
  # powertop. Excludes the iGPU (0x1002), NVMe (0x15b7) and Wi-Fi (0x8086).
  ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{power/control}="auto"

  # Enable only after the observation period below:
  # ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x2725", ATTR{power/control}="auto"
  # ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x15b7", ATTR{device}=="0x5017", ATTR{power/control}="auto"
'';
```

`hosts/nostromo/power-profile.nix` already defines `services.udev.extraRules`
for AC-adapter handling. Multiple modules setting it is fine — NixOS
concatenates them — but keep power tunables in their own module rather than
appending to that one.

## Testing a tunable without committing to it

Runtime PM is writable live and resets on reboot, so test before putting it in
the flake:

```bash
# Try it
echo auto | sudo tee /sys/bus/pci/devices/0000:02:00.0/power/control   # NVMe
echo auto | sudo tee /sys/bus/pci/devices/0000:01:00.0/power/control   # Wi-Fi

# Revert
echo on | sudo tee /sys/bus/pci/devices/0000:02:00.0/power/control
```

## What to observe for stability

Run for at least a week of normal use, including several suspend/resume
cycles, before trusting either of the two risky ones.

```bash
# Kernel errors this boot — the single most useful check
journalctl -k -p err -b

# Across reboots, for NVMe timeouts and iwlwifi firmware errors
journalctl -k --since "7 days ago" | grep -iE "nvme|iwlwifi|firmware error|hardware error"

# Did it actually enter a low-power state? (runtime_suspended_time grows)
cat /sys/bus/pci/devices/0000:02:00.0/power/runtime_status
cat /sys/bus/pci/devices/0000:02:00.0/power/runtime_suspended_time
```

Specific symptoms to watch for:

- **NVMe**: `I/O tag ... timeout`, `controller is down`, multi-second UI
  freezes during file writes, or a hang on resume. Revert immediately — this
  one can cost data.
- **Wi-Fi**: `iwlwifi ... Microcode SW error`, unexplained reconnects, or
  ping latency spiking from ~1ms to hundreds of ms on an idle link. Test with
  `ping -i 0.2` while the link is otherwise idle.
- **Audio** (only if you ignored the advice above and set `power_save=1`):
  a pop on playback start, or the first fraction of a notification sound
  missing.
- **Display** (only if you forced the iGPU to `auto`): black screen on
  return from idle, cursor-only screen, or compositor restart.

Measuring whether any of it helped — this battery exposes `current_now`
(µA) and `voltage_now` (µV) but no `power_now`, so compute watts:

```bash
awk '{v[NR]=$1} END{printf "%.2f W\n", v[1]*v[2]/1e12}' \
  /sys/class/power_supply/BAT1/current_now \
  /sys/class/power_supply/BAT1/voltage_now
```

Compare on battery, screen at a fixed brightness, idle desktop, before and
after. Expect the chipset rules to move this by nothing; NVMe and Wi-Fi
runtime PM are where any real change would show up.

## Related

- `hosts/nostromo/docs/suspend-verification-notes.md` — confirming
  suspend/resume actually works, which overlaps with the resume-side symptoms
  above.
- `hosts/nostromo/docs/touchpad-resume-bug-notes.md` — a known
  resume-related fault; don't misattribute it to a power tunable.
