# Lint and Format Skill

This skill automatically checks and fixes code style issues in the repository using `ruff` for linting and `black` for formatting.

## What It Does

1. **Lint Check** — Runs `ruff check` to identify code style violations and potential bugs
2. **Format Check** — Runs `black --check` to identify formatting inconsistencies
3. **Auto-fix** — Optionally applies `ruff --fix` and `black` to automatically resolve issues
4. **Report** — Summarizes findings and any changes made

## When to Use

- After merging feature branches to ensure consistent code style
- Before cutting a release to clean up any accumulated style drift
- As part of CI validation to catch issues early
- When onboarding new contributors whose editors may not be configured

## Inputs

| Variable | Description | Default |
|---|---|---|
| `AUTO_FIX` | Whether to automatically apply fixes (`true`/`false`) | `false` |
| `TARGET_PATH` | Path within the repo to lint/format | `.` |
| `FAIL_ON_ERROR` | Exit with non-zero code if issues found | `true` |

## Outputs

- Console summary of lint violations and formatting issues
- Exit code `0` if clean (or fixes applied successfully), non-zero otherwise
- If `AUTO_FIX=true`, modified files are left staged for review

## Requirements

- Python 3.9+
- `ruff` and `black` installed (included in dev dependencies via `pyproject.toml`)
- Run from the repository root

## Example Usage

```bash
# Check only (no changes)
AUTO_FIX=false bash .agents/skills/lint-and-format/scripts/run.sh

# Auto-fix issues
AUTO_FIX=true bash .agents/skills/lint-and-format/scripts/run.sh

# Lint a specific subdirectory
TARGET_PATH=src/agents AUTO_FIX=false bash .agents/skills/lint-and-format/scripts/run.sh
```

## Notes

- `ruff` is preferred over `flake8`/`pylint` for speed; configuration lives in `pyproject.toml` under `[tool.ruff]`
- `black` formatting is non-negotiable; PRs with unformatted code will fail CI
- Type-checking (`mypy`/`pyright`) is handled separately by the `code-change-verification` skill
