# AI CLI safety wrappers.
#
# Source this file from ~/.zshrc:
#
#   source ~/.config/ai-cli-wrapper/scripts/ai-safe.zsh

_ai_safe_has_override() {
  local name="$1"

  [[ "${(P)name}" == "1" ]]
}

_ai_safe_require() {
  local cmd

  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      print -u2 "Missing required command: $cmd"
      return 1
    fi
  done
}

_ai_safe_ensure_gitleaks() {
  if command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi

  print -u2 "gitleaks is not installed."
  print -n "Install with brew now? [y/N]: "
  read -r answer

  case "$answer" in
    y|Y|yes|YES)
      if ! command -v brew >/dev/null 2>&1; then
        print -u2 "brew is not installed. Cannot install gitleaks automatically."
        return 1
      fi

      print "Installing gitleaks..."
      HOMEBREW_NO_AUTO_UPDATE=1 brew install gitleaks || return 1
      ;;
    *)
      print -u2 "Aborted. Secret scan is required before starting."
      return 1
      ;;
  esac
}

_ai_safe_gitleaks() {
  local label="$1"
  local override="$2"

  shift 2

  print "Running Gitleaks ${label}..."

  "$@"
  local status=$?

  if (( status == 0 )); then
    return 0
  fi

  if (( status != 3 )); then
    print -u2 "Gitleaks ${label} failed (exit code ${status})."
    return 1
  fi

  if _ai_safe_has_override "$override"; then
    print "WARNING: Gitleaks reported findings, but override is enabled. Continuing at user risk."
    return 0
  fi

  print -u2 "Gitleaks reported findings. Refusing to start."
  print -u2 "Review the findings or set ${override}=1 if you explicitly accept the risk."

  return 1
}

_ai_safe_preflight() {
  local cli="$1"
  local override="$2"
  local update_hint="$3"

  _ai_safe_require git "$cli" || return 1
  _ai_safe_ensure_gitleaks || return 1

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print -u2 "This directory is not inside a git repository."
    print -n "Continue anyway? [y/N]: "
    read -r answer

    case "$answer" in
      y|Y|yes|YES) ;;
      *) print -u2 "Aborted."; return 1 ;;
    esac
  fi

  print "Directory: $PWD"
  print "Git status:"
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
    print "To check for $cli CLI updates, run: $update_hint"
  fi
}

_ai_safe_claude() {
  if [[ "$CLAUDE_SAFE_SANDBOX" == "1" ]]; then
    if claude --help 2>&1 | grep -q -- "--sandbox"; then
      claude --sandbox --permission-mode default "$@"
      return $?
    fi

    print -u2 "Claude sandbox mode was requested, but this Claude CLI does not list a supported sandbox option."

    if [[ "$CLAUDE_SAFE_ALLOW_UNSANDBOXED" != "1" ]]; then
      print -u2 "Set CLAUDE_SAFE_ALLOW_UNSANDBOXED=1 to start Claude without sandbox mode."
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
