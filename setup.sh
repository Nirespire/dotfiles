#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Profile: "personal" (default) or "work". Work adds Brewfile.work and signs
# in to the Atlassian CLI. Pick it with --work or DOTFILES_PROFILE=work.
PROFILE="${DOTFILES_PROFILE:-personal}"
for arg in "$@"; do
  case "$arg" in
    --work) PROFILE=work ;;
    *) echo "Usage: $0 [--work]" >&2; exit 1 ;;
  esac
done
if [ "$PROFILE" != personal ] && [ "$PROFILE" != work ]; then
  echo "Unknown profile '$PROFILE' (expected personal or work)" >&2
  exit 1
fi

echo "==> Setting up dotfiles from $DOTFILES_DIR ($PROFILE profile)"

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

echo "==> Running brew bundle"
brew bundle --file="$DOTFILES_DIR/Brewfile"

if [ "$PROFILE" = work ]; then
  # Brewfile.work trusts its third-party tap via `trusted:`, which needs
  # Homebrew 6+ (the release that introduced `brew trust`).
  if ! brew trust &>/dev/null; then
    echo "==> Updating Homebrew for tap trust support"
    brew update
  fi
  echo "==> Running brew bundle (work)"
  brew bundle --file="$DOTFILES_DIR/Brewfile.work"
fi

# ── 2. pure prompt ────────────────────────────────────────────────────────────
if [ ! -d "$HOME/.zsh/pure" ]; then
  echo "==> Installing pure prompt"
  mkdir -p "$HOME/.zsh"
  git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
else
  echo "==> pure prompt already installed; skipping"
fi

# ── 3. nvm ────────────────────────────────────────────────────────────────────
if [ ! -d "$HOME/.nvm" ]; then
  echo "==> Installing nvm"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
else
  echo "==> nvm already installed; skipping"
fi

# ── 4. macOS defaults ─────────────────────────────────────────────────────────
echo "==> Applying macOS defaults"
dock_changed=false
while read -r domain key type value; do
  [[ -z "$domain" || "$domain" == \#* ]] && continue
  defaults write "$domain" "$key" "-$type" "$value"
  [[ "$domain" == "com.apple.dock" ]] && dock_changed=true
done < "$DOTFILES_DIR/macos-defaults"
[ "$dock_changed" = true ] && killall Dock

# ── 5. Symlink dotfiles ───────────────────────────────────────────────────────
DOTFILES=()
while read -r file; do
  [[ -z "$file" || "$file" == \#* ]] && continue
  DOTFILES+=("$file")
done < "$DOTFILES_DIR/dotfiles.list"

for file in "${DOTFILES[@]}"; do
  src="$DOTFILES_DIR/$file"
  dest="$HOME/$file"

  if [ ! -f "$src" ]; then
    echo "==> WARNING: $src not found, skipping"
    continue
  fi

  mkdir -p "$(dirname "$dest")"

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "==> Backing up existing $dest to ${dest}.bak"
    mv "$dest" "${dest}.bak"
  fi

  echo "==> Linking $src -> $dest"
  ln -sf "$src" "$dest"
done

# ── 6. Symlink Claude Code skills ───────────────────────────────────────
# Each skill is linked individually rather than linking .claude/skills wholesale,
# so any hand-written skills already in ~/.claude/skills keep working.
SKILLS=()
while read -r path; do
  [[ -z "$path" || "$path" == \#* ]] && continue
  SKILLS+=("$(basename "$path")")
done < "$DOTFILES_DIR/skills.list"

if [ ${#SKILLS[@]} -gt 0 ]; then
  echo "==> Linking ${#SKILLS[@]} Claude Code skills"
  mkdir -p "$HOME/.claude/skills"

  for skill in "${SKILLS[@]}"; do
    src="$DOTFILES_DIR/.claude/skills/$skill"
    dest="$HOME/.claude/skills/$skill"

    if [ ! -d "$src" ]; then
      echo "==> WARNING: $src not found, skipping (run ./sync-skills.sh)"
      continue
    fi

    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
      echo "==> Backing up existing $dest to ${dest}.bak"
      mv "$dest" "${dest}.bak"
    fi

    # -n so re-running replaces the link instead of nesting inside it
    ln -sfn "$src" "$dest"
  done
fi

# ── 7. Atlassian CLI sign-in (work only) ─────────────────────────────────────
# Last, so a skipped or failed sign-in never blocks the rest of setup. Reads
# ATLASSIAN_SITE / ATLASSIAN_EMAIL / ATLASSIAN_API_TOKEN if set, else prompts.
# The token goes to acli on stdin, never argv, so it stays out of `ps`.
if [ "$PROFILE" = work ]; then
  if acli jira auth status &>/dev/null; then
    echo "==> acli already signed in; skipping"
  else
    site="${ATLASSIAN_SITE:-}"
    email="${ATLASSIAN_EMAIL:-}"
    token="${ATLASSIAN_API_TOKEN:-}"

    if { [ -z "$site" ] || [ -z "$email" ] || [ -z "$token" ]; } && [ ! -t 0 ]; then
      echo "==> WARNING: no terminal to prompt for Atlassian credentials; skipping acli sign-in"
      echo "    Set ATLASSIAN_SITE, ATLASSIAN_EMAIL and ATLASSIAN_API_TOKEN, or re-run interactively"
    else
      echo "==> Signing in to Atlassian CLI"
      [ -z "$site" ] && read -r -p "    Atlassian site (e.g. mycompany.atlassian.net): " site
      [ -z "$email" ] && read -r -p "    Atlassian account email: " email
      if [ -z "$token" ]; then
        token_url="https://id.atlassian.com/manage-profile/security/api-tokens"
        echo "    Create an API token at $token_url"
        open "$token_url" 2>/dev/null || true
        read -r -s -p "    Paste API token: " token
        echo ""
      fi

      site="${site#https://}"
      site="${site%/}"
      if printf '%s' "$token" | acli jira auth login --site "$site" --email "$email" --token; then
        echo "==> acli signed in to $site"
      else
        echo "==> WARNING: acli sign-in failed; re-run ./setup.sh --work to retry"
      fi
    fi
    unset token
  fi
fi

echo ""
echo "✓ Done. Open a new terminal to pick up the new shell config."
