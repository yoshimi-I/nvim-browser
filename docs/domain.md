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
- tmux gets escape passthrough wrapping, but tmux behavior still needs explicit
  validation and documentation before it should be treated as a first-class
  high-fidelity target.
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
- Supports navigation, reload, stop, back/forward, scroll, find, focused input,
  key presses, selector focus, point clicks, hints, and direct href following.
- Shows live browser state in a preview footer: status, title/URL, scroll
  progress, output mode, cells, viewport, and errors.
- Performs live recapture while idle and suppresses background recapture while a
  navigation-like operation is pending.
- Extracts a reader buffer from the current browser page and resolves reader
  links against the page URL.

## Current Risks

- Multiplexer support is the largest portability risk. Zellij degrades to ANSI;
  tmux passthrough needs real validation.
- Click accuracy depends on configured terminal cell pixel dimensions. Doctor
  output and future auto-detection should reduce this burden.
- Quiet input improves text latency but means metadata, hints, and screenshots
  can lag until Enter, exit, or a later capture.
- Long-running Chromium lifecycle, stuck navigation cancellation, and late
  response handling remain operational risk areas and should stay covered by
  tests.
- Changes to the CDP renderer, JSONL `serve` protocol, frame payloads, hints,
  page text, or resize behavior should run the opt-in real Chromium E2E test
  with `NVBROWSER_E2E=1` in addition to the fake-renderer unit suite.
