# nvim-browser

`nvim-browser` is an experimental browser runtime for Neovim.

The goal is to keep browsing, Markdown/PDF preview, and image preview inside the
terminal/Neovim workflow instead of jumping to an external browser tab. The
first target terminal is Ghostty, using terminal graphics as the future display
surface.

## Status

This repository is an early MVP scaffold. Today it includes:

- Rust backend binary: `nvbrowser`
- target classification for URLs, Markdown, HTML/PDF, and images
- styled Markdown-to-HTML rendering with local asset base paths
- local HTML, SVG, PDF, and raster image file previews through the Chromium/CDP browser
  session path
- standalone CLI image output through Kitty graphics protocol with fit modes
- Chromium/CDP browser sessions rendered through Kitty graphics or ANSI output
- Ghostty-oriented browser previews use full-frame Kitty Unicode image placement
  with cursor-addressable placeholder cells
- large literal Kitty browser frames are split into stable image tiles to keep
  oversized transfers replaceable inside the preview surface
- Neovim commands for opening, navigating, reloading, stopping pending loads, history, scrolling, finding text, text input, keys, selector focus, point clicks, right-clicks, point hovers, and hinted element actions
- browser element hints overlaid on cursor-addressable previews
- persistent Neovim preview surface reuse
- current URL, title, scroll progress, status, runtime diagnostics, preview footer, lightweight live state refresh, and preview buffer naming from the active browser session
- Markdown preview support for Mermaid fenced diagrams
- CLI integration tests for backend command contracts
- initial OSS packaging and CI

Planned next steps:

- terminal-multiplexer graphics passthrough support and documentation
- richer browser interaction for links and form controls
- KaTeX and richer document preview features

## Architecture

```text
Ghostty
└─ Neovim
   ├─ Lua plugin
   │  ├─ commands.lua
   │  ├─ backend.lua
   │  └─ terminal.lua
   └─ Rust backend
      ├─ nvbrowser-core
      │  ├─ target
      │  ├─ markdown
      │  ├─ session
      │  ├─ renderer
      │  └─ terminal/kitty
      └─ nvbrowser-cli
```

See [docs/architecture.md](docs/architecture.md) for module boundaries.

## Requirements

- Neovim 0.10+
- Rust stable
- Ghostty for the intended terminal graphics experience

## Installation

With lazy.nvim:

```lua
{
  "yoshimi-I/nvim-browser",
  tag = "v0.1.3",
  build = "cargo build --release",
  config = function()
    require("nvim-browser").setup({
      graphics = "auto",
    })
  end,
}
```

The plugin looks for `target/release/nvbrowser` in the plugin checkout first,
then `target/debug/nvbrowser`, then `nvbrowser` on `$PATH`. To use a binary from
a GitHub Release or a package manager, set an explicit path:

```lua
require("nvim-browser").setup({
  binary = vim.fn.expand("~/.local/bin/nvbrowser"),
})
```

With `graphics = "auto"`, nvim-browser resolves graphics from the terminal
environment. Ghostty, Kitty, and WezTerm use `kitty-unicode` for browser frames;
the standalone `nvbrowser show-image` CLI uses `kitty` for raster images.
Zellij falls back to ANSI because Kitty graphics passthrough is unreliable
there. Lua backend tests cover the `ZELLIJ=1` auto resolution for browser
sessions and image targets, and the opt-in Chromium E2E suite covers that ANSI
browser surface with frame rendering, hints, text input, clicks, and page text.
tmux keeps Kitty output and relies on tmux passthrough wrapping. Unknown
terminals use ANSI as the safe fallback. Override with `graphics = "ansi"`,
`"kitty"`, or `"kitty-unicode"` when needed.

For tmux, enable passthrough in your tmux config before expecting Kitty graphics
to render:

```tmux
set -g allow-passthrough on
```

`:NBrowserDoctor` reports `ok: tmux allow-passthrough=on` or warns when the
setting is disabled or cannot be probed.

When `TMUX` is present, standalone image output such as
`nvbrowser show-image --output kitty` wraps Kitty escapes in tmux passthrough
from Rust. Neovim browser sessions keep browser payloads as raw Kitty graphics
and apply tmux passthrough only at the Lua terminal egress boundary, so the
preview is wrapped exactly once.

