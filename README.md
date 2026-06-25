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
5. Symlinks each dotfile from the repo into `$HOME` (backs up pre-existing files as `*.bak`)

## What's included

| File | Purpose |
|------|---------|
| `.zshrc` | Interactive shell: Bitwarden SSH agent, Docker completions, pure prompt, sources `.aliases` |
| `.zprofile` | Login shell: brew shellenv, nvm loader |
| `.aliases` | Shell aliases (`untar`, `tarup`) |
| `.gitconfig` | Git identity + `gh` credential helpers |
| `Brewfile` | Desired-state formula/cask list |
| `setup.sh` | Full bootstrap script |
| `install.sh` | Remote curl bootstrap: clones repo then runs `setup.sh` |
| `.claude/settings.json` | Claude Code settings (model, theme, statusline) |
| `.claude/statusline.sh` | Claude Code custom status line (cwd · branch · model · context · rate limits) |

## Notes

- **Apple Silicon only** — paths assume `/opt/homebrew`.
- **Zsh only** — bash is not supported.
- The repo is the source of truth. Always edit files here, not in `~`.
- `SSH_AUTH_SOCK` in `.zshrc` and the statusline path in `.claude/settings.json` are machine-specific and intentionally not portable.
