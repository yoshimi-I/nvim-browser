# Neovim Browser MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the first OSS skeleton for a Neovim-native browser runtime that can open web URLs, local Markdown, and image files inside Ghostty/Neovim.

**Architecture:** The project is a monorepo with a Rust backend binary (`nvbrowser`) and a Lua Neovim plugin. The backend owns target classification, Markdown-to-HTML conversion, browser session state, and future Chromium/CDP rendering. The Lua plugin exposes commands and delegates rendering to the backend through a terminal-backed preview surface.

**Tech Stack:** Rust 2021, `clap`, `serde`, `comrak`, `mime_guess`, Neovim Lua, GitHub Actions.

### Task 1: Rust core target classification

**Files:**
- Create: `crates/nvbrowser/src/lib.rs`
- Modify: `crates/nvbrowser/src/main.rs`
- Test: `crates/nvbrowser/src/lib.rs`

**Step 1:** Write tests for URL, Markdown file, image file, and HTML file classification.

**Step 2:** Run `cargo test -p nvbrowser target_kind` and confirm the tests fail because production code is missing.

**Step 3:** Implement the minimal classifier.

**Step 4:** Re-run `cargo test -p nvbrowser target_kind`.

### Task 2: Markdown rendering

**Files:**
- Modify: `crates/nvbrowser/src/lib.rs`
- Test: `crates/nvbrowser/src/lib.rs`

**Step 1:** Write a test proving Markdown is wrapped in a complete HTML document.

**Step 2:** Run the test and confirm it fails.

**Step 3:** Implement Markdown rendering with `comrak`.

**Step 4:** Re-run cargo tests.

### Task 3: CLI contract

**Files:**
- Modify: `crates/nvbrowser/src/main.rs`
- Test: Rust unit tests for command payloads.

**Step 1:** Write tests for JSON output shape.

**Step 2:** Implement `nvbrowser inspect <target>` returning JSON.

**Step 3:** Add `nvbrowser render-md <path>` returning HTML.

### Task 4: Neovim plugin shell

**Files:**
- Create: `lua/nvim-browser/init.lua`
- Create: `plugin/nvim-browser.lua`
- Create: `doc/nvim-browser.txt`

**Step 1:** Add commands `:NBrowserOpen`, `:NBrowserPreview`, and `:NBrowserInspect`.

**Step 2:** Implement terminal-backed command execution.

**Step 3:** Document setup and command behavior.

### Task 5: OSS packaging

**Files:**
- Create: `README.md`
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `.github/workflows/ci.yml`
- Create: `CONTRIBUTING.md`

**Step 1:** Document project scope and architecture.

**Step 2:** Add MIT license.

**Step 3:** Add CI running `cargo fmt`, `cargo clippy`, and `cargo test`.

### Task 6: Publish

**Files:**
- Local git repository.

**Step 1:** Run all verification commands.

**Step 2:** Commit the initial project.

**Step 3:** If `gh` is authenticated, create `yoshimi/nvim-browser` and push `main`.