If your terminal font cell size makes browser previews look stretched or click
targets feel offset, tune the viewport cell pixels:

```lua
require("nvim-browser").setup({
  viewport = {
    cell_width_px = 9,
    cell_height_px = 18,
  },
})
```

You can adjust those values at runtime and immediately resize an active browser
session. Runtime calibration values are saved under Neovim state and reused on
the next `setup({})` call unless `viewport.cell_width_px` / `cell_height_px` are
configured explicitly:

```vim
:NBrowserCalibrate 9 18
:NBrowserDoctor
```

For guided calibration, open the fixture with `:NBrowserCalibrate`, move the
Neovim cursor onto the small yellow guide point, then run:

```vim
:NBrowserCalibrateHere
```

The command computes cell pixels from the cursor position, saves them under
Neovim state, and immediately resizes the active browser preview.

`NBrowserDoctor` reports whether Chromium/CDP is available, whether the latest
browser runtime metadata matches the configured cell-pixel calibration, and
whether the active preview has click geometry that matches the rendered frame.
It also reports whether the active cell-pixel values came from defaults,
explicit config, persisted calibration state, or the last guided calibration
sample.
The calibration page also exposes fixed click, right-click, hover, type, and
wheel targets; after interacting with them, `:NBrowserDoctor` reports which
fixture hit tests have been observed.
Inside tmux, it also checks `allow-passthrough` when Kitty graphics are selected.

To attach to an already-running Chrome DevTools Protocol browser instead of
letting `nvbrowser` launch Chrome, pass the browser WebSocket URL:

```lua
require("nvim-browser").setup({
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/<id>",
})
```

To keep cookies, localStorage, and login state across launched Chromium
sessions, opt in to a dedicated profile directory. nvim-browser never defaults
to your normal Chrome profile:

```lua
require("nvim-browser").setup({
  user_data_dir = vim.fn.expand("~/.local/state/nvim-browser/chrome-profile"),
})
```

The same setting is available to the backend as `NVBROWSER_USER_DATA_DIR` or
`--user-data-dir`. Reusing one profile directory from multiple simultaneous
browser sessions can fail because Chromium locks active profiles.

To save browser-initiated downloads from clicks, hints, forms, or forwarded
keys, configure a dedicated download directory:

```lua
require("nvim-browser").setup({
  download_dir = vim.fn.expand("~/Downloads/nvim-browser"),
})
```

The same setting is available to the backend as `NVBROWSER_DOWNLOAD_DIR` or
`--download-dir`. Completed downloads are reported in the preview footer and
`:NBrowserStatus` as `download=filename`. The serve protocol can report
multiple completed downloads from one interaction response and keeps a bounded
list available via `:NBrowserDownloads` with 1-based indexes. Completed
downloads are persisted in the normal nvim-browser session file when
`session.persist` is enabled; nvim-browser does not provide progress UI,
cancellation, or filename prompts.
JavaScript dialogs are auto-handled so Chromium does not block: alerts are
accepted, confirm/prompt/beforeunload dialogs are dismissed, and the latest
handled dialog is reported as `dialog=confirm dismissed: message`.

Active browser previews refresh lightweight page state every 1500ms by default
so URL, title, scroll, focus, and download metadata stay current without
constant screenshots. When that lightweight state shows the page changed while
idle, nvim-browser debounces one full-frame capture so the visible preview does
not stay stale. Use `:NBrowserRefresh` when you want a fresh frame immediately.
Navigation-like operations and explicit frame captures are guarded by a
Neovim-side watchdog based on `navigation_timeout_ms`; if Chromium/CDP stalls,
the preview hard-stops the serve job, ignores late output from that generation,
shows `timeout | ...` in the footer, and can restart with `:NBrowserRefresh`,
`:NBrowserReload`, or `:NBrowserAddress`.
Disable live refresh or tune its interval with:

```lua
require("nvim-browser").setup({
  live_refresh = {
    enabled = false,
    interval_ms = 2500,
  },
})
```

