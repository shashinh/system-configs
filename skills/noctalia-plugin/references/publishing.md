# Publishing to noctalia-dev/community-plugins

**Stop: this file applies only when the owner has explicitly asked to publish
a plugin.** Their plugins are personal by default. If they have not asked, do
not act on anything below; at most, mention that publishing is possible. Once
they have asked, still confirm before each outward-facing step (pushing to a
fork, opening or updating a PR, commenting upstream).

Read the repo's current `README.md`, `README_TEMPLATE.md` and
`.github/PULL_REQUEST_TEMPLATE.md` before submitting; the rules below are a
snapshot (October 2026) of those files and of
`.github/workflows/scripts/validate-plugins.py`, which CI runs on every push.
`official-plugins` does not accept third-party plugins.

Fetch only what you need:

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/noctalia-dev/community-plugins.git
cd community-plugins && git sparse-checkout set .github <your-plugin-or-a-reference-plugin>
```

## Layout and required files

One top-level directory per plugin, named exactly as the id part after `/`
(`me/hello` → `hello/`). Directory names are first-come; reserved: `license`,
`readme`, `index`, `api`, `admin`, `static`, `assets`.

Required: `plugin.toml`, the entry scripts, `README.md`, `thumbnail.webp`,
`translations/en.json`. A non-MIT plugin also ships `LICENSE` in its directory.

Not allowed: symlinks, git submodules, more than 200 files, obfuscated /
minified / generated code, downloading and executing remote code. Never edit
or commit `catalog.toml` (CI generates it). One plugin per PR.

## Manifest rules CI enforces beyond what the host accepts

- Unknown root, entry, setting, option or `visible_when` fields are errors.
- `id` segments match `[a-z0-9][a-z0-9._-]*`; `version` is `N.N.N` and bumped
  on every change; `plugin_api` is a positive integer.
- `description` ≤ 120 characters.
- `tags` only from:
  - surfaces: `bar`, `desktop`, `launcher`, `panel`, `service`, `shortcut`
  - purpose: `ai`, `animation`, `audio`, `clock`, `countdown`, `demo`,
    `development`, `emoticon`, `fun`, `gaming`, `hardware`, `indicator`,
    `language`, `media`, `music`, `network`, `privacy`, `productivity`,
    `recording`, `system`, `theming`, `time`, `utility`, `video`, `wallpaper`
  - compositors: `hyprland`, `labwc`, `mangowc`, `niri`, `sway`
  - distributions: `arch`, `debian`, `fedora`, `gentoo`, `nixos`, `opensuse`, `void`
  Propose a new tag in the PR rather than inventing one.
- Every setting needs a `default`, except `file` and `folder`. `glyph`,
  `color` and `select` defaults must be **non-empty** strings (so "empty means
  automatic" is not expressible for a glyph: use a real default glyph, or a
  separate bool / select for the automatic behaviour). A `select` default must
  be one of its option values.
- `visible_when.values` must be non-empty **strings**: write `["true"]`, not
  `[true]` (the host tolerates bools, CI does not).
- `min <= default <= max`; `min` / `max` only on `int` / `double`;
  `extensions` only on `file`; `options` only on `select`.
- Entry files must exist and stay inside the plugin directory.
- Feature gates are checked against `plugin_api`: `string_map` ≥ 6,
  `keyboard_focus` ≥ 10, `persistent` ≥ 11, `capture_keys` ≥ 13,
  `[widget.actions]` ≥ 14. `width` / `height = "fill"` requires
  `placement = "floating"`.
- Launcher `prefix` matches `[a-z]+`.
- `barWidget.getConfig`, `panel.getConfig`, `desktopWidget.getConfig`,
  `launcher.getConfig` were removed: only `noctalia.getConfig`.

## Translations

- Write `translations/en.json` only. Other locales come from Noctalia
  Translate; do not add machine translations or edit existing ones.
- Every `label_key` / `description_key` must resolve in `en.json`.
- Keys are nested objects. Each object key is one lowercase segment of
  `a-z 0-9 - _` (no leading underscore, **no dots**, no uppercase). A flat
  `"settings.foo.label"` key is rejected.

## README

No raw HTML. Follow `README_TEMPLATE.md`; CI derives what must appear from the
manifest:

- `# Title` followed by a short introduction
- `## Plugin` with a table giving the id and every entry id in backticks,
  exactly as in `plugin.toml`
- `## Usage`, non-empty, explaining how to reach every entry; for each panel
  the exact line `noctalia msg panel-toggle <author>/<plugin>:<panel-id>`; for
  each launcher provider its `/<prefix>`
- `## Requirements` when `dependencies` is non-empty, naming each dependency in
  backticks
- `## Settings` when any setting is declared (a table of setting, type,
  default, description)
- `## IPC` and `## Notes` for extra events, files written, network access,
  spawned processes

## Thumbnail

`thumbnail.webp`, exactly 960×540, under 512 KiB, made with the generator at
https://assets.noctalia.dev/plugins/thumbnail-generator.html from a screenshot.
This needs the user: ask them for a screenshot and to run the generator.

## Editor and style conventions of the repo

- Every `.luau` file starts with `--!nonstrict`; `.luaurc` sets
  `languageMode = "nonstrict"`.
- `noctalia.d.luau` (from official-plugins, gitignored here) gives luau-lsp the
  whole API: `curl -O https://raw.githubusercontent.com/noctalia-dev/official-plugins/main/noctalia.d.luau`.

## Pull request

The PR description must keep the template's marker line and, before leaving
draft: exactly one plugin type checked, at least one compositor tested, the
Noctalia version and plugin API level stated, every checklist and attestation
box checked, and screenshots or video for anything visual. The description must
account for every network call, filesystem write and spawned process.
Maintainers read the code; expect comments on anything not obvious from the
description. Opening a PR is outward-facing: get the user's go-ahead first.

## Self-hosted source instead

A repo can be its own source: plugins in subdirectories named after the id
suffix, plus a root `catalog.toml` with one `[[plugin]]` row per plugin (`id`,
`name`, `plugin_api` required) and optional `[[plugin.release]]` rows (`plugin_api`,
`version`, 40-character `rev`) so older Noctalia versions get the last
compatible revision. Users add it with
`noctalia msg plugins source add <name> git <url>`.
