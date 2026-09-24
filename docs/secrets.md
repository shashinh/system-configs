# Secrets handling for this repo

Status: sops-nix is IMPLEMENTED as the backbone (see "What is implemented"
below). The rest of this document is the survey that led to that choice and
the list of things still open.

## What is implemented

| Piece | Where |
|---|---|
| Recipients (operator + both host keys) | `.sops.yaml` |
| Encrypted store | `secrets/common.yaml` |
| Baseline wiring (input, host-key decryption, CLI tools) | `modules/pc/sops.nix` |
| First secret: noctalia wallhaven API key | `modules/features/noctalia-wallhaven.nix` |

Hosts decrypt with their own SSH host key (`ssh-to-age`); humans decrypt and
edit with their personal SSH key. Secrets are rendered at activation into
`/run/secrets` and never enter the Nix store — verified by scanning the
whole system closure for the plaintext value.

Still to migrate: the CIFS credentials (see the inventory below), which
remain a hand-placed file at `/home/shashin/.smb/creds`.

## Why now

The repo is public. Vendoring noctalia's GUI-managed `settings.toml`
surfaced a wallhaven API key that noctalia rewrites into that file on every
GUI save — the first concrete collision between "track everything" and
"public repo". Rather than special-casing it, this document surveys how
secrets are idiomatically handled in Nix configs and what fits here.

## Current secret inventory

| Secret | Where it lives today | Mechanism | Assessment |
|---|---|---|---|
| wallhaven API key | `~/.local/state/noctalia/settings.toml` | plaintext, inside a file the app itself rewrites | the motivating problem; see §App-owned files |
| CIFS credentials (NAS) | `/home/shashin/.smb/creds` on serenity | out-of-band file, referenced by path in `features/nas.nix` | works, but unmanaged: not in repo, not provisioned by rebuild, silently required |
| searxng secret key | `/persist/secrets/searx-env` on serenity | generated on-host by a systemd oneshot (`openssl rand`), guarded by ConditionPathExists | good pattern — never leaves the machine, survives impermanence |
| lanzaboote signing keys | `/var/lib/sbctl` | generated on-host by sbctl (Phase 6 of INSTALL.md) | correct as-is; never repo material |
| open-webui `OPENAI_API_KEY` | `features/ai/open-webui.nix` | hardcoded `"sk-local"` | placeholder, not a real secret |
| noctalia calendar credentials | Desktop Secret Service (gnome-keyring) | per noctalia docs | correct as-is; keyring-backed |

Two distinct problem classes emerge:

1. **Machine-consumed secrets** (CIFS creds, service tokens, future API
   keys for services): a NixOS module needs a file path or env var at
   runtime. This is the class the Nix ecosystem tooling solves well.
2. **App-owned files containing secrets** (noctalia `settings.toml`): the
   application owns the file, rewrites it wholesale, and mixes secrets
   with non-secret settings. No activation-time tool solves this cleanly —
   see §App-owned files.

## The constraint every option lives under

Anything that enters the Nix store is world-readable on every machine that
has the store path, and its hash is in the public closure. Therefore:
**secrets must never pass through the store** — not as `builtins.readFile`,
not as string interpolation into a config file, not as a derivation input.
Every serious tool decrypts at activation/boot time to a root-owned tmpfs
path (`/run/...`) *outside* the store, and modules consume the *path*.

## Options

### 1. sops-nix

Secrets live in the repo as SOPS files (YAML/JSON/INI/binary) with values
encrypted and keys visible — diffs show *which* secret changed, not what
it is. Encryption is to a set of age recipients (or GPG/KMS).

- **Key management fit**: each NixOS host's *SSH host key* converts to an
  age key (`ssh-to-age`), so machines decrypt with a key they already
  have — nothing to provision beyond what an install already creates. A
  personal age/GPG key is added as recipient for editing.
- **Runtime**: decrypts to `/run/secrets/<name>` before services start
  (`sops.secrets.<name>` → owner/group/mode per secret). Modules reference
  `config.sops.secrets.<name>.path`.
