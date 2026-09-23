# NixOS Install Guide — serenity & nostromo

This guide takes you from a blank machine to a fully running NixOS system with:
- BTRFS on LUKS2 (two independent encrypted pools)
- KDE Plasma 6, using Plasma Login Manager (PLM) as the display manager
- Lanzaboote secure boot
- TPM2 + PIN LUKS unlock
- zram swap
- All subvolumes pre-staged for future impermanence

This guide covers **both hosts** in the flake:
- **serenity** — Framework Desktop AI Max+ 395
- **nostromo** — Framework 13 Ryzen 7840U

Anywhere you see `$HOST`, substitute `serenity` or `nostromo` depending on which
machine you're installing. A few phases are called out as host-specific where
the two machines genuinely differ (fingerprint reader hardware, disk layout).

**Phases at a glance**

| Phase | What happens | Machine state |
|-------|-------------|---------------|
| 1 | Boot installer, get online | Live USB |
| 2 | Learn about the flake, verify disk devices | Live USB |
| 3 | Disko partitions and formats both drives | Live USB |
| 4 | Generate hardware config, run nixos-install | Live USB → First reboot |
| 5 | First boot verification | Installed system |
| 6 | Enroll Secure Boot keys, enable lanzaboote | Installed system |
| 7 | Enroll LUKS to TPM2 + PIN | Installed system |
| 8 | Enroll fingerprints | Installed system |
| 9 | Enable impermanence (optional, your schedule) | Installed system |

---

## A note on Flakes (read before starting)

A **Nix flake** is just a directory with a `flake.nix` file. Think of it like a
`package.json` for your whole system. It has two parts:

```
inputs  — where to fetch things from (nixpkgs, lanzaboote, disko, etc.)
outputs — what you produce (your NixOS system configuration)
```

When you run `nixos-install --flake .#$HOST`, Nix reads `flake.nix`, resolves
all inputs (downloading them), and builds your system. The resolved versions are
locked in `flake.lock` — a file you commit to git. This means you can reproduce
the exact same system months later.

Key commands you will use:
```
nix flake update           # update all inputs to latest (like npm update)
nix flake update nixpkgs   # update only nixpkgs
nixos-rebuild switch       # rebuild and activate the running system
nixos-rebuild switch --upgrade  # rebuild after updating flake.lock
```

You only need these after the install. During install you use `nixos-install`.

---

## Phase 1 — Boot the installer

### 1.1 Download the NixOS ISO

Download the **graphical** installer (not minimal) from https://nixos.org/download.
Grab whatever is currently the latest stable release ISO — don't hardcode a
version number here, it'll just go stale.

Write it to a USB drive:
```bash
# On Linux (replace /dev/sdX with your USB, and the filename with the ISO you downloaded):
sudo dd if=nixos-graphical-*-x86_64-linux.iso of=/dev/sdX bs=4M status=progress conv=fsync

# Or use Balena Etcher / Rufus on Windows/Mac.
```

### 1.2 UEFI settings before you boot

Before booting the USB, enter the UEFI (press **F2** at the Framework logo on
either machine):

1. **Disable Secure Boot** for now. Go to Security → Secure Boot → Disable.
   - You will re-enable it in Phase 6.
2. **Set boot order**: USB drive first, then NVMe.
3. **Save and exit** (F10).

> **What you see after saving:** The machine restarts and shows the USB boot
> menu. You may see a black screen briefly while the kernel loads.

### 1.3 Boot the installer

Select **NixOS Graphical Installer** from the USB boot menu.

> **What you see:** A graphical desktop environment (GNOME or KDE-based) with
> the NixOS installer icon on the desktop. There is also a terminal available.

### 1.4 Get internet access

**Ethernet (easiest):** Plug in a cable. NetworkManager connects automatically.

**WiFi:**
1. Click the network icon in the taskbar or open a terminal and run:
   ```
   nmtui
   ```
2. Select "Activate a connection" → pick your WiFi → enter password.

**Verify connectivity:**
```bash
ping -c 3 1.1.1.1
```
> **Expected output:** Three lines of `64 bytes from 1.1.1.1: ...` with no packet loss.

