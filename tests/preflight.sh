#!/usr/bin/env bash

set -eu

repo="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# Stub gitleaks so tests can verify calls without depending on real findings.
printf "#!/bin/sh\nprintf '%%s|%%s\\n' \"\$1\" \"\$2\" >> \"\$GITLEAKS_LOG\"\nexit \"\${GITLEAKS_STATUS:-0}\"\n" > "$tmp/gitleaks"
chmod +x "$tmp/gitleaks"

# Build a tiny Git repo with a nested directory to prove scans start at the root.
git init -q "$tmp/repo"
mkdir "$tmp/repo/nested"

# The command strings must expand variables in the shell under test.
# shellcheck disable=SC2016
for shell in bash zsh; do
  log="$tmp/$shell.log"

  # Preflight must fail closed when launched outside any Git repository.
  if (cd "$tmp" && PATH="$tmp:$PATH" GITLEAKS_LOG="$log" "$shell" -c 'source "$1"; _ai_safe_preflight sh TEST_OVERRIDE "${TEST_OVERRIDE:-}" ""' _ "$repo/scripts/ai-safe.sh" < /dev/null); then
    printf '%s preflight allowed a non-Git directory\n' "$shell" >&2
    exit 1
  fi

  # From a subdirectory, both filesystem and Git-history scans must target repo root.
  (cd "$tmp/repo/nested" && PATH="$tmp:$PATH" GITLEAKS_LOG="$log" "$shell" -c 'source "$1"; _ai_safe_preflight sh TEST_OVERRIDE "${TEST_OVERRIDE:-}" ""' _ "$repo/scripts/ai-safe.sh")
  printf 'dir|%s\ngit|%s\n' "$tmp/repo" "$tmp/repo" | cmp -s - "$log" || {
    printf '%s preflight did not scan the Git repository root\n' "$shell" >&2
    exit 1
  }

  # Simulated gitleaks findings must block execution unless an override is explicit.
  if (cd "$tmp/repo" && PATH="$tmp:$PATH" GITLEAKS_LOG="$log" GITLEAKS_STATUS=3 "$shell" -c 'source "$1"; _ai_safe_preflight sh TEST_OVERRIDE "" ""' _ "$repo/scripts/ai-safe.sh"); then
    printf '%s preflight allowed findings without an override\n' "$shell" >&2
    exit 1
  fi

  # Explicit override keeps the wrapper usable for intentional exceptions.
  (cd "$tmp/repo" && PATH="$tmp:$PATH" GITLEAKS_LOG="$log" GITLEAKS_STATUS=3 TEST_OVERRIDE=1 "$shell" -c 'source "$1"; _ai_safe_preflight sh TEST_OVERRIDE "$TEST_OVERRIDE" ""' _ "$repo/scripts/ai-safe.sh")

  # AI_SAFE_ALLOW_NO_GIT runs the working-file scan only, skipping the history scan.
  : > "$log"
  (cd "$tmp" && PATH="$tmp:$PATH" GITLEAKS_LOG="$log" AI_SAFE_ALLOW_NO_GIT=1 "$shell" -c 'source "$1"; _ai_safe_preflight sh TEST_OVERRIDE "${TEST_OVERRIDE:-}" ""' _ "$repo/scripts/ai-safe.sh" < /dev/null)
  printf 'dir|%s\n' "$tmp" | cmp -s - "$log" || {
    printf '%s preflight did not run a dir-only scan with AI_SAFE_ALLOW_NO_GIT\n' "$shell" >&2
    exit 1
  }
done

# Installer migration must replace old shell-specific wrapper references.
home="$tmp/home"
mkdir -p "$home/.config/ai-cli-wrapper/scripts"
printf 'source ~/.config/ai-cli-wrapper/scripts/ai-safe.zsh\n' > "$home/.zshrc"
printf 'source ~/.config/ai-cli-wrapper/scripts/ai-safe.bash\n' > "$home/.bashrc"
touch "$home/.config/ai-cli-wrapper/scripts/ai-safe.zsh"
touch "$home/.config/ai-cli-wrapper/scripts/ai-safe.bash"
HOME="$home" "$repo/install.sh" both >/dev/null

cmp -s "$repo/scripts/ai-safe.sh" "$home/.config/ai-cli-wrapper/scripts/ai-safe.sh"
for shell in bash zsh; do
  rc="$home/.$shell"rc
  grep -Fxq 'source ~/.config/ai-cli-wrapper/scripts/ai-safe.sh' "$rc"
  if grep -Fq "ai-safe.$shell" "$rc" || [[ -e "$home/.config/ai-cli-wrapper/scripts/ai-safe.$shell" ]]; then
    printf '%s installer left the legacy wrapper configured\n' "$shell" >&2
    exit 1
  fi
done
