#!/usr/bin/env bash
# Lint and Format Skill - run.sh
# Runs linting and formatting checks (and optionally auto-fixes) on the repository.
# Usage: bash run.sh [--fix]

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
FIX_MODE=false
EXIT_CODE=0

# Parse arguments
for arg in "$@"; do
  case $arg in
    --fix)
      FIX_MODE=true
      shift
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Usage: bash run.sh [--fix]"
      exit 1
      ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
log_info()  { echo "[INFO]  $*"; }
log_ok()    { echo "[OK]    $*"; }
log_warn()  { echo "[WARN]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }

require_tool() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Required tool '$1' not found. Please install it and retry."
    exit 1
  fi
}

# ── Environment setup ─────────────────────────────────────────────────────────
log_info "Checking required tools..."
require_tool python3
require_tool pip

# Ensure dev dependencies are available
if [ -f "pyproject.toml" ]; then
  log_info "Installing dev dependencies from pyproject.toml..."
  pip install --quiet ".[dev]" 2>/dev/null || pip install --quiet ruff mypy 2>/dev/null
elif [ -f "requirements-dev.txt" ]; then
  log_info "Installing dev dependencies from requirements-dev.txt..."
  pip install --quiet -r requirements-dev.txt
else
  log_warn "No pyproject.toml or requirements-dev.txt found; attempting to install ruff and mypy directly."
  pip install --quiet ruff mypy
fi

# ── Ruff: lint ────────────────────────────────────────────────────────────────
log_info "Running ruff linter..."
if $FIX_MODE; then
  if ruff check --fix .; then
    log_ok "ruff lint (fix mode) passed."
  else
    log_error "ruff lint reported issues that could not be auto-fixed."
    EXIT_CODE=1
  fi
else
  if ruff check .; then
    log_ok "ruff lint passed."
  else
    log_error "ruff lint failed. Run with --fix to attempt auto-fixes."
    EXIT_CODE=1
  fi
fi

# ── Ruff: format ─────────────────────────────────────────────────────────────
log_info "Running ruff formatter..."
if $FIX_MODE; then
  if ruff format .; then
    log_ok "ruff format (fix mode) applied."
  else
    log_error "ruff format encountered an error."
    EXIT_CODE=1
  fi
else
  if ruff format --check .; then
    log_ok "ruff format check passed."
  else
    log_error "ruff format check failed. Run with --fix to auto-format."
    EXIT_CODE=1
  fi
fi

# ── Mypy: type checking ───────────────────────────────────────────────────────
log_info "Running mypy type checker..."
MYPY_ARGS=("--ignore-missing-imports")

# Detect source directory
if [ -d "src" ]; then
  MYPY_TARGET="src"
elif [ -d "agents" ]; then
  MYPY_TARGET="agents"
else
  MYPY_TARGET="."
fi

if mypy "${MYPY_ARGS[@]}" "$MYPY_TARGET"; then
  log_ok "mypy type check passed."
else
  log_error "mypy type check failed."
  EXIT_CODE=1
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [ $EXIT_CODE -eq 0 ]; then
  log_ok "All lint and format checks passed."
else
  log_error "One or more checks failed. Review the output above."
fi

exit $EXIT_CODE
