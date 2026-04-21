#!/usr/bin/env bash
# Dependency Update Skill
# Automatically checks for outdated dependencies and creates update PRs
# Usage: ./run.sh [--dry-run] [--major] [--minor] [--patch]

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
DRY_RUN=false
UPDATE_MAJOR=false
UPDA
UPDATE_PATCH=true
BRANCH_PREFIX="deps/update"
COMMIT_MESSAGE_PREFIX="chore(deps): update"

# ─── Argument Parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=true;    shift ;;
    --major)     UPDATE_MAJOR=true; shift ;;
    --no-minor)  UPDATE_MINOR=false; shift ;;
    --no-patch)  UPDATE_PATCH=false; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
err()  { echo "[ERROR] $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || err "Required command not found: $1"
}

# ─── Prerequisites ────────────────────────────────────────────────────────────
require_cmd python3
require_cmd pip
REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

log "Repository root: $REPO_ROOT"
log "Dry run: $DRY_ Detect Package Manager ───────────────────────────────────────────────────
if [[ -f "pyproject.toml" ]]; then
  PKG_MANAGER="uv"
  require_cmd uv
elif [[ -f "requirements.txt" ]]; then
  PKG_MANAGER="pip"
else
  err "No supported package manifest found (pyproject.toml or requirements.txt)"
fi

log "Package manager: $PKG_MANAGER"

# ─── Fetch Outdated Packages ──────────────────────────────────────────────────
log "Checking for outdated packages..."

if [[ "$PKG_MANAGER" == "uv" ]]; then
  OUTDATED_JSON=$(uv pip list --outdated --format=json 2>/dev/null || echo "[]")
else
  OUTDATED_JSON=$(pip list --outdated --format=json 2>/dev/null || echo "[]")
fi

PACKAGE_COUNT=$(echo "$OUTDATED_JSON" | python3 -c "
import sys, json
pkgs = json.load(sys.stdin)
print(len(pkgs))
")

if [[ "$PACKAGE_COUNT" -eq 0 ]]; then
  log "All dependencies are up to date. Nothing to do."
  exit 0
fi

log "Found $PACKAGE_COUNT outdated package(s)."

# ─── Filter by Semver Level ───────────────────────────────────────────────────
FILTERED_PACKAGES=$(echo "$OUTDATED_JSON" | python3 - <<'PYEOF'
import sys, json, os

data = json.load(sys.stdin)
update_major = os.environ.get("UPDATE_MAJOR", "false") == "true"
update_minor = os.environ.get("UPDATE_MINOR", "true") == "true"
update_patch = os.environ.get("UPDATE_PATCH", "true") == "true"

result = []
for pkg in data:
    cur  = [int(x) for x in pkg["version"].split(".")[:3]]
    new  = [int(x) for x in pkg["latest_version"].split(".")[:3]]
    if new[0] > cur[0] and update_major:
        result.append(pkg)
    elif new[0] == cur[0] and new[1] > cur[1] and update_minor:
        result.append(pkg)
    elif new[0] == cur[0] and new[1] == cur[1] and new[2] > cur[2] and update_patch:
        result.append(pkg)

print(json.dumps(result))
PYEOF
)

export UPDATE_MAJOR UPDATE_MINOR UPDATE_PATCH

FILTERED_COUNT=$(echo "$FILTERED_PACKAGES" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

if [[ "$FILTERED_COUNT" -eq 0 ]]; then
  log "No packages match the selected update policy. Exiting."
  exit 0
fi

log "$FILTERED_COUNT package(s) eligible for update."

# ─── Apply Updates ────────────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BRANCH_NAME="${BRANCH_PREFIX}-${TIMESTAMP}"

if [[ "$DRY_RUN" == "false" ]]; then
  git checkout -b "$BRANCH_NAME"
  log "Created branch: $BRANCH_NAME"
fi

echo "$FILTERED_PACKAGES" | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    print(p['name'], p['latest_version'])
" | while read -r PKG VERSION; do
  log "Updating $PKG → $VERSION"
  if [[ "$DRY_RUN" == "false" ]]; then
    if [[ "$PKG_MANAGER" == "uv" ]]; then
      uv add "${PKG}==${VERSION}" --quiet
    else
      pip install --quiet "${PKG}==${VERSION}"
    fi
  fi
done

# ─── Commit & Summary ─────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "false" ]]; then
  git add pyproject.toml uv.lock requirements*.txt 2>/dev/null || true

  SUMMARY=$(echo "$FILTERED_PACKAGES" | python3 -c "
import sys, json
lines = []
for p in json.load(sys.stdin):
    lines.append(f\"{p['name']} {p['version']} -> {p['latest_version']}\")
print(', '.join(lines))
")

  git commit -m "${COMMIT_MESSAGE_PREFIX} dependencies" \
             -m "Updated: ${SUMMARY}" \
    || warn "Nothing to commit — lock file may not have changed."

  log "Changes committed on branch '$BRANCH_NAME'."
  log "Push the branch and open a pull request to complete the update."
else
  log "[DRY RUN] Would update the following packages:"
  echo "$FILTERED_PACKAGES" | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    print(f\"  {p['name']:40s} {p['version']} -> {p['latest_version']}\")
"
fi

log "Dependency update skill finished."
