# AI CLI Wrapper

## What it does

Reusable `zsh` wrapper functions for starting AI coding CLIs after local safety checks.

Supported wrappers:

- `agy-safe`
- `gemini-safe`
- `codex-safe`
- `claude-safe`

The implementation lives in `scripts/ai-safe.zsh`. Gitleaks scans the working directory and git history before the selected CLI starts. Antigravity and Codex start in sandbox mode. Claude starts without bypassing normal permission prompts, with optional sandbox mode when supported by the installed Claude CLI.

## Installation

```zsh
git clone https://github.com/mstrugarevic1/ai-cli-wrapper.git ~/.config/ai-cli-wrapper-source
cd ~/.config/ai-cli-wrapper-source
./install.sh
source ~/.zshrc
```

## Usage

```zsh
agy-safe
gemini-safe
codex-safe
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

- verify git repository
- print current directory
- print git status
- scan working directory with Gitleaks
- scan git history with Gitleaks
- stop on findings unless override is explicitly set
- start selected CLI

Gitleaks commands:

```zsh
gitleaks dir . --redact --verbose --timeout 120
gitleaks git . --redact --verbose --timeout 120
```

## Requirements

| Tool | Required for | Purpose |
|---|---|---|
| zsh | all wrappers | shell runtime |
| git | all wrappers | repository checks |
| gitleaks | all wrappers | secret scanning |
| agy | agy-safe / gemini-safe | Antigravity / Gemini CLI |
| codex | codex-safe | Codex CLI |
| claude | claude-safe | Claude CLI |

## Claude sandbox mode

`claude-safe` runs the shared pre-flight checks and starts Claude with normal permission handling. If the installed Claude CLI supports sandbox settings, `CLAUDE_SAFE_SANDBOX=1` enables sandbox mode.

## Limitations

- this is not a complete security boundary
- Gitleaks can have false positives and false negatives
- sandbox behavior depends on the underlying CLI
- Claude sandbox mode depends on installed Claude CLI support
- users must still review files, permissions and prompts
- do not run inside repositories containing real secrets

## Validation

```zsh
zsh -n scripts/ai-safe.zsh
zsh -n install.sh
make lint
```
