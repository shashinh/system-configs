# Nostromo cold-boot login slowness — diagnosis & fix

## Context
- The Plasma XDG fix (`hosts/nostromo/plasma-xdg-fix.nix`, see
  https://github.com/NixOS/nixpkgs/issues/126590#issuecomment-3194531220) fixed general
  Plasma runtime slowness (desktop file / icon lookups) *after* login.
- Separately: on nostromo, cold-boot login is still painfully slow. On serenity,
  cold-boot login is instantaneous.

## Diagnosis
`systemd-analyze critical-chain` on nostromo showed:

```
graphical.target @9.290s
└─multi-user.target @9.290s
  └─tailscaled.service @9.046s +242ms
    └─NetworkManager-wait-online.service @2.542s +6.502s
```

- `graphical.target` (starts `plasmalogin.service`, the login greeter) `Requires=multi-user.target`.
- `multi-user.target` `Wants=tailscaled.service`.
- `tailscaled.service` is ordered `After=NetworkManager-wait-online.service`.
- So boot stalls ~6.5s waiting for NetworkManager to confirm the network is fully up,
  *before* the login screen is even allowed to appear.

The 6.5s is WiFi association + WPA handshake + DHCP — nostromo is a Framework 13 laptop
on WiFi. Serenity is the Framework Desktop, on wired Ethernet, where link-up + DHCP is
near-instant, so `NetworkManager-wait-online.service` returns immediately there and never
becomes a bottleneck. Both hosts pull in `tailscaled` via shared `pc-common.nix`
(`services.tailscale.enable = true`), so both have the same dependency chain — only
nostromo's link is slow enough to notice.

## Fix applied
`tailscaled` doesn't need network confirmed-up to start; it reconnects on its own once
the link is ready. Dropped its ordering on `NetworkManager-wait-online.service` in
`hosts/nostromo/configuration.nix` (added right after the `networking = { ... };` block):

```nix
systemd.services.tailscaled.after = lib.mkForce [
  "network-pre.target"
  "NetworkManager.service"
  "systemd-resolved.service"
];
```

This was chosen over the broader alternative (globally disabling
`systemd.services.NetworkManager-wait-online.enable`) to avoid affecting any other unit
that might genuinely rely on network-confirmed-up at boot.

**Status: edit applied, NOT yet rebuilt/tested.**

## Resume steps after reboot
1. Rebuild: `sudo nixos-rebuild switch --flake ~/system-configs/nixos-config#nostromo`
2. Reboot cold and check `systemd-analyze critical-chain` again — `tailscaled.service`
   should no longer be gated behind `NetworkManager-wait-online.service`.
3. Confirm the login screen appears noticeably faster.
4. If still slow, re-run `systemd-analyze blame` / `critical-chain` to find the next
   bottleneck in the chain to `graphical.target`.

## CORRECTION (2026-08-15) — original theory falsified

Fix from above was applied and rebooted successfully: confirmed via live
`systemctl show tailscaled.service -p After` (no longer lists
`NetworkManager-wait-online.service`) and a fresh `critical-chain` where
`tailscaled.service` no longer appears. **But login is still slow**, and a new
bottleneck with the identical shape appeared: `mullvad-daemon.service`
(`WantedBy=multi-user.target`, `Wants=network-online.target`) is now gating
`graphical.target` behind the same ~6.5s `NetworkManager-wait-online.service` stall.
Not yet fixed/tested.

More importantly, the original wired-vs-wireless theory for why serenity is fast and
nostromo is slow is **wrong**. Serenity is confirmed on WiFi too (`nmcli device
status` shows `wlp192s0 wifi connected sevastopol`, both ethernet ports
"unavailable"), and its own `critical-chain` shows an equally long (actually longer)
stall:

```
graphical.target @9.933s
└─multi-user.target @9.933s
  └─tailscaled.service @9.687s +245ms
    └─NetworkManager-wait-online.service @2.406s +7.278s
```

So both hosts reach `graphical.target` in roughly the same ~9-10s of *userspace*
time — the tailscaled/mullvad/NetworkManager-wait-online chain is a real
inefficiency but does NOT explain why nostromo feels slower than serenity.

New lead: `systemd-analyze` (full breakdown, not just critical-chain) on nostromo
shows time is being lost *before* userspace even starts:

```
Startup finished in 6.582s (firmware) + 1.726s (loader) + 572ms (kernel)
  + 8.015s (initrd) + 9.290s (userspace) = 26.186s
```

`critical-chain graphical.target` only measures the userspace column, so it
completely missed this. `systemd-analyze blame` shows `dev-tpmrm0.device` and the
LUKS partition device (`dev-disk-by-partlabel-nixos-luks.device`) both sitting at
~8.2-8.5s before becoming ready during initrd — consistent with the known AMD fTPM
slow-init issue on Ryzen laptops (Framework 13), not a NixOS config problem. Both
hosts use identical LUKS2 + TPM2+PIN + systemd-initrd setup
(`hosts/{nostromo,serenity}/disko.nix` and `configuration.nix` are symmetric here),
so config isn't the differentiator — likely hardware/firmware TPM behavior differs
between the Framework 13 and Framework Desktop's TPM implementations.

**Next step:** waiting on `systemd-analyze` + `systemd-analyze blame | head -20`
from serenity to confirm its firmware/loader/initrd numbers are actually lower than
nostromo's, before chasing the fTPM angle further.

## ROOT CAUSE FOUND (2026-08-15) — fingerprint reader, not boot ordering at all

Serenity's `systemd-analyze` / `blame` came back with much *bigger* absolute numbers
than nostromo's (firmware 15.9s, loader 12.1s, initrd 24.7s, userspace 46.6s — total
1min41s), which killed the initrd/fTPM lead too. Those phase totals turned out to be
mostly noise: `firmware`/`loader`/`initrd` include human-dependent wait time (how
long you sit at a boot menu, how long typing a LUKS passphrase takes), and
`systemd-analyze blame`'s top entries (`nix-gc.service` 44.7s, `fstrim.service`
39.9s) are background timers, not blocking the boot critical path. Across both real
comparisons run so far, `graphical.target reached after Xs in userspace` — the one
deterministic, comparable number — was nearly identical on both hosts (nostromo
9.290s, serenity 9.933s). **All of the systemd-boot-ordering investigation above
(tailscaled, mullvad-daemon, NetworkManager-wait-online, TPM/initrd) turned out to
be a red herring for the user-perceived slowness.**

