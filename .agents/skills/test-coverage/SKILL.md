# Test Coverage Skill

This skill analyzes and improves test coverage for the openai-agents-python project.

## Overview

The test coverage skill performs the following tasks:

1. **Coverage Analysis** — Runs the test suite with coverage tracking and generates a detailed report
2. **Gap Identification** — Identifies modules, classes, and functions lacking adequate test coverage
3. **Test Generation** — Suggests or generates new tests to fill coverage gaps
4. **Threshold Enforcement** — Fails the check if coverage drops below the configured minimum threshold

## Usage

### Running the Skill

**Linux/macOS:**
```bash
bash .agents/skills/test-coverage/scripts/run.sh
```

**Windows (PowerShell):**
```powershell
.agents/skills/test-coverage/scripts/run.ps1
```

### Configuration

The skill reads configuration from environment variables:

| Variable | Default | Description |
|---|---|---|
| `COVERAGE_MIN_THRESHOLD` | `80` | Minimum acceptable coverage percentage (0-100) |
| `COVERAGE_REPORT_FORMAT` | `term-missing` | Report format: `term`, `term-missing`, `html`, `xml`, `json` |
| `COVERAGE_FAIL_UNDER` | `true` | Whether to exit non-zero if threshold not met |
| `COVERAGE_INCLUDE_PATTERNS` | `src/**` | Glob patterns for files to include in coverage |
| `COVERAGE_OMIT_PATTERNS` | `tests/**,**/__init__.py` | Glob patterns for files to omit |
| `COVERAGE_HTML_DIR` | `htmlcov` | Output directory for HTML reports |

## Output

The skill produces:

- A **terminal report** showing per-file coverage percentages and missing line numbers
- An optional **HTML report** for detailed line-by-line inspection
- A **JSON summary** written to `.agents/skills/test-coverage/output/coverage-summary.json`
- A **coverage badge** value written to `.agents/skills/test-coverage/output/badge.txt`

## Thresholds & CI Integration

Add the following to your CI pipeline to enforce coverage:

```yaml
- name: Check test coverage
  run: bash .agents/skills/test-coverage/scripts/run.sh
  env:
    COVERAGE_MIN_THRESHOLD: 85
    COVERAGE_REPORT_FORMAT: xml
```

The script exits with code `0` on success and `1` if:
- Tests fail to run
- Coverage falls below `COVERAGE_MIN_THRESHOLD` (when `COVERAGE_FAIL_UNDER=true`)
- Required dependencies (`pytest`, `pytest-cov`) are not installed

## Dependencies

- `pytest >= 7.0`
- `pytest-cov >= 4.0`
- `coverage >= 7.0`

Install with:
```bash
pip install pytest pytest-cov coverage
```
