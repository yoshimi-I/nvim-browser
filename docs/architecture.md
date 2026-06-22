# Architecture

`nvim-browser` is split into a Neovim UI layer and a Rust runtime layer.

## Repository Layout

```text
crates/
  nvbrowser-core/    Browser runtime library and renderer-independent logic.
  nvbrowser-cli/     Thin command-line adapter used by the Neovim plugin.
lua/nvim-browser/   Neovim UI, command registration, backend invocation.
plugin/             Plugin entrypoint loaded by Neovim.
doc/                Vim help documentation.
```

## Rust Boundaries

- `target`: classifies URLs, files, and search queries.
- `markdown`: turns Markdown into browser-renderable HTML.
- `terminal`: terminal graphics protocol support.
- `session`: renderer-independent browser/page/frame lifecycle state.
- `renderer`: renderer trait and request/response contract for browser actions.

The CLI crate should stay thin. It parses arguments, calls `nvbrowser-core`,
and writes stdout/stderr. Browser behavior belongs in `nvbrowser-core`.

## Neovim Boundaries

- `config.lua`: user options and defaults.
- `backend.lua`: converts plugin actions into backend commands.
- `terminal.lua`: owns split and terminal-buffer behavior.
- `commands.lua`: registers user-facing Ex commands.
- `init.lua`: public Lua API and state coordination.

## Renderer Direction

The first full browser renderer should be implemented as a Chromium/CDP adapter
inside `nvbrowser-core`. Chromium/CDP types must stay behind that adapter.
Public code should speak in terms of sessions, pages, viewports, renderer
requests, and rendered frames.

The renderer contract intentionally does not mention terminal graphics. A
renderer returns frame artifacts and metadata. A later presentation layer can
turn those artifacts into Kitty graphics, text buffers, tiled screenshots, or
other terminal output.

Image preview should also follow this contract. Direct image handling can be a
renderer adapter that accepts a file target, produces a `RenderedFrame` with a
PNG artifact, and leaves sizing or Kitty placement to the presentation layer.
This keeps Markdown, image, Chromium/CDP, and future renderers behind the same
browser pipeline.

Current renderer-independent concepts:

- `BrowserSession`: one browser runtime session with an active page.
- `PageState`: current URL, loading state, viewport, and last frame metadata.
- `Viewport`: pixel dimensions plus device scale factor.
- `FrameMetadata`: frame ID, page ID, URL, viewport, and capture timestamp.
- `Renderer`: trait for navigate, render frame, scroll, reload, and shutdown.