- **Templates**: `sops.templates` renders whole config files containing
  secret placeholders at activation — the answer for "this service wants a
  config file with the token inline".
- **home-manager module** exists (secrets for user-level services).
- Editing: `sops secrets/foo.yaml` (decrypt-edit-reencrypt in one step).
- `.sops.yaml` declares which recipients encrypt which paths — per-host
  scoping is a policy file, not ceremony.

### 2. agenix (and the ragenix / agenix-rekey variants)

One age-encrypted blob per secret file (`secrets/foo.age`), recipients
listed in `secrets.nix`. Same runtime shape as sops-nix
(`age.secrets.<name>.path` → `/run/agenix/...`), also decrypts with SSH
host keys.

- Simpler mental model than SOPS (a file is a secret; no structured
  format), but: no partial encryption (diffs are opaque), no built-in
  templating, editing is `agenix -e` per file.
- `agenix-rekey` adds a master-key workflow, per-host auto-rekeying, and
  *generated* secrets (declare a generator; it materializes and encrypts).
- Precedent: the dendritic reference implementation uses agenix, wired as
  its own feature module — the integration shape ports directly here.

### 3. git-crypt / transcrypt (git filter encryption)

Whole files transparently encrypted in git via clean/smudge filters;
plaintext in the working tree.

- Uniquely, this handles **app-owned files**: the app rewrites the
  plaintext working-tree file; commits store ciphertext.
- Costs: symmetric key shared out-of-band per clone; a clone without the
  filter configured silently commits plaintext (the same trap as a
  hand-rolled clean filter); ciphertext churn on every save; no per-secret
  granularity; largely superseded in the Nix world by (1)/(2).

### 4. Machine-local, out of repo (the status quo for CIFS creds)

Gitignored/absent files at known paths, restored by hand (or from
`/persist` under impermanence). Zero crypto, zero tooling — and zero
replication: a reinstall silently lacks them until something fails.
Acceptable only when paired with documentation (INSTALL.md) and ideally an
assertion that the file exists.

### 5. On-host generation (the searxng pattern)

For secrets that never need to be shared or known — random tokens, host
keys — generate at first boot with a oneshot guarded by
`ConditionPathExists`, write to `/persist`. Already in use here
(`features/ai/searxng.nix`); `agenix-rekey` generators or
`systemd-creds` can formalize it, but the plain pattern is sound.

### 6. systemd-creds (TPM2-sealed credentials)

`systemd-creds encrypt` seals a credential to the host's TPM2; units
receive it via `LoadCredential=`/`SetCredentialEncrypted=` as
`$CREDENTIALS_DIRECTORY/<name>`. The sealed blob is useless off-machine,
so it *could* live in the public repo.

- Native systemd, no flake inputs; both machines have TPM2 enabled.
- Strictly per-host (sealed to one TPM — re-seal per machine), no
  editing workflow, and consuming services must support credentials.
  Best viewed as a hardening/delivery detail, not the management layer.

### 7. Desktop Secret Service (gnome-keyring / KWallet)

For GUI apps that support it (noctalia calendar does). Not a general
mechanism — apps must opt in — but where an app supports it, it beats
every file-based approach. The wallhaven plugin does *not* support it
today (it persists the key into `settings.toml`).

## Comparison

| | in-repo (encrypted) | per-host keys for free | templating | HM support | app-owned files | extra inputs |
|---|---|---|---|---|---|---|
| sops-nix | yes, value-level | yes (ssh-to-age) | yes | yes | no | 1 |
| agenix | yes, file-level | yes (ssh host keys) | no (rekey addon: generators) | community | no | 1 |
| git-crypt | yes, file-level | no (shared key) | n/a | n/a | **yes** | 0 (external tool) |
| machine-local | no | n/a | n/a | n/a | yes | 0 |
| on-host generation | n/a (never shared) | n/a | n/a | n/a | no | 0 |
| systemd-creds | yes (TPM-sealed, per host) | yes (TPM) | no | no | no | 0 |
| Secret Service | no | n/a | n/a | n/a | app-dependent | 0 |

