#!/usr/bin/env zsh
set -e

target_dir="$HOME/.config/ai-cli-wrapper"
target_script="$target_dir/scripts/ai-safe.zsh"
source_line='source ~/.config/ai-cli-wrapper/scripts/ai-safe.zsh'
zshrc="$HOME/.zshrc"
backup="$HOME/.zshrc.ai-cli-wrapper.backup"

mkdir -p "$target_dir/scripts"
cp "scripts/ai-safe.zsh" "$target_script"

touch "$zshrc"
if ! grep -Fxq "$source_line" "$zshrc"; then
  cp "$zshrc" "$backup"
  printf '\n%s\n' "$source_line" >> "$zshrc"
fi

print "Run: source ~/.zshrc"
print "Then use: agy-safe, gemini-safe, codex-safe, claude-safe"
