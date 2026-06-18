#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Setting up dotfiles from $DOTFILES_DIR"

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(/opt/homebrew/bin/brew shellenv)"

echo "==> Running brew bundle"
brew bundle --file="$DOTFILES_DIR/Brewfile"

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

# ── 4. Symlink dotfiles ───────────────────────────────────────────────────────
DOTFILES=(
  ".zshrc"
  ".zprofile"
  ".aliases"
  ".gitconfig"
)

for file in "${DOTFILES[@]}"; do
  src="$DOTFILES_DIR/$file"
  dest="$HOME/$file"

  if [ ! -f "$src" ]; then
    echo "==> WARNING: $src not found, skipping"
    continue
  fi

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "==> Backing up existing $dest to ${dest}.bak"
    mv "$dest" "${dest}.bak"
  fi

  echo "==> Linking $src -> $dest"
  ln -sf "$src" "$dest"
done

echo ""
echo "✓ Done. Open a new terminal to pick up the new shell config."
