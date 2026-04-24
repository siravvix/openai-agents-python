# Changelog Generator Skill

Automatically generates or updates a `CHANGELOG.md` file based on Git commit history, pull request titles, and conventional commit messages.

## What This Skill Does

1. **Analyzes Git history** — Reads commits since the last tagged release (or a configurable range)
2. **Categorizes changes** — Groups commits by type: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `breaking`
3. **Formats changelog** — Outputs a well-structured `CHANGELOG.md` following [Keep a Changelog](https://keepachangelog.com/) conventions
4. **Handles versioning** — Detects or accepts a version string; falls back to `Unreleased` section
5. **Preserves history** — Prepends new entries without overwriting existing changelog content

## Inputs

| Variable | Required | Default | Description |
|---|---|---|---|
| `VERSION` | No | `Unreleased` | The version label for this changelog entry |
| `FROM_REF` | No | last git tag | Starting git ref for commit range |
| `TO_REF` | No | `HEAD` | Ending git ref for commit range |
| `CHANGELOG_FILE` | No | `CHANGELOG.md` | Path to the changelog file |
| `REPO_URL` | No | auto-detected | Base URL for commit/PR links |

## Outputs

- Updated `CHANGELOG.md` with a new versioned section prepended
- Summary printed to stdout listing counts per category

## Conventions Supported

- [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, etc.)
- Breaking changes via `BREAKING CHANGE:` footer or `!` suffix (e.g., `feat!:`)
- Merge commit messages referencing PR numbers (`(#123)`)

## Example Usage

```bash
# Generate changelog for an upcoming release
VERSION=1.2.0 bash .agents/skills/changelog-generator/scripts/run.sh

# Generate for a specific commit range
FROM_REF=v1.1.0 TO_REF=v1.2.0 VERSION=1.2.0 bash .agents/skills/changelog-generator/scripts/run.sh

# PowerShell
$env:VERSION="1.2.0"; .agents/skills/changelog-generator/scripts/run.ps1
```

## Output Format

```markdown
## [1.2.0] - 2024-01-15

### Added
- feat: support streaming responses in agent runner (#142)

### Fixed
- fix: handle None tool call arguments gracefully (#139)

### Documentation
- docs: add tracing guide to README (#135)

### Breaking Changes
- feat!: rename `run_sync` to `run_sync_loop` for clarity (#140)
```

## Notes

- Commits that don't follow conventional commit format are placed under `### Other`
- The skill is non-destructive: it will not overwrite existing changelog entries
- If `CHANGELOG.md` does not exist, it will be created with a standard header
