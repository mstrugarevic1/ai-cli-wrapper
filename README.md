# AI CLI Wrapper

Shell wrappers that run local safety checks before starting AI coding CLIs:
Antigravity / Gemini, Codex, and Claude.

The wrappers scan the current Git repository for secrets with Gitleaks, show the
working directory and Git status before launch, and start each CLI with the
sandbox or default permission mode supported by that CLI. They are a guardrail,
not a security boundary.

The shared bash/zsh implementation lives in `scripts/ai-safe.sh`.

## Wrappers

- `agy-safe`
- `gemini-safe`
- `codex-safe`
- `claude-safe`

`gemini-safe` is a legacy alias that delegates to `agy-safe`.

## Install

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

The installer detects your shell from `$SHELL`. You can also choose explicitly:

```zsh
./install.sh zsh
./install.sh bash
./install.sh both
```

It copies `scripts/ai-safe.sh` to:

```text
~/.config/ai-cli-wrapper/scripts/ai-safe.sh
```

Then it adds this line to `~/.zshrc` or `~/.bashrc` if it is missing:

```zsh
source ~/.config/ai-cli-wrapper/scripts/ai-safe.sh
```

Before changing the rc file, the installer writes a backup at
`<rc>.ai-cli-wrapper.backup`.

On macOS, Terminal may start bash as a login shell and read `~/.bash_profile`
instead of `~/.bashrc`. In that case, source `~/.bashrc` from
`~/.bash_profile`, or add the wrapper source line there.

## Usage

```zsh
agy-safe
gemini-safe
codex-safe
claude-safe
```

Arguments are passed through to the underlying CLI:

```zsh
agy-safe --prompt "Review this repository"
codex-safe "Fix failing tests"
claude-safe
```

Claude starts with normal permission prompts:

```zsh
claude --permission-mode default
```

If your installed Claude CLI supports `--sandbox`, you can request it with:

```zsh
CLAUDE_SAFE_SANDBOX=1 claude-safe
```

If sandbox mode is requested but unsupported, the wrapper stops unless this is
set:

```zsh
CLAUDE_SAFE_ALLOW_UNSANDBOXED=1
```

## Preflight

Before starting a CLI, each wrapper:

- requires the current directory to be inside a Git repository
- checks that the selected CLI, `git`, and `gitleaks` are available
- offers `brew install gitleaks` if Gitleaks is missing
- prints the current directory and `git status --short`
- scans the repository root with `gitleaks dir`
- scans Git history with `gitleaks git`
- blocks on Gitleaks findings unless an explicit override is set

The scans run against `git rev-parse --show-toplevel`, even when the wrapper is
started from a subdirectory.

Override variables:

```zsh
AGY_SAFE_ALLOW_RISK=1
GEMINI_SAFE_ALLOW_RISK=1
CODEX_SAFE_ALLOW_RISK=1
CLAUDE_SAFE_ALLOW_RISK=1
```

Use overrides only after reviewing the Gitleaks findings and accepting the risk.

## Requirements

Required for all wrappers: `zsh` or `bash`, `git`, and `gitleaks`.

Install the CLI you plan to use: `agy`, `codex`, or `claude`.

## Update

```zsh
cd ~/.config/ai-cli-wrapper-source
make update
```

`make update` runs `git pull` and `./install.sh` for the shell detected from
`$SHELL`. To update both shells after pulling, run:

```zsh
./install.sh both
```

## Validation

```zsh
make lint
```

This checks shell syntax for the shared wrapper and installer, then runs the
preflight test script.

## Limitations

This wrapper is not a complete security boundary. Gitleaks can have false
positives and false negatives, and sandbox behavior depends on the installed
CLI version.

Do not run AI coding tools inside repositories containing real secrets.

## Disclaimer

This software is provided "as is", without warranty of any kind. You run it at
your own risk.