## App-owned files: the honest assessment

Why doesn't `sops.templates` apply here, when it exists precisely for
"config file with token inline"? Because templating is **one-way and
assumes a read-only consumer**: repo template → rendered file at
activation → app *reads* it; next rebuild re-renders. `settings.toml`
inverts every part of that: noctalia is the *writer* (every GUI save
rewrites it), so a rendered file is either read-only (GUI saves break) or
writable (the first save overwrites the rendered content, the next
rebuild clobbers the GUI changes, and noctalia has re-persisted the
plaintext key itself — sops only seeded it). And the originally desired
property — GUI change → dirty repo tree — is a *reverse* data flow that
activation-time rendering has no mechanism for.

A partial sops route does exist via the hand-written layer
(`~/.config/noctalia/*.toml`), which noctalia reads and merges but never
writes: template a small `zz-secrets.toml` carrying the key into that
layer and delete the key from `settings.toml`. Two caveats before
trusting it: (a) **empirical**: our `settings.toml` looks like a
comprehensive settings dump, not a delta — if noctalia re-dumps the
*merged* wallhaven settings on the next save, the key re-materializes in
`settings.toml` and nothing was gained; test by moving the key, making a
GUI change, and inspecting. (b) **mechanical**: `~/.config/noctalia` is
currently one whole-directory out-of-store symlink into the repo; a
sops-rendered file cannot live inside it, so the config dir would revert
to per-file links.

The real choices:

1. **Don't track it.** GUI settings stay machine-local state. Promote
   deliberate settings into the tracked, hand-written
   `~/.config/noctalia/*.toml` layer (which loads first; `settings.toml`
   overrides it) — optionally seeded via `noctalia config export`, minus
   the key. Cleanest boundary: *tracked = declarative layer, untracked =
   GUI layer*. Cost: GUI tweaks don't dirty the tree.
2. **Track it behind a redacting clean filter** (hand-rolled or
   git-crypt). GUI tweaks dirty the tree as desired; commits carry a
   redacted (or encrypted) blob. Cost: per-clone filter setup, and a
   mis-configured clone stages the plaintext key.
3. **Upstream fix**: wallhaven plugin support for Secret Service or a
   key-file path. Would dissolve the problem; worth an issue regardless.

## Preliminary recommendation (for discussion)

- **General mechanism: sops-nix**, keyed by SSH host keys via ssh-to-age
  plus one personal editing key. Rationale over agenix: value-level
  encryption (reviewable diffs), built-in templates (covers
  "config file with token inline" cases), HM module, single input. The
  dendritic integration is one feature module (`modules/features/` or
  `modules/pc/`) plus a `secrets/` directory and `.sops.yaml`.
- **First migration target: the CIFS credentials** — the clearest win:
  `features/nas.nix` consumes `config.sops.secrets."smb-creds".path`
  instead of a hand-placed `/home/shashin/.smb/creds`, making reinstalls
  self-contained.
- **Keep the searxng on-host generation pattern** as-is for
  never-shared randomness.
- **noctalia `settings.toml`: option 1 (don't track)** unless the
  dirty-tree-on-GUI-change property is worth the clean-filter trap; file
  an upstream issue for the wallhaven key either way.
- systemd-creds and Secret Service remain point solutions to adopt
  opportunistically, not the backbone.

## Open questions

1. Is dirty-tree-on-GUI-change a hard requirement for noctalia settings,
   or is the declarative-layer promotion workflow acceptable?
2. Should the personal editing key be a plain age keypair (stored where?
   `/persist`? a password manager?) or your existing GPG key
   (`dotfiles/gnupg` suggests one exists)?
3. Per-host secret scoping policy: encrypt everything to both hosts by
   default, or least-privilege per host (`.sops.yaml` path rules)?
4. Does home-manager-level secret delivery matter near-term (user-scope
   services), or is system-scope enough to start?
5. Rotate the wallhaven key now? It has only ever existed in local files —
   never committed — but it has been pasted into GUI state on one machine
   for some time.