### 1.5 Open a terminal

Right-click the desktop → Open Terminal, OR find a terminal in the app menu.
All remaining steps in this guide are terminal commands.

Become root (stays as root for the install session):
```bash
sudo -i
```
> **What you see:** Your prompt changes to `root@nixos#`.

---

## Phase 2 — Prepare the configuration

### 2.1 Enable flakes in the installer

The NixOS installer does not have flakes enabled by default. Enable them for
this session:
```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

> **Tip:** This only lasts for the current terminal session. If you close the
> terminal and open a new one, run this export again before continuing.

### 2.2 Get the configuration files

**Option A — clone from GitHub** (if you pushed the files first):
```bash
cd /mnt   # we'll install to /mnt, but we haven't mounted yet — use /tmp for now
cd /tmp
git clone https://github.com/YOUR_USERNAME/nixos-setups.git
cd nixos-setups
```

**Option B — copy from USB** (if you put the files on the USB):
```bash
# Mount the USB data partition (adjust /dev/sdX1 to your USB partition):
mkdir -p /tmp/usb
mount /dev/sdX1 /tmp/usb
cp -r /tmp/usb/nixos-setups /tmp/nixos-setups
cd /tmp/nixos-setups
```

**Option C — type it (last resort):**
The files are short enough to recreate by hand using `nano`. Not recommended.

### 2.3 Identify your disk devices

**This step is critical.** `hosts/$HOST/disko.nix` has device paths hardcoded.
Verify these match your machine before doing anything else — disk layout
specifics (sizes, single vs. dual drive) aren't covered in this guide, so
check `hosts/$HOST/disko.nix` itself for what it expects on your machine:

```bash
lsblk -d -o NAME,SIZE,MODEL
```

> **What you see (example):**
> ```
> NAME    SIZE MODEL
> nvme0n1 931.5G WD_BLACK SN770 1TB
> nvme1n1   1.8T Samsung 990 Pro 2TB
> ```

Compare against what `lsblk` actually shows on your machine and correct the
`device` fields in `hosts/$HOST/disko.nix` if they don't match:
```bash
nano /tmp/nixos-setups/hosts/$HOST/disko.nix
```
Save with **Ctrl+O**, exit with **Ctrl+X**.

> **Why this matters:** Disko will ERASE the named devices. Getting this wrong
> destroys the wrong drive. Double-check before running Phase 3.

---

## Phase 3 — Partition and format with Disko

### 3.1 Run disko

Disko reads your `disko.nix`, creates GPT partition tables, LUKS containers,
BTRFS pools, and subvolumes — all in one command.

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- \
  --mode disko \
  /tmp/nixos-setups/hosts/$HOST/disko.nix
```

> **What you see:** Disko will print partition creation steps. At two points it
> will pause and prompt:
>
> ```
> Enter passphrase for /dev/nvme0n1p2:
> Verify passphrase:
> ```
> Then again for the secondary disk:
> ```
> Enter passphrase for /dev/nvme1n1p1:
> Verify passphrase:
> ```
>
> **Choose a strong passphrase.** This becomes your LUKS recovery passphrase
> even after TPM enrollment — if the TPM ever fails (firmware update, hardware
> change), this is how you get back in. Write it down and store it securely
> offline (not digitally). Use the **same passphrase for both drives** to keep
> recovery simple.

> **Expected output at the end:**
> ```
> Created @root-blank read-only snapshot.
> Done. Snapshot @root-blank created.
> ```
> You will also see both drives mounted under /mnt.

> **If disko fails:** Read the error. Common issues:
> - Device name mismatch (wrong /dev/nvmeXnX) → fix disko.nix and re-run
> - "Device is busy" → check if any partition is already mounted: `lsblk`
> - Passphrase typo on verify → disko will abort; re-run from the beginning

### 3.2 Verify mounts

After disko completes, check that everything is mounted correctly. (The
example below matches serenity's two-drive layout; nostromo's may differ —
check whatever `hosts/$HOST/disko.nix` actually declares.)

```bash
mount | grep /mnt
```

