#!/usr/bin/env bash
# stow.sh — stow all Linux dotfiles packages
# Usage: ./stow.sh [--dry-run]
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_DIR="$DOTFILES_DIR/linux"
TARGET="$HOME"
STOW_FLAGS=(--dir="$LINUX_DIR" --target="$TARGET" --restow)

if [[ "${1:-}" == "--dry-run" ]]; then
  STOW_FLAGS+=(--simulate --verbose)
  echo "── DRY RUN ──────────────────────────────────"
fi

# Core packages
PACKAGES=(
  fish
  fastfetch
  lazygit
  htop
  starship
  tmux
  git
)

# Uncomment when ready:
# PACKAGES+=(nvim)   # LazyVim — set up ~/.config/nvim first
# PACKAGES+=(kitty)  # native Arch Linux only

echo "Stowing to: $TARGET"
echo "────────────────────────────────────────────"

for pkg in "${PACKAGES[@]}"; do
  echo "→ $pkg"
  stow "${STOW_FLAGS[@]}" "$pkg"
done

echo "────────────────────────────────────────────"
echo "✓ Done"
