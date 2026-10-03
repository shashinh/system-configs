---
name: noctalia-plugin
description: Use when designing, planning, writing, debugging, testing, packaging or publishing a plugin for the Noctalia shell v5 or later (a `plugin.toml` manifest plus Luau entry scripts) — bar widgets, panels, background services, control-center shortcuts, launcher providers or desktop widgets. Also use when a Noctalia plugin "does not show up", a panel control misbehaves, or a plugin has to be installed through Nix / home-manager. Gives the platform's hard limits, the idioms the official plugins follow, the pitfalls that cost debugging loops, and the develop → live-test → package → deploy workflow.
---

# Noctalia v5+ plugin development

Noctalia v5 is a C++ Wayland shell. A plugin is a directory holding a static
`plugin.toml` and one or more **Luau** entry scripts. It is not QML and has
nothing to do with Quickshell: discard anything you remember about plugins for
Noctalia v4 and earlier.

The plugin system is still in beta and the API moves between releases, so this
skill is a map, not the territory. **Read the docs of the version that is
actually installed before you design anything** (next section).

Supporting files, read them when you reach that stage:

- `references/api.md`: manifest, entry callbacks, `noctalia.*`, `ui.*` cheat sheet
- `references/project.md`: repo layout, unit tests off-host, Nix packaging, deployment
- `references/publishing.md`: community-plugins submission rules and CI checks

**Plugins are for the owner's personal use unless they say otherwise.** The
default deliverable is a plugin in its own repository, installed through Nix.
Do not start anything aimed at the community repository on your own
initiative: no fork or clone for submission, no branch, no PR, no issue, no
thumbnail request, no reshaping of the plugin to satisfy that repo's CI. If
publishing seems worthwhile, mention it once and wait. Read
`references/publishing.md` only after the owner has explicitly asked to
publish, and even then confirm again before each outward-facing step (pushing
to a fork, opening the PR). Reading community plugins as prior art is fine.

## 1. Establish ground truth first

```sh
noctalia --version
# Source tree of the locked Noctalia (docs + C++), from the system flake:
rev=$(jq -r '.nodes.noctalia.locked.rev' ~/system-configs/flake.lock)
src=$(nix flake prefetch --json "github:noctalia-dev/noctalia/$rev" | jq -r .storePath)
ls $src/docs/user/plugins/development/   # index manifest entries declarative-ui runtime-api workflow plugin-api
jq -r '.[] | "\(.level)\t\(.noctaliaVersion)\t\(.feature)"' $src/docs/plugin-api.json
```

| Need | Where |
|---|---|
| Authoritative docs for the installed version | `$src/docs/user/plugins/` (online: docs.noctalia.dev, may be newer) |
| Supported API range | `$src/src/scripting/plugin_api.h`; per-level features in `$src/docs/plugin-api.json` |
| Behaviour the docs do not state | `$src/src/scripting/` (host bindings, manifest parser, registry), `$src/src/ui/ui_tree_reconciler.cpp` |
| Valid glyph names | `$src/assets/fonts/tabler.json` (grep the exact name before using it) |
| Palette roles | `$src/docs/user/theming/palette.mdx` |
| Whole API as types | `noctalia.d.luau` at the root of `noctalia-dev/official-plugins` |
| Reference plugins | official-plugins `example` (every entry kind) and `timer` (service + bar + panel + desktop) |
| Prior art | community-plugins: check whether a plugin already does this, and read one that is close |