Rapid scroll input is coalesced inside Neovim before it reaches the backend, so
holding scroll keys or using the mouse wheel produces fewer full-frame browser
captures while preserving the latest accumulated delta. Mouse wheel events over
cursor-addressable previews still use native CDP wheel events at the mapped
browser coordinates when geometry is valid.

Release tags use `vMAJOR.MINOR.PATCH`; replace `v0.1.3` with the latest release
tag when installing. Until `v1.0.0`, plugin and backend compatibility is
guaranteed only within the same tag or commit; pin the Neovim plugin and
`nvbrowser` binary together. `:NBrowserDoctor` compares the plugin's expected
serve protocol with both the installed backend and any active browser session so
stale binaries or mismatched lazy.nvim pins are visible before debugging
browser input.

## Development

Build the backend:

```sh
cargo build
```

Run tests:

```sh
cargo test
for test in tests/lua/*_test.lua; do nvim --headless -u NONE -l "$test"; done
```

Try the backend:

```sh
cargo run -p nvbrowser -- inspect https://example.com
cargo run -p nvbrowser -- render-md README.md
cargo run -p nvbrowser -- show-image path/to/image.png
cargo run -p nvbrowser -- capture https://example.com --output /tmp/frame.png --metadata /tmp/frame.json
cargo run -p nvbrowser -- browse https://example.com
cargo run -p nvbrowser -- doctor --json
```

The `browse`, `capture`, and browser-session previews for local HTML/SVG/PDF
files require Chrome or Chromium. PDF quality and behavior come from Chrome's
built-in PDF viewer; nvim-browser does not rasterize PDFs itself. Set
`NVBROWSER_CHROME` when auto-detection cannot find the browser binary.
Alternatively, set `NVBROWSER_CDP_WS_URL` or pass `--cdp-ws-url` to attach to an
existing browser websocket endpoint. Chrome exposes that URL from
`http://127.0.0.1:9222/json/version` when started with
`--remote-debugging-port=9222`.
Use `NVBROWSER_USER_DATA_DIR` or `--user-data-dir` to opt in to a persistent
Chromium profile directory for launched browser sessions.
`nvbrowser doctor --json` reports the detected backend and serve protocol
without launching Chrome; `:NBrowserDoctor` includes the same readiness and
protocol compatibility check inside Neovim.
The `capture` command writes raw Chromium viewport PNG frames independently
from terminal rendering. Use `--output -` for PNG bytes on stdout, and
`--metadata -` for JSON metadata on stdout when `--output` is a file.

Try the plugin from this checkout:

```sh
nvim --cmd 'set rtp+=.'
```

Then run:

```vim
:NBrowserInspect https://example.com
:NBrowserOpen https://example.com
:NBrowserPreview
:NBrowserReload
:NBrowserStop
:NBrowserNavigate https://example.org
:NBrowserAddress
:NBrowserOpenUnderCursor
:NBrowserHistory
:NBrowserBookmark
:NBrowserBookmarks
:NBrowserResume
:NBrowserActions
:NBrowserBack
:NBrowserForward
:NBrowserScrollDown 400
:NBrowserPageDown
:NBrowserPageUp
:NBrowserScrollTop
:NBrowserScrollBottom
:NBrowserHalfPageDown
:NBrowserHalfPageUp
:NBrowserZoomIn
:NBrowserZoom 1.25
:NBrowserZoomOut
:NBrowserZoomReset
:NBrowserFind search text
:NBrowserFindNext
:NBrowserFindPrevious
:NBrowserFocusSelector input[name="q"]
:NBrowserInput hello
:NBrowserInputMode
:NBrowserTextMode
:NBrowserPaste +
:NBrowserSelectRegion 12 8 12 40
:NBrowserYankRegion 12 8 12 40 +
:NBrowserYankSelection +
:NBrowserYankPageText +
:NBrowserYankUrl +
:NBrowserYankHintUrl a +
:NBrowserScreenshot /tmp/page.png
:NBrowserKey Enter
:NBrowserKey A ctrl
:NBrowserClick 120 240
:NBrowserRightClick 120 240
:NBrowserClickHere
:NBrowserRightClickHere
:NBrowserHoverHere
:NBrowserHints
:NBrowserClickHint 1
:NBrowserRightClickHint 1
:NBrowserHoverHint 1
:NBrowserFocusHint s
:NBrowserFollowHint a
:NBrowserTypeHint s hello world
:NBrowserSubmitHint s hello world
:NBrowserSelectHint s Canada
:NBrowserUploadHint u /tmp/example.txt
:NBrowserToggleHint c
:NBrowserTypeHere hello world
:NBrowserSubmitHere hello world
:NBrowserTypeHintMode
:NBrowserSubmitHintMode
:NBrowserSelectHintMode
:NBrowserUploadHintMode
:NBrowserFocusHintMode
:NBrowserToggleHintMode
:NBrowserHintMode
:NBrowserCurrentUrl
:NBrowserCurrentTitle
:NBrowserStatus
:NBrowserDownloads
:NBrowserOpenDownload
:NBrowserReader
:NBrowserReaderFollow
:NBrowserDoctor
:NBrowserCalibrate 9 18
:NBrowserCalibrateHere
:NBrowserToggle
```

