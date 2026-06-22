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
- Neovim commands for opening and inspecting targets
- initial OSS packaging and CI

Planned next steps:

- Chromium/CDP renderer backend
- Kitty graphics protocol output for Ghostty
- tile-based page screenshots inside a Neovim preview split
- scroll/input bridge from Neovim to the browser session
- image, SVG, PDF, Mermaid, and KaTeX preview through the same browser runtime

## Architecture

```text
Ghostty
└─ Neovim
   ├─ Lua plugin
   │  ├─ :NBrowserOpen
   │  ├─ :NBrowserPreview
   │  └─ :NBrowserInspect
   └─ Rust backend
      ├─ target/session model
      ├─ Markdown and file renderers
      ├─ future Chromium/CDP adapter
      └─ future Kitty graphics output
```

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
```

Try the plugin from this checkout:

```sh
nvim --cmd 'set rtp+=.'
```

Then run:

```vim
:NBrowserInspect https://example.com
:NBrowserPreview
```

## License

MIT
