# powertop tuning notes (Framework 13 AMD / nostromo)

Context: `powertop` was added to `nixos-config/hosts/pc-common.nix` to check for
power tunables. On the AMD Phoenix + Intel AX210 hardware, the "Tunables" tab
flagged the following as "Bad".

## What each category means

**NMI watchdog**
Kernel debug feature that pings each CPU core via a non-maskable interrupt so
the kernel can detect a hard lockup (core stuck with interrupts disabled) and
panic/report it. Costs a small amount of power/wakeups for a feature that's
only useful when debugging kernel hangs.

**VM writeback timeout** (`vm.dirty_writeback_centisecs`)
Controls how often dirty (written-but-not-yet-persisted) pages get flushed
from RAM to disk — default is every 5s. Raising it lets the disk/CPU coalesce
writes and idle longer between flushes. Tradeoff: more dirty data sits in RAM
longer, so a crash or power loss loses more unsaved work.

**Runtime PM for PCI Device X**
Sets `power/control = auto` for that PCI device, letting the kernel
autosuspend it when idle instead of keeping it at D0 permanently. Risk varies
a lot by device.

## What's safe to flip vs. what to test carefully

**Safe, essentially no downside:**
- All the "AMD Phoenix Dummy Host Bridge / Dummy Function / Data Fabric
  Function N / Root Complex / IOMMU / FCH LPC Bridge / FCH SMBus Controller /
  PSP/CCP" runtime-PM entries. These are internal chipset plumbing devices,
  not real peripherals — negligible effect either way, no realistic
  instability risk.
- NMI watchdog off — pure debugging aid, not in use. No stability impact.

**Worth testing before trusting long-term:**
- **NVMe SSD runtime PM** (Sandisk WD SN770) — generally fine on modern
  kernels, but a subset of NVMe firmware has had bugs with aggressive
  APST/runtime suspend causing stutter or rare filesystem hiccups. Watch
  `dmesg` for NVMe errors for a week before treating as permanent.
- **Wi-Fi (Intel AX210) runtime PM** — iwlwifi handles this well these days,
  but occasional latency spikes/reconnects are still reported on some setups.
  First thing to revert if Wi-Fi gets flaky.

**Tune with data-safety awareness (not a stability risk, but a durability
tradeoff):**
- **VM writeback timeout** — safe for the system, but increasing it trades
  data durability for power savings. A modest bump (500 → 1500 centisecs) is
  the common sweet spot; going much higher (powertop sometimes suggests
  6000+) means more data at risk on an unclean shutdown.

## How to persist in NixOS

```nix
boot.kernel.sysctl = {
  "kernel.nmi_watchdog" = 0;
  "vm.dirty_writeback_centisecs" = 1500;
};

services.udev.extraRules = ''
  # Runtime PM for AMD Phoenix chipset devices (safe — internal fabric/bridges)
  SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{power/control}="auto"

  # Runtime PM for AX210 wifi — enable only after testing for flakiness
  # SUBSYSTEM=="pci", ATTR{vendor}=="0x8086", ATTR{device}=="0x2725", ATTR{power/control}="auto"
'';
```

The AMD vendor-ID rule (`0x1022`) sweeps all the Phoenix chipset entries in
one line without touching NVMe or Wi-Fi, so those two can be added
individually once confirmed stable.