Markdown files are rendered with a docs-oriented browser shell and a local
`<base>` path so relative images can resolve from the Markdown file directory.
Fenced `mermaid` blocks are promoted to Mermaid diagrams. When a Markdown file
contains at least one Mermaid block, the generated preview imports Mermaid
`10.9.3` from `cdn.jsdelivr.net`; Markdown files without Mermaid blocks do not
load that script.
HTML, SVG, PDF, and raster image files are opened through Chromium using
`file://` URLs. The standalone `nvbrowser show-image` CLI still supports
`original`, `contain`, `width`, and `height` fit modes.

`:NBrowserOpenUnderCursor` opens the Markdown link target, raw URL, `file://`
URL, readable local file path, or host-like text under the cursor, falling back
to the current line as search text. It navigates an active browser session when
one exists and otherwise opens a new browser preview.

`:NBrowserClickHere` maps the preview cursor to browser viewport pixels. It is
available for ANSI and Kitty Unicode browser previews. Active browser previews
reserve the bottom preview row for a compact status footer, so cursor clicks in
that footer are not sent to the browser page.
`:NBrowserDoubleClickHere` uses the same mapping and sends a native Chromium
left-button double-click at the preview cursor.
`:NBrowserRightClickHere` uses the same cursor-to-viewport mapping and sends a
native Chromium right-click, so page `contextmenu` handlers can run inside the
preview.
`:NBrowserHoverHere` sends a real Chromium mouse-move event to the browser
viewport point under the preview cursor. Use it to reveal CSS `:hover` menus or
tooltips without leaving Neovim. Preview scroll-wheel events are also sent as
native Chromium mouse-wheel input at the mouse position when the preview is
cursor-addressable, then fall back to page-level scrolling if coordinates are
not available.

Browser preview footers show the latest serve status, title or URL, scroll
progress, focused element kind/label, latest handled JavaScript dialog, latest
completed download filename, non-default zoom, output mode, cell geometry, and
current URL when reported by the Chromium/CDP session. `:NBrowserStatus`
echoes the same browser-session state in the command line. Focus metadata is
reported as `focus=input Search`, `focus=text_area Notes`, and similar compact
labels after captured browser interactions. Non-default zoom is reported as
`zoom=125%`.
`:NBrowserDownloads` lists completed downloads reported during the current and
persisted browser sessions, including a 1-based index, filename, and full path.
`:NBrowserOpenDownload` opens a completed download by index or with a picker.

While a browser session is idle, nvim-browser periodically sends a lightweight
page-state request to keep metadata current without repainting the preview
image. Meaningful idle changes schedule one debounced full-frame capture. It
does not send background requests while a navigation-like operation is pending,
and it stops the timer when the browser preview is stopped, closed, or replaced.

Navigation-like operations show immediate `loading | ... | Esc stop` feedback
in the preview footer before Chromium returns a frame. Run `:NBrowserStop`, or
press `<Esc>` in the focused preview buffer, to cancel the pending operation and
terminate a stuck serve job. After a hard stop, `:NBrowserRefresh`,
`:NBrowserReload`, or `:NBrowserAddress` starts a fresh serve session from the
stopped, timed-out, or requested URL; closing the preview does not restart it.

