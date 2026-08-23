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
7. Symlinks each Claude Code skill listed in `skills.list` into `~/.claude/skills/` (one symlink per skill, so hand-written skills already there keep working)

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
| `.claude/skills/` | Vendored Claude Code skills — generated, never hand-edited |
| `skills.list` | Upstream paths of the vendored skills; shared with `sync-skills.sh` and `setup.sh` |
| `sync-skills.sh` | Mirrors the vendored skills from upstream; leaves changes in the working tree |
| `.github/workflows/sync-skills.yml` | Daily job that runs the sync and opens a draft PR when upstream moves |
| `.claude/settings.json` | Claude Code settings (model, theme, statusline) |
| `.claude/statusline.sh` | Claude Code custom status line (cwd · branch · model · context · rate limits) |

## Notes

- **Apple Silicon only** — paths assume `/opt/homebrew`.
- **Zsh only** — bash is not supported.
- The repo is the source of truth. Always edit files here, not in `~`.
- `SSH_AUTH_SOCK` in `.zshrc` and the statusline path in `.claude/settings.json` are machine-specific and intentionally not portable.

## Claude Code skills

`.claude/skills/` vendors [Matt Pocock's skills](https://github.com/mattpocock/skills)
— specifically the **main flow** documented at [aihero.dev](https://www.aihero.dev/):

```
grill-with-docs → to-spec → to-tickets → implement → code-review
```

Four more skills come along because the flow calls them by name: `grill-with-docs`
is a seven-line skill whose whole body invokes `grilling` and `domain-modeling`,
`implement` defers to `/tdd`, and `to-spec`/`to-tickets`/`code-review` all point at
`/setup-matt-pocock-skills` for per-repo tracker config. Vendoring the five steps
alone would leave those references dangling.

Note that `code-review` deliberately shadows Claude Code's own built-in
`/code-review`, so that `implement`'s cross-reference resolves to the two-axis
reviewer the upstream docs describe.

Upstream ships an `agents/openai.yaml` beside each skill — a Codex harness
manifest encoding the same metadata Claude reads from `SKILL.md` frontmatter.
Those are excluded, since nothing here drives Codex. A useful side effect: an
upstream commit touching only those files produces no diff, so the daily job
opens no PR for it.

**These files are generated.** `sync-skills.sh` deletes and re-copies each skill
directory from upstream, so hand-edits are lost on the next sync. Change
`skills.list` to track a different set:

```sh
./sync-skills.sh   # mirror upstream into .claude/skills/, then review with git diff
./setup.sh         # re-link into ~/.claude/skills/
```

`.claude/skills/UPSTREAM.md` records which upstream commit is currently pinned.

### Staying current

`.github/workflows/sync-skills.yml` runs the sync **daily at 14:47 UTC** and opens
a draft PR whenever upstream content has changed, updating the same PR in place
rather than stacking new ones.

The schedule is measured, not arbitrary: upstream ships roughly 2.3 relevant
changes a week, clustered in 08:00–14:00 UTC, with no commits ever landing on a
Sunday or between 22:00 and 06:00 UTC. Firing just after that daily window closes
gives ~6h average staleness, against ~55h for the best possible weekly slot.

The workflow also asserts that upstream still documents the main flow above. If
that chain changes, the sync still runs but the PR is flagged — the vendored set
was picked to match it and would need re-choosing.
