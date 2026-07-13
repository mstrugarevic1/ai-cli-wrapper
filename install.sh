#!/usr/bin/env bash
#
# Installer for the AI CLI safety wrappers.
#
# What it does:
#   - copies scripts/ai-safe.sh to ~/.config/ai-cli-wrapper/scripts/
#   - adds a "source" line for it to your shell rc file if not already present
#   - backs up the rc file to <rc>.ai-cli-wrapper.backup before the first change
#
# Usage:
#   ./install.sh            install for the shell detected from $SHELL
#   ./install.sh zsh        install for zsh only (~/.zshrc)
#   ./install.sh bash       install for bash only (~/.bashrc)
#   ./install.sh both       install for zsh and bash
#
# Disclaimer:
#   This software is provided "as is", without warranty of any kind. You run it
#   at your own risk. The authors are not liable for any damage, data loss, or
#   leaked secrets resulting from its use.

set -e

target_dir="$HOME/.config/ai-cli-wrapper"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_for_shell() {
  local shell="$1"
  local rc source_script target_script source_line legacy_source_line backup tmp

  case "$shell" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc" ;;
    *)
      printf 'Unknown shell: %s\n' "$shell" >&2
      return 1
      ;;
  esac

  source_script="$script_dir/scripts/ai-safe.sh"
  target_script="$target_dir/scripts/ai-safe.sh"
  source_line="source ~/.config/ai-cli-wrapper/scripts/ai-safe.sh"
  legacy_source_line="source ~/.config/ai-cli-wrapper/scripts/ai-safe.$shell"
  backup="$rc.ai-cli-wrapper.backup"

  if [ ! -f "$source_script" ]; then
    printf 'Cannot find source script: %s\n' "$source_script" >&2
    return 1
  fi

  mkdir -p "$target_dir/scripts"
  cp "$source_script" "$target_script"
  rm -f "$target_dir/scripts/ai-safe.$shell"

  touch "$rc"

  if grep -Fxq "$legacy_source_line" "$rc" || ! grep -Fxq "$source_line" "$rc"; then
    cp "$rc" "$backup"
    tmp="$(mktemp)"
    grep -Fvx "$legacy_source_line" "$rc" > "$tmp" || true
    if ! grep -Fxq "$source_line" "$tmp"; then
      printf '\n%s\n' "$source_line" >> "$tmp"
    fi
    cat "$tmp" > "$rc"
    rm -f "$tmp"
  fi

  printf 'Installed ai-safe wrapper (%s) to: %s\n' "$shell" "$target_script"
  printf 'Run: source %s\n' "$rc"
}

detect_shell() {
  case "$(basename "${SHELL:-}")" in
    zsh)  printf 'zsh' ;;
    bash) printf 'bash' ;;
    *)    printf '' ;;
  esac
}

case "${1:-}" in
  zsh|bash)
    install_for_shell "$1"
    ;;
  both)
    install_for_shell zsh
    install_for_shell bash
    ;;
  "")
    detected="$(detect_shell)"
    if [ -z "$detected" ]; then
      printf "Could not detect shell from \$SHELL. Run: ./install.sh zsh|bash|both\n" >&2
      exit 1
    fi
    install_for_shell "$detected"
    ;;
  *)
    printf 'Usage: ./install.sh [zsh|bash|both]\n' >&2
    exit 1
    ;;
esac

printf 'Then use: agy-safe, gemini-safe, codex-safe, claude-safe\n'