`:NBrowserHints` echoes the latest keyboard labels and numbered browser
elements, including link destinations when available. On ANSI and Kitty Unicode
browser previews, the same labels are also overlaid on the preview.
Hint discovery covers the top document, open shadow roots, and same-origin
iframes. Closed shadow roots and cross-origin iframe DOMs are intentionally not
inspected.
`:NBrowserClickHint {id-or-label}` clicks the backend hint id without relying
on viewport coordinates. For link hints with `target="_blank"` and an `href`,
it follows the `href` in the current preview instead of opening a popup target.
`:NBrowserRightClickHint {id-or-label}` dispatches a native right-click at the
hinted element. `:NBrowserHoverHint {id-or-label}` moves to the matching
element coordinates.
`:NBrowserFollowHint {label}` uses a link hint's `href` directly when
available, which avoids coordinate-click drift and keeps the active browser
session on the navigated URL; non-link hints fall back to backend hint clicks.
`:NBrowserPickHint [follow|click|right-click|focus|hover|toggle|type|submit|select|upload|yank-url]` opens a `vim.ui.select`
picker for the current hints and runs the selected action, defaulting to
`follow`. The `type` and `submit` actions show only input-like hints, then
prompt for text. The `select`, `upload`, and `yank-url` actions show only
compatible hints, then select an enabled option, prompt for a file path, or yank
the link destination.
`:NBrowserHintMode` prompts for a label and follows it. In preview buffers, the
default `f` mapping enters a transient hint mode instead: type the visible hint
label directly, use additional keys for multi-character labels such as `aa`, or
press `<Esc>` to cancel.
`:NBrowserTypeHint {id-or-label} {text}` focuses the backend hint id and types
text into it without relying on viewport coordinates. `:NBrowserSubmitHint
{id-or-label} {text}` also presses Enter after the text is queued.
`:NBrowserFocusHint {id-or-label}` focuses a hinted field or focusable element
and captures a fresh frame; follow it with `:NBrowserInput`, `:NBrowserPaste`,
or `:NBrowserKey Enter` for search box workflows.
`:NBrowserSelectHint {id-or-label} {choice}` selects an option in a hinted
`<select>` element. Numeric choices use 1-based option indexes; otherwise the
runtime matches option values, then normalized visible option text.
`:NBrowserUploadHint {id-or-label} {path...}` uploads one or more local files
into a hinted `<input type="file">` and captures a fresh frame. Escape spaces
with Vim filename escaping, for example `:NBrowserUploadHint u /tmp/a\ b.txt`.
The backend validates that every path exists before sending the request to
Chromium.
`:NBrowserToggleHint {id-or-label}` toggles a hinted checkbox or selects a
hinted radio input. Checkbox/radio hints show `[checked]` or `[unchecked]` in
`:NBrowserHints`.
`:NBrowserTypeHere {text}` maps the preview cursor to browser viewport pixels,
clicks/focuses that point, and types text there. `:NBrowserSubmitHere {text}`
does the same and presses Enter after the text is queued. These commands require
an ANSI or Kitty Unicode browser preview and ignore the preview footer row.

