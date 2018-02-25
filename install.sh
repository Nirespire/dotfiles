#!/bin/sh

if [ ! -d "$HOME/.yadr-nirespire"]; then
    echo "Installing Nirespire-YADR configurations for the first time"
    git clone --depth=1 https://github.com/Nirespire/dotfiles.git "$HOME/.yard-nirespire"
    cd "$HOME/.yadr-nirespire"
    ./setup.sh
else
    echo "Nirespire-YADR is already installed"
fi
