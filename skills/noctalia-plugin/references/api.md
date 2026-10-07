# Noctalia plugin API cheat sheet

Condensed from the Noctalia 5.1.0 docs and source (plugin API levels 3..32).
It tells you what exists and where the traps are; the docs of the installed
version are authoritative for signatures (see SKILL.md section 1). `(N)` after
a name is the API level that introduced it; unmarked items are level 3.

## Manifest (`plugin.toml`)

```toml
id           = "me/hello"      # "<author>/<plugin>", both segments [a-z0-9][a-z0-9._-]*
name         = "Hello"
version      = "1.0.0"         # strict MAJOR.MINOR.PATCH, no suffixes
plugin_api   = 9               # oldest API level required
author       = "me"
license      = "MIT"           # optional, defaults to MIT
icon         = "puzzle"        # optional glyph name
description  = "One line."     # catalog copy, <= 120 chars
tags         = ["bar"]         # from the fixed list in publishing.md
dependencies = ["jq"]          # external commands; informational, does not gate enabling
deprecated   = false

[[setting]]                    # plugin-level: one value, visible to every entry
key = "interval"
type = "int"
label_key = "settings.interval.label"
description_key = "settings.interval.description"
default = 5
min = 1
max = 60

[[service]]
id = "service"
entry = "service.luau"

[[widget]]
id = "bar"
entry = "bar.luau"

  [widget.actions]             # (14) gesture defaults; a binding replaces the script callback
  middle = "none"              # frees onMiddleClick

  [[widget.setting]]           # per widget instance; wins over a plugin-level key of the same name
  key = "glyph"
  type = "glyph"
  label_key = "settings.glyph.label"
  default = "puzzle"

[[panel]]
id = "panel"
entry = "panel.luau"
width = 420                    # number, or "fill" (floating only)
height = 410
placement = "attached"         # or "floating"
position = "auto"              # "center" or a screen anchor when floating
open_near_click = true
```

Entry kinds: `[[widget]]`, `[[panel]]`, `[[service]]`, `[[shortcut]]`,
`[[launcher_provider]]`, `[[desktop_widget]]`. Address: `<author>/<plugin>:<entry-id>`.
Settings can be declared on widget, panel, desktop_widget and launcher_provider
entries, and at the root.

Setting fields: `key`, `type`, `label_key` (required; a literal `label` is
rejected), `description_key`, `default`, `min` / `max` (int, double), `options`
(select: `[{ value, label_key }]`), `extensions` (file), `visible_when =
{ key = "other", values = ["true"] }`, `advanced`.

Setting types: `string`, `string_list`, `string_map` (6), `bool`, `int`,
`double`, `select`, `file`, `folder`, `glyph`, `color`.

Panel-only manifest keys: `dismiss_on_outside_click` (8), `keyboard_focus`
`on_demand|exclusive|none` (10), `persistent` (11), `capture_keys` (13),
`layer` `top|overlay` (30). The host injects placement / position / layer /
open-near-click settings for every panel; do not redeclare them.
`keyboard_focus = "none"` and `persistent = true` both require
`dismiss_on_outside_click = false`.

Launcher provider keys: `prefix` (bare lowercase word, no slash), `glyph`,
`include_in_global_search`, `debounce_ms`.

User-side configuration the manifest does not contain:

```toml
[plugins]
enabled = ["me/hello"]

[plugin_settings."me/hello"]   # plugin-level values
interval = 10

[widget.my_hello]              # one named instance; widget settings live here
type = "me/hello:bar"
glyph = "star"

[bar.default]
end = ["my_hello", "clock"]
```

## Entry callbacks (globals the host calls)

| Function | Entries | Notes |
|---|---|---|
| `update()` | widget, desktop, panel, service | every `setUpdateInterval(ms)` (min 16 ms) |
| `onClick()` / `onRightClick()` | widget, shortcut | overridable by user bindings |
| `onMiddleClick()` | widget | only if `middle = "none"` |
| `onScroll(axis, steps, startsGesture)` | widget | `steps` negative = up/left |
| `onQuery(text)` / `onActivate(id)` | launcher | echo `text` back in `setResults` |
| `onOpen(context)` / `onClose()` | panel | `context` is the optional IPC string |
| `onKey(chord, pressed)` | panel (13) | only chords in `capture_keys` |
| `onFrameTick(deltaMs)` | desktop, panel (18) | after `setNeedsFrameTick(true)` |
| `onIpc(event, payload)` | all | `noctalia msg plugin <id>:<entry> <target> <event> [payload]` |
| `onConfigChanged()` | service | defining it turns a restart into an in-place update |
| `onEnable()` | service (17) | explicit enable only, not ordinary startup |
| `onOutputsChanged()` | service | output set or geometry changed |
| `onExit(signal, reason)` | all | `reason` (17): `disable`, `uninstall`, `reload`, `shutdown`; normal time budget; a `runAsync` without callback outlives the runtime |

Top-level code runs once at load: set up state and register `state.watch` there.

## `barWidget.*`

`setText`, `setGlyph`, `setImage(path [, watch [, w [, h]]])`,
`setTooltip(string | {k, v} | rows)`, `clearTooltip`, `setFont(family [, baseline])`,
`setColor(color [, "script"])`, `setGlyphColor`, `setVisible(bool)`,
`isVertical()`, `outputName()`, `render(tree)`.

- `setColor("")` / `setGlyphColor("")` restore the widget's configured colour.
- The official timer plugin guards `clearTooltip()` so it is only called when a
  tooltip was set; do the same.
