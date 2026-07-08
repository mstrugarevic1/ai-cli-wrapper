# AI CLI safety wrappers.
#
# Source this file from ~/.bashrc:
#
#   source ~/.config/ai-cli-wrapper/scripts/ai-safe.bash

_ai_safe_has_override() {
  local name="$1"

  [[ "${!name}" == "1" ]]
}

_ai_safe_require() {
  local cmd

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Missing required command: $cmd" >&2
      return 1
    fi
  done
}

_ai_safe_ensure_gitleaks() {
  if command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi

  echo "gitleaks is not installed." >&2
  printf "Install with brew now? [y/N]: "
  read -r answer

  case "$answer" in
    y|Y|yes|YES)
      if ! command -v brew >/dev/null 2>&1; then
        echo "brew is not installed. Cannot install gitleaks automatically." >&2
        return 1
      fi

      echo "Installing gitleaks..."
      HOMEBREW_NO_AUTO_UPDATE=1 brew install gitleaks || return 1
      ;;
    *)
      echo "Aborted. Secret scan is required before starting." >&2
      return 1
      ;;
  esac
}

_ai_safe_gitleaks() {
  local label="$1"
  local override="$2"

  shift 2

  echo "Running Gitleaks ${label}..."

  "$@"
  local scan_status=$?

  if (( scan_status == 0 )); then
    return 0
  fi

  if (( scan_status != 3 )); then
    echo "Gitleaks ${label} failed (exit code ${scan_status})." >&2
    return 1
  fi

  if _ai_safe_has_override "$override"; then
    echo "WARNING: Gitleaks reported findings, but override is enabled. Continuing at user risk."
    return 0
  fi

  echo "Gitleaks reported findings. Refusing to start." >&2
  echo "Review the findings or set ${override}=1 if you explicitly accept the risk." >&2

  return 1
}

_ai_safe_preflight() {
  local cli="$1"
  local override="$2"
  local update_hint="$3"

  _ai_safe_require git "$cli" || return 1
  _ai_safe_ensure_gitleaks || return 1

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "This directory is not inside a git repository." >&2
    printf "Continue anyway? [y/N]: "
    read -r answer

    case "$answer" in
      y|Y|yes|YES) ;;
      *) echo "Aborted." >&2; return 1 ;;
    esac
  fi

  echo "Directory: $PWD"
  echo "Git status:"
  git status --short

  _ai_safe_gitleaks \
    "working directory scan" \
    "$override" \
    gitleaks dir . --redact --verbose --timeout 120 --exit-code 3 || return 1

  _ai_safe_gitleaks \
    "git history scan" \
    "$override" \
    gitleaks git . --redact --verbose --timeout 120 --exit-code 3 || return 1

  if [[ -n "$update_hint" ]]; then
    echo "To check for $cli CLI updates, run: $update_hint"
  fi
}

_ai_safe_claude() {
  if [[ "$CLAUDE_SAFE_SANDBOX" == "1" ]]; then
    if claude --help 2>&1 | grep -q -- "--sandbox"; then
      claude --sandbox --permission-mode default "$@"
      return $?
    fi

    echo "Claude sandbox mode was requested, but this Claude CLI does not list a supported sandbox option." >&2

    if [[ "$CLAUDE_SAFE_ALLOW_UNSANDBOXED" != "1" ]]; then
      echo "Set CLAUDE_SAFE_ALLOW_UNSANDBOXED=1 to start Claude without sandbox mode." >&2
      return 1
    fi
  fi

  claude --permission-mode default "$@"
}

agy-safe() {
  _ai_safe_preflight agy AGY_SAFE_ALLOW_RISK "brew info --cask antigravity-cli" || return 1

  agy --sandbox "$@"
}

gemini-safe() {
  if [[ "$GEMINI_SAFE_ALLOW_RISK" == "1" && "$AGY_SAFE_ALLOW_RISK" != "1" ]]; then
    AGY_SAFE_ALLOW_RISK=1 agy-safe "$@"
    return $?
  fi

  agy-safe "$@"
}

codex-safe() {
  _ai_safe_preflight codex CODEX_SAFE_ALLOW_RISK || return 1

  codex --sandbox workspace-write "$@"
}

claude-safe() {
  _ai_safe_preflight claude CLAUDE_SAFE_ALLOW_RISK "brew info --cask claude-code" || return 1

  _ai_safe_claude "$@"
}
