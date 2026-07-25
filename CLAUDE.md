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
| `dotfiles.list` | List of repo-relative paths symlinked by `setup.sh`; shared with `reconcile.sh` |
| `macos-defaults` | Curated watchlist of `defaults` keys (domain/key/type/value) applied by `setup.sh`; shared with `reconcile.sh` |
| `setup.sh` | Full bootstrap: Homebrew → brew bundle → pure → nvm → apply macOS defaults → symlink dotfiles |
| `reconcile.sh` | Reverse direction: finds Brew packages, macOS defaults, and dotfiles present on the machine but missing from the repo, and walks each one with a y/N prompt to write it back |
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
- After `brew install`/`brew uninstall`, update `Brewfile` manually, or run `./reconcile.sh` to be walked through adding anything installed but untracked.
- After adding a new dotfile to the repo, add its repo-relative path to `dotfiles.list` and re-run `setup.sh`.
- To pull drift from the machine back into the repo (new Brew packages, changed macOS defaults, new dotfiles worth tracking), run `./reconcile.sh`. It prompts per item and leaves changes in the working tree — review with `git diff` and commit yourself.
