#!/usr/bin/env bash
# Test Coverage Skill - Run Script
# Analyzes test coverage for the openai-agents-python project and reports gaps

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
MIN_COVERAGE_THRESHOLD=${MIN_COVERAGE_THRESHOLD:-80}
COVERAGE_REPORT_DIR="coverage_reports"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Helpers ─────────────────────────────────────────────────────────────────
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_dependency() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Required tool not found: $1"
    exit 1
  fi
}

# ─── Dependency Checks ───────────────────────────────────────────────────────
check_dependency python3
check_dependency pip

log_info "Project root: ${PROJECT_ROOT}"
cd "${PROJECT_ROOT}"

# ─── Install Coverage Dependencies ───────────────────────────────────────────
log_info "Ensuring coverage tools are installed..."
pip install --quiet coverage pytest pytest-cov 2>&1 | tail -5

# ─── Create Report Directory ─────────────────────────────────────────────────
mkdir -p "${COVERAGE_REPORT_DIR}"

# ─── Run Tests with Coverage ─────────────────────────────────────────────────
log_info "Running test suite with coverage tracking..."

COVERAGE_FILE="${COVERAGE_REPORT_DIR}/.coverage_${TIMESTAMP}"

if ! python3 -m pytest \
    --cov=src \
    --cov-report=term-missing \
    --cov-report="html:${COVERAGE_REPORT_DIR}/html_${TIMESTAMP}" \
    --cov-report="xml:${COVERAGE_REPORT_DIR}/coverage_${TIMESTAMP}.xml" \
    --cov-report="json:${COVERAGE_REPORT_DIR}/coverage_${TIMESTAMP}.json" \
    --cov-config=pyproject.toml \
    -q \
    tests/ 2>&1 | tee "${COVERAGE_REPORT_DIR}/test_output_${TIMESTAMP}.txt"; then
  log_warn "Some tests failed — coverage data may be incomplete."
fi

# ─── Parse Coverage Results ──────────────────────────────────────────────────
log_info "Parsing coverage results..."

COVERAGE_JSON="${COVERAGE_REPORT_DIR}/coverage_${TIMESTAMP}.json"

if [[ ! -f "${COVERAGE_JSON}" ]]; then
  log_error "Coverage JSON report not found: ${COVERAGE_JSON}"
  exit 1
fi

# Extract total coverage percentage using python
TOTAL_COVERAGE=$(python3 - <<EOF
import json, sys
try:
    with open("${COVERAGE_JSON}") as f:
        data = json.load(f)
    pct = data.get("totals", {}).get("percent_covered", 0)
    print(f"{pct:.1f}")
except Exception as e:
    print("0.0")
EOF
)

log_info "Total coverage: ${TOTAL_COVERAGE}%"

# ─── Identify Uncovered Files ─────────────────────────────────────────────────
log_info "Identifying files below threshold (${MIN_COVERAGE_THRESHOLD}%)..."

python3 - <<'PYEOF'
import json, os, sys

coverage_json = None
for f in sorted(os.listdir("coverage_reports"), reverse=True):
    if f.startswith("coverage_") and f.endswith(".json"):
        coverage_json = os.path.join("coverage_reports", f)
        break

if not coverage_json:
    print("No coverage JSON found.")
    sys.exit(0)

with open(coverage_json) as fh:
    data = json.load(fh)

threshold = float(os.environ.get("MIN_COVERAGE_THRESHOLD", 80))
files = data.get("files", {})
below = []

for filepath, info in files.items():
    pct = info.get("summary", {}).get("percent_covered", 100)
    if pct < threshold:
        missing = info.get("missing_lines", [])
        below.append((filepath, pct, missing))

below.sort(key=lambda x: x[1])

if below:
    print(f"\n{'File':<60} {'Coverage':>10}  Missing Lines")
    print("-" * 100)
    for fp, pct, missing in below:
        missing_str = ", ".join(str(l) for l in missing[:10])
        if len(missing) > 10:
            missing_str += f" (+{len(missing)-10} more)"
        print(f"{fp:<60} {pct:>9.1f}%  {missing_str}")
else:
    print(f"All files meet the {threshold}% coverage threshold. ✓")
PYEOF

# ─── Threshold Check ─────────────────────────────────────────────────────────
TOTAL_INT=$(echo "${TOTAL_COVERAGE}" | cut -d'.' -f1)

if (( TOTAL_INT >= MIN_COVERAGE_THRESHOLD )); then
  log_ok "Coverage ${TOTAL_COVERAGE}% meets minimum threshold of ${MIN_COVERAGE_THRESHOLD}%"
  EXIT_CODE=0
else
  log_error "Coverage ${TOTAL_COVERAGE}% is below minimum threshold of ${MIN_COVERAGE_THRESHOLD}%"
  EXIT_CODE=1
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
log_info "Reports saved to: ${COVERAGE_REPORT_DIR}/"
log_info "  HTML : ${COVERAGE_REPORT_DIR}/html_${TIMESTAMP}/index.html"
log_info "  XML  : ${COVERAGE_REPORT_DIR}/coverage_${TIMESTAMP}.xml"
log_info "  JSON : ${COVERAGE_REPORT_DIR}/coverage_${TIMESTAMP}.json"

exit ${EXIT_CODE}
