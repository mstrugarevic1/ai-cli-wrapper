#!/usr/bin/env zsh

set -e

target_dir="$HOME/.config/ai-cli-wrapper"
target_script="$target_dir/scripts/ai-safe.zsh"
source_line='source ~/.config/ai-cli-wrapper/scripts/ai-safe.zsh'
zshrc="$HOME/.zshrc"
backup="$HOME/.zshrc.ai-cli-wrapper.backup"

script_dir="${0:A:h}"
source_script="$script_dir/scripts/ai-safe.zsh"

if [[ ! -f "$source_script" ]]; then
  print -u2 "Cannot find source script: $source_script"
  exit 1
fi

mkdir -p "$target_dir/scripts"

cp "$source_script" "$target_script"

touch "$zshrc"

if ! grep -Fxq "$source_line" "$zshrc"; then
  cp "$zshrc" "$backup"
  printf '\n%s\n' "$source_line" >> "$zshrc"
fi

print "Installed ai-safe wrapper to: $target_script"
print "Run: source ~/.zshrc"
print "Then use: agy-safe, gemini-safe, codex-safe, claude-safe"
