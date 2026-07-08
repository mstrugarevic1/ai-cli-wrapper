# AI CLI Wrapper

Shell wrappers that run local safety checks before starting AI coding CLIs (Antigravity / Gemini, Codex, Claude).

AI coding agents read files in the current repository and can send their contents to external services. If the repository contains secrets — API keys, tokens, credentials in config files or in old commits — those can leak. Agents can also execute commands with broad permissions in the wrong directory.

These wrappers reduce that risk before the CLI starts. They scan the working tree and full git history for secrets with Gitleaks and refuse to start on findings, print the directory and git status so a wrong location is visible up front, and launch each CLI in its sandbox or default-permission mode where supported.

The checks run locally and add a few seconds per start. They are a guardrail, not a security boundary; see Limitations.

The implementation lives in `scripts/ai-safe.zsh` (zsh) and `scripts/ai-safe.bash` (bash).

Supported wrappers:

- `agy-safe`
- `gemini-safe`
- `codex-safe`
- `claude-safe`

## What it does

The wrapper runs a small set of local checks before starting the selected AI CLI.

It checks that the current directory is a Git repository, prints the current directory and Git status, scans the working tree and Git history with Gitleaks, and only then starts the requested CLI.

Antigravity and Codex are started in sandbox mode where supported by their CLIs.

Claude is started without bypassing normal permission prompts. Optional Claude sandbox mode can be requested with `CLAUDE_SAFE_SANDBOX=1` when supported by the installed Claude CLI.

## Installation

Clone the repository:

```zsh
git clone https://github.com/mstrugarevic1/ai-cli-wrapper.git ~/.config/ai-cli-wrapper-source
cd ~/.config/ai-cli-wrapper-source
```

Run the installer:

```zsh
./install.sh
```

Reload your shell configuration:

```zsh
source ~/.zshrc
```

The installer copies `scripts/ai-safe.zsh` to:

```text
~/.config/ai-cli-wrapper/scripts/ai-safe.zsh
```

and adds this line to `~/.zshrc` if it is not already present:

```zsh
source ~/.config/ai-cli-wrapper/scripts/ai-safe.zsh
```

### Bash

The installer only sets up zsh. For bash, copy the script and source it from `~/.bashrc` manually. Skip the clone if the repository is already checked out:

```bash
git clone https://github.com/mstrugarevic1/ai-cli-wrapper.git ~/.config/ai-cli-wrapper-source
mkdir -p ~/.config/ai-cli-wrapper/scripts
cp ~/.config/ai-cli-wrapper-source/scripts/ai-safe.bash ~/.config/ai-cli-wrapper/scripts/ai-safe.bash
grep -Fxq 'source ~/.config/ai-cli-wrapper/scripts/ai-safe.bash' ~/.bashrc \
  || echo 'source ~/.config/ai-cli-wrapper/scripts/ai-safe.bash' >> ~/.bashrc
```

Reload your shell configuration:

```bash
source ~/.bashrc
```

On macOS, Terminal starts bash as a login shell, which reads `~/.bash_profile` instead of `~/.bashrc`. Either add the source line to `~/.bash_profile`, or make `~/.bash_profile` source `~/.bashrc`.

## Usage

Start Antigravity / Gemini:

```zsh
agy-safe
```

Legacy Gemini alias:

```zsh
gemini-safe
```

Start Codex:

```zsh
codex-safe
```

Start Claude:

```zsh
claude-safe
```

Examples:

```zsh
agy-safe --prompt "Review this repository"
codex-safe "Fix failing tests"
claude-safe
CLAUDE_SAFE_SANDBOX=1 claude-safe
```

## Pre-flight checks

Each wrapper performs these checks before starting the selected CLI:

- checks whether the current directory is inside a Git repository; if not, asks to continue anyway
- checks whether Gitleaks is installed; if not, offers to install it with `brew`
- prints the current directory
- prints `git status --short`
- scans the working directory with Gitleaks
- scans Git history with Gitleaks
- stops on findings unless an explicit override variable is set
- prints a CLI update hint (Antigravity, Claude) where available
- starts the selected CLI only after checks pass

Gitleaks commands:

```zsh
gitleaks dir . --redact --verbose --timeout 120 --exit-code 3
gitleaks git . --redact --verbose --timeout 120 --exit-code 3
```

Override variables:

```zsh
AGY_SAFE_ALLOW_RISK=1
GEMINI_SAFE_ALLOW_RISK=1
CODEX_SAFE_ALLOW_RISK=1
CLAUDE_SAFE_ALLOW_RISK=1
```

Use overrides only when you have reviewed the findings and accepted the risk.

## Requirements

| Tool | Required for | Purpose |
|---|---|---|
| zsh or bash | all wrappers | shell runtime |
| git | all wrappers | repository checks |
| gitleaks | all wrappers | secret scanning |
| agy | `agy-safe` / `gemini-safe` | Antigravity / Gemini CLI |
| codex | `codex-safe` | Codex CLI |
| claude | `claude-safe` | Claude CLI |

## Claude sandbox mode

`claude-safe` keeps Claude's normal permission prompts.

By default, it runs the shared pre-flight checks and starts Claude with normal permission handling:

```zsh
claude --permission-mode default
```

If the installed Claude CLI supports a sandbox flag, this can be requested with:

```zsh
CLAUDE_SAFE_SANDBOX=1 claude-safe
```

If sandbox mode is requested but not supported by the installed Claude CLI, the wrapper stops unless this explicit override is set:

```zsh
CLAUDE_SAFE_ALLOW_UNSANDBOXED=1
```

## Limitations

This wrapper is not a complete security boundary.

Gitleaks can have false positives and false negatives. Sandbox behavior depends on the underlying CLI. Claude sandbox support depends on the installed Claude CLI version.

Users still need to review files, permissions, prompts, and tool output.

Do not run AI coding tools inside repositories containing real secrets.

## Validation

Run:

```zsh
zsh -n scripts/ai-safe.zsh
bash -n scripts/ai-safe.bash
zsh -n install.sh
make lint
```
