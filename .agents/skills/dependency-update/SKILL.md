# Dependency Update Skill

This skill automates the process of checking for outdated dependencies, evaluating compatibility, and applying safe updates to the project.

## Overview

The dependency update skill performs the following steps:

1. **Audit current dependencies** — Scans `pyproject.toml` and `requirements*.txt` files for declared dependencies.
2. **Check for updates** — Uses `pip index versions` and PyPI API to identify newer versions.
3. **Evaluate compatibility** — Runs the test suite against candidate updates to verify nothing breaks.
4. **Apply safe updates** — Updates version pins for dependencies that pass compatibility checks.
5. **Generate report** — Produces a summary of applied updates, skipped updates, and any failures.

## Usage

### Running the skill

**Linux/macOS:**
```bash
bash .agents/skills/dependency-update/scripts/run.sh
```

**Windows (PowerShell):**
```powershell
.agents/skills/dependency-update/scripts/run.ps1
```

## Configuration

The skill respects the following environment variables:

| Variable | Default | Description |
|---|---|---|
| `DEP_UPDATE_DRY_RUN` | `false` | If `true`, report changes without applying them |
| `DEP_UPDATE_EXCLUDE` | `` | Comma-separated list of packages to skip |
| `DEP_UPDATE_ALLOW_MAJOR` | `false` | If `true`, allow major version bumps |
| `DEP_UPDATE_TEST_CMD` | `pytest` | Command used to validate updates |

## Output

The skill writes results to `dependency-update-report.md` in the repository root.

## Constraints

- Only updates packages listed in `pyproject.toml` under `[project.dependencies]` or `[project.optional-dependencies]`.
- Skips packages pinned with `==` unless `DEP_UPDATE_ALLOW_EXACT` is set to `true`.
- Requires a passing baseline test run before applying any updates.
- Each dependency is updated and tested in isolation before being committed to the final changeset.

## Notes

- This skill does **not** commit changes automatically. It prepares a diff for human review.
- Compatible with both `pip` and `uv` package managers (auto-detected).
