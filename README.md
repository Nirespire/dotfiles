# dotfiles

Personal macOS dotfiles for Apple Silicon (`/opt/homebrew`). Zsh only.

## Quick start

**New machine (remote bootstrap):**

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Nirespire/dotfiles/master/install.sh)"
```

Clones the repo to `~/.dotfiles` and runs `setup.sh`.

**Already cloned:**

```sh
./setup.sh
```

Idempotent — safe to re-run.

## What `setup.sh` does

1. Installs [Homebrew](https://brew.sh) if missing
2. Runs `brew bundle` to install packages from `Brewfile`
3. Clones [pure](https://github.com/sindresorhus/pure) prompt to `~/.zsh/pure`
4. Installs [nvm](https://github.com/nvm-sh/nvm) to `~/.nvm`
5. Applies the macOS defaults listed in `macos-defaults` (currently: Dock auto-hide with zero-delay reveal)
6. Symlinks each dotfile listed in `dotfiles.list` from the repo into `$HOME` (backs up pre-existing files as `*.bak`)

## Reconciling machine drift back into the repo

`setup.sh` only flows one way (repo → machine). If you `brew install` something,
tweak a watched macOS default, or hand-create a config file, run:

```sh
./reconcile.sh
```

It finds Brew packages, `macos-defaults` values, and dotfiles present on the
machine but missing from the repo, and prompts per item (`y`/`N`/`skip-rest`)
before writing anything back. It never commits — review with `git diff`
afterward. Brewfile entries that exist but aren't installed here are reported
only, never removed (the Brewfile is an intentional superset across machines).

## What's included

| File | Purpose |
|------|---------|
| `.zshrc` | Interactive shell: Bitwarden SSH agent, Docker completions, pure prompt, sources `.aliases` |
| `.zprofile` | Login shell: brew shellenv, nvm loader |
| `.aliases` | Shell aliases (`untar`, `tarup`) |
| `.gitconfig` | Git identity + `gh` credential helpers |
| `Brewfile` | Desired-state formula/cask list |
| `dotfiles.list` | Repo-relative paths symlinked by `setup.sh`; shared with `reconcile.sh` |
| `macos-defaults` | Curated watchlist of `defaults` keys applied by `setup.sh`; shared with `reconcile.sh` |
| `setup.sh` | Full bootstrap script |
| `reconcile.sh` | Walks machine → repo drift (Brew, defaults, dotfiles) and writes back what you accept |
| `install.sh` | Remote curl bootstrap: clones repo then runs `setup.sh` |
| `.claude/settings.json` | Claude Code settings (model, theme, statusline) |
| `.claude/statusline.sh` | Claude Code custom status line (cwd · branch · model · context · rate limits) |

## Notes

- **Apple Silicon only** — paths assume `/opt/homebrew`.
- **Zsh only** — bash is not supported.
- The repo is the source of truth. Always edit files here, not in `~`.
- `SSH_AUTH_SOCK` in `.zshrc` and the statusline path in `.claude/settings.json` are machine-specific and intentionally not portable.