Clarified with the user what "slow login" actually means: the delay from the
greeter to a usable desktop, *not* boot-to-greeter time. That reframing pointed at
the Plasma session/PAM layer instead of systemd boot targets.

`journalctl -b -u plasmalogin` showed the real cause — an exact ~30s dead gap on
every single login attempt tonight:

```
00:24:44  "Place your finger on the fingerprint reader"
00:25:14  "Verification timed out"   ← 30s later, falls back to password/kwallet
...
00:33:21  "Place your finger on the fingerprint reader"
00:33:51  "Verification timed out"   ← 30s later, falls back to password/kwallet
```

Root cause: `services.fprintd.enable = true` on nostromo (`false` on serenity —
this is the actual, confirmed config difference between the two hosts).
`security.pam.services.*.fprintAuth` defaults to `services.fprintd.enable` for
*every* PAM service (`nixos/modules/security/pam.nix`), which wires fingerprint
into the `login` PAM service — and `plasmalogin` inherits it via
`auth substack login` (confirmed via `/etc/pam.d/plasmalogin` and
`/etc/pam.d/login`). The Goodix MOC Fingerprint Sensor has 2 prints enrolled
(`fprintd-list shashin`) but never successfully matches at the greeter, so every
login eats the full 30s PAM/fprintd timeout before falling through to
password/kwallet auth.

This is separate from KDE's own "Logging into the system with your fingerprint is
not yet supported" tooltip in System Settings — that's about KDE's own greeter
integration/toggle not existing, not about whether the underlying PAM stack tries
fingerprint. NixOS's fprintd module wires it in at the OS level regardless.

Also checked: `/etc/pam.d/kde` (kscreenlocker, used for lock-screen unlock) has
**no** fprintd entry at all — only a separate unused `kde-fingerprint` service does
— so lock-screen unlock was never using fingerprint and is unaffected by the fix
below either way.

### Fix applied

In `hosts/nostromo/configuration.nix`, replaced the old commented-out manual PAM
block with:

```nix
services.fprintd.enable = true;

# security.pam.services.*.fprintAuth defaults to services.fprintd.enable for
# every PAM service, which wires the reader into "login" (and therefore
# plasmalogin, which substacks login) even though KDE's own Settings says
# fingerprint login isn't supported. In practice the reader never matches at
# the greeter and each boot eats a flat 30s PAM timeout before falling back
# to password. Disable it there; sudo keeps the default (true).
security.pam.services.login.fprintAuth = false;
```

`sudo` and `vlock` are untouched — they keep fingerprint via the same
`fprintAuth` default (`true`, since `services.fprintd.enable = true`).

**Status: edit made, NOT yet rebuilt.** `nixos-rebuild switch` needs to run
interactively (sudo password prompt requires a real TTY — confirmed this by
trying it non-interactively, which itself hit the same 30s fingerprint timeout on
`sudo` before failing on the password prompt).

## Resume steps after reboot (current)

1. Rebuild interactively: `sudo nixos-rebuild switch --flake ~/system-configs/nixos-config#nostromo`
2. Log out and back in (or reboot cold for the cleanest before/after feel) —
   `plasmalogin` should go straight to password with no fingerprint prompt and no
   30s wait.
3. Confirm via `journalctl -b -u plasmalogin` that there's no more
   "Place your finger on the fingerprint reader" → "Verification timed out" gap.
4. If login still feels slow after this, the remaining candidates are genuinely
   the systemd-boot-ordering items found earlier (mullvad-daemon's
   NetworkManager-wait-online dependency is still unfixed, ~6.5s) — but treat
   those as a much smaller, secondary effect now that we know they affect serenity
   equally and serenity feels instant.
