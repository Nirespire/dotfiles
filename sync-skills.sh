#!/usr/bin/env bash
set -euo pipefail

# Mirror the skills listed in skills.list from the upstream repo into
# .claude/skills/. Writes changes to the working tree and never commits —
# same contract as reconcile.sh. Review with `git diff` afterward.
#
# Exit codes:
#   0  synced cleanly
#   1  a path in skills.list no longer exists upstream, or the clone failed
#   3  synced, but the documented main flow no longer matches EXPECTED_CHAIN

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_LIST="$DOTFILES_DIR/skills.list"
SKILLS_DIR="$DOTFILES_DIR/.claude/skills"
MANIFEST="$SKILLS_DIR/UPSTREAM.md"

UPSTREAM_REPO="https://github.com/mattpocock/skills"
UPSTREAM_REF="main"

# The chain documented at https://www.aihero.dev/ and repeated verbatim across
# the upstream docs/ tree. If upstream stops saying this, the set of skills we
# vendor is no longer "the main flow" and a human needs to re-pick it.
EXPECTED_CHAIN="grill-with-docs → to-spec → to-tickets → implement → code-review"

echo "==> Syncing skills into $SKILLS_DIR"

if [ ! -f "$SKILLS_LIST" ]; then
  echo "==> ERROR: $SKILLS_LIST not found"
  exit 1
fi

# ── 1. Read skills.list ──────────────────────────────────────────────────────
WANTED=()
while read -r path; do
  [[ -z "$path" || "$path" == \#* ]] && continue
  WANTED+=("$path")
done < "$SKILLS_LIST"

if [ ${#WANTED[@]} -eq 0 ]; then
  echo "==> ERROR: no skills listed in $SKILLS_LIST"
  exit 1
fi
echo "==> ${#WANTED[@]} skills listed"

# ── 2. Clone upstream ────────────────────────────────────────────────────────
UPSTREAM_DIR="$(mktemp -d)"
trap 'rm -rf "$UPSTREAM_DIR"' EXIT

echo "==> Cloning $UPSTREAM_REPO ($UPSTREAM_REF)"
if ! git clone --quiet --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" "$UPSTREAM_DIR"; then
  echo "==> ERROR: clone failed"
  exit 1
fi

UPSTREAM_SHA="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
UPSTREAM_SHORT="$(git -C "$UPSTREAM_DIR" rev-parse --short HEAD)"
UPSTREAM_DATE="$(git -C "$UPSTREAM_DIR" log -1 --format=%cs)"
UPSTREAM_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$UPSTREAM_DIR/.claude-plugin/plugin.json" | head -1)"
[ -z "$UPSTREAM_VERSION" ] && UPSTREAM_VERSION="unknown"
echo "==> Upstream at $UPSTREAM_SHORT (v$UPSTREAM_VERSION, $UPSTREAM_DATE)"

# ── 3. Verify every listed path still exists upstream ────────────────────────
MISSING=()
for path in "${WANTED[@]}"; do
  if [ ! -f "$UPSTREAM_DIR/$path/SKILL.md" ]; then
    MISSING+=("$path")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "==> ERROR: ${#MISSING[@]} path(s) in skills.list no longer exist upstream:"
  for path in "${MISSING[@]}"; do
    echo "      $path"
  done
  echo "==> Upstream renamed or removed these. Update skills.list, then re-run."
  exit 1
fi

# ── 4. Check the documented main flow still reads as we expect ───────────────
chain_ok=true
if ! grep -rqF "$EXPECTED_CHAIN" "$UPSTREAM_DIR/docs" 2>/dev/null; then
  chain_ok=false
  echo "==> WARNING: upstream docs no longer state the expected main flow:"
  echo "      $EXPECTED_CHAIN"
  echo "==> Syncing content anyway; the vendored skill set needs a human re-check."
fi

# ── 5. Mirror each listed skill ──────────────────────────────────────────────
mkdir -p "$SKILLS_DIR"

KEEP=()
for path in "${WANTED[@]}"; do
  name="$(basename "$path")"
  KEEP+=("$name")
  # rm first so upstream file deletions and renames propagate
  rm -rf "${SKILLS_DIR:?}/$name"
  cp -R "$UPSTREAM_DIR/$path" "$SKILLS_DIR/$name"
  echo "==> Vendored $path -> .claude/skills/$name"
done

# ── 6. Prune skills no longer listed ─────────────────────────────────────────
for dir in "$SKILLS_DIR"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  keep=false
  for wanted in "${KEEP[@]}"; do
    [ "$name" = "$wanted" ] && keep=true && break
  done
  if [ "$keep" = false ]; then
    echo "==> Pruning .claude/skills/$name (no longer in skills.list)"
    rm -rf "$dir"
  fi
done

# ── 7. Write the provenance manifest ─────────────────────────────────────────
{
  echo "# Vendored skills — do not edit by hand"
  echo ""
  echo "Mirrored from <$UPSTREAM_REPO> by \`sync-skills.sh\`. Every file under"
  echo "\`.claude/skills/\` is overwritten on the next sync, so edits here are lost."
  echo "To track or untrack a skill, change \`skills.list\` and re-run \`./sync-skills.sh\`."
  echo ""
  echo "| | |"
  echo "|---|---|"
  echo "| Upstream | [\`mattpocock/skills\`]($UPSTREAM_REPO) |"
  echo "| Ref | \`$UPSTREAM_REF\` |"
  echo "| Commit | [\`$UPSTREAM_SHORT\`]($UPSTREAM_REPO/commit/$UPSTREAM_SHA) |"
  echo "| Plugin version | \`$UPSTREAM_VERSION\` |"
  echo "| Upstream commit date | $UPSTREAM_DATE |"
  echo "| Main flow | $EXPECTED_CHAIN |"
  if [ "$chain_ok" = false ]; then
    echo ""
    echo "> **⚠️ The upstream docs no longer state that main flow.** The vendored set"
    echo "> below was chosen to match it, so it may now be wrong. Re-check against"
    echo "> <https://www.aihero.dev/> and update \`skills.list\`."
  fi
  echo ""
  echo "## Vendored skills"
  echo ""
  echo "| Skill | Upstream path |"
  echo "|---|---|"
  for path in "${WANTED[@]}"; do
    echo "| \`$(basename "$path")\` | \`$path\` |"
  done
} > "$MANIFEST"

echo ""
if [ "$chain_ok" = false ]; then
  echo "✓ Synced $UPSTREAM_SHORT, but the documented main flow has moved."
  echo "  Review with: git -C \"$DOTFILES_DIR\" diff"
  exit 3
fi
echo "✓ Synced ${#WANTED[@]} skills at $UPSTREAM_SHORT."
echo "  Review with: git -C \"$DOTFILES_DIR\" diff"
