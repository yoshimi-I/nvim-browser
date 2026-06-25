# Domain Notes

This document records project-specific domain knowledge that should guide future
implementation work.

## Product Direction

`nvim-browser` is an OSS Neovim browser plugin. The target experience is a
practical browser preview inside Neovim, close to the casty-style model:
Headless Chrome renders real pages, CDP drives browser actions, and terminal
graphics display full-page frames without leaving the editor.

Markdown, HTML/SVG, raster image preview, reader mode, and browser sessions are
supporting features. Markdown preview includes Mermaid fenced diagrams and KaTeX
math rendering. These features should reinforce the primary goal: a browser that
can be opened, viewed, navigated, clicked, searched, and typed into from Neovim.

## Architecture Principles

- Keep Neovim UI behavior in Lua and browser/runtime behavior in Rust.
- Keep `nvbrowser-cli` thin; shared browser behavior belongs in
  `nvbrowser-core`.
- Keep Chromium/CDP details behind the renderer adapter boundary.
- Keep terminal graphics out of renderer contracts. Renderers produce artifacts
  and metadata; presentation code turns those into Kitty, ANSI, or future output
  formats.
- Keep Neovim-derived viewport sizing and reader-buffer link resolution in Lua;
  Rust should receive already bounded cells/viewport pixels and concrete
  navigation targets.
- Keep Chromium target adoption, popup recovery, and closed-target heuristics in
  the Rust Chromium renderer, where CDP lifecycle state is observable.
- Prefer small, tested protocol extensions over broad rewrites when improving
  interaction latency.

## Terminal Graphics Constraints

- Ghostty is the primary target terminal.
- Kitty graphics and Kitty Unicode placeholders are the preferred high-fidelity
  display path outside problematic multiplexers.
- Zellij currently blocks the desired Kitty graphics path in practice, so
  `graphics = "auto"` intentionally falls back to ANSI when `ZELLIJ` is set.
  The ANSI fallback is treated as a real browser path, not a dead-end degraded
  mode: Lua backend tests cover the `ZELLIJ=1` auto command resolution, opt-in
  Chromium E2E covers rendering, hints, text input, clicks, and page text on the
  ANSI browser surface, and Doctor reports that the fallback stays
  cursor-addressable.
- tmux gets escape passthrough wrapping and is detected explicitly; users still
  need passthrough-capable tmux configuration for high-fidelity graphics.
  Doctor probes `tmux show -gqv allow-passthrough` and reports `ok` for `on`
  or `all`; other values warn with the required `set -g allow-passthrough on`.
  Standalone image CLI output is wrapped in Rust, while browser `browse` and
  `serve` payloads stay raw and are wrapped exactly once by Lua at terminal
  egress when they run through the plugin.
- Unknown terminals should use ANSI in auto mode rather than assuming Kitty
  support.
- ANSI output is a compatibility fallback, not the end-state browser quality.
- Kitty Unicode output is limited by the placeholder address space. Lua must cap
  both startup command geometry and live preview geometry before passing
  `--columns`, `--rows`, `--width`, or `--height` to Rust.

## Neovim Interaction Principles

- Neovim owns the preview buffer, split/window lifecycle, keymaps, footer,
  buffer names, hint overlays, and request lifecycle.
- Browser previews should stay cursor-addressable where possible. ANSI and Kitty
  Unicode previews support cursor-to-viewport clicks, double-clicks,
  right-clicks, cursor-local `<select>` option selection, cursor-local
  checkbox/radio toggles, hint overlays, and jumping the Neovim cursor to a
  hinted element before running cursor-local browser actions. Cursor-local DOM
  inspection should use the same
  rendered-frame geometry as cursor-local input, so yanking a link under the
  preview cursor and clicking that cursor position refer to the same browser
  point.
- The action picker should expose common cursor-addressable browser input
  directly so users can discover click, double-click, right-click, hover,
  select-at-cursor, toggle-at-cursor, and type-at-cursor without memorizing
  separate commands.
- Cursor-local URL follow is intentionally href navigation, not a browser click.
  It should inspect the link under the preview cursor and open that href in the
  same preview, including target-blank links, without relying on page click
  handlers or popup adoption.
- The bottom preview row is reserved for status. Clicks, double-clicks, and
  right-clicks in the footer must not be converted into browser viewport
  coordinates.
- Point interactions must target the same rendered browser frame the user can
  see. If the active preview geometry no longer matches the last rendered frame,
  Neovim should refresh instead of sending click, double-click, hover, type,
  wheel, or drag coordinates to Chromium.
- Rendered frame geometry is the contract behind cursor-addressable browser
  input. Smoke and state diagnostics should expose both viewport pixels and
  runtime-reported frame cells so resize, Kitty Unicode cell caps, and CDP
  coordinate mapping can be debugged before trusting click or text-mode
  workflows.
- Chromium hint `x`/`y` values are viewport center coordinates, not top-left
  corners. Any hint-to-preview-cell conversion should map those center
  coordinates directly through the rendered frame geometry. Computed preview
  cells are one-based, but `nvim_win_set_cursor` takes a zero-based column.
