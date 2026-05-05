# marginalia.nvim

Terminal-native, AI-assisted code review for Neovim. Side-by-side diff, inline comments, agent handshake via `REVIEW.md`.

Named for the notes scholars wrote in the margins of manuscripts — the plugin literally adds marginalia to a diff.

**Status:** early development. Not yet usable.

## Requirements

- Neovim >= 0.9
- [diffview.nvim](https://github.com/sindrets/diffview.nvim)
- git

## Architecture

Four-layer: diff engine (diffview) → comment layer (extmarks + floating UI) → review file bridge (`REVIEW.md` serializer) → agent handshake (file watcher on `REVIEW.md`).

All diffview.nvim calls are isolated in `lua/marginalia/engine/diffview.lua`. No other module imports diffview directly.

## License

MIT. See `LICENSE`.
