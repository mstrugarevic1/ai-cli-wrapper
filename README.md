# Antigravity (Gemini) CLI Security Wrapper

## Purpose
This repository documents and maintains a security wrapper function (`agy-safe`) for the Antigravity (Gemini) CLI. The wrapper runs essential safety checks before starting the agent in the current folder. Its goal is to reduce the accidental exposure of secrets or sensitive files to an AI coding agent by enforcing git context checks, secret scanning, and running the agent in sandbox mode.

## Installation Requirements
The wrapper requires the following tools to be installed:
- `git`: For repository context and history checks.
- `gitleaks`: For scanning the working directory and git history for secrets.
- `brew`: (macOS/Homebrew) For automatically installing `gitleaks` and updating `antigravity-cli`.
- `agy`: The Antigravity CLI executable.

## Existing `.zshrc` Configuration
The wrapper is implemented as a shell function named `agy-safe` (with a legacy alias `gemini-safe`) inside `~/.zshrc`. 

## Security Checks
Before launching the CLI, the wrapper performs the following checks:
1. **Git Context Check**: Verifies if the current folder is a git repository (`git rev-parse --is-inside-work-tree`). If not, it prompts the user to confirm before proceeding.
2. **Secret Scan (Working Directory)**: Runs `gitleaks dir . --redact --verbose --timeout 120` to detect exposed secrets in the current directory.
3. **Secret Scan (Git History)**: Runs `gitleaks git . --redact --verbose --timeout 120` to detect exposed secrets in the repository's commit history.
4. **CLI Update Check**: Uses `brew outdated` to check if `antigravity-cli` needs an update, prompting the user to upgrade if a newer version is available.
5. **Context Summary**: Prints the current working directory (`pwd`) and git status (`git status --short`).
6. **Sandbox Execution**: Launches the CLI using the `--sandbox` flag (`agy --sandbox "$@"`).

## Usage Examples

Run the wrapper normally:
```bash
agy-safe
```

Run with arguments passed to the Antigravity CLI:
```bash
agy-safe --task "Fix the build"
```

Use the legacy alias (redirects to `agy-safe`):
```bash
gemini-safe
```

Override secret scan findings to force execution:
```bash
AGY_SAFE_ALLOW_RISK=1 agy-safe
```
*(Alternatively, `GEMINI_SAFE_ALLOW_RISK=1` can be used).*

## Dependencies
- `gitleaks`
- `brew`
- `git`
- `agy`

## Troubleshooting
- **`gitleaks is not installed`**: The wrapper will prompt to install it via `brew`. If `brew` is missing, you must install `gitleaks` manually.
- **`Possible secrets found`**: The wrapper halts execution to prevent secret leaks. Review the findings from `gitleaks`. If you are certain it's a false positive, you can override using the `AGY_SAFE_ALLOW_RISK=1` environment variable.
- **`agy CLI is not installed`**: Ensure the Antigravity CLI is installed and available in your shell's `$PATH`.

## Updating the Wrapper
To modify the wrapper, edit the `agy-safe` function in your `~/.zshrc`. 
Always back up `.zshrc` before making changes:
```bash
cp ~/.zshrc ~/.zshrc.backup
```
And validate syntax after changes:
```bash
zsh -n ~/.zshrc
source ~/.zshrc
```
