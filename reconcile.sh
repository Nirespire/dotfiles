#!/usr/bin/env bash
# Reconcile the local machine's config *back* into this dotfiles repo.
#
# setup.sh is one-directional (repo -> system). Over time the machine drifts
# ahead of the repo: a `brew install`, a tweaked macOS default, a new config
# file. This script finds that drift and, for each item, asks whether to pull
# it into the repo. It never commits — review with `git diff` afterward.
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BREWFILE="$DOTFILES_DIR/Brewfile"
MACOS_DEFAULTS="$DOTFILES_DIR/macos-defaults"
DOTFILES_LIST="$DOTFILES_DIR/dotfiles.list"

[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

brews_added=0
casks_added=0
defaults_updated=0
dotfiles_imported=0

# ── helpers ────────────────────────────────────────────────────────────────

# y/N/skip-rest prompt. Returns 0 for yes, 1 otherwise. Setting the section's
# *_skip_rest variable to true short-circuits remaining prompts in that section.
prompt_yn() {
  local msg="$1" ans
  read -r -p "$msg [y/N/skip-rest] " ans
  case "$ans" in
    [Yy]*) return 0 ;;
    [Ss]*) return 2 ;;  # skip-rest sentinel
    *) return 1 ;;
  esac
}

array_contains() {
  local needle="$1"; shift
  local item
  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

echo "==> Reconciling $DOTFILES_DIR against this machine"

# ── 1. Brew packages ─────────────────────────────────────────────────────────
echo ""
echo "── Brew packages ──"

if ! command -v brew &>/dev/null; then
  echo "  brew not found; skipping"
else
  installed_onrequest=()
  while read -r name; do
    [ -n "$name" ] && installed_onrequest+=("$name")
  done < <(brew leaves --installed-on-request 2>/dev/null)

  installed_formulae_all=()
  while read -r name; do
    [ -n "$name" ] && installed_formulae_all+=("$name")
  done < <(brew list --formula 2>/dev/null)

  installed_casks=()
  while read -r name; do
    [ -n "$name" ] && installed_casks+=("$name")
  done < <(brew list --cask 2>/dev/null)

  existing_brews=()
  while read -r name; do
    [ -n "$name" ] && existing_brews+=("$name")
  done < <(grep -oE '^brew "[^"]+"' "$BREWFILE" 2>/dev/null | sed -E 's/^brew "(.+)"$/\1/')

  existing_casks=()
  while read -r name; do
    [ -n "$name" ] && existing_casks+=("$name")
  done < <(grep -oE '^cask "[^"]+"' "$BREWFILE" 2>/dev/null | sed -E 's/^cask "(.+)"$/\1/')

  brewfile_add() {
    # $1 = brew|cask, $2 = name
    local kind="$1" name="$2" content lineno tmp
    content="${kind} \"${name}\""
    lineno=$(grep -nE "^${kind} \"" "$BREWFILE" | tail -1 | cut -d: -f1)
    tmp="$BREWFILE.tmp"
    if [ -n "$lineno" ]; then
      awk -v n="$lineno" -v c="$content" '{print} NR==n{print c}' "$BREWFILE" > "$tmp" && mv "$tmp" "$BREWFILE"
    else
      printf '%s\n' "$content" >> "$BREWFILE"
    fi
  }

  skip_rest=false
  for name in "${installed_onrequest[@]}"; do
    array_contains "$name" "${existing_brews[@]}" && continue
    if [ "$skip_rest" = true ]; then continue; fi
    prompt_yn "Add formula '$name' to Brewfile?"; rc=$?
    if [ $rc -eq 0 ]; then
      brewfile_add brew "$name"
      existing_brews+=("$name")
      brews_added=$((brews_added + 1))
      echo "  + added brew \"$name\""
    elif [ $rc -eq 2 ]; then
      skip_rest=true
    fi
  done

  skip_rest=false
  for name in "${installed_casks[@]}"; do
    array_contains "$name" "${existing_casks[@]}" && continue
    if [ "$skip_rest" = true ]; then continue; fi
    prompt_yn "Add cask '$name' to Brewfile?"; rc=$?
    if [ $rc -eq 0 ]; then
      brewfile_add cask "$name"
      existing_casks+=("$name")
      casks_added=$((casks_added + 1))
      echo "  + added cask \"$name\""
    elif [ $rc -eq 2 ]; then
      skip_rest=true
    fi
  done

  # Report-only: Brewfile is an intentional superset across machines, so
  # entries not installed here are informational, never removed.
  for name in "${existing_brews[@]}"; do
    array_contains "$name" "${installed_formulae_all[@]}" || echo "  i in Brewfile, not installed here: brew \"$name\""
  done
  for name in "${existing_casks[@]}"; do
    array_contains "$name" "${installed_casks[@]}" || echo "  i in Brewfile, not installed here: cask \"$name\""
  done
fi

# ── 2. macOS defaults (curated watchlist) ────────────────────────────────────
echo ""
echo "── macOS defaults ──"

update_macos_defaults_value() {
  # $1 = domain, $2 = key, $3 = new value
  local domain="$1" key="$2" newvalue="$3" tmp="$MACOS_DEFAULTS.tmp"
  awk -v d="$domain" -v k="$key" -v v="$newvalue" '
    /^#/ || NF==0 { print; next }
    $1==d && $2==k { printf "%s\t%s\t%s\t%s\n", $1,$2,$3,v; next }
    { print }
  ' "$MACOS_DEFAULTS" > "$tmp" && mv "$tmp" "$MACOS_DEFAULTS"
}

normalize_bool() {
  case "$1" in
    1|true|TRUE|yes|YES) echo "true" ;;
    0|false|FALSE|no|NO) echo "false" ;;
    *) echo "$1" ;;
  esac
}