> **Expected output (order may vary):**
> ```
> /dev/mapper/cryptroot on /mnt type btrfs (...)
> /dev/mapper/cryptroot on /mnt/home type btrfs (...)
> /dev/mapper/cryptroot on /mnt/nix type btrfs (...)
> /dev/mapper/cryptroot on /mnt/persist type btrfs (...)
> /dev/mapper/cryptroot on /mnt/var/log type btrfs (...)
> /dev/mapper/cryptroot on /mnt/.snapshots type btrfs (...)
> /dev/nvme0n1p1 on /mnt/boot type vfat (...)
> /dev/mapper/cryptdata on /mnt/data type btrfs (...)
> ```

Also confirm the blank root snapshot was created:
```bash
btrfs subvolume list /mnt | grep blank
```
> **Expected output:**
> ```
> ID 260 gen ... top level 5 path @root-blank
> ```

---

## Phase 4 — Generate hardware config and install

### 4.1 Generate hardware-configuration.nix

```bash
nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
  > /tmp/nixos-setups/hosts/$HOST/hardware-configuration.nix
```

The `--no-filesystems` flag skips generating `fileSystems` entries (disko
handles those). The output captures your exact NVMe controller modules, CPU
microcode settings, and host platform.

> **What you see:** The command exits silently if successful. The file is
> created in the config directory.

View what was generated (for your education):
```bash
cat /tmp/nixos-setups/hosts/$HOST/hardware-configuration.nix
```

You do not need to edit this file. It is purely auto-detected hardware data.

### 4.2 Copy config to /mnt

```bash
mkdir -p /mnt/etc/nixos
cp -r /tmp/nixos-setups/. /mnt/etc/nixos/
```

> This puts your flake config where `nixos-install` will find it.

### 4.3 Check the flake parses correctly

```bash
cd /mnt/etc/nixos
nix flake check --no-build
```

> **What you see:** A few lines of evaluation output, then silent success.
>
> **If you see errors:** Common causes:
> - Syntax error in a .nix file you edited (look for "error: ... at line N")
> - Missing hardware-configuration.nix (check the copy in 4.2)

### 4.4 Run nixos-install

```bash
nixos-install --flake /mnt/etc/nixos#$HOST --no-root-passwd
```

> **What you see:** Nix downloads all inputs (nixpkgs, lanzaboote, etc.) and
> builds the system. This takes **10–30 minutes** depending on your internet
> speed. You will see lines like:
> ```
> copying path '/nix/store/...' from 'https://cache.nixos.org'...
> building '/nix/store/...nixos-system-serenity-25.11...'
> ```
> At the end:
> ```
> installation finished!
> ```

The `--no-root-passwd` flag skips setting a root password. You will use your
user account with sudo instead.

### 4.5 Set your user password

**Important:** Do this before rebooting, or you will not be able to log in.

```bash
nixos-enter --root /mnt -- passwd shashin
```

> **What you see:** A prompt for a new password. Type it twice. No characters
> are displayed while typing — that is normal.

### 4.6 Reboot

```bash
reboot
```

Remove the USB when the screen goes dark. The machine will boot from the NVMe.

> **What you see:** The UEFI splash, then systemd-boot shows a menu with your
> NixOS generation. Wait a few seconds (or press Enter).
>
> **Then:** A passphrase prompt:
> ```
> Please enter passphrase for disk cryptroot:
> ```
> Enter the LUKS passphrase you chose in Phase 3. You will then see a second
> prompt for cryptdata (the 2 TB drive). Enter the same (or your chosen)
> passphrase.
>
> **After both prompts:** systemd finishes booting, the Plasma Login Manager
> (PLM) screen appears.

---

## Phase 5 — First boot verification

### 5.1 Log in

At the PLM login screen, click on your username (shashin), enter your password.

> **What you see:** KDE Plasma (Wayland). PLM is KDE-specific by design — there's
> no session picker for alternate window managers the way SDDM had one.

### 5.2 Basic checks

Press **SUPER** and search for "Konsole" to open a terminal.

