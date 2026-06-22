# Contributing

This project is intentionally early. Keep changes small, tested, and focused on
the Neovim browser runtime goal.

## Development Rules

- Add or update tests for Rust behavior.
- Run `cargo fmt`, `cargo clippy --all-targets -- -D warnings`, and `cargo test`
  before opening a pull request.
- Keep browser engine work behind backend adapters.
- Avoid coupling Neovim UI code directly to a single renderer implementation.

## Useful Commands

```sh
cargo fmt --all -- --check
cargo clippy --all-targets -- -D warnings
cargo test
```
