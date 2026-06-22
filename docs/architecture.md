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
- `renderer`: reserved for future browser renderers such as Chromium/CDP.
- `session`: reserved for future tab/page lifecycle state.

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
inside `nvbrowser-core`. It should expose a stable session API before the Lua
plugin depends on Chromium-specific details.