- Hint cursor jumping is local Neovim cursor movement only. It must not dispatch
  Chromium/CDP input or capture a fresh frame by itself.
- `:NBrowserSmoke` should prove the browser surface is usable from Neovim, not
  only that Chromium loaded a page. The smoke fixture should require fresh
  input hints with viewport geometry, place the preview cursor over the input
  hint, send a cursor click, then submit through smart cursor activation.
  Focused element metadata is useful diagnostics when observed, but should not
  be the sole success gate for the smoke interaction because real capture timing
  can make focus metadata transient. Smoke reports should distinguish hint
  discovery, cursor placement, point click dispatch, smart activation, and any
  hint-backed fallback. Both the Zellij ANSI fallback profile and direct Kitty
  Unicode profile should keep exercising this interaction contract.
- Smart cursor activation should be diagnosable during real use. Unsupported
  plain text, protocol-old generic input metadata, missing viewport coordinates,
  and rejected backend actions should warn with a concrete reason rather than
  making `ga` appear inert.
- On editable fields, smart cursor activation should focus the browser point and
  enter `:NBrowserTextMode` by default. One-shot cursor-local typing remains
  available through `:NBrowserTypeHere`, `:NBrowserSubmitHere`, `gI`, and `gS`.
- Kitty Unicode terminal graphics diagnostics should keep raw payload bytes and
  terminal egress bytes separate. Multiplexer wrapping belongs at egress time, so
  replay can re-wrap the stored raw payload for the active transport. Egress
  reason values distinguish fresh frames from focus, focus replay, and toggle
  reopen recovery.
- `:NBrowserTextMode` is the default path for form typing from a focused browser
  preview. It should feel closer to browser input than a command prompt.
- Interaction latency matters. Text mode printable/editing input should avoid
  per-key screenshot recapture and update the preview at meaningful boundaries.

## Current POC Capabilities

- Opens URLs, Markdown files, HTML/SVG/PDF files, and raster images. PDF files
  use Chrome's built-in file viewer through the Chromium/CDP browser session
  path; Markdown and raster image files use generated Chromium preview wrappers
  that can be navigated inside an existing browser session.
- Mermaid Markdown diagrams and KaTeX Markdown math use pinned `cdn.jsdelivr.net`
  assets and therefore require network access only when a Markdown file contains
  a Mermaid fence or inline/display math.
- Runs persistent Chromium/CDP browser sessions over a JSONL `serve` protocol.
- Supports navigation, reload, stop, back/forward, browser-like preview scroll
  motions, repeatable find next/previous, focused input, key presses, selector
  focus, point clicks, native CDP double-clicks, native CDP right-clicks for
  page `contextmenu` handlers, CDP mouse-move hovers, native CDP mouse-wheel
  input at preview coordinates, native CDP drag selection and region yanking
  from preview-cell regions, hints,
  hinted focus for search/input workflows, hinted preview-cursor jumps, hinted
  right-clicks, hinted `<select>` option selection with Neovim pickers when
  option metadata is available, cursor-local `<select>` option selection by
  preview point, hinted `<input type="file">` uploads through CDP
  `DOM.setFileInputFiles`, hinted and cursor-local checkbox/radio toggles,
  smart cursor activation that dispatches links/forms/buttons from live point
  metadata, direct href following, current URL, hinted link URL, live DOM point inspection
  at the preview cursor, link URL yanking from the preview cursor, and
  whole-page text snapshot yanking, focused-element metadata, and
  submit-current-focus form UX.
- Page text is a Chromium/CDP snapshot surface, not a scrape of the terminal
  preview or reader buffer. Whole-page text yank should keep using the
  `page_text` request, validate writable one-character Neovim registers, and
  preserve existing register contents on empty, failed, or stale responses.
- Auto-handles JavaScript dialogs with a safe non-interactive policy: alerts are
  accepted, confirm/prompt/beforeunload dialogs are dismissed, and handled
  dialog metadata is surfaced to Neovim.
- Browser hint discovery walks the top document, open shadow roots, and
  same-origin iframe documents with top-viewport coordinate translation for
  hinted click/right-click/hover actions. Closed shadow roots and cross-origin
  iframe DOMs are outside the POC scope.
- Shows live browser state in a preview footer: status, title/URL, scroll
  progress, focused element kind/label, latest handled JavaScript dialog,
  latest completed download filename, non-default zoom, output mode, cells,
  viewport, and errors.
- Saves browser-initiated downloads into a configured `download_dir`, reports
  the latest completed file path in the JSONL response plus footer/status,
  keeps an indexed persisted-session list for `:NBrowserDownloads`, and can
  reopen completed downloads through the normal browser open path.
- Performs lightweight live page-state refresh while idle and suppresses
  background refresh while a navigation-like operation is pending. Manual
  `:NBrowserRefresh` and browser actions still capture fresh frames. Meaningful
  idle metadata or DOM mutation epoch changes debounce one full-frame capture so
  the preview image catches up without returning to constant screenshots.
