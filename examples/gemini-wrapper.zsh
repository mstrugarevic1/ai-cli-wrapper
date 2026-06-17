_ai_cli_safe() {
  setopt localoptions no_nomatch

  local agent_key="$1"
  shift

  local agent_name cli_command cli_update_cask risk_env launch_note
  local -a launch_cmd

  case "$agent_key" in
    codex)
      agent_name="Codex"
      cli_command="codex"
      cli_update_cask=""
      risk_env="CODEX_SAFE_ALLOW_RISK"
      launch_cmd=(codex --sandbox workspace-write)
      launch_note="Codex workspace-write sandbox mode"
      ;;
    agy|antigravity)
      agent_name="Antigravity"
      cli_command="agy"
      cli_update_cask="antigravity-cli"
      risk_env="AGY_SAFE_ALLOW_RISK"
      launch_cmd=(agy --sandbox)
      launch_note="Antigravity sandbox mode"
      ;;
    *)
      echo "🛑 Unknown safe CLI target: $agent_key"
      return 1
      ;;
  esac

  echo "🛡️  $agent_name safe pre-check"
  echo ""
  echo "ℹ️  Purpose:"
  echo "ℹ️  This wrapper runs safety checks before starting $agent_name over the current folder."
  echo "ℹ️  It checks git context, possible secrets, git history, and $launch_note."
  echo "ℹ️  Goal: reduce accidental exposure of secrets or sensitive files to an AI coding agent."
  echo ""

  # 1. Git repo check
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "⚠️  Current folder is not a git repository."
    printf "❓ Continue anyway? [y/N]: "
    read -r answer
    case "$answer" in
      y|Y|yes|YES) ;;
      *) echo "🛑 Aborted."; return 1 ;;
    esac
  else
    echo "✅ Git repo: $(git rev-parse --show-toplevel)"
  fi

  # 2. Secret scan with gitleaks
  if ! command -v gitleaks >/dev/null 2>&1; then
    echo "⚠️  gitleaks is not installed."
    printf "❓ Install with brew now? [y/N]: "
    read -r answer
    case "$answer" in
      y|Y|yes|YES)
        if ! command -v brew >/dev/null 2>&1; then
          echo "🛑 brew is not installed. Cannot install gitleaks automatically."
          return 1
        fi

        echo "📦 Installing gitleaks..."
        HOMEBREW_NO_AUTO_UPDATE=1 brew install gitleaks || return 1
        ;;
      *)
        echo "🛑 Aborted. Secret scan is required before running $agent_name sandbox."
        return 1
        ;;
    esac
  fi

  local findings_overridden=0

  echo "🔍 Running gitleaks working directory scan..."
  gitleaks dir . \
    --redact \
    --verbose \
    --timeout 120 \
    --exit-code 3

  local gl_code=$?

  if [ $gl_code -eq 3 ]; then
    echo ""
    echo "🚨 Possible secrets found in working directory."
    echo "🛑 Review findings before running $agent_name here."

    if [ "${(P)risk_env}" = "1" ] || [ "$AGY_SAFE_ALLOW_RISK" = "1" ] || [ "$GEMINI_SAFE_ALLOW_RISK" = "1" ]; then
      echo "⚠️  $risk_env=1 is set. Continuing despite findings."
      findings_overridden=1
    else
      echo "ℹ️  To override manually, run: $risk_env=1 ${agent_key}-safe"
      return 1
    fi
  elif [ $gl_code -ne 0 ]; then
    echo ""
    echo "🚨 Gitleaks working directory scan failed (exit code $gl_code)."
    echo "🛑 Aborting to prevent unsafe execution."
    return 1
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "🔍 Running gitleaks git history scan..."
    gitleaks git . \
      --redact \
      --verbose \
      --timeout 120 \
      --exit-code 3

    local gl_git_code=$?

    if [ $gl_git_code -eq 3 ]; then
      echo ""
      echo "🚨 Possible secrets found in git history."
      echo "🛑 Review findings before running $agent_name here."

      if [ "${(P)risk_env}" = "1" ] || [ "$AGY_SAFE_ALLOW_RISK" = "1" ] || [ "$GEMINI_SAFE_ALLOW_RISK" = "1" ]; then
        echo "⚠️  $risk_env=1 is set. Continuing despite findings."
        findings_overridden=1
      else
        echo "ℹ️  To override manually, run: $risk_env=1 ${agent_key}-safe"
        return 1
      fi
    elif [ $gl_git_code -ne 0 ]; then
      echo ""
      echo "🚨 Gitleaks git history scan failed (exit code $gl_git_code)."
      echo "🛑 Aborting to prevent unsafe execution."
      return 1
    fi
  fi

  if [ "$findings_overridden" -eq 1 ]; then
    echo "WARNING: Gitleaks findings were detected and manually overridden."
  else
    echo "✅ No secrets found by gitleaks."
  fi

  # 3. Check CLI version via brew when a cask is configured.
  if [ -n "$cli_update_cask" ] && command -v brew >/dev/null 2>&1; then
    echo "🔄 Checking $cli_update_cask updates via brew..."

    local outdated brew_outdated_code
    outdated="$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask --quiet "$cli_update_cask" 2>/dev/null)"
    brew_outdated_code=$?

    if [ $brew_outdated_code -ne 0 ]; then
      echo "⚠️  Could not check $cli_update_cask updates via brew."
      echo "ℹ️  Continuing without an update check."
      outdated=""
    fi

    if [ -n "$outdated" ]; then
      echo "⬆️  New $cli_update_cask version available."
      printf "❓ Upgrade $cli_update_cask now? [y/N]: "
      read -r answer
      case "$answer" in
        y|Y|yes|YES)
          echo "📦 Upgrading $cli_update_cask..."
          HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --cask "$cli_update_cask" || return 1
          ;;
        *)
          echo "⏭️  Skipping $cli_update_cask upgrade."
          ;;
      esac
    elif [ $brew_outdated_code -eq 0 ]; then
      echo "✅ $cli_update_cask is up to date."
    fi
  elif [ -n "$cli_update_cask" ]; then
    echo "⚠️  brew not found, skipping $cli_update_cask update check."
  fi

  # 4. Extra safety info
  echo ""
  echo "📁 Current folder:"
  pwd

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo ""
    echo "📌 Git status:"
    git status --short
  fi

  if ! command -v "$cli_command" >/dev/null 2>&1; then
    echo ""
    echo "🛑 $cli_command CLI is not installed or not in PATH."
    return 1
  fi

  echo ""
  echo "🚀 Starting $agent_name in sandbox mode..."
  echo "ℹ️  If folder is untrusted, review permissions inside $agent_name."
  echo ""

  "${launch_cmd[@]}" "$@"
}

agy-safe() {
  _ai_cli_safe agy "$@"
}

codex-safe() {
  _ai_cli_safe codex "$@"
}

gemini-safe() {
  echo "⚠️  gemini-safe is deprecated. Redirecting to agy-safe..."
  agy-safe "$@"
}
