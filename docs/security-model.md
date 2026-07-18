# Security Model

This project is a local guardrail for AI coding CLIs. It is not a security
boundary.

## What Preflight Checks

Each wrapper runs the same preflight before starting the selected CLI:

- verifies the selected CLI and `git` are installed
- requires the current directory to be inside a Git repository
- verifies `gitleaks` is installed, or offers `brew install gitleaks`
- prints the current directory
- prints `git status --short`
- runs `gitleaks dir` against the repository root
- runs `gitleaks git` against the repository root

The repository root is resolved with:

```zsh
git rev-parse --show-toplevel
```

So running a wrapper from a subdirectory still scans the whole repository.

## Non-Git Directories

The wrapper refuses to start outside a Git repository, because AI edits there
cannot be undone with Git. To run in a throwaway or temporary directory anyway:

```zsh
AI_SAFE_ALLOW_NO_GIT=1 codex-safe
```

This still runs the `gitleaks dir` working directory scan, but skips `git status`
and the `gitleaks git` history scan (there is no history to scan).

## Findings And Overrides

Gitleaks exits with code `3` when it finds secrets. The wrapper blocks startup in
that case.

Override only after reviewing the findings:

```zsh
AGY_SAFE_ALLOW_RISK=1 agy-safe
GEMINI_SAFE_ALLOW_RISK=1 gemini-safe
CODEX_SAFE_ALLOW_RISK=1 codex-safe
CLAUDE_SAFE_ALLOW_RISK=1 claude-safe
```

Other Gitleaks failures still stop the wrapper.

## CLI Launch Modes

Antigravity:

```zsh
agy --sandbox
```

Codex:

```zsh
codex --sandbox workspace-write
```

Claude:

```zsh
claude --permission-mode default
```

Claude sandbox mode is opt-in and only used when the installed Claude CLI lists
`--sandbox` in `claude --help`:

```zsh
CLAUDE_SAFE_SANDBOX=1 claude-safe
```

If sandbox mode is requested but unsupported, startup is blocked unless this is
set:

```zsh
CLAUDE_SAFE_ALLOW_UNSANDBOXED=1
```

## Limits

Gitleaks can miss secrets and can report false positives. CLI sandbox behavior
depends on the installed CLI version.

Do not run AI coding tools inside repositories that contain real secrets.
