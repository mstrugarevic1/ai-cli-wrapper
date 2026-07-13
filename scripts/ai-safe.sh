# AI CLI safety wrappers for bash and zsh.
#
# Each public wrapper validates its dependencies and Git repository, scans the
# repository working tree and history for secrets, then starts the requested CLI.
# Internal helper names use the _ai_safe_ prefix to avoid shell function clashes.
#
# Source this file from ~/.bashrc or ~/.zshrc:
#
#   source ~/.config/ai-cli-wrapper/scripts/ai-safe.sh

# Fails when any command needed by the selected wrapper is unavailable.
_ai_safe_require() {
  local cmd

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      printf 'Missing required command: %s\n' "$cmd" >&2
      return 1
    fi
  done
}

# Requires Gitleaks, offering a Homebrew installation when it is missing.
_ai_safe_ensure_gitleaks() {
  local answer

  if command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi

  printf 'gitleaks is not installed.\n' >&2
  printf 'Install with brew now? [y/N]: '
  read -r answer

  case "$answer" in
    y|Y|yes|YES)
      if ! command -v brew >/dev/null 2>&1; then
        printf 'brew is not installed. Cannot install gitleaks automatically.\n' >&2
        return 1
      fi

      printf 'Installing gitleaks...\n'
      HOMEBREW_NO_AUTO_UPDATE=1 brew install gitleaks || return 1
      ;;
    *)
      printf 'Aborted. Secret scan is required before starting.\n' >&2
      return 1
      ;;
  esac
}

# Runs one Gitleaks command and allows findings only through an explicit override.
_ai_safe_gitleaks() {
  local label="$1"
  local override_name="$2"
  local override_value="$3"
  local scan_status

  shift 3

  printf 'Running Gitleaks %s...\n' "$label"

  "$@"
  scan_status=$?

  if (( scan_status == 0 )); then
    return 0
  fi

  if (( scan_status != 3 )); then
    printf 'Gitleaks %s failed (exit code %s).\n' "$label" "$scan_status" >&2
    return 1
  fi

  if [[ "$override_value" == "1" ]]; then
    printf 'WARNING: Gitleaks reported findings, but override is enabled. Continuing at user risk.\n'
    return 0
  fi

  printf 'Gitleaks reported findings. Refusing to start.\n' >&2
  printf 'Review the findings or set %s=1 if you explicitly accept the risk.\n' "$override_name" >&2
  return 1
}

# Validates the repository and runs working-tree and history scans before launch.
_ai_safe_preflight() {
  local cli="$1"
  local override_name="$2"
  local override_value="$3"
  local update_hint="$4"
  local repo_root

  _ai_safe_require git "$cli" || return 1

  if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'This directory is not inside a git repository.\n' >&2
    return 1
  fi

  _ai_safe_ensure_gitleaks || return 1

  printf 'Directory: %s\n' "$PWD"
  printf 'Git status:\n'
  git status --short

  _ai_safe_gitleaks \
    "working directory scan" \
    "$override_name" \
    "$override_value" \
    gitleaks dir "$repo_root" --redact --verbose --timeout 120 --exit-code 3 || return 1

  _ai_safe_gitleaks \
    "git history scan" \
    "$override_name" \
    "$override_value" \
    gitleaks git "$repo_root" --redact --verbose --timeout 120 --exit-code 3 || return 1

  if [[ -n "$update_hint" ]]; then
    printf 'To check for %s CLI updates, run: %s\n' "$cli" "$update_hint"
  fi
}

# Starts Claude with normal permissions or its optional, explicitly requested sandbox.
_ai_safe_claude() {
  if [[ "${CLAUDE_SAFE_SANDBOX:-}" == "1" ]]; then
    if claude --help 2>&1 | grep -q -- "--sandbox"; then
      claude --sandbox --permission-mode default "$@"
      return $?
    fi

    printf 'Claude sandbox mode was requested, but this Claude CLI does not list a supported sandbox option.\n' >&2

    if [[ "${CLAUDE_SAFE_ALLOW_UNSANDBOXED:-}" != "1" ]]; then
      printf 'Set CLAUDE_SAFE_ALLOW_UNSANDBOXED=1 to start Claude without sandbox mode.\n' >&2
      return 1
    fi
  fi

  claude --permission-mode default "$@"
}

# Runs the shared preflight and starts Antigravity in its sandbox.
agy-safe() {
  _ai_safe_preflight agy AGY_SAFE_ALLOW_RISK "${AGY_SAFE_ALLOW_RISK:-}" "brew info --cask antigravity-cli" || return 1

  agy --sandbox "$@"
}

# Preserves the legacy Gemini command while delegating execution to Antigravity.
gemini-safe() {
  if [[ "${GEMINI_SAFE_ALLOW_RISK:-}" == "1" && "${AGY_SAFE_ALLOW_RISK:-}" != "1" ]]; then
    AGY_SAFE_ALLOW_RISK=1 agy-safe "$@"
    return $?
  fi

  agy-safe "$@"
}

# Runs the shared preflight and starts Codex with workspace-write sandboxing.
codex-safe() {
  _ai_safe_preflight codex CODEX_SAFE_ALLOW_RISK "${CODEX_SAFE_ALLOW_RISK:-}" "" || return 1

  codex --sandbox workspace-write "$@"
}

# Runs the shared preflight and starts Claude through its sandbox-aware launcher.
claude-safe() {
  _ai_safe_preflight claude CLAUDE_SAFE_ALLOW_RISK "${CLAUDE_SAFE_ALLOW_RISK:-}" "brew info --cask claude-code" || return 1

  _ai_safe_claude "$@"
}