default_lines=()
while read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  default_lines+=("$line")
done < "$MACOS_DEFAULTS"

skip_rest=false
for line in "${default_lines[@]}"; do
  # Use a here-string so this read doesn't touch the script's real stdin —
  # prompt_yn below needs stdin free to read the user's actual answer.
  read -r domain key type value <<< "$line"

  current=$(defaults read "$domain" "$key" 2>/dev/null)
  if [ -z "$current" ]; then
    echo "  i $domain $key not set on this system; skipping"
    continue
  fi

  cmp_current="$current"
  cmp_stored="$value"
  if [ "$type" = "bool" ]; then
    cmp_current=$(normalize_bool "$current")
    cmp_stored=$(normalize_bool "$value")
  fi

  if [ "$cmp_current" = "$cmp_stored" ]; then
    continue
  fi

  if [ "$skip_rest" = true ]; then continue; fi
  prompt_yn "$domain $key differs (system=$current repo=$value). Update repo value?"; rc=$?
  if [ $rc -eq 0 ]; then
    update_macos_defaults_value "$domain" "$key" "$current"
    defaults_updated=$((defaults_updated + 1))
    echo "  + updated $domain $key -> $current"
  elif [ $rc -eq 2 ]; then
    skip_rest=true
  fi
done

# ── 3. Untracked dotfiles (curated candidate list) ───────────────────────────
echo ""
echo "── Untracked dotfiles ──"

# Common config files worth tracking if they show up as real files in $HOME.
CANDIDATE_DOTFILES=(
  ".vimrc"
  ".tmux.conf"
  ".editorconfig"
  ".npmrc"
  ".ssh/config"
  ".config/git/ignore"
)

tracked=()
while read -r file; do
  [ -z "$file" ] && continue
  case "$file" in \#*) continue ;; esac
  tracked+=("$file")
done < "$DOTFILES_LIST"

skip_rest=false
for candidate in "${CANDIDATE_DOTFILES[@]}"; do
  dest="$HOME/$candidate"

  [ -L "$dest" ] && continue                      # already a symlink somewhere
  [ -f "$dest" ] || continue                       # not present on this machine
  array_contains "$candidate" "${tracked[@]}" && continue  # already tracked

  if [ "$skip_rest" = true ]; then continue; fi
  prompt_yn "Import $candidate into the repo?"; rc=$?
  if [ $rc -eq 0 ]; then
    repo_dest="$DOTFILES_DIR/$candidate"
    if [ -e "$repo_dest" ]; then
      echo "  ! $repo_dest already exists in repo; skipping import to avoid overwrite"
      continue
    fi
    mkdir -p "$(dirname "$repo_dest")"
    cp "$dest" "$repo_dest"
    mv "$dest" "${dest}.bak"
    ln -sf "$repo_dest" "$dest"
    printf '%s\n' "$candidate" >> "$DOTFILES_LIST"
    tracked+=("$candidate")
    dotfiles_imported=$((dotfiles_imported + 1))
    echo "  + imported $candidate (original backed up to ${dest}.bak)"
  elif [ $rc -eq 2 ]; then
    skip_rest=true
  fi
done

# ── 4. Symlink health check (report-only) ───────────────────────────────────
echo ""
echo "── Symlink health check ──"

while read -r file; do
  [ -z "$file" ] && continue
  case "$file" in \#*) continue ;; esac

  dest="$HOME/$file"
  src="$DOTFILES_DIR/$file"

  if [ ! -e "$dest" ]; then
    echo "  ! $file: missing at $dest"
  elif [ -L "$dest" ]; then
    target=$(readlink "$dest")
    if [ "$target" = "$src" ]; then
      echo "  ok $file"
    else
      echo "  ! $file: symlink points to $target (expected $src)"
    fi
  else
    echo "  ! $file: exists as a real file, not a symlink (re-run setup.sh or resolve manually)"
  fi
done < "$DOTFILES_LIST"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "==> Done. brews:+$brews_added casks:+$casks_added defaults:+$defaults_updated dotfiles:+$dotfiles_imported"
if [ $((brews_added + casks_added + defaults_updated + dotfiles_imported)) -gt 0 ]; then
  echo "==> Changes were left in the working tree. Review with: git -C \"$DOTFILES_DIR\" diff"
fi