`:NBrowserTypeHintMode` prompts for a hint label and text, then types into the
hinted element. `:NBrowserSubmitHintMode` does the same and presses Enter after
the text is queued. `:NBrowserSelectHintMode` opens Neovim pickers for hinted
`<select>` elements and their enabled options when option metadata is available,
falling back to typed hint and option prompts for older metadata. Disabled
options are not submitted. `:NBrowserUploadHintMode` prompts for a file-input
hint label and a path. `:NBrowserFocusHintMode` prompts for a hint label and
focuses the matching element. `:NBrowserToggleHintMode` prompts for a
checkbox/radio hint label. Lua mappings can call `require("nvim-browser").hint_mode()`,
`require("nvim-browser").pick_hint({ action = "focus" })`,
`require("nvim-browser").type_hint_mode(nil, { submit = true })`, or
`require("nvim-browser").select_hint_mode()` /
`require("nvim-browser").upload_hint_mode()` /
`require("nvim-browser").focus_hint_mode()` /
`require("nvim-browser").toggle_hint_mode()`.
`:NBrowserAddress [url-or-search]` works like a small omnibox; host-like input
opens as a URL, and plain words use the configured search URL. With no
argument, the prompt is prefilled with the current URL when available, falling
back to the last target. Command-line completion includes recent session history
URLs. Recent pages are persisted by default in
`stdpath("state") .. "/nvim-browser/session.json"` so they survive Neovim
restarts. `:NBrowserHistory` opens the recent page picker and navigates to the
selected URL, or opens it when no browser session is active. `:NBrowserBookmark`
saves the current browser page into the same session file, and
`:NBrowserBookmarks` opens saved pages through a bookmark picker. `:NBrowserResume`
opens the active session URL when available, otherwise the last persisted target,
otherwise the newest persisted history URL.
Lua mappings can call `require("nvim-browser").address()` or pass a value
directly with `require("nvim-browser").address("example.com")`.
`:NBrowserActions` opens a compact picker for common browser actions such as
opening, previewing, inspecting, resuming, bookmarking, address, reload, history
movement, find, hints, text mode, cursor click/double-click/right-click/hover/type,
downloads, screenshot, reader, status, zoom, doctor, and close. Preview buffers
map `?` to this picker by default.

`:NBrowserZoom {scale}` sets an exact page scale, for example `1.25` for
125%, while `:NBrowserZoomIn`, `:NBrowserZoomOut`, and `:NBrowserZoomReset`
step or reset the scale.

`:NBrowserFind {text}` finds text in the active browser page, scrolls to the
match through the browser's native find behavior, and captures a fresh frame.
The preview footer shows the latest visible-text match count, such as
`find: 3 matches`.
`:NBrowserFindNext` and `:NBrowserFindPrevious` repeat the last browser find
query forward or backward. In preview buffers, the default `n` and `N` mappings
repeat the current page find like a normal editor search.

`:NBrowserInput {text}` types text into the currently focused browser element.
`:NBrowserInputMode` prompts once for text and sends it to the focused element.
`:NBrowserPaste [register]` sends the contents of a Neovim register to the
focused browser element, defaulting to the unnamed register.
`:NBrowserSubmitFocused` submits the current focused form-capable browser
element by sending Enter only when the backend reports the active element as
submittable.
`:NBrowserYankSelection [register]` reads the browser's current selected text
and writes it into a Neovim register, defaulting to the unnamed register.
`:NBrowserYankPageText [register]` asks the active Chromium session for the
current page text snapshot and writes that Markdown-like body to a Neovim
register without opening or mutating the reader buffer. It yanks the live DOM
snapshot, not the rendered terminal preview, and preserves the register when the
snapshot is empty or the browser session is inactive.
`:NBrowserSelectRegion [start-row start-col end-row end-col]` drags across the
cursor-addressable preview to create a native browser text selection. With four
arguments it uses those preview-cell coordinates; without arguments it uses the
current Visual selection marks. Follow it with `:NBrowserYankSelection`.
`:NBrowserYankRegion [register]` selects the current Visual preview region in
Chromium and writes the resulting browser selection into a Neovim register. It
also accepts `start-row start-col end-row end-col [register]` for explicit
preview-cell coordinates. In focused preview buffers, normal `y` yanks the
current browser selection and Visual `y` yanks the Visual preview region.
`:NBrowserYankUrl [register]` writes the active browser page URL into a Neovim
register without recapturing the page. `:NBrowserYankHintUrl {id-or-label}
[register]` writes a hinted link destination from the latest frame.
`:NBrowserScreenshot [path]` captures the active browser session viewport to a
PNG file without replacing the Neovim preview frame. Without a path, it writes a
timestamped PNG under Neovim's cache directory.
`:NBrowserTextMode` enters an interactive browser text mode for the focused
preview: printable keys are sent as text, `<CR>`, `<Tab>`, `<S-Tab>`, `<BS>`,
Delete, and arrow keys are forwarded as browser keys, and `<Esc>` exits the text
mode locally. Printable input and editing keys use a low-latency path that skips
per-key screenshot recapture while still applying lightweight URL, scroll, and
focused-element metadata when the backend returns it; exiting text mode triggers
one fresh capture.
Enter still requests an immediate captured response because it often submits or
navigates. Focused preview buffers map `i` to this text mode by default after
clicking a field or focusing one with hints. Outside text mode, preview buffers
also forward common browser keys: `<CR>`, `<Tab>`, `<S-Tab>`, `<BS>`, `x`
Delete, `ge` Escape, `A` Ctrl-A select-all, `gl` address prompt, and arrow
keys. `:NBrowserKey {key} [modifier ...]` accepts modifier names such as
`ctrl`, `shift`, `alt`, and `meta`.

