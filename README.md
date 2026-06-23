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
- Neovim commands for opening, navigating, reloading, history, scrolling, finding text, text input, keys, selector focus, point clicks, and hinted element clicks
- browser element hints overlaid on cursor-addressable previews
- persistent Neovim preview surface reuse
- current URL, title, scroll progress, status, and preview buffer naming from the active browser session
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

To attach to an already-running Chrome DevTools Protocol browser instead of
letting `nvbrowser` launch Chrome, pass the browser WebSocket URL:

```lua
require("nvim-browser").setup({
  cdp_ws_url = "ws://127.0.0.1:9222/devtools/browser/<id>",
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
:NBrowserNavigate https://example.org
:NBrowserAddress
:NBrowserBack
:NBrowserForward
:NBrowserScrollDown 400
:NBrowserFind search text
:NBrowserFocusSelector input[name="q"]
:NBrowserInput hello
:NBrowserKey Enter
:NBrowserClick 120 240
:NBrowserClickHere
:NBrowserHints
:NBrowserClickHint 1
:NBrowserFollowHint a
:NBrowserTypeHint s hello world
:NBrowserSubmitHint s hello world
:NBrowserHintMode
:NBrowserCurrentUrl
:NBrowserCurrentTitle
:NBrowserStatus
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
available for ANSI and Kitty Unicode browser previews.

`:NBrowserHints` echoes the latest keyboard labels and numbered browser
elements, including link destinations when available. On ANSI and Kitty Unicode
browser previews, the same labels are also overlaid on the preview.
`:NBrowserClickHint {id-or-label}` and
`:NBrowserFollowHint {label}` click the matching element. `:NBrowserHintMode`
prompts for a label and follows it.
`:NBrowserTypeHint {id-or-label} {text}` clicks a hinted element and types text
into it. `:NBrowserSubmitHint {id-or-label} {text}` also presses Enter after the
text is queued.

Lua mappings can call `require("nvim-browser").hint_mode()` for the same prompt.
`:NBrowserAddress` prompts for a URL or search query; host-like input opens as a
URL, and plain words use the configured search URL. Lua mappings can call
`require("nvim-browser").address()`.

`:NBrowserFind {text}` finds text in the active browser page, scrolls to the
match through the browser's native find behavior, and captures a fresh frame.

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
address, `<leader>b/` find, and `<leader>bf` hint mode. Existing mappings are
left untouched; choose another prefix or mapping key if one is already in use.

Configure search with `require("nvim-browser").setup({ search_url = "https://www.google.com/search?q=%s" })`.
The `%s` placeholder receives the encoded query; write literal percent signs as
`%%`.

## License

MIT