Run these checks:
```bash
# Network
ping -c 3 1.1.1.1

# Verify both LUKS volumes are open
ls /dev/mapper/

# Verify subvolumes
btrfs subvolume list /

# Check NVMe drives
lsblk

# Check GPU is working
glxinfo | grep "OpenGL renderer"
# or:
vulkaninfo --summary 2>/dev/null | grep deviceName

# Check zram is active
cat /proc/swaps
# Expected: a line with /dev/zram0

# Check TPM is present
ls /dev/tpm*
# Expected: /dev/tpm0 and /dev/tpmrm0
```

### 5.3 Push to GitHub (now or later)

If you have not yet pushed the config to GitHub, now is a good time:
```bash
cd /etc/nixos
git init
git add .
git commit -m "Initial NixOS configuration for $HOST"
git remote add origin https://github.com/YOUR_USERNAME/nixos-setups.git
git push -u origin main
```

From this point on, the workflow is:
1. Edit files in `/etc/nixos/`
2. `sudo nixos-rebuild switch` to apply changes
3. `git add -A && git commit && git push` to back up

---

## Phase 6 — Secure Boot with Lanzaboote

> **Overview:** You will create your own Secure Boot signing keys, enroll them
> into UEFI (keeping Microsoft's keys for firmware compatibility), then switch
> the bootloader from systemd-boot to lanzaboote. Lanzaboote signs a Unified
> Kernel Image (UKI) for each NixOS generation so the TPM can verify the full
> boot chain.

### 6.1 Enter UEFI Setup Mode

Secure Boot key enrollment requires the firmware to be in "Setup Mode" — a
state where the key database is writable.

1. Reboot the machine.
2. Press **F2** at the Framework logo to enter UEFI.
3. Navigate to **Security → Secure Boot**.
4. Find **"Delete All Secure Boot Keys"** or **"Reset to Setup Mode"**.
   Select it and confirm. This clears the existing key databases and puts
   firmware into Setup Mode.
   > **What you see:** A confirmation dialog. After confirming, Secure Boot
   > shows as "Setup Mode" or the key databases show as empty.
5. Make sure Secure Boot is **ENABLED** (but in Setup Mode, not User Mode).
6. **Save and exit** (F10). The machine reboots into NixOS.
   > You may see a warning about "Secure Boot violation" on this boot — that is
   > expected because the existing signed bootloader is now untrusted (you cleared
   > the keys). If the machine refuses to boot entirely, enter UEFI and temporarily
   > disable Secure Boot, boot into NixOS, complete steps 6.2–6.5, then re-enable.

### 6.2 Verify Setup Mode

Once logged into NixOS:
```bash
sbctl status
```
> **Expected output:**
> ```
> Installed:    ✓ sbctl is installed
> Owner GUID:   <some UUID>
> Setup Mode:   ✓ Enabled
> Secure Boot:  ✗ Disabled
> ```
> The important line is **Setup Mode: ✓ Enabled**. If it says "User Mode",
> go back to UEFI and reset the keys again.

### 6.3 Create your Secure Boot keys

```bash
sudo sbctl create-keys
```
> **Expected output:**
> ```
> Created Owner UUID: <UUID>
> Creating secure boot keys...✓
> Wrote keys to /var/lib/sbctl
> ```
> Current `sbctl` writes keys to `/var/lib/sbctl` by default — that's also
> the path `pkiBundle` is already set to in both hosts' `configuration.nix`,
> so there's nothing to redirect here. (Older guides for lanzaboote reference
> `/etc/secureboot` — that was the old sbctl default and doesn't apply here.)

### 6.4 Enroll your keys (keep Microsoft keys)

```bash
sudo sbctl enroll-keys --microsoft
```
The `--microsoft` flag includes Microsoft's keys alongside yours. This is
important because AMD and some firmware components are signed by Microsoft.
Omitting it can cause the machine to fail to POST after enabling Secure Boot.

> **Expected output:**
> ```
> Enrolling keys to EFI variables...✓
> ```

> **If you see "permission denied" or "EFI variables are read-only":**
> You are not in Setup Mode. Go back to step 6.1.

### 6.5 A note on persistence

`/var/lib/sbctl` lives on `@root`, which is only wiped once you turn on
impermanence (Phase 9) — so nothing to do here yet. **When** you do enable
impermanence later, add `/var/lib/sbctl` to your `environment.persistence`
directories list (see Phase 9) or your keys will vanish on the next boot and
lanzaboote will stop being able to sign new generations. This guide's Phase 9
example already includes it.

### 6.6 Enable Lanzaboote in configuration.nix

Edit the config:
```bash
sudo nano /etc/nixos/hosts/$HOST/configuration.nix
```

Find the `lanzaboote` block inside `boot.loader` — it's already there, just
disabled:
```nix
lanzaboote = {
  enable    = false;
  pkiBundle = "/var/lib/sbctl";
};
```
Flip `enable` to `true`:
```nix
lanzaboote = {
  enable    = true;
  pkiBundle = "/var/lib/sbctl";
};
```
You do **not** need to touch `boot.loader.systemd-boot.enable` — lanzaboote's
module automatically forces it off when `lanzaboote.enable = true`.

Save and exit.

### 6.7 Rebuild and activate

```bash
sudo nixos-rebuild switch
```

> **What you see during the build:** Normal NixOS build output. At the end you
> will see lanzaboote signing each generation's UKI:
> ```
> lanzaboote: signing /boot/EFI/Linux/nixos-generation-1.efi...
> ```

### 6.8 Enable Secure Boot in UEFI

1. Reboot: `sudo reboot`
2. Press **F2** to enter UEFI before NixOS boots.
3. Go to Security → Secure Boot.
4. Change from **Setup Mode** to **User Mode** (this "locks" the enrolled keys).
5. Make sure Secure Boot is **Enabled**.
6. Save and exit (F10).

> **What you see on the next boot:** The machine boots normally. No Secure Boot
> violation warnings. The UKI is signed with your keys.

### 6.9 Verify Secure Boot is working

```bash
sbctl status
```
> **Expected output:**
> ```
> Installed:    ✓ sbctl is installed
> Setup Mode:   ✗ Disabled
> Secure Boot:  ✓ Enabled
> ```

```bash
sbctl verify
```
> **Expected output:** All bootloader files listed as "✓ Signed".

---

## Phase 7 — TPM2 + PIN LUKS enrollment

> **What this does:** Seals a LUKS unlock key inside the TPM, bound to PCRs
> (Platform Configuration Registers) that represent the current secure boot
> state. The key is only released if the firmware and bootloader chain match
> the state at enrollment time, AND you type the correct PIN.
>
> After this phase, booting prompts for a short PIN (not the long passphrase).
> The long passphrase remains as a fallback if the TPM ever fails.
>
> **Prerequisite:** Secure Boot must be active (Phase 6 complete). PCR 7
> captures the Secure Boot state; if Secure Boot is off, PCR 7 is all-zeros
> and meaningless, defeating the TPM's protection.

### 7.1 Find the LUKS partition device paths

You need the block device path of each LUKS partition (not the mapper device):
```bash
lsblk -o NAME,FSTYPE,PARTLABEL
```

Look for partitions with `FSTYPE = crypto_LUKS`:
> **Example output:**
> ```
> nvme0n1
> ├─nvme0n1p1   vfat     ESP
> └─nvme0n1p2   crypto_LUKS  nixos-luks
> nvme1n1
> └─nvme1n1p1   crypto_LUKS  data-luks
> ```

Note the device paths: `/dev/nvme0n1p2` (system) and `/dev/nvme1n1p1` (data).
Yours may differ.

### 7.2 Enroll the system drive (cryptroot)

```bash
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=0+7 \
  --tpm2-with-pin=yes \
  /dev/nvme0n1p2
```

Replace `/dev/nvme0n1p2` with your actual system LUKS partition path.

`--tpm2-pcrs=0+7`:
- **PCR 0**: firmware/BIOS measurements — changes if firmware is flashed
- **PCR 7**: Secure Boot state — changes if Secure Boot is disabled or keys change

Using PCR 7 means: if someone disables Secure Boot, the TPM refuses to release
the key. This is the minimum recommended set. You can add PCR 2 (driver/ROM
code) for more coverage.

> **Tradeoff:** because PCR 0 is included, every BIOS/firmware update (e.g.
> via `fwupdmgr`/LVFS) changes PCR 0 and breaks TPM auto-unlock on both
> drives until you re-enroll (see Troubleshooting below). If that churn is
> more annoying than useful to you, drop PCR 0 and enroll with
> `--tpm2-pcrs=7` only — PCR 7 alone still detects Secure Boot being
> disabled or the key database changing, which is the actual threat model
> (evil-maid attacks), without tying the seal to the exact firmware binary.

> **What you see:**
> ```
> Please enter current passphrase for disk /dev/nvme0n1p2:
> ```
> Enter your LUKS passphrase (the one from Phase 3).
> ```
> New TPM2 PIN:
> Repeat TPM2 PIN:
> ```
> Choose a short (6–10 digit) PIN. Write it down. This is what you will type
> at every boot.
>
> **Expected final output:**
> ```
> New enrolled token: tpm2
> ```

### 7.3 Enroll the data drive (cryptdata)

```bash
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=0+7 \
  --tpm2-with-pin=yes \
  /dev/nvme1n1p1
```

Replace `/dev/nvme1n1p1` with your actual data LUKS partition path.

> **What you see:** Same prompts as 7.2. Use the same PIN for consistency —
> both drives will unlock from a single PIN entry at boot.

### 7.4 Configure NixOS to use systemd-cryptsetup for TPM unlock

The initrd must use systemd-based crypto setup (already enabled in
`configuration.nix`). Verify it is enabled:
```bash
grep -n "systemd.enable" /etc/nixos/hosts/$HOST/configuration.nix
```
> **Expected output:** `initrd.systemd.enable = true;`

No changes needed — this was set up in Phase 1 already.

### 7.5 Test the TPM unlock

```bash
sudo reboot
```

> **What you see at boot:**
> ```
> Please enter passphrase for disk cryptroot!
> PIN: _
> ```
> Type your PIN (not the long passphrase). After entering it, the system
> continues booting normally. You should NOT see the cryptdata prompt if
> both drives enrolled to the TPM correctly — systemd unlocks cryptdata
> automatically using the same TPM2 policy.
>
> **If the PIN prompt does not appear** and you see the old passphrase prompt:
> The TPM slot may not have been picked up. Try rebooting once more. If it
> persists, check: `sudo cryptsetup luksDump /dev/nvme0n1p2 | grep Token`.

### 7.6 Keep the passphrase as fallback

The original passphrase slot (slot 0) remains active alongside the TPM slot.
If the TPM ever fails (after a firmware update, hardware change, or if you
disable Secure Boot), you can unlock using the passphrase at the prompt.

**Do not remove the passphrase slot.** Store the passphrase securely offline.

---

## Phase 8 — Fingerprint enrollment (nostromo only)

The Framework 13's power button doubles as a fingerprint reader, supported by
`fprintd`. **This applies to nostromo only** — serenity is a desktop with no
fingerprint hardware, and its `configuration.nix` correctly sets
`services.fprintd.enable = false;`.

**Current status:** this phase is not active yet. `services.fprintd.enable`
is `true` on nostromo, but the PAM wiring (`security.pam.services.*.fprintAuth`)
is still commented out from earlier work-in-progress, so nothing will actually
prompt for a fingerprint yet. Treat this whole phase as optional future work —
skip it for now and come back once you're ready to wire it up. When you do:

- Uncomment and adjust the `security.pam.services` block in
  `hosts/nostromo/configuration.nix`.
- Since nostromo uses Plasma Login Manager rather than SDDM, PLM already
  prompts for a fingerprint automatically at the login screen once
  `fprintd.enable = true` — you don't need a PAM change for the *login screen*
  itself, only for `sudo` (`security.pam.services.sudo.fprintAuth = true;`).
  Check the current [Plasma Login Manager wiki page](https://wiki.nixos.org/wiki/Plasma_Login_Manager)
  for the latest details, since this module is still actively changing.

### 8.1 Verify fprintd sees the reader

```bash
fprintd-list shashin
```
> **Expected output (before enrollment):**
> ```
> Using device /net/reactivated/Fprint/Device/0
> shashin: 0 fingers enrolled
> ```
> If you see "No devices available", check:
> ```bash
> sudo systemctl status fprintd
> lsusb | grep -i finger
> ```

### 8.2 Enroll fingerprints

```bash
fprintd-enroll shashin
```
> **What you see:**
> ```
> Using device /net/reactivated/Fprint/Device/0
> Enrolling right-index-finger finger.
> Enroll result: enroll-stage-passed
> Enroll result: enroll-stage-passed
> ... (several passes)
> Enroll result: enroll-completed
> ```
>
> Place your finger on the reader when prompted. Move it slightly between
> each scan for better coverage.

Enroll additional fingers (recommended — right and left index):
```bash
fprintd-enroll -f left-index-finger shashin
```

### 8.3 Test fingerprint for sudo

```bash
sudo -k    # clear cached sudo credentials
sudo echo "Fingerprint sudo works"
```

> **What you see:** A fingerprint scan prompt (the terminal will pause).
> Touch the reader.
>
> **If it falls back to password:** Check that PAM fprintAuth is set to true
> in `configuration.nix` and rebuild: `sudo nixos-rebuild switch`.

---

## Phase 9 — Enable Impermanence (your schedule)

At this point your system has all the subvolumes needed for impermanence:
- `@root-blank` exists as a read-only snapshot
- `@home` is separate and will keep your files
- `@persist` is mounted at `/persist` for explicit state
- `@nix` keeps the Nix store safe

To activate the root wipe-on-boot:

1. Open `hosts/$HOST/configuration.nix`.
2. Find the commented-out `boot.initrd.systemd.services.wipe-root` block.
3. Uncomment the entire block.
4. Move anything from `/` that you want to keep into `/persist/`:
   ```bash
   # Example: persist SSH host keys
   sudo mkdir -p /persist/etc/ssh
   sudo cp /etc/ssh/ssh_host_* /persist/etc/ssh/

   # Example: persist NetworkManager connections
   sudo mkdir -p /persist/etc/NetworkManager/system-connections
   sudo cp /etc/NetworkManager/system-connections/* \
     /persist/etc/NetworkManager/system-connections/

   # Secure Boot keys — required if lanzaboote is enabled (Phase 6),
   # or your keys disappear on the next wipe and lanzaboote can't sign
   # new generations
   sudo mkdir -p /persist/var/lib/sbctl
   sudo cp -r /var/lib/sbctl/. /persist/var/lib/sbctl/
   ```
5. Add `environment.persistence` declarations to `configuration.nix` for
   anything that must persist (SSH keys, machine-id, Secure Boot keys, etc.):
   ```nix
   environment.persistence."/persist" = {
     hideMounts = true;
     directories = [
       "/etc/NetworkManager/system-connections"
       "/var/lib/bluetooth"
       "/var/lib/systemd/coredump"
       "/var/lib/sbctl"   # lanzaboote signing keys — see Phase 6
     ];
     files = [
       "/etc/machine-id"
       "/etc/ssh/ssh_host_ed25519_key"
       "/etc/ssh/ssh_host_ed25519_key.pub"
       "/etc/ssh/ssh_host_rsa_key"
       "/etc/ssh/ssh_host_rsa_key.pub"
     ];
   };
   ```
6. `sudo nixos-rebuild switch`
7. Reboot and verify the system comes up cleanly.

> **Before enabling impermanence**, verify your system is stable and you
> understand what will be wiped. The wipe is reversible (the data is not
> deleted, just the subvolume is swapped) but debugging a broken impermanence
> setup requires booting from a live USB.

---

## Flakes workflow quick reference

```bash
# Apply a config change
sudo nixos-rebuild switch

# Apply a config change AND update all inputs first
sudo nix flake update /etc/nixos && sudo nixos-rebuild switch

# Roll back to the previous generation (if something broke)
sudo nixos-rebuild switch --rollback
# OR select the previous generation from the systemd-boot menu at next boot

# List all installed generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Manually garbage collect (removes old generations)
sudo nix-collect-garbage -d

# Check what changed between generations
nix store diff-closures \
  /nix/var/nix/profiles/system-N-link \
  /nix/var/nix/profiles/system-M-link

# Add a new package system-wide (add to environment.systemPackages, then):
sudo nixos-rebuild switch

# Search for a package
nix search nixpkgs firefox
```

---

## Troubleshooting

### Boot fails: "cryptroot: No key available"
The TPM could not release the LUKS key. Causes:
- Secure Boot state changed (e.g. firmware update changed PCR 7)
- **A BIOS/firmware update was applied (e.g. via `fwupdmgr`/LVFS)** — this
  changes PCR 0, which is expected and will happen on every firmware flash
  as long as PCR 0 is part of the enrollment. Not a sign anything is wrong.
- TPM PIN entered incorrectly

At the prompt, type your **LUKS passphrase** (not the TPM PIN) to get in.
Then re-enroll the TPM **on both drives** (they were both enrolled with the
same PCR set):
```
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+7 --tpm2-with-pin=yes /dev/nvme0n1p2
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-pcrs=0+7 --tpm2-with-pin=yes /dev/nvme1n1p1
```
If this happens often enough to be annoying, see the tradeoff note in
Phase 7.2 about dropping PCR 0 from the enrollment.

### Plasma Login Manager shows a blank screen
Check the PLM/greeter logs: `journalctl -u plasmalogin` (unit name may vary —
`systemctl list-units | grep -i plasma` to confirm). If PLM itself won't
start, you can drop to a TTY (Ctrl+Alt+F2) and check
`journalctl -b -u display-manager`.

### Secure Boot verification fails after a nixos-rebuild
Lanzaboote signs new generations automatically during `nixos-rebuild switch`.
If you see unsigned entries: `sudo sbctl sign-all` signs everything manually.

### After applying a firmware update via fwupd/LVFS
Firmware updates are normally safe for Secure Boot itself — your enrolled
keys (PK/KEK/db) live in NVRAM and aren't touched by a routine BIOS flash.
Two things to check afterward anyway:
1. `sbctl status` — confirms Secure Boot is still enabled and not reset to
   Setup Mode (rare, but some vendor updates do this).
2. If the machine drops to a LUKS passphrase prompt instead of auto-unlocking
   with the TPM+PIN, that's expected (see "cryptroot: No key available"
   above) — it means PCR 0 changed, not that something broke.

LVFS also distributes UEFI dbx (revocation list) updates as their own
category, separate from BIOS updates — these intentionally modify the
Secure Boot database and will also change PCR 7, triggering the same
re-enrollment need.

### Fingerprint not detected (nostromo only)
Framework ships firmware updates via fwupd. Run: `sudo fwupdmgr update`
Reboot, then try `fprintd-list shashin` again.

### /data drive not mounting at boot
Check: `sudo systemctl status systemd-cryptsetup@cryptdata`
If it failed, the TPM slot for cryptdata may need re-enrollment.

---

*Sources consulted during preparation of this guide:*
- [nixos-hardware: framework-desktop-amd-ai-max-300-series](https://github.com/NixOS/nixos-hardware)
- [nixos-hardware: framework-13-7040-amd](https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd)
- [nix-community/disko](https://github.com/nix-community/disko)
- [nix-community/lanzaboote — Prepare your system](https://github.com/nix-community/lanzaboote/blob/master/docs/getting-started/prepare-your-system.md)
  (current upstream example uses `pkiBundle = "/var/lib/sbctl"`, matching this repo's configs)
- [NixOS Wiki — Plasma Login Manager](https://wiki.nixos.org/wiki/Plasma_Login_Manager)
- [NixOS Wiki — KDE](https://wiki.nixos.org/wiki/KDE)
- [Secure Boot & TPM FDE on NixOS — jnsgr.uk](https://jnsgr.uk/2024/04/nixos-secure-boot-tpm-fde/)
- [NixOS Framework Partnership Announcement](https://nixos.org/blog/announcements/2026/framework-partnership-announcement/)