# Security Scan Skill

This skill performs automated security scanning on the codebase to identify vulnerabilities, insecure dependencies, and common security anti-patterns.

## What It Does

1. **Dependency Vulnerability Scan** — Uses `pip-audit` to check for known CVEs in project dependencies
2. **Static Analysis** — Uses `bandit` to detect common security issues in Python code
3. **Secret Detection** — Scans for accidentally committed secrets, API keys, or credentials
4. **Dependency License Check** — Flags dependencies with potentially problematic licenses

## When to Use

- Before merging pull requests that update dependencies
- After adding new third-party integrations
- As part of a periodic security review
- When onboarding new contributors to verify the baseline is clean

## Inputs

| Variable | Description | Required | Default |
|---|---|---|---|
| `SCAN_PATH` | Path to scan (relative to repo root) | No | `.` |
| `SEVERITY_THRESHOLD` | Minimum severity to fail: `low`, `medium`, `high`, `critical` | No | `medium` |
| `SKIP_TESTS` | Skip scanning test directories | No | `false` |
| `OUTPUT_FORMAT` | Report format: `text`, `json`, `sarif` | No | `text` |

## Outputs

- Console report of all findings grouped by severity
- `security-report.json` artifact with full scan results
- Exit code `0` if no issues above threshold, `1` otherwise

## Tools Used

- [`pip-audit`](https://github.com/pypa/pip-audit) — Python dependency vulnerability scanner
- [`bandit`](https://bandit.readthedocs.io/) — Python AST-based security linter
- [`detect-secrets`](https://github.com/Yelp/detect-secrets) — Secret detection in source code

## Setup

All tools are installed automatically by the skill scripts. No manual setup required.

```bash
# Run locally (Linux/macOS)
bash .agents/skills/security-scan/scripts/run.sh

# Run locally (Windows)
pwsh .agents/skills/security-scan/scripts/run.ps1
```

## Example Output

```
[Security Scan] Starting security scan...
[Security Scan] Running pip-audit for dependency vulnerabilities...
  ✓ No vulnerable dependencies found
[Security Scan] Running bandit for static analysis...
  ⚠ HIGH: B608 - Possible SQL injection via string-based query (src/db.py:42)
[Security Scan] Running detect-secrets...
  ✓ No secrets detected
[Security Scan] Scan complete. 1 issue(s) found above threshold.
```

## Notes

- The skill respects `.banditignore` and `.secrets.baseline` files if present in the repo root
- False positives can be suppressed with `# nosec` inline comments for bandit
- Run `detect-secrets scan > .secrets.baseline` to establish a baseline before first use
