# Dotfiles Repo — Claude Context

Personal macOS dotfiles for **Apple Silicon** (`/opt/homebrew`). Shell: **zsh exclusively** — bash is not supported or tested here.

## Deploy model

`setup.sh` **symlinks** each tracked dotfile into `$HOME` (with `.bak` backup of any pre-existing non-symlink file). The repo is the single source of truth — always edit the repo copy, not the file in `~`.

```sh
./setup.sh          # run from repo root; idempotent
./setup.sh --work   # work profile: also Brewfile.work + acli sign-in (or DOTFILES_PROFILE=work)
```

## File roles

| File | Purpose |
|------|---------|
| `.zshrc` | Interactive shell: Bitwarden SSH agent, Docker completions, compinit, pure prompt, sources `.aliases` |
| `.zprofile` | Login shell: brew shellenv, nvm loader, Go bin on `PATH` |
| `.aliases` | Shell aliases (`untar`, `tarup`); sourced by `.zshrc` |
| `.gitconfig` | Git identity + gh credential helpers |
| `Brewfile` | Desired-state formula/cask list; a superset (not all packages may be installed) |
| `Brewfile.work` | Work-profile-only packages, installed by `setup.sh --work`. Currently `acli` from the third-party `atlassian/acli` tap |
| `dotfiles.list` | Repo-relative paths symlinked by `setup.sh` (mod files are added automatically, see `tracked-paths.sh`); shared with `reconcile.sh` |
| `macos-defaults` | Curated watchlist of `defaults` keys (domain/key/type/value) applied by `setup.sh`; shared with `reconcile.sh` |
| `setup.sh` | Full bootstrap: Homebrew → brew bundle (+ `Brewfile.work` on `--work`) → pure → nvm → apply macOS defaults → symlink dotfiles → (work) `acli` sign-in via Atlassian API token |
| `reconcile.sh` | Reverse direction: finds Brew packages, macOS defaults, and dotfiles present on the machine but missing from the repo, and walks each one with a y/N prompt to write it back; also health-checks mod links and offers to import mods authored in a session (`~/.claude/dev-mods/`) |
| `install.sh` | Remote curl bootstrap: clones repo to `~/.dotfiles` then runs `setup.sh` |
| `.claude/settings.json` | Claude Code global settings (model, theme, `env.CLAUDE_CODE_PLUGIN_DIRS` that loads the mods) |
| `.claude/mods/<name>/` | Claude Code mods (plugin folders). Every file inside is symlinked to `~/.claude/mods/<name>/…` by `setup.sh`; no `dotfiles.list` entry needed |
| `.claude/mods/statusline/` | The status line: cwd · branch · model · ctx bar · 5h/7d limits, drawn above the prompt. Replaced the old `statusline.sh` |
| `tracked-paths.sh` | Sourced by `setup.sh` and `reconcile.sh`; defines `tracked_paths` = `dotfiles.list` entries + every file under `.claude/mods/` |
| `.claude/skills/` | Claude Code skills **vendored** from `mattpocock/skills` — the aihero.dev "main flow" plus its dependency closure. Generated, never hand-written |
| `skills.list` | Upstream-relative paths of the vendored skills; shared with `sync-skills.sh` and `setup.sh` |
| `sync-skills.sh` | Mirrors the skills in `skills.list` from upstream into `.claude/skills/`, then writes `.claude/skills/UPSTREAM.md`. Leaves changes in the working tree; never commits |
| `.github/workflows/sync-skills.yml` | Runs `sync-skills.sh` daily at 14:47 UTC and opens (or refreshes) a draft PR when upstream has moved |

## Invariants — do not break these

1. **`.gitconfig` must keep the `[credential "https://github.com"]` and `[credential "https://gist.github.com"]` helper blocks** pointing at `/opt/homebrew/bin/gh auth git-credential`. Removing them breaks `gh` auth silently.
2. **pure** lives at `~/.zsh/pure` (git clone from `sindresorhus/pure`), not installed via brew. `setup.sh` handles this.
3. **nvm** lives at `~/.nvm` (installed via the nvm install script), not via brew. `.zprofile` loads it; `setup.sh` installs it.
4. **`SSH_AUTH_SOCK`** in `.zshrc` is the Bitwarden Desktop SSH agent socket path — machine-specific, leave as-is.
5. **`env.CLAUDE_CODE_PLUGIN_DIRS`** in `.claude/settings.json` is a `:`-separated list of `~/.claude/mods/<name>` entries, one per folder in `.claude/mods/`. A mod missing from it is linked but never loaded (`reconcile.sh` flags this). Settings `env` is the only persistent loader; a project's settings are ignored for it.
6. **No `statusLine` key in `.claude/settings.json`.** The status line is the `statusline` mod; re-adding the key would draw a second one.
7. **Mod folders hold source only.** Files Claude Code lays in `.claude-plugin/types/` are generated and git-ignored; never edit them.
8. **`.claude/skills/**` is vendored — never hand-edit it.** `sync-skills.sh` deletes and re-copies each skill directory wholesale, so any local edit is silently lost on the next sync (and the daily Action will re-open a PR reverting it). To change *what* is tracked, edit `skills.list`; to change a skill's *content*, send a PR upstream to `mattpocock/skills`. The mirror is upstream **minus** each skill's `agents/openai.yaml` (Codex harness manifests, unused by Claude), so the tree differing from upstream by exactly those files is expected, not drift.
9. **`code-review` intentionally shadows Claude Code's built-in `/code-review`.** The vendored skill keeps its upstream name so `implement`'s "use `/code-review` to review the work" instruction resolves to the two-axis (Standards + Spec) reviewer the upstream docs describe. Renaming it breaks that cross-reference.
10. **`EXPECTED_CHAIN` in `sync-skills.sh` is a tripwire, not decoration.** It holds the main flow as documented upstream (`grill-with-docs → to-spec → to-tickets → implement → code-review`). If upstream stops saying it, the sync still runs but exits 3 and the PR is flagged — because the set of skills in `skills.list` was chosen to match that chain and may no longer be right.

