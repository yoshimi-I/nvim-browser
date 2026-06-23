# nvim-browser

`nvim-browser` is an experimental browser runtime for Neovim.

The goal is to keep browsing, Markdown preview, and image preview inside the
terminal/Neovim workflow instead of jumping to an external browser tab. The
first target terminal is Ghostty, using terminal graphics as the future display
surface.

## Status

This repository is an early MVP scaffold. Today it includes:

- Rust backend binary: `nvbrowser`
- target classification for URLs, Markdown, HTML, and images
- styled Markdown-to-HTML rendering with local asset base paths
- local HTML file previews through the Chromium/CDP browser session path
- image output through Kitty graphics protocol with fit modes
- Chromium/CDP browser sessions rendered through Kitty graphics or ANSI output
- Ghostty-oriented browser previews use full-frame Kitty Unicode image placement
  with cursor-addressable placeholder cells
- large literal Kitty browser frames are split into stable image tiles to keep
  oversized transfers replaceable inside the preview surface
- Neovim commands for opening, navigating, reloading, stopping pending loads, history, scrolling, finding text, text input, keys, selector focus, point clicks, point hovers, and hinted element actions
- browser element hints overlaid on cursor-addressable previews
- persistent Neovim preview surface reuse
- current URL, title, scroll progress, status, runtime diagnostics, preview footer, live recapture, and preview buffer naming from the active browser session
- CLI integration tests for backend command contracts
- initial OSS packaging and CI

Planned next steps:

- terminal-multiplexer graphics passthrough support and documentation
- richer browser interaction for links and form controls
- PDF, Mermaid, KaTeX, and richer image preview through the same browser runtime

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
      image_fit = "contain",
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
environment. Ghostty, Kitty, and WezTerm use `kitty-unicode` for browser frames
and `kitty` for raster images. Zellij falls back to ANSI because Kitty graphics
passthrough is unreliable there. tmux keeps Kitty output and relies on tmux
passthrough wrapping. Unknown terminals use ANSI as the safe fallback. Override
with `graphics = "ansi"`, `"kitty"`, or `"kitty-unicode"` when needed.

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

Active browser previews recapture the page every 1500ms by default so async
page updates and SPA state changes appear in Neovim without manual refresh.
Disable it or tune the interval with:

```lua
require("nvim-browser").setup({
  live_refresh = {
    enabled = false,
    interval_ms = 2500,
  },
})
```

Release tags use `vMAJOR.MINOR.PATCH`; replace `v0.1.3` with the latest release
tag when installing. Until `v1.0.0`, plugin and backend compatibility is
guaranteed only within the same tag or commit; pin the Neovim plugin and
`nvbrowser` binary together.

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
```

The `browse` and `capture` commands require Chrome or Chromium. Set
`NVBROWSER_CHROME` when auto-detection cannot find the browser binary.
Alternatively, set `NVBROWSER_CDP_WS_URL` or pass `--cdp-ws-url` to attach to an
existing browser websocket endpoint. Chrome exposes that URL from
`http://127.0.0.1:9222/json/version` when started with
`--remote-debugging-port=9222`.
Use `NVBROWSER_USER_DATA_DIR` or `--user-data-dir` to opt in to a persistent
Chromium profile directory for launched browser sessions.
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
:NBrowserBack
:NBrowserForward
:NBrowserScrollDown 400
:NBrowserPageDown
:NBrowserPageUp
:NBrowserFind search text
:NBrowserFindNext
:NBrowserFindPrevious
:NBrowserFocusSelector input[name="q"]
:NBrowserInput hello
:NBrowserInputMode
:NBrowserTextMode
:NBrowserPaste +
:NBrowserYankSelection +
:NBrowserKey Enter
:NBrowserKey A ctrl
:NBrowserClick 120 240
:NBrowserClickHere
:NBrowserHoverHere
:NBrowserHints
:NBrowserClickHint 1
:NBrowserHoverHint 1
:NBrowserFocusHint s
:NBrowserFollowHint a
:NBrowserTypeHint s hello world
:NBrowserSubmitHint s hello world
:NBrowserSelectHint s Canada
:NBrowserToggleHint c
:NBrowserTypeHere hello world
:NBrowserSubmitHere hello world
:NBrowserTypeHintMode
:NBrowserSubmitHintMode
:NBrowserSelectHintMode
:NBrowserFocusHintMode
:NBrowserToggleHintMode
:NBrowserHintMode
:NBrowserCurrentUrl
:NBrowserCurrentTitle
:NBrowserStatus
:NBrowserReader
:NBrowserReaderFollow
:NBrowserDoctor
:NBrowserToggle
```

Markdown files are rendered with a docs-oriented browser shell and a local
`<base>` path so relative images can resolve from the Markdown file directory.
HTML and SVG files are opened through Chromium using `file://` URLs.
Raster image previews support `original`, `contain`, `width`, and `height` fit modes.
Configure Neovim's default with
`require("nvim-browser").setup({ image_fit = "contain" })`.

