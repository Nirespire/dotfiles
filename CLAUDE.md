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
| `.claude/skills/` | Claude Code skills **vendored** from `mattpocock/skills` — the aihero.dev "main flow" plus its dependency closure. Generated, never hand-written |
| `skills.list` | Upstream-relative paths of the vendored skills; shared with `sync-skills.sh` and `setup.sh` |
| `sync-skills.sh` | Mirrors the skills in `skills.list` from upstream into `.claude/skills/`, then writes `.claude/skills/UPSTREAM.md`. Leaves changes in the working tree; never commits |
| `.github/workflows/sync-skills.yml` | Runs `sync-skills.sh` daily at 14:47 UTC and opens (or refreshes) a draft PR when upstream has moved |

## Invariants — do not break these

1. **`.gitconfig` must keep the `[credential "https://github.com"]` and `[credential "https://gist.github.com"]` helper blocks** pointing at `/opt/homebrew/bin/gh auth git-credential`. Removing them breaks `gh` auth silently.
2. **pure** lives at `~/.zsh/pure` (git clone from `sindresorhus/pure`), not installed via brew. `setup.sh` handles this.
3. **nvm** lives at `~/.nvm` (installed via the nvm install script), not via brew. `.zprofile` loads it; `setup.sh` installs it.
4. **`SSH_AUTH_SOCK`** in `.zshrc` is the Bitwarden Desktop SSH agent socket path — machine-specific, leave as-is.
5. **`statusLine.command`** in `.claude/settings.json` is the absolute path `/Users/sanjaynair/.claude/statusline.sh` — Claude Code does not guarantee `~`/`$HOME` expansion, so this must stay absolute. It is intentionally machine-specific (same rationale as `SSH_AUTH_SOCK`).
6. **`.claude/skills/**` is vendored — never hand-edit it.** `sync-skills.sh` deletes and re-copies each skill directory wholesale, so any local edit is silently lost on the next sync (and the daily Action will re-open a PR reverting it). To change *what* is tracked, edit `skills.list`; to change a skill's *content*, send a PR upstream to `mattpocock/skills`.
7. **`code-review` intentionally shadows Claude Code's built-in `/code-review`.** The vendored skill keeps its upstream name so `implement`'s "use `/code-review` to review the work" instruction resolves to the two-axis (Standards + Spec) reviewer the upstream docs describe. Renaming it breaks that cross-reference.
8. **`EXPECTED_CHAIN` in `sync-skills.sh` is a tripwire, not decoration.** It holds the main flow as documented upstream (`grill-with-docs → to-spec → to-tickets → implement → code-review`). If upstream stops saying it, the sync still runs but exits 3 and the PR is flagged — because the set of skills in `skills.list` was chosen to match that chain and may no longer be right.

## Conventions

- Add new shell aliases to `.aliases` (not inline in `.zshrc`).
- After `brew install`/`brew uninstall`, update `Brewfile` manually, or run `./reconcile.sh` to be walked through adding anything installed but untracked.
- After adding a new dotfile to the repo, add its repo-relative path to `dotfiles.list` and re-run `setup.sh`.
- To add or remove a vendored skill: edit `skills.list`, run `./sync-skills.sh` (mirrors and prunes), then `./setup.sh` (re-links). Never create a directory under `.claude/skills/` by hand.
- To pull drift from the machine back into the repo (new Brew packages, changed macOS defaults, new dotfiles worth tracking), run `./reconcile.sh`. It prompts per item and leaves changes in the working tree — review with `git diff` and commit yourself.