11. **Third-party taps must be trusted in the Brewfile, per item.** Homebrew 6+ won't load an untrusted tap. Use a fully qualified `brew "owner/tap/formula", trusted: true` rather than `tap "…", trusted: true`, which would trust everything the tap ever ships. Never set `HOMEBREW_NO_REQUIRE_TAP_TRUST`.
12. **Work-only packages go in `Brewfile.work`, not `Brewfile`.** The personal profile must not pull work tooling. `reconcile.sh` treats `Brewfile.work` entries as already tracked.

## Conventions

- Add new shell aliases to `.aliases` (not inline in `.zshrc`).
- After `brew install`/`brew uninstall`, update `Brewfile` manually, or run `./reconcile.sh` to be walked through adding anything installed but untracked.
- After adding a new dotfile to the repo, add its repo-relative path to `dotfiles.list` and re-run `setup.sh`.
- To add or remove a vendored skill: edit `skills.list`, run `./sync-skills.sh` (mirrors and prunes), then `./setup.sh` (re-links). Never create a directory under `.claude/skills/` by hand.
- To pull drift from the machine back into the repo (new Brew packages, changed macOS defaults, new dotfiles worth tracking), run `./reconcile.sh`. It prompts per item and leaves changes in the working tree — review with `git diff` and commit yourself.
- Mods: `claude plugin validate .claude/mods/<name>` and `claude plugin test .claude/mods/<name>` must pass before committing. Keep logic pure in `hooks/format.ts`-style modules with a `*.test.ts`; keep `register.tsx` as thin wiring.
- Validator rule: `$` may only be passed to a function declared at the top level of the module (not a closure inside `register`).
- New mod: write it under `.claude/mods/<name>/`, add `~/.claude/mods/<name>` to `env.CLAUDE_CODE_PLUGIN_DIRS`, run `./setup.sh`, restart Claude Code. A mod authored in a session lands in `~/.claude/dev-mods/`; `./reconcile.sh` imports it and updates the env list.

## Where a new Claude Code feature goes

Decide in this order and stop at the first match.

| The feature… | Implement as | Why |
|---|---|---|
| Is glanceable, always-on information (a value, a bar, a threshold color) | **A segment in the `statusline` mod** (`format.ts` + `format.test.ts`; fed from `register.tsx`) | One status line, one place; pure formatting is unit-testable |
| Fires on a moment (limit crossed 80%, turn finished, long turn) | **Toast / sound from a mod** (`session.measure`, `turn.complete`) | A status line is state, not events |
| Blocks, rewrites or reacts to tool calls or prompts; injects system-prompt text | **Its own mod** (`tool.call`, `prompt.submit`, `prompt.compose`) | Only hooks can intercept; keep it separate from display |
| Needs interaction or a lot of room (history, a list, buttons) | **A pane in a mod** (`$.ui.open`) | The band is one row |
| Is a repeatable chore you invoke | **A slash command in a mod** (`$.command.register`) | |
| Is reusable instructions the model loads on demand | **A skill** (vendored via `skills.list`, or hand-written in `~/.claude/skills/`), not a mod | Skills are prompts; mods are code |
| Has to work without Claude Code's mod runtime (older build, `claude -p`, another terminal tool like tmux or the zsh prompt) | **A plain script in this repo** (and, only for the Claude Code footer, the native `statusLine` command) | Mods need `CLAUDE_CODE_PLUGIN_DIRS` and the engine's mod API; shell scripts need neither |

Rules of thumb:
- Do not mix concerns: the `statusline` mod only displays. Guardrails, notifications and commands are separate mods so each can be disabled by dropping one entry from `CLAUDE_CODE_PLUGIN_DIRS`.
- `$.ui.status(text)` is plain text and one-per-plugin; use it for a short transient notice from a non-display mod, not for the status line.
- Prefer the mod API's own figures (`$.session.usage()`, `$.session.model()`, `session.measure`) over shelling out; shell out (`$.process.run`) only for what the API lacks (git branch).