`:NBrowserClickHere` maps the preview cursor to browser viewport pixels. It is
available for ANSI and Kitty Unicode browser previews. Active browser previews
reserve the bottom preview row for a compact status footer, so cursor clicks in
that footer are not sent to the browser page.
`:NBrowserHoverHere` sends a real Chromium mouse-move event to the browser
viewport point under the preview cursor. Use it to reveal CSS `:hover` menus or
tooltips without leaving Neovim. Preview scroll-wheel events are also sent as
native Chromium mouse-wheel input at the mouse position when the preview is
cursor-addressable, then fall back to page-level scrolling if coordinates are
not available.

Browser preview footers show the latest serve status, title or URL, scroll
progress, focused element kind/label, output mode, cell geometry, and current
URL when reported by the Chromium/CDP session. `:NBrowserStatus` echoes the
same browser-session state in the command line. Focus metadata is reported as
`focus=input Search`, `focus=text_area Notes`, and similar compact labels after
captured browser interactions.

While a browser session is idle, nvim-browser periodically sends a lightweight
capture request to keep the preview current. It does not send background
captures while a navigation-like operation is pending, and it stops the timer
when the browser preview is stopped, closed, or replaced.

Navigation-like operations show immediate `loading | ... | Esc stop` feedback
in the preview footer before Chromium returns a frame. Run `:NBrowserStop`, or
press `<Esc>` in the focused preview buffer, to cancel the pending operation and
terminate a stuck serve job.

`:NBrowserHints` echoes the latest keyboard labels and numbered browser
elements, including link destinations when available. On ANSI and Kitty Unicode
browser previews, the same labels are also overlaid on the preview.
`:NBrowserClickHint {id-or-label}` clicks the backend hint id without relying
on viewport coordinates. `:NBrowserHoverHint {id-or-label}` moves to the
matching element coordinates.
`:NBrowserFollowHint {label}` uses a link hint's `href` directly when
available, which avoids coordinate-click drift and keeps the active browser
session on the navigated URL; non-link hints fall back to backend hint clicks.
`:NBrowserPickHint [follow|click|focus|hover|toggle]` opens a `vim.ui.select`
picker for the current hints and runs the selected action, defaulting to
`follow`.
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
`:NBrowserToggleHint {id-or-label}` toggles a hinted checkbox or selects a
hinted radio input. Checkbox/radio hints show `[checked]` or `[unchecked]` in
`:NBrowserHints`.
`:NBrowserTypeHere {text}` maps the preview cursor to browser viewport pixels,
clicks/focuses that point, and types text there. `:NBrowserSubmitHere {text}`
does the same and presses Enter after the text is queued. These commands require
an ANSI or Kitty Unicode browser preview and ignore the preview footer row.

