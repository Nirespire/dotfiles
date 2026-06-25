# Dotfiles Repo — Claude Context

Personal macOS dotfiles for **Apple Silicon** (`/opt/homebrew`). Shell: **zsh exclusively** — bash is not supported or tested here.

## Deploy model

`setup.sh` **symlinks** each tracked dotfile into `$HOME` (with `.bak` backup of any pre-existing non-symlink file). The repo is the single source of truth — always edit the repo copy, not the file in `~`.

```sh
./setup.sh     # run from repo root; idempotent
```

## File roles

| File | Purpose |
|------|---------|
| `.zshrc` | Interactive shell: Bitwarden SSH agent, Docker completions, compinit, pure prompt, sources `.aliases` |
| `.zprofile` | Login shell: brew shellenv, nvm loader |
| `.aliases` | Shell aliases (`untar`, `tarup`); sourced by `.zshrc` |
| `.gitconfig` | Git identity + gh credential helpers |
| `Brewfile` | Desired-state formula/cask list; a superset (not all packages may be installed) |
| `setup.sh` | Full bootstrap: Homebrew → brew bundle → pure → nvm → symlink dotfiles |
| `install.sh` | Remote curl bootstrap: clones repo to `~/.dotfiles` then runs `setup.sh` |
| `.claude/settings.json` | Claude Code global settings (model, theme, statusline wiring) |
| `.claude/statusline.sh` | Claude Code custom status line script (cwd · branch · model · ctx bar · rate limits) |

## Invariants — do not break these

1. **`.gitconfig` must keep the `[credential "https://github.com"]` and `[credential "https://gist.github.com"]` helper blocks** pointing at `/opt/homebrew/bin/gh auth git-credential`. Removing them breaks `gh` auth silently.
2. **pure** lives at `~/.zsh/pure` (git clone from `sindresorhus/pure`), not installed via brew. `setup.sh` handles this.
3. **nvm** lives at `~/.nvm` (installed via the nvm install script), not via brew. `.zprofile` loads it; `setup.sh` installs it.
4. **`SSH_AUTH_SOCK`** in `.zshrc` is the Bitwarden Desktop SSH agent socket path — machine-specific, leave as-is.
5. **`statusLine.command`** in `.claude/settings.json` is the absolute path `/Users/sanjaynair/.claude/statusline.sh` — Claude Code does not guarantee `~`/`$HOME` expansion, so this must stay absolute. It is intentionally machine-specific (same rationale as `SSH_AUTH_SOCK`).

## Conventions

- Add new shell aliases to `.aliases` (not inline in `.zshrc`).
- After `brew install`/`brew uninstall`, update `Brewfile` manually or run `brew bundle dump --force` to regenerate it.
- After adding a new dotfile to the repo, add it to the `DOTFILES` array in `setup.sh` and re-run `setup.sh`.
