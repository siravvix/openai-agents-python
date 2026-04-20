#!/usr/bin/env bash
# examples-auto-run/scripts/run.sh
# Automatically discovers and runs all examples in the repository,
# capturing output and reporting pass/fail status.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
EXAMPLES_DIR="${REPO_ROOT}/examples"
LOG_DIR="${REPO_ROOT}/.agents/skills/examples-auto-run/logs"
TIMEOUT_SECONDS=${TIMEOUT_SECONDS:-60}
PYTHON=${PYTHON:-python}
PASSED=0
FAILED=0
SKIPPED=0
FAILED_EXAMPLES=()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[examples-auto-run] $*"; }
warn() { echo "[examples-auto-run] WARNING: $*" >&2; }
err()  { echo "[examples-auto-run] ERROR: $*" >&2; }

require_command() {
  if ! command -v "$1" &>/dev/null; then
    err "Required command not found: $1"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
require_command "$PYTHON"
require_command timeout

if [[ ! -d "$EXAMPLES_DIR" ]]; then
  err "Examples directory not found: $EXAMPLES_DIR"
  exit 1
fi

mkdir -p "$LOG_DIR"

# ---------------------------------------------------------------------------
# Determine which examples to run
# ---------------------------------------------------------------------------
# Collect all top-level Python files and directories containing a main.py
mapfile -t EXAMPLE_FILES < <(
  find "$EXAMPLES_DIR" -maxdepth 2 -name '*.py' \
    | grep -v '__pycache__' \
    | grep -v 'conftest' \
    | sort
)

if [[ ${#EXAMPLE_FILES[@]} -eq 0 ]]; then
  warn "No example files found under $EXAMPLES_DIR"
  exit 0
fi

log "Found ${#EXAMPLE_FILES[@]} example file(s) to evaluate."

# ---------------------------------------------------------------------------
# Check whether an example should be skipped
# An example is skipped when it contains a marker comment:
#   # examples-auto-run: skip
# or when it requires interactive input / live API keys that are absent.
# ---------------------------------------------------------------------------
should_skip() {
  local file="$1"
  # Explicit skip marker
  if grep -q 'examples-auto-run: skip' "$file"; then
    return 0
  fi
  # Skip if file uses input() and we are in non-interactive mode
  if grep -q 'input(' "$file" && [[ ! -t 0 ]]; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Run a single example
# ---------------------------------------------------------------------------
run_example() {
  local file="$1"
  local rel_path="${file#"$REPO_ROOT/"}"
  local log_file="${LOG_DIR}/$(echo "$rel_path" | tr '/' '_').log"

  if should_skip "$file"; then
    log "SKIP  $rel_path"
    (( SKIPPED++ )) || true
    return
  fi

  log "RUN   $rel_path"

  local exit_code=0
  timeout "$TIMEOUT_SECONDS" \
    "$PYTHON" "$file" \
    > "$log_file" 2>&1 \
    || exit_code=$?

  if [[ $exit_code -eq 124 ]]; then
    warn "TIMEOUT ($TIMEOUT_SECONDS s) — $rel_path"
    echo "[TIMEOUT after ${TIMEOUT_SECONDS}s]" >> "$log_file"
    (( FAILED++ )) || true
    FAILED_EXAMPLES+=("$rel_path (timeout)")
  elif [[ $exit_code -ne 0 ]]; then
    err "FAIL  $rel_path (exit $exit_code)"
    (( FAILED++ )) || true
    FAILED_EXAMPLES+=("$rel_path (exit $exit_code)")
  else
    log "PASS  $rel_path"
    (( PASSED++ )) || true
  fi
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
for example in "${EXAMPLE_FILES[@]}"; do
  run_example "$example"
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
log "========================================"
log "Results: PASSED=$PASSED  FAILED=$FAILED  SKIPPED=$SKIPPED"
log "Logs written to: $LOG_DIR"

if [[ ${#FAILED_EXAMPLES[@]} -gt 0 ]]; then
  log "Failed examples:"
  for ex in "${FAILED_EXAMPLES[@]}"; do
    log "  - $ex"
  done
  log "========================================"
  exit 1
fi

log "========================================"
exit 0
