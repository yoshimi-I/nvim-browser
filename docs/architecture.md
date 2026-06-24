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

The Kitty terminal module provides escape builders for one-shot image transfer
as well as stable image IDs, placement IDs, placement dimensions, and deletion.
Persistent preview code should use those primitives to replace frames instead
of creating unrelated terminal output streams.

Ghostty is the primary target terminal today. In normal panes it supports the
Kitty graphics protocol, but multiplexers can block or degrade image transport.
The Neovim browser path therefore prefers Kitty Unicode placeholders when
available and falls back to ANSI rendering in known-problem environments. A
browser frame replacement should be self-contained: clear the previous stable
image ID or placement, then emit the new frame with the same placement geometry.
That keeps redraw ordering inside a single backend response instead of relying
on unrelated Lua-side cleanup.

## Neovim Boundaries

- `config.lua`: user options and defaults.
- `backend.lua`: converts plugin actions into backend commands.
- `terminal.lua`: owns persistent split and terminal-buffer behavior.
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

The default browser preview path uses a single full-frame Chromium PNG per
capture and presents it as one Kitty Unicode virtual placement. The Neovim
buffer is filled with terminal-cell placeholders so the preview remains
cursor-addressable. Literal Kitty output (`--output kitty`) can split large
browser frames into stable row-major image tiles. Tile payloads clear the full
stable tile ID range before reusing IDs so frame replacement is deterministic
when a large capture is followed by a smaller one.

The persistent `serve` protocol is JSONL over stdin/stdout. Protocol version 18
includes lightweight `page_state` requests for idle metadata refresh,
multi-download reporting through a `downloads` array while preserving the
single `download` compatibility field, and auto-handled JavaScript dialog
reporting through `dialog`/`dialogs`. The same protocol also covers
screenshot, click, right-click, hover, wheel, focus, form, text, key, reader,
selection, find, and hint actions. Most browser actions default to returning a
fresh frame payload after applying the action. Text input and key press requests
also accept `capture = false`; that quiet path applies the CDP input and
settles browser state without returning a frame. Neovim uses quiet requests
inside browser text mode to avoid per-key screenshot recapture, then requests
an explicit capture when text mode exits. Quiet and page-state responses should
not clear preview metadata, page metrics, or hint overlays unless they report
an error. When an idle page-state response reports meaningful visible changes,
Neovim debounces one follow-up `capture` instead of increasing the steady-state
screenshot cadence.

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
- `Renderer`: trait for navigate, render frame, scroll, find text, point
  click/right-click/hover/wheel input, hinted click/right-click/focus/
  selection/toggle, reload, and shutdown.