`:NBrowserReader` captures the current browser page as Markdown-like text in a
normal scratch buffer so page content can be selected, searched, and yanked
without leaving Neovim. Links are preserved as Markdown links where possible;
press `<CR>` or `gf` on a reader link, or run `:NBrowserReaderFollow`, to
navigate the active browser session to that URL. Reader follow resolves
root-relative paths, page-relative paths, and `#fragment` links against the
current page URL; if a line has exactly one link, it can be followed even when
the cursor is not directly on the link text.

Opt-in browser keymaps can be enabled from setup:

```lua
require("nvim-browser").setup({
  keymaps = {
    enabled = true,
    prefix = "<leader>b",
  },
})
```

The default mappings are `<leader>br` reload, `<leader>bh` back, `<leader>bl`
forward, `<leader>bj` scroll down, `<leader>bk` scroll up, `<leader>ba`
address, `<leader>bg` open the target under the cursor, `<leader>b/` find,
`<leader>bf` hint mode, `<leader>bt` type into a hinted field, `<leader>bs`
type and submit, `<leader>bo` select a hinted option, and `<leader>bc` toggle a
hinted checkbox/radio. Existing mappings are left untouched; choose another
prefix or mapping key if one is already in use.

Focused preview buffers also install buffer-local browser controls by default:
`r` reload, `H` back, `L` forward, `j`/`k` scroll, `<PageDown>/<PageUp>` scroll
by 90% of the browser viewport, `gg` top, `G` bottom, `<C-d>/<C-u>` scroll by
half the browser viewport, `+` zoom in, `-` zoom out, `=` reset zoom,
`a` address, `?` actions picker, `/` find, `n` repeat find forward, `N`
repeat find backward, `f` hint mode, `t` type into a hinted field, `s` type and
submit, `gs` submit the focused form-capable element, `o` select a hinted option,
`c` toggle a hinted checkbox/radio, `i`
type into the focused element with browser text mode, `p` paste the selected
register into the focused element, `y` yank the browser selection into the
selected register, `Y` yank the active browser URL into the selected register,
`<CR>` Enter, `<Tab>` Tab, `<S-Tab>` reverse Tab, `<BS>`
Backspace, `x` Delete, `ge` browser Escape, `A` Ctrl-A select-all, `gl` address
prompt, arrow keys, `gc` click the browser viewport at the cursor, `gd`
double-click at the cursor, `gr` right-click at the cursor, `gh` hover the
browser viewport at the cursor, `<Esc>` stop a pending load, left click to click
the browser viewport, double left click to send a native browser double-click,
right click to send a native browser right-click, scroll wheel to send a native
browser wheel event at the mouse position, and `q` close.
Disable or remap them with
`preview_keymaps = { enabled = false }` or `preview_keymaps.mappings`.

Configure search with `require("nvim-browser").setup({ search_url = "https://www.google.com/search?q=%s" })`.
The `%s` placeholder receives the encoded query; write literal percent signs as
`%%`.
Configure persistent recents, bookmarks, and completed-download history with
`require("nvim-browser").setup({ session = { persist = true, history_limit = 50, path = "/tmp/nvim-browser-session.json" } })`.
`history_limit` bounds each persisted list. Set `session.persist = false` to
keep history and bookmarks in memory only and avoid writing download history.

## License

MIT
