#!/bin/sh

DOTFILES_DIR="$HOME/.dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "==> Cloning dotfiles to $DOTFILES_DIR"
  git clone https://github.com/Nirespire/dotfiles.git "$DOTFILES_DIR"
  cd "$DOTFILES_DIR"
  ./setup.sh
else
  echo "==> Dotfiles already installed at $DOTFILES_DIR"
fi
