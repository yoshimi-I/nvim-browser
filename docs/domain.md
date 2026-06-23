# Domain Notes

This document records project-specific domain knowledge that should guide future
implementation work.

## Product Direction

`nvim-browser` is an OSS Neovim browser plugin. The target experience is a
practical browser preview inside Neovim, close to the casty-style model:
Headless Chrome renders real pages, CDP drives browser actions, and terminal
graphics display full-page frames without leaving the editor.

Markdown, HTML/SVG, raster image preview, reader mode, and browser sessions are
supporting features. They should reinforce the primary goal: a browser that can
be opened, viewed, navigated, clicked, searched, and typed into from Neovim.

## Architecture Principles

- Keep Neovim UI behavior in Lua and browser/runtime behavior in Rust.
- Keep `nvbrowser-cli` thin; shared browser behavior belongs in
  `nvbrowser-core`.
- Keep Chromium/CDP details behind the renderer adapter boundary.
- Keep terminal graphics out of renderer contracts. Renderers produce artifacts
  and metadata; presentation code turns those into Kitty, ANSI, or future output
  formats.
- Prefer small, tested protocol extensions over broad rewrites when improving
  interaction latency.

## Terminal Graphics Constraints

- Ghostty is the primary target terminal.
- Kitty graphics and Kitty Unicode placeholders are the preferred high-fidelity
  display path outside problematic multiplexers.
- Zellij currently blocks the desired Kitty graphics path in practice, so
  `graphics = "auto"` intentionally falls back to ANSI when `ZELLIJ` is set.
- tmux gets escape passthrough wrapping and is detected explicitly; users still
  need passthrough-capable tmux configuration for high-fidelity graphics.
- Unknown terminals should use ANSI in auto mode rather than assuming Kitty
  support.
- ANSI output is a compatibility fallback, not the end-state browser quality.

## Neovim Interaction Principles

- Neovim owns the preview buffer, split/window lifecycle, keymaps, footer,
  buffer names, hint overlays, and request lifecycle.
- Browser previews should stay cursor-addressable where possible. ANSI and Kitty
  Unicode previews support cursor-to-viewport clicks and hint overlays.
- The bottom preview row is reserved for status. Clicks in the footer must not
  be converted into browser viewport coordinates.
- `:NBrowserTextMode` is the default path for form typing from a focused browser
  preview. It should feel closer to browser input than a command prompt.
- Interaction latency matters. Text mode printable/editing input should avoid
  per-key screenshot recapture and update the preview at meaningful boundaries.

## Current POC Capabilities

- Opens URLs, Markdown files, HTML/SVG files, and raster images.
- Runs persistent Chromium/CDP browser sessions over a JSONL `serve` protocol.
- Supports navigation, reload, stop, back/forward, browser-like preview scroll
  motions, repeatable find next/previous, focused input, key presses, selector
  focus, point clicks, CDP mouse-move hovers, native CDP mouse-wheel input at
  preview coordinates, hints, hinted focus for search/input workflows, hinted
  `<select>` option selection, hinted checkbox/radio toggles, direct href
  following, focused-element metadata, and submit-current-focus form UX.
- Shows live browser state in a preview footer: status, title/URL, scroll
  progress, focused element kind/label, output mode, cells, viewport, and
  errors.
- Performs live recapture while idle and suppresses background recapture while a
  navigation-like operation is pending.
- Extracts a reader buffer from the current browser page and resolves reader
  links against the page URL.
- Hover interactions are first-class browser input, not DOM-only simulation:
  `hover_point`, `hover_here`, and `hover_hint` move the Chromium mouse cursor
  so CSS `:hover` and hover menus can change the next captured frame.
- Preview scroll-wheel interactions should prefer native CDP `mouseWheel`
  events at the mouse position over page-level JavaScript scrolling. That keeps
  nested scroll regions, dropdowns, editors, maps, and similar browser-owned
  hit-testing behavior aligned with a real browser.

## Current Risks

- Multiplexer support is the largest portability risk. Zellij degrades to ANSI;
  tmux passthrough needs real validation.
- Click accuracy depends on configured terminal cell pixel dimensions. Doctor
  output and future auto-detection should reduce this burden.
- Quiet input improves text latency by skipping screenshots and hint
  recomputation, but successful quiet responses still return lightweight
  URL/title, page-metrics, and focused-element metadata. The current frame and
  hints remain visible until Enter, exit, or a later captured response refreshes
  them.
- Chromium target lifecycle is a core reliability area. `target=_blank`,
  `window.open`, and delayed `about:blank` navigations should stay covered by
  opt-in E2E because real pages commonly create and navigate child targets
  asynchronously.
- Hint clicks on `a[target=_blank][href]` should follow the direct `href` in the
  current preview. Native popup-opening pointer events can close the old CDP
  target before adoption, so direct href navigation is the stable single-preview
  behavior. This intentionally skips page pointer/click handlers for that link
  class; keep separate `window.open` and delayed `about:blank` E2E coverage for
  real child target adoption.
- Long-running Chromium lifecycle, stuck navigation cancellation, and late
  response handling remain operational risk areas and should stay covered by
  tests.
- Changes to the CDP renderer, JSONL `serve` protocol, frame payloads, hints,
  page text, or resize behavior should run the opt-in real Chromium E2E test
  with `NVBROWSER_E2E=1` in addition to the fake-renderer unit suite.
