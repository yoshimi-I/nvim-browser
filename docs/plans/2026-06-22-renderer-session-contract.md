# Renderer Session Contract Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement issues #5 and #13 by adding a renderer-independent browser session model and renderer adapter contract to `nvbrowser-core`.

**Architecture:** `session.rs` owns browser/page/frame state that is independent from Chromium, Neovim, and terminal graphics. `renderer/mod.rs` defines the trait and request/response types renderers must implement. Terminal-specific output remains in `terminal`.

**Tech Stack:** Rust 2021, existing `serde` dependency, current workspace tests and CI.

### Task 1: Session Model

**Files:**
- Create: `crates/nvbrowser-core/src/session.rs`
- Modify: `crates/nvbrowser-core/src/lib.rs`

**Steps:**
1. Write failing tests for `BrowserSession`, `PageState`, `Viewport`, `LoadingState`, and `FrameMetadata`.
2. Run `cargo test -p nvbrowser-core session::tests`.
3. Implement minimal value types and state transitions.
4. Re-run `cargo test -p nvbrowser-core session::tests`.

### Task 2: Renderer Contract

**Files:**
- Create: `crates/nvbrowser-core/src/renderer/mod.rs`
- Modify: `crates/nvbrowser-core/src/lib.rs`

**Steps:**
1. Write failing tests for renderer request/response data and a fake renderer implementation.
2. Run `cargo test -p nvbrowser-core renderer::tests`.
3. Implement the renderer trait and shared types.
4. Re-run `cargo test -p nvbrowser-core renderer::tests`.

### Task 3: Architecture Docs

**Files:**
- Modify: `docs/architecture.md`

**Steps:**
1. Document session and renderer boundaries.
2. Document that terminal graphics are downstream of renderer frames, not part of renderer traits.
3. Run full verification.
