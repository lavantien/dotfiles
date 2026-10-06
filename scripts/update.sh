#!/usr/bin/env bash
# Pulls the live shell, git, and wezterm configs back into the repo.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cp ~/.bash_aliases "$ROOT_DIR/home/"
cp ~/.zshrc "$ROOT_DIR/home/"
cp ~/.gitconfig "$ROOT_DIR/home/"
cp ~/.config/wezterm/wezterm.lua "$ROOT_DIR/.config/wezterm/wezterm.lua"
