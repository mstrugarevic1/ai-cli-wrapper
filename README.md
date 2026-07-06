# Antigravity (Gemini), Codex, and Claude Code CLI Security Wrapper

## Purpose
This repository documents and maintains security wrapper functions (`agy-safe`, `codex-safe`, and `claude-safe`) for the Antigravity (Gemini), Codex, and Claude Code CLIs. The wrapper runs essential safety checks before starting the agent in the current folder. Its goal is to reduce the accidental exposure of secrets or sensitive files to an AI coding agent by enforcing git context checks, secret scanning, and running the agent in sandbox or permission-prompt mode.

## Dependencies

| Tool | Required | Purpose | Installation |
|---|---:|---|---|
| `zsh` | Yes | Runs the `agy-safe`, `codex-safe`, and `claude-safe` shell functions | Included with macOS |
| `git` | Yes | Repository context, status and history checks | `brew install git` |
| `gitleaks` | Yes | Scans the working directory and Git history for potential secrets | `brew install gitleaks` |
| `brew` | Yes | Installs Gitleaks and can be used to check Antigravity/Claude Code CLI updates | Install Homebrew separately |
| `agy` | Yes | Starts the Antigravity CLI in sandbox mode | Install Antigravity CLI and ensure `agy` is available in `$PATH` |
| `codex` | Optional | Starts the Codex CLI in sandbox mode | Install Codex CLI and ensure `codex` is available in `$PATH` |
| `claude` | Optional | Starts the Claude Code CLI with its built-in OS-level Bash sandbox enabled | Install Claude Code and ensure `claude` is available in `$PATH` |

```bash
command -v zsh git gitleaks brew agy codex claude
```

## Existing `.zshrc` Configuration
The wrapper is implemented as shell functions named `agy-safe`, `codex-safe`, and `claude-safe` (with a legacy alias `gemini-safe`) inside `~/.zshrc`. 

## Security Checks

> [!WARNING]
> Use this wrapper at your own risk. It can help reduce the chance of accidentally exposing secrets, but it is not a complete security boundary and does not guarantee safe usage of Gemini CLI.
>
> Security depends on careful use of the tool and basic security hygiene. Always review the directory in which the CLI is started, keep credentials and sensitive files outside project directories where possible, use least-privilege credentials, review requested permissions, and rotate any credential that may have been exposed.
>
> Secret scanning and sandboxing reduce risk, but they do not replace responsible usage, access controls, secure credential storage, and manual review.
Before launching the CLI, the wrapper performs the following checks:
1. **CLI Availability Check**: Verifies that the selected CLI (`agy`, `codex`, or `claude`) is installed and available in `$PATH`.
2. **Git Context Check**: Verifies if the current folder is a git repository (`git rev-parse --is-inside-work-tree`). If not, it prompts the user to confirm before proceeding.
3. **Secret Scan (Working Directory)**: Runs `gitleaks dir . --redact --verbose --timeout 120` to detect exposed secrets in the current directory.
4. **Secret Scan (Git History)**: Runs `gitleaks git . --redact --verbose --timeout 120` to detect exposed secrets in the repository's commit history.
5. **CLI Update Hint**: For Antigravity and Claude Code, prints the Homebrew command that can be used to check the current cask version.
6. **Context Summary**: Prints the current working directory (`pwd`) and git status (`git status --short`).
7. **Sandbox Execution**: Launches the CLI restricted to the workspace: `agy --sandbox "$@"`, `codex --sandbox workspace-write "$@"`, or `claude --settings '{"sandbox":{"enabled":true,"failIfUnavailable":true}}' "$@"`.

For Claude Code, "sandbox" refers to its built-in OS-level Bash sandbox (Seatbelt on macOS, bubblewrap on Linux/WSL2), enabled here via `--settings`. It restricts Bash filesystem writes to the working directory and session temp directory, and blocks network access until a domain is approved. `failIfUnavailable: true` makes `claude-safe` refuse to start unsandboxed if the sandbox cannot initialize (e.g. missing `bubblewrap`/`socat` on Linux), instead of silently falling back like Claude Code does by default. Built-in file tools (Read/Edit/Write) still go through Claude Code's normal permission prompts; the sandbox only constrains Bash and its subprocesses.

## How It Works

```text
agy-safe / codex-safe / claude-safe
   |
   +-- Check selected CLI is installed
   +-- Check Git repository context
   +-- Scan the working directory with Gitleaks
   +-- Scan Git history with Gitleaks
   +-- Show Antigravity/Claude Code CLI update check command
   +-- Display the current directory and Git status
   +-- Start the selected CLI restricted to the workspace
```

## Demo

![agy-safe pre-flight checks](assets/agy-safe-demo.png)

The screenshot shows an example of the wrapper completing its pre-flight checks before starting Antigravity CLI.

## Usage Examples

Run the wrapper normally:
```bash
agy-safe
```

Run Codex with the same pre-flight checks:
```bash
codex-safe
```

Run Claude Code with the same pre-flight checks:
```bash
claude-safe
```

Run with arguments passed to the Antigravity CLI:
```bash
agy-safe --prompt "Fix the build"
```

Run with arguments passed to the Codex CLI:
```bash
codex-safe "Fix the build"
```

Run with arguments passed to the Claude Code CLI:
```bash
claude-safe "Fix the build"
```

Use the legacy alias (redirects to `agy-safe`):
```bash
gemini-safe
```

Override secret scan findings to force execution:
```bash
AGY_SAFE_ALLOW_RISK=1 agy-safe
```
For Codex:
```bash
CODEX_SAFE_ALLOW_RISK=1 codex-safe
```
For Claude Code:
```bash
CLAUDE_SAFE_ALLOW_RISK=1 claude-safe
```
*(Alternatively, `GEMINI_SAFE_ALLOW_RISK=1` can still be used).*

## Troubleshooting
- **`gitleaks is not installed`**: The wrapper will prompt to install it via `brew`. If `brew` is missing, you must install `gitleaks` manually.
- **`Possible secrets found`**: The wrapper halts execution to help reduce risk. Review the findings from `gitleaks`. If you are certain it's a false positive, you can override using `AGY_SAFE_ALLOW_RISK=1`, `CODEX_SAFE_ALLOW_RISK=1`, or `CLAUDE_SAFE_ALLOW_RISK=1`.
- **`agy CLI is not installed`**: Ensure the Antigravity CLI is installed and available in your shell's `$PATH`.
- **`codex CLI is not installed`**: Ensure the Codex CLI is installed and available in your shell's `$PATH`.
- **`claude CLI is not installed`**: Ensure Claude Code is installed and available in your shell's `$PATH`.
- **Claude Code exits with a sandbox error**: `failIfUnavailable: true` makes `claude-safe` abort rather than run unsandboxed. On Linux/WSL2, install the sandbox dependencies with `sudo apt-get install bubblewrap socat` (or your distro's equivalent), then retry.

## Updating the Wrapper
To modify the wrapper, edit the safe wrapper functions in your `~/.zshrc`. 
Always back up `.zshrc` before making changes:
```bash
cp ~/.zshrc ~/.zshrc.backup
```
And validate syntax after changes:
```bash
zsh -n ~/.zshrc
source ~/.zshrc
```