Both plugin repos are large. Never clone them whole:

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/noctalia-dev/community-plugins.git
cd community-plugins && git sparse-checkout set <plugin-dir> [<plugin-dir> ...]
```

When the docs are silent or ambiguous, read the C++ instead of guessing. A
level in `plugin-api.json` whose `noctaliaVersion` is `null` is unreleased: the
local build may have it, tagged releases do not.

## 2. Design before code

Interview the user about behaviour, then decide these explicitly:

1. **Entries.** Which of widget, panel, service, shortcut, launcher provider,
   desktop widget. Each entry is a separate isolated VM.
2. **Who owns the data.** If more than one entry shows the same data, or the
   data needs polling or a subprocess, a `[[service]]` owns it and publishes on
   `noctalia.state`; UI entries are thin clients that `state.watch` and render.
   UI entries send commands back by setting a state key the service watches.
3. **Setting scope**, per setting: plugin-level (`[[setting]]`, one value,
   seen by every entry) or per widget instance (`[[widget.setting]]`). Ask
   "could two instances on the bar reasonably differ here?" If yes it is a
   widget setting, and section 3's rules about services apply. Getting this
   wrong later is a breaking config change.
4. **`plugin_api`.** The lowest level that covers every capability used. List
   the features that set the floor in a manifest comment.
5. **External commands.** Each goes in `dependencies`, is checked or degrades
   gracefully when missing, and never prompts.

Then check the design against section 3. Most redesigns in practice come from
discovering one of those limits after the code exists.

## 3. Platform limits that shape the design

Verified against the 5.1.0 source; re-verify when the version differs.

**Runtime**

- One VM per entry, off the UI thread. CPU budget is about 100 ms for the
  top-level load and 25 ms per callback; repeated overruns get the entry
  killed. Never do blocking or heavy work in a callback: use the async APIs
  and keep parsers linear.
- Entries share nothing but `noctalia.state`: plain data only (no functions),
  copied, per plugin, in memory. It outlives a service restart, so a cache
  stored there must be keyed by the config it was computed from.
  `state.set` notifies watchers on every call, including an unchanged value.
- A **panel's runtime exists only while the panel is open**. IPC to a closed
  panel fails with "matched plugin entry is not ready", and it cannot run
  background work. Anything that must persist or keep running belongs in the
  service.
- A bar widget has one runtime per placement, so a widget on bars across
  several monitors runs several copies. Deduplicate shared work in the service.

**Subprocesses**

- `runAsync(cmd, cb [, timeoutMs])`: the timeout argument is undocumented;
  default 5 s, clamped to 50 ms..60 s. Output is capped at 1 MiB per stream
  (`stdoutTruncated`). At most 8 concurrent commands per entry, 32 globally:
  coalesce (one running + one pending), never queue unboundedly.
- Use the argv-array form (API 24) for anything containing a path, setting or
  user input. The string form goes through `/bin/sh -c`.
- `runStream(cmd, onLine)` takes a shell string only, returns no handle, has no
  exit callback and cannot be cancelled; it dies only with the runtime. If you
  need either, wrap it: `<cmd> & echo <PID_MARK> $!; wait; echo <EXIT_MARK>`,
  record the PID from the first line, kill it with a detached `runAsync`, and
  restart on the exit marker with backoff. Shell-quote every interpolated value.
- There is no file-watch API. Poll `fileInfo(path).mtime`, or stream
  `inotifywait -m` and debounce events to one refresh per tick. Always keep a
  fallback poll: the watcher can be missing or die.
- Commands inherit the shell's environment and have no terminal. Network or
  auth commands must be non-interactive (batch mode, prompts disabled) so they
  fail fast instead of hanging until the timeout.

**Settings**

- `getConfig(key)` only resolves keys declared in the manifest for that entry.
  A service sees plugin-level settings only: **widget settings are invisible to
  the service**.
- Changing a setting rebuilds widgets, panels and desktop widgets (so they may
  read config once at top level). A plugin-level change restarts the service
  unless it defines `onConfigChanged()`. A *widget* setting change does **not**
  restart or notify the service.
- So a service that needs per-instance configuration must discover instances
  itself: `noctalia.getSetting("widget")` (API 26) returns every `[widget.*]`
  table; filter by `type == "<author>/<plugin>:<entry>"`, rescan on a timer,
  start work for new instances and stop it for removed ones.
- Plugins cannot write configuration. `noctalia.openSettings()` opens the
  plugin-level page only. Widget settings are reached by the user through the
  widget's built-in middle-click binding, so tell them that in the UI instead
  of offering a button that leads to the wrong page.
- `visible_when` hides a field; nothing can grey one out. Its `values` are
  strings (`"true"` / `"false"` for a bool key).
- `file` and `folder` values arrive unexpanded: run them through `expandPath`
  and validate with `fileInfo` before use.

**Panels and gestures**

- One panel instance per entry id, shared by every widget that opens it.
  `togglePanel(id)` carries no argument, so a widget that wants the panel to
  show *its* data writes a target to `noctalia.state` immediately before
  toggling (state writes are synchronous), and the panel reads it in `onOpen`.
- Clicking a second widget while the panel is open for the first: toggle twice
  (close, then reopen anchored at the new widget). Have the panel publish what
  it is showing in `onOpen` and clear it in `onClose` so widgets can tell.
- Panel size is fixed in the manifest; there is no runtime resize.
- Middle click is taken by the host (opens widget settings) unless the manifest
  sets `middle = "none"`. A user binding in `[widget.<name>.actions]` replaces
  the matching script callback, so never make a gesture the only way to reach
  a function.

**Theme**

- Exactly 16 palette roles: `primary`, `secondary`, `tertiary`, `error`,
  `surface`, `surface_variant`, their `on_*` partners, `outline`, `shadow`,
  `hover`, `on_hover`. There is no warning or success role and
  `outline_variant` is not accepted. Map states onto these (`error` for
  problems, `tertiary` or `secondary` for attention, `outline` or
  `on_surface_variant` for inactive) and say which you chose.
- Never hardcode hex for anything that should follow the theme. Translucent
  variants are `role/alpha` (`"error/0.12"`).

## 4. Declarative UI pitfalls

The host diffs each `render()` against the previous tree and reuses native
controls **by position** unless nodes carry a `key`. Two real bugs came from
this, both invisible in code review:

- A button that replaced another at the same position inherited its disabled
  state. `enabled` is applied only when the prop is present. **Pass `enabled`
  explicitly on every interactive control, true or false.**
- Expanding a row made a neighbouring toggle flicker, because inserting a node
  shifted every later sibling onto a different native control. **Give a `key`
  to every node that is conditional, repeated, or follows something
  conditional**, and to the root of each alternative view (loading, error,
  normal) so switching views never reuses controls across them.

Also:

- `ui.input` is uncontrolled: `value` only seeds it. To clear or replace the
  text programmatically, change its `key` (a generation counter). Keep the key
  stable otherwise or the user loses what they typed.
- `toggle`, `slider`, `select` are controlled: pass the current value on every
  render. Callback arguments are always **strings** (`"true"`, `"42"`).
- Closures as callbacks need API 9; they belong to the render that made them,
  so keyed nodes are what keeps a handler alive across renders.
- `column` / `row` / `scroll` stretch children on the cross axis; use
  `align = "center"` for a row of mixed-height items.
- An unknown control or prop is logged and skipped, not an error. After any UI
  change, grep the log for warnings instead of trusting a clean compile.
- In the bar: `input`, `select`, `scroll` are unavailable, the capsule clips to
  bar thickness, and the layout must branch on `barWidget.isVertical()`. Once
  `barWidget.render()` is used, `setText` / `setGlyph` no longer show.
- Destructive or outward-facing actions get an inline confirm row, not a
  silent click. Disable the action row while a command is running and surface
  the result in the panel as well as by notification.

## 5. Idioms the official plugins follow

- Every `.luau` file starts with `--!nonstrict`, then a short comment saying
  what the entry is and which APIs it leans on. Two-space indent.
- Structure of a UI entry: read config at top level, declare locals, a local
  `render()`, `state.watch` handlers that update locals and call `render()`,
  lifecycle globals (`update`, `onClick`, `onOpen`, …), then an initial
  `render()`.
- State keys are namespaced strings (`"timer.state"`, `"status:<id>"`).
  Commands to the service are state keys too; include a sequence number or the
  target in the value so the service can tell requests apart.
- Every user-visible string goes through `noctalia.tr` / `noctalia.trp` with
  the English text in `translations/en.json`, including panel and tooltip
  text, not only setting labels. `en.json` uses nested objects with lowercase
  single-segment keys (a manifest `label_key` of `settings.foo.label` resolves
  through `{"settings": {"foo": {"label": …}}}`); never flat dotted keys.
- Settings: a `glyph`-typed setting for a configurable icon, a `folder` /
  `file` type for paths, `hide_when_<condition>` bools implemented with
  `barWidget.setVisible(false)`. Give every setting a `default` (optional only
  for `file` / `folder`) and a `description_key` when the label is not enough.
- A widget that cannot work yet (unset or invalid configuration) stays visible
  in an inactive colour with a tooltip that says so, even when a hide setting
  is on, and its panel explains how to fix it.
- Prefer in-process APIs (`togglePanel`, `setWallpaper`, `http`) over shelling
  out to the `noctalia` CLI or `curl`.
- Simple widgets use the imperative `barWidget.setText/setGlyph`; switch to
  `barWidget.render` only for composite content.
- Persist with `pluginDataDir()`, never inside `pluginDir()`.
- Luau, not Lua 5.1: `if c then a else b` expressions, `+=`, backtick
  interpolation, generalized `for k, v in t do`. Do not shadow builtins
  (`next`, `type`, `select`) with locals.
- `require("./lib/x.luau")`: relative, with the extension, resolved from the
  requiring file. Keep `lib/` modules pure and free of their own `require`
  calls, taking the host and sibling modules as arguments, so the entry script
  is the only composition point and the modules run under the plain `luau` CLI
  for tests (see `references/project.md`).

## 6. Development loop

The user's desktop is live and you cannot see it. Work in this order:

1. **Off-host first.** Unit-test pure modules with the `luau` CLI and
   syntax-check every script with `luau-compile --null <files>` (exit status is
   reliable). Generate parser fixtures from the real tool's output rather than
   writing them by hand, and run each planned command sequence once against
   throwaway data before encoding it.
2. **Install for development** into the implicit local source, which is always
   scanned and outranks every other source:
   `ln -sfn <plugin-dir> ~/.local/share/noctalia/plugins/<plugin>`.
   Do not add a `[[plugins.source]]` for this (see section 7).
3. **Installed is not enabled is not placed.** Enable the id
   (`noctalia msg plugins enable <author>/<plugin>`), define
   `[widget.<name>] type = "<author>/<plugin>:<entry>"`, and put `<name>` in a
   bar's `start` / `center` / `end` list.
4. **Reloading.** `.luau` edits to a loaded file hot-reload. Manifest changes
   need `noctalia msg config-reload`. Repointing the symlink at a new build
   (a new store path) is *not* noticed: run `config-reload`, and confirm from
   the log which path was loaded before asking the user to test.
5. **Watch the log**: `~/.cache/noctalia/noctalia.log`.
   - `[plugins] loaded plugin '<id>' (N entries) from <path>`
   - `[plugin-service] started service …` / `restarted service … after settings change`
   - `[bar.actions] widget.<name>: …` appears once per widget the bar actually
     created. No such line for your widget means it was never placed.
   - `[WRN] [config] … unrecognized widget type` means the plugin is not
     loaded or not enabled.
   - `noctalia.log()` output is tagged `[script-runtime]`.
6. **Probe state over IPC.** A temporary `onIpc` handler that logs
   `noctalia.json.encode(state)` beats guessing:
   `noctalia msg plugin <id>:<entry> all <event> [payload]` (`focused` or a
   connector for bar widgets; open a panel first with
   `noctalia msg panel-toggle <id>:<entry>`). Remove the hook afterwards.
7. **Live-verify with the user, one scenario at a time.** Point the plugin at
   scratch data you control, state exactly what they should see, and ask.
   Cover: each visual state, every action's success and failure path, each
   setting, the unconfigured state, hide/show, a vertical bar if they use one,
   and two instances when settings are per widget. When a report does not match
   your model, re-read it literally before debugging (a wrong assumption about
   *which* button was meant cost a full investigation once).
8. **Clean up**: temporary settings, debug hooks, scratch instances, stale
   `[plugin_settings."<old-id>"]` blocks, and the dev symlink before a
   home-manager build takes over that path.

Back up `~/.local/state/noctalia/settings.toml` before editing it, and ask
before changing the user's live shell config.

## 7. Config layering: why a plugin "does not show up"

Noctalia merges every `~/.config/noctalia/*.toml` in name order, then
`~/.local/state/noctalia/settings.toml` (written by the GUI) last. Tables merge
per key; **arrays are replaced wholesale**. No warning is logged when a list is
overridden. Check in this order:

1. Loaded? Look for the `loaded plugin` log line and its path.
2. Enabled? A later file or the GUI's `[plugins] enabled` replaces the list in
   an earlier file entirely. Find every definition:
   `grep -n 'enabled' ~/.config/noctalia/*.toml ~/.local/state/noctalia/settings.toml`.
3. Placed? Same for `[bar.<name>] start / center / end`: a GUI-edited bar
   layout in `settings.toml` overrides the lists in config files, so the widget
   is defined but never created. Add it to the list that wins.
4. Declaring `[[plugins.source]]` explicitly **drops the default official and
   community sources**, breaking every other plugin. Use the local source
   directory instead, also for Nix-managed plugins.
5. `settings.toml` drifts on its own. A bar entry whose widget type was
   unknown for a while (plugin removed or renamed) has been seen to disappear
   from its GUI-written list, and the GUI writes `[plugin_settings."<id>"]`
   when the user edits settings. After a rename or a reinstall, re-check
   placement and remove blocks for the old id.

## 8. Before calling it done

- [ ] `plugin_api` is the true minimum; `version` is strict `MAJOR.MINOR.PATCH` and bumped
- [ ] Every `label_key` / `description_key` resolves in `translations/en.json`; UI strings use `tr`
- [ ] Every glyph name exists in `tabler.json`; colours are palette roles
- [ ] Interactive controls carry `key` and explicit `enabled`
- [ ] All I/O async with timeouts, coalesced; streams restart and are stoppable
- [ ] Dynamic values only reach commands through argv arrays or shell quoting
- [ ] `dependencies` lists every external command; missing ones degrade with a clear message
- [ ] Unconfigured, error, loading and empty states each render something sensible
- [ ] Unit tests and `luau-compile` pass; the log is free of plugin warnings after a full click-through
- [ ] The user has confirmed each scenario live
- [ ] README states id, entry ids, settings, dependencies, panel IPC command
- [ ] Dev symlink and temporary config removed; packaging verified (`references/project.md`)
