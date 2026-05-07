# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

marginalia.nvim — a Neovim plugin for terminal-native, AI-assisted code review. Adds margin notes (comments) to diffs inside Neovim, bridging human reviewers and AI agents via a REVIEW.md file.

**Status:** Early stage. Layer 1 (Diff Engine) and Layer 2 (Comment Layer) are implemented. Pending manual testing.

## Commands

- **Run all tests:** `make test`
- **Unit tests only:** `make test-unit` (comments + extmarks)
- **UI tests:** `make test-ui`
- **Keymap tests:** `make test-keymaps`
- **Integration tests:** `make test-integration` (requires git, spawns child Neovim)
- **Manual testing:** open Neovim in a git repo with diffview.nvim installed, then run `:Review` / `:ReviewClose`.

## Commits

Semantic commits: `type(scope): description`

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
Scopes: `engine`, `comment`, `bridge`, `agent` (matching the four layers), or omit for cross-cutting changes.

## Architecture

Four planned layers, only the first is implemented:

1. **Diff Engine** (`lua/marginalia/engine/`) — abstraction over diff viewers. Currently only `diffview.lua` adapter exists.
2. **Comment Layer** (`lua/marginalia/comments.lua`, `lua/marginalia/ui.lua`) — extmarks + floating UI for margin notes. After-side only (keymaps bound on "b" buffers).
3. **Review File Bridge** — serializes comments to/from `REVIEW.md` (planned).
4. **Agent Handshake** — file watcher letting AI agents read/write `REVIEW.md` (planned).

### Key constraints

- **Import discipline:** Only files inside `lua/marginalia/engine/` may import diffview.nvim. All other modules interact through the engine's public API. This allows swapping engines (e.g., native `:diffthis`) without cascading changes.
- **Neovim >= 0.9** required.
- **Runtime dependency:** `diffview.nvim` (loaded via pcall for graceful degradation).

### Entry points

- `plugin/marginalia.lua` — registers `:Review` and `:ReviewClose` user commands.
- `lua/marginalia/init.lua` — public API: `setup(opts)`, `open(source)`, `close()`. Wires keymaps on after-side diff buffers via `on_buffer_ready`.
- `lua/marginalia/engine/diffview.lua` — engine adapter exposing: `open`, `close`, `get_buffer_pair`, `current_file`, `side_of`, `on_buffer_ready`, `on_close`, `is_active`.
- `lua/marginalia/comments.lua` — comment data store (add/get/update/delete) + extmark placement/refresh/snapshot.
- `lua/marginalia/ui.lua` — floating windows: `open_input` (vim-native `:w`/`ZZ` to submit, `q`/`:q!` to cancel) and `open_view` (read-only viewer).
