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
- Markdown-to-HTML rendering
- image output through Kitty graphics protocol
- Chromium/CDP browser sessions rendered through Kitty graphics or ANSI output
- Neovim commands for opening, navigating, reloading, history, scrolling, text input, keys, selector focus, and point clicks
- persistent Neovim preview surface reuse
- current URL, title, and status reporting from the active browser session
- CLI integration tests for backend command contracts
- initial OSS packaging and CI

Planned next steps:

- terminal-multiplexer graphics passthrough support and documentation
- richer browser interaction hints for links and form controls
- image, SVG, PDF, Mermaid, and KaTeX preview through the same browser runtime

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

## Development

Build the backend:

```sh
cargo build
```

Run tests:

```sh
cargo test
```

Try the backend:

```sh
cargo run -p nvbrowser -- inspect https://example.com
cargo run -p nvbrowser -- render-md README.md
cargo run -p nvbrowser -- show-image path/to/image.png
cargo run -p nvbrowser -- browse https://example.com
```

The `browse` command requires Chrome or Chromium. Set `NVBROWSER_CHROME` when
auto-detection cannot find the browser binary.

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
:NBrowserBack
:NBrowserForward
:NBrowserScrollDown 400
:NBrowserFocusSelector input[name="q"]
:NBrowserInput hello
:NBrowserKey Enter
:NBrowserClick 120 240
:NBrowserClickHere
:NBrowserHints
:NBrowserClickHint 1
:NBrowserCurrentUrl
:NBrowserCurrentTitle
:NBrowserStatus
:NBrowserToggle
```

`:NBrowserClickHere` maps the preview cursor to browser viewport pixels. It is
available for ANSI and Kitty Unicode browser previews.

## License

MIT