- `outputName()` is per placement; `noctalia.focusedOutputName()` is global.

## `shortcut.*`, `launcher.*`, `desktopWidget.*`, `panel.*`

- `shortcut.setLabel`, `setIcon(on [, off])`, `setActive`, `setEnabled`
- `launcher.setResults(query, results)` with rows `{ id, title, subtitle?, glyph?, icon?, badge?, query?, score? }`;
  `launcher.setQuery(text)` keeps the launcher open (drill-in)
- `desktopWidget.render`, `setWantsSecondTicks`, `setNeedsFrameTick`
- `panel.render`, `close`, `openContextMenu(request)` (28), `setWantsSecondTicks`, `setNeedsFrameTick` (18)

## `noctalia.*`

Runtime and config: `setUpdateInterval`, `log`, `getConfig(key)`,
`getSetting(dottedPath)` (26, any shell config value, tables become Luau
tables), `getColor(role)` (31), `isDarkMode`, `focusedOutputName`, `outputs`,
`togglePanel(fullId)`, `openSettings()` (15), `openColorPicker(initial, cb)`.

Processes: `runAsync(cmdOrArgv [, cb [, timeoutMs]])` (argv form 24; result
`{ exitCode, stdout, stderr, timedOut, stdoutTruncated, stderrTruncated }`),
`runStream(cmd, onLine)`, `runInTerminal(cmd)`, `commandExists(name)`,
`processMatches(cb, ...)`, `getenv`, `expandPath`, `flatpakAppInstalled`,
`portalAvailable`.

Files: `readFile`, `readFileAsync(path, cb)` (23, 4 MiB, 4 pending),
`writeFile`, `mkdirAll`, `removeFile`, `renameFile`, `fileExists`,
`fileInfo(path)` → `{ size, mtime, isDir }` or `nil, err`, `listDir`,
`pluginDir`, `pluginDataDir`, `loadFont`. Relative paths resolve against the
plugin directory; `~` expands.

Network: `http(request, cb)` → `{ ok, status, body }`, `httpStream(request,
onLine, onClose)` (4) → handle with `stop()`, `download(url, dest, cb)`.
Request: `{ url, method, body, headers = { "K: v" }, basic_username,
basic_password, follow_redirects, allow_insecure_tls (7) }`. Prefer headers in
`http` over `curl` so secrets stay off the process list.

Time and desktop: `formatTime(pattern [, unixSeconds [, tz]])`, `nowMs()` (12),
`timeFormat` / `dateFormat` / `isValidTimezone` (19), `notify(title, body)`,
`notifyError`, `copyToClipboard(text, mime)`, `clipboardText`,
`appIconPath(appId, sizePx)`, `setWallpaper`, `wallpaperDirectory`,
`sound.load` / `sound.play` (20).

System: `systemStats()`, `cpuCores()` (12), `diskMounts()`, `diskStats(path)`
(16). Absent sensors are `nil`, not `0`; the first call opts into sampling.

Helpers: `tr(key [, subst])`, `trp(key, count [, subst])` (`<key>.one` /
`<key>.other`), `json.encode(value [, pretty])`, `json.decode`, `string.trim`,
`string.urlEncode` / `urlDecode`, `fuzzyScore(pattern, text)`.

State: `state.set(key, value)`, `state.get(key)`, `state.watch(key, fn)`.

Modules: `require("./relative/path.luau")` (22). Per-entry cache, own global
environment, hot-reloads the owning entry when a loaded module changes.

## `ui.*`

Containers: `column`, `row`, `scroll` (`gap`, `padding`, `paddingH`,
`paddingV`, `align`, `justify`, `fill`, `radius`, `border`, `borderWidth`,
`minWidth`, `minHeight`, `onClick`, `onHover`, `tooltip` (32)).
`scroll` adds `stickToBottom`, `onScroll`, `scrollToBottomRev` (21).

Display: `label` (`text`, `fontSize`, `color`, `fontWeight`, `fontFamily`,
`maxWidth`, `maxLines`, `textAlign`), `markdown` (21), `glyph` (`name`, `size`,
`color`), `image` (local files only), `box`, `separator`, `spacer`, `progress`,
`graph` (pointer callbacks 29).

Interactive: `button` (`text`, `glyph`, `variant`
`default|primary|secondary|destructive|outline|ghost`, `controlSize`
`sm|md|lg`, `tooltip`, `enabled`, `selected`, `onClick`, `onRightClick`),
`toggle` (`checked`, `enabled`, `onChange`), `slider`, `select` (`options`,
`selectedIndex`), `input` (`value` seeds once, `placeholder`, `password`,
`multiline`, `submitOnEnter` (21), `frameVisible` (27), `focus`, `enabled`,
`onChange`, `onSubmit`; multiline submits on Ctrl+Enter).

Panels only: `dragSource`, `dropZone` (5).

Every node: `key`, `width`, `height`, `flexGrow`, `opacity` (group opacity,
fades children too), `visible`. Colours: role token, `role/alpha`, `#rrggbb`,
`#rrggbbaa`. Callbacks: a global function name, or a closure (9).

## CLI used during development

```sh
noctalia msg plugins list | enable <id> | disable <id> | update <source>
noctalia msg config-reload
noctalia msg panel-toggle <id>:<panel>
noctalia msg plugin <id>:<entry> focused|all|<connector> <event> [payload]
noctalia msg --help
```