`:NBrowserTypeHintMode` prompts for a hint label and text, then types into the
hinted element. `:NBrowserSubmitHintMode` does the same and presses Enter after
the text is queued. `:NBrowserSelectHintMode` prompts for a hint label and
option choice. `:NBrowserFocusHintMode` prompts for a hint label and focuses
the matching element. `:NBrowserToggleHintMode` prompts for a checkbox/radio
hint label. Lua mappings can call `require("nvim-browser").hint_mode()`,
`require("nvim-browser").pick_hint({ action = "focus" })`,
`require("nvim-browser").type_hint_mode(nil, { submit = true })`, or
`require("nvim-browser").select_hint_mode()` /
`require("nvim-browser").focus_hint_mode()` /
`require("nvim-browser").toggle_hint_mode()`.
`:NBrowserAddress [url-or-search]` works like a small omnibox; host-like input
opens as a URL, and plain words use the configured search URL. With no
argument, the prompt is prefilled with the current URL when available, falling
back to the last target. Lua mappings can call `require("nvim-browser").address()`
or pass a value directly with `require("nvim-browser").address("example.com")`.

`:NBrowserFind {text}` finds text in the active browser page, scrolls to the
match through the browser's native find behavior, and captures a fresh frame.
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
`:NBrowserTextMode` enters an interactive browser text mode for the focused
preview: printable keys are sent as text, `<CR>`, `<Tab>`, `<S-Tab>`, `<BS>`,
Delete, and arrow keys are forwarded as browser keys, and `<Esc>` exits the text
mode locally. Printable input and editing keys use a low-latency path that skips
per-key screenshot recapture; exiting text mode triggers one fresh capture.
Enter still requests an immediate captured response because it often submits or
navigates. Focused preview buffers map `i` to this text mode by default after
clicking a field or focusing one with hints. Outside text mode, preview buffers
also forward common browser keys: `<CR>`, `<Tab>`, `<S-Tab>`, `<BS>`, `x`
Delete, `ge` Escape, `A` Ctrl-A select-all, `gl` Meta-L focus location, and
arrow keys. `:NBrowserKey {key} [modifier ...]` accepts modifier names such as
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
address, `<leader>b/` find, `<leader>bf` hint mode, `<leader>bt` type into a
hinted field, `<leader>bs` type and submit, and `<leader>bo` select a hinted
option, and `<leader>bc` toggle a hinted checkbox/radio. Existing mappings are left
untouched; choose another prefix or mapping key if one is already in use.

Focused preview buffers also install buffer-local browser controls by default:
`r` reload, `H` back, `L` forward, `j`/`k` scroll, `<PageDown>/<PageUp>` scroll
by 90% of the browser viewport, `gg` top, `G` bottom, `<C-d>/<C-u>` scroll by
half the browser viewport, `a` address, `/` find, `n` repeat find forward, `N`
repeat find backward, `f` hint mode, `t` type into a hinted field, `s` type and
submit, `o` select a hinted option, `c` toggle a hinted checkbox/radio, `i`
type into the focused element with browser text mode, `p` paste the selected
register into the focused element, `y` yank the browser selection into the
selected register, `<CR>` Enter, `<Tab>` Tab, `<S-Tab>` reverse Tab, `<BS>`
Backspace, `x` Delete, `ge` browser Escape, `A` Ctrl-A select-all, `gl` Meta-L
focus location, arrow keys, `gc` click the browser viewport at the cursor, `gh`
hover the browser viewport at the cursor, `<Esc>` stop a pending load, left
click to click the browser viewport, scroll wheel to send a native browser
wheel event at the mouse position, and `q` close.
Disable or remap them with
`preview_keymaps = { enabled = false }` or `preview_keymaps.mappings`.

Configure search with `require("nvim-browser").setup({ search_url = "https://www.google.com/search?q=%s" })`.
The `%s` placeholder receives the encoded query; write literal percent signs as
`%%`.

## License

MIT
