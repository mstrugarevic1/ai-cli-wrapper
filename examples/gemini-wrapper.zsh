agy-safe() {
  setopt localoptions no_nomatch

  echo "🛡️  Antigravity safe pre-check"
  echo ""
  echo "ℹ️  Purpose:"
  echo "ℹ️  This wrapper runs safety checks before starting Antigravity over the current folder."
  echo "ℹ️  It checks git context, possible secrets, git history, and Antigravity sandbox mode."
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
        echo "🛑 Aborted. Secret scan is required before running Antigravity sandbox."
        return 1
        ;;
    esac
  fi

  echo "🔍 Running gitleaks working directory scan..."
  gitleaks dir . \
    --redact \
    --verbose \
    --timeout 120

  if [ $? -ne 0 ]; then
    echo ""
    echo "🚨 Possible secrets found in working directory, or gitleaks scan failed."
    echo "🛑 Review findings before running Antigravity here."

    if [ "$AGY_SAFE_ALLOW_RISK" = "1" ] || [ "$GEMINI_SAFE_ALLOW_RISK" = "1" ]; then
      echo "⚠️  AGY_SAFE_ALLOW_RISK=1 is set. Continuing despite findings."
    else
      echo "ℹ️  To override manually, run: AGY_SAFE_ALLOW_RISK=1 agy-safe"
      return 1
    fi
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "🔍 Running gitleaks git history scan..."
    gitleaks git . \
      --redact \
      --verbose \
      --timeout 120

    if [ $? -ne 0 ]; then
      echo ""
      echo "🚨 Possible secrets found in git history, or gitleaks scan failed."
      echo "🛑 Review findings before running Antigravity here."

      if [ "$AGY_SAFE_ALLOW_RISK" = "1" ] || [ "$GEMINI_SAFE_ALLOW_RISK" = "1" ]; then
        echo "⚠️  AGY_SAFE_ALLOW_RISK=1 is set. Continuing despite findings."
      else
        echo "ℹ️  To override manually, run: AGY_SAFE_ALLOW_RISK=1 agy-safe"
        return 1
      fi
    fi
  fi

  echo "✅ No secrets found by gitleaks."

  # 3. Check Antigravity CLI version via brew
  if command -v brew >/dev/null 2>&1; then
    echo "🔄 Checking antigravity-cli updates via brew..."

    outdated="$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --cask --quiet antigravity-cli 2>/dev/null)"

    if [ -n "$outdated" ]; then
      echo "⬆️  New antigravity-cli version available."
      printf "❓ Upgrade antigravity-cli now? [y/N]: "
      read -r answer
      case "$answer" in
        y|Y|yes|YES)
          echo "📦 Upgrading antigravity-cli..."
          HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --cask antigravity-cli || return 1
          ;;
        *)
          echo "⏭️  Skipping antigravity-cli upgrade."
          ;;
      esac
    else
      echo "✅ antigravity-cli is up to date."
    fi
  else
    echo "⚠️  brew not found, skipping antigravity-cli update check."
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

  if ! command -v agy >/dev/null 2>&1; then
    echo ""
    echo "🛑 agy CLI is not installed or not in PATH."
    return 1
  fi

  echo ""
  echo "🚀 Starting Antigravity in sandbox mode..."
  echo "ℹ️  If folder is untrusted, use /permissions inside Antigravity."
  echo ""

  agy --sandbox "$@"
}

gemini-safe() {
  echo "⚠️  gemini-safe is deprecated. Redirecting to agy-safe..."
  agy-safe "$@"
}