- Guards pending navigation-like operations and explicit frame captures with a
  Neovim-side watchdog based on `navigation_timeout_ms`. `:NBrowserStop` first
  asks Chromium/CDP to stop loading while keeping the serve session alive; if
  Chromium/CDP stalls or rejects that request, Lua hard-stops the serve job,
  advances the generation so late stdout is quarantined, leaves `timeout | ...`
  or `stopped | ...` footer metadata, and can restart from the stopped target
  through refresh, reload, or address navigation.
- Extracts a reader buffer from the current browser page and resolves reader
  links against the snapshot page URL, including dot-segment normalization for
  relative `http(s)` and `file` links while preserving meaningful path content.
- Hover interactions are first-class browser input, not DOM-only simulation:
  `hover_point`, `hover_here`, and `hover_hint` move the Chromium mouse cursor
  so CSS `:hover` and hover menus can change the next captured frame.
- Preview scroll-wheel interactions should prefer native CDP `mouseWheel`
  events at the mouse position over page-level JavaScript scrolling. That keeps
  nested scroll regions, dropdowns, editors, maps, and similar browser-owned
  hit-testing behavior aligned with a real browser.

## Current Risks

- Multiplexer support is the largest portability risk. Zellij degrades to ANSI;
  tmux passthrough can now be diagnosed, but still needs real terminal/session
  validation.
- Click accuracy depends on configured terminal cell pixel dimensions.
  `:NBrowserCalibrate` now opens a fixed hit-test fixture and Doctor can report
  observed click/right-click/hover/type/wheel fixture state. Calibrated cell
  pixels persist under Neovim state and Doctor reports whether active values
  came from defaults, explicit config, persisted calibration, or the last guided
  calibration sample. `:NBrowserCalibrateHere` reduces first-run guesswork by
  computing cell pixels from the cursor position on the fixture guide point.
- Quiet input and idle live refresh improve latency by skipping screenshots and
  hint recomputation, but successful lightweight responses still return
  URL/title, page-metrics, focused-element metadata, and a Chromium-backed DOM
  mutation epoch when available. The current frame and hints remain visible
  until Enter, exit, manual refresh, or an adaptive/live captured response
  refreshes them. When that DOM epoch advances without a captured frame, old
  hints must stay visible only as stale context; hint-driven actions should not
  send old backend hint IDs until a fresh captured frame refreshes hints. A
  stale hint action should request the appropriate recovery refresh itself:
  resize for preview-geometry staleness first, then capture for DOM-epoch
  staleness. This applies to hint click, right-click, hover, focus, follow,
  type, select, upload, toggle, and hinted URL lookup paths. Repeated stale
  actions should coalesce with any matching resize debounce, adaptive capture,
  or in-flight capture instead of flooding the backend.
- Chromium target lifecycle is a core reliability area. `target=_blank`,
  `window.open`, and delayed `about:blank` navigations should stay covered by
  opt-in E2E because real pages commonly create and navigate child targets
  asynchronously.
- Native mouse popup recovery belongs to click and right-click input alike: a
  closed current target after point or hinted mouse dispatch should open a short
  suppression window so the real child target can be adopted instead of leaking
  a stale preview.
- Interaction settling favors correctness over the fastest possible capture:
  Chromium responses wait for DOM quiet plus multiple stable complete
  URL/title samples before screenshotting, with a bounded latest-sample fallback
  when pages stay unstable.
- Hint clicks on `a[target=_blank][href]` should follow the direct `href` in the
  current preview. Native popup-opening pointer events can close the old CDP
  target before adoption, so direct href navigation is the stable single-preview
  behavior. Lua uses Chromium-provided hint `target` metadata for this path.
  This intentionally skips page pointer/click handlers for that link class; keep
  separate `window.open` and delayed `about:blank` E2E coverage for real child
  target adoption.
- File uploads must validate local paths before invoking CDP. Real Chromium E2E
  should cover file inputs because DOM-only JS cannot set true local upload
  files.
- Downloads are intentionally a completed-report POC surface: multiple
  downloads completed during one interaction can be surfaced in the JSONL
  response and appended to a bounded completed-download list that persists with
  the normal Neovim session state when enabled, but there is no progress UI,
  cancellation, retry, or filename prompt yet.
- Long-running Chromium lifecycle remains an operational risk. Lua now covers
  stuck pending-operation and explicit-capture timeouts with hard-stop and
  late-response quarantine tests; CDP-side lifecycle and target-adoption changes
  should still stay covered by focused Rust and opt-in real Chromium tests.
- Changes to the CDP renderer, JSONL `serve` protocol, frame payloads, hints,
  page text, or resize behavior should run the opt-in real Chromium E2E test
  with `NVBROWSER_E2E=1` in addition to the fake-renderer unit suite.
- Geometry and reader-link changes should have Lua overlay tests; CDP lifecycle
  changes should have focused Rust unit coverage for the heuristic plus opt-in
  real Chromium E2E for adoption behavior.
