# Sourced by setup.sh and reconcile.sh. Defines tracked_paths: every
# repo-relative path that gets symlinked into $HOME.
#
#   1. each entry of dotfiles.list
#   2. every file inside a Claude Code mod folder, .claude/mods/<name>/...
#      (files the engine generates inside a mod are not source; skipped)

tracked_paths() {
  local dir="$1" file

  while read -r file; do
    [[ -z "$file" || "$file" == \#* ]] && continue
    printf '%s\n' "$file"
  done < "$dir/dotfiles.list"

  if [ -d "$dir/.claude/mods" ]; then
    (cd "$dir" && find .claude/mods -type f \
      -not -path '*/.claude-plugin/types/*' \
      -not -path '*/node_modules/*' \
      -not -name '.DS_Store' | sort)
  fi
}
