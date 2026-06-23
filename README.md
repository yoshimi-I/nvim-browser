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
- Neovim commands for opening, navigating, reloading, stopping pending loads, history, scrolling, finding text, text input, keys, selector focus, point clicks, and hinted element clicks
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

With `graphics = "auto"`, browser and raster image previews use Kitty graphics
outside terminal multiplexers and fall back to ANSI output when `ZELLIJ` is
detected.

To attach to an already-running Chrome DevTools Protocol browser instead of
letting `nvbrowser` launch Chrome, pass the browser WebSocket URL:

```lua
require("nvim-browser").setup({
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/<id>",
})
```

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
:NBrowserFind search text
:NBrowserFocusSelector input[name="q"]
:NBrowserInput hello
:NBrowserInputMode
:NBrowserKey Enter
:NBrowserKey A ctrl
:NBrowserClick 120 240
:NBrowserClickHere
:NBrowserHints
:NBrowserClickHint 1
:NBrowserFollowHint a
:NBrowserTypeHint s hello world
:NBrowserSubmitHint s hello world
:NBrowserTypeHintMode
:NBrowserSubmitHintMode
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

Browser preview footers show the latest serve status, title or URL, scroll
progress, output mode, cell geometry, and current URL when reported by the
Chromium/CDP session. `:NBrowserStatus` echoes the same browser-session state in
the command line.

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
`:NBrowserClickHint {id-or-label}` and
`:NBrowserFollowHint {label}` act on the matching element. Follow uses a link
hint's `href` directly when available, which avoids coordinate-click drift and
keeps the active browser session on the navigated URL; non-link hints fall back
to a coordinate click. `:NBrowserHintMode` prompts for a label and follows it.
`:NBrowserTypeHint {id-or-label} {text}` clicks a hinted element and types text
into it. `:NBrowserSubmitHint {id-or-label} {text}` also presses Enter after the
text is queued.

`:NBrowserTypeHintMode` prompts for a hint label and text, then types into the
hinted element. `:NBrowserSubmitHintMode` does the same and presses Enter after
the text is queued. Lua mappings can call `require("nvim-browser").hint_mode()`
or `require("nvim-browser").type_hint_mode(nil, { submit = true })`.
`:NBrowserAddress [url-or-search]` works like a small omnibox; host-like input
opens as a URL, and plain words use the configured search URL. With no
argument, the prompt is prefilled with the current URL when available, falling
back to the last target. Lua mappings can call `require("nvim-browser").address()`
or pass a value directly with `require("nvim-browser").address("example.com")`.

`:NBrowserFind {text}` finds text in the active browser page, scrolls to the
match through the browser's native find behavior, and captures a fresh frame.

`:NBrowserInput {text}` types text into the currently focused browser element.
`:NBrowserInputMode` prompts once for text and sends it to the focused element,
which is useful after clicking a field or focusing one with hints. Focused
preview buffers also forward common browser keys: `<CR>`, `<Tab>`, `<S-Tab>`,
`<BS>`, `x` Delete, `ge` Escape, `A` Ctrl-A select-all, `gl` Meta-L focus
location, and arrow keys. `:NBrowserKey {key} [modifier ...]` accepts modifier
names such as `ctrl`, `shift`, `alt`, and `meta`.

`:NBrowserReader` captures the current browser page as Markdown-like text in a
normal scratch buffer so page content can be selected, searched, and yanked
without leaving Neovim. Links are preserved as Markdown links where possible;
press `<CR>` or `gf` on a reader link, or run `:NBrowserReaderFollow`, to
navigate the active browser session to that URL.

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
hinted field, and `<leader>bs` type and submit. Existing mappings are left
untouched; choose another prefix or mapping key if one is already in use.

Focused preview buffers also install buffer-local browser controls by default:
`r` reload, `H` back, `L` forward, `j`/`k` scroll, `a` address, `/` find, `f`
hint mode, `t` type into a hinted field, `s` type and submit, `i` type into the
focused element, `<CR>` Enter, `<Tab>` Tab, `<S-Tab>` reverse Tab, `<BS>`
Backspace, `x` Delete, `ge` browser Escape, `A` Ctrl-A select-all, `gl` Meta-L
focus location, arrow keys, `<Esc>` stop a pending load, left click to click
the browser viewport, scroll wheel to scroll the page, and `q` close.
Disable or remap them with
`preview_keymaps = { enabled = false }` or `preview_keymaps.mappings`.

Configure search with `require("nvim-browser").setup({ search_url = "https://www.google.com/search?q=%s" })`.
The `%s` placeholder receives the encoded query; write literal percent signs as
`%%`.

## License

MIT
