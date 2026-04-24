#!/usr/bin/env bash
# Changelog Generator Skill
# Generates or updates CHANGELOG.md based on git history and conventional commits

set -euo pipefail

# ─── Configuration ────────────────────────────────────────────────────────────
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
FROM_TAG="${FROM_TAG:-}"
TO_REF="${TO_REF:-HEAD}"
REPO_URL="${REPO_URL:-}"
INCLUDE_UNRELEASED="${INCLUDE_UNRELEASED:-true}"
DRY_RUN="${DRY_RUN:-false}"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo "[changelog] $*"; }
warn() { echo "[changelog] WARNING: $*" >&2; }
err()  { echo "[changelog] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || err "Required command not found: $1"
}

# ─── Dependency checks ────────────────────────────────────────────────────────
require_cmd git

# ─── Detect repo URL if not provided ──────────────────────────────────────────
if [[ -z "$REPO_URL" ]]; then
  REPO_URL=$(git remote get-url origin 2>/dev/null || true)
  # Normalise SSH → HTTPS
  REPO_URL=$(echo "$REPO_URL" | sed -E 's|git@github\.com:(.+)\.git|https://github.com/\1|')
  REPO_URL=$(echo "$REPO_URL" | sed -E 's|\.git$||')
fi

# ─── Resolve tag range ────────────────────────────────────────────────────────
get_latest_tag() {
  git tag --sort=-version:refname | grep -E '^v?[0-9]+\.[0-9]+' | head -n1 || true
}

if [[ -z "$FROM_TAG" ]]; then
  FROM_TAG=$(get_latest_tag)
  if [[ -z "$FROM_TAG" ]]; then
    log "No existing tags found; collecting full history."
    GIT_RANGE="$TO_REF"
  else
    GIT_RANGE="${FROM_TAG}..${TO_REF}"
  fi
else
  GIT_RANGE="${FROM_TAG}..${TO_REF}"
fi

log "Collecting commits: ${GIT_RANGE:-<all>}"

# ─── Collect commits ──────────────────────────────────────────────────────────
# Format: <hash> <subject>
MAPPED_COMMITS=$(git log ${GIT_RANGE} --no-merges --pretty=format:"%H %s" 2>/dev/null || true)

if [[ -z "$MAPPED_COMMITS" ]]; then
  log "No new commits found in range. Nothing to do."
  exit 0
fi

# ─── Parse conventional commits ───────────────────────────────────────────────
declare -a FEAT=() FIX=() DOCS=() CHORE=() REFACTOR=() PERF=() TEST=() BREAKING=()

while IFS= read -r line; do
  hash=$(echo "$line" | cut -d' ' -f1)
  subject=$(echo "$line" | cut -d' ' -f2-)
  short_hash="${hash:0:7}"

  # Detect breaking changes
  if echo "$subject" | grep -qE '!:|BREAKING CHANGE'; then
    BREAKING+=("- ${subject} ([\`${short_hash}\`](${REPO_URL}/commit/${hash}))")
  fi

  if   echo "$subject" | grep -qE '^feat(\(.+\))?!?:';     then FEAT+=("- ${subject} ([\`${short_hash}\`](${REPO_URL}/commit/${hash}))")
  elif echo "$subject" | grep -qE '^fix(\(.+\))?!?:';      then FIX+=("- ${subject} ([\`${short_hash}\`](${REPO_URL}/commit/${hash}))")
  elif echo "$subject" | grep -qE '^docs(\(.+\))?!?:';     then DOCS+=("- ${subject} ([\`${short_hash}\`](${REPO_URL}/commit/${hash}))")
  elif echo "$subject" | grep -qE '^refactor(\(.+\))?!?:'; then REFACTOR+=("- ${subject} ([\`${short_hash}\`](${REPO_URL}/commit/${hash}))")
  elif echo "$subject" | grep -qE '^perf(\(.+\))?!?:';     then PERF+=("- ${subject} ([\`${short_hash}\`](${REPO_URL}/commit/${hash}))")
  elif echo "$subject" | grep -qE '^test(\(.+\))?!?:';     then TEST+=("- ${subject} ([\`${short_hash}\`](${REPO_URL}/commit/${hash}))")
  elif echo "$subject" | grep -qE '^chore(\(.+\))?!?:';    then CHORE+=("- ${subject} ([\`${short_hash}\`](${REPO_URL}/commit/${hash}))")
  fi
done <<< "$MAPPED_COMMITS"

# ─── Build changelog section ──────────────────────────────────────────────────
DATE=$(date +%Y-%m-%d)
NEW_VERSION="${NEW_VERSION:-Unreleased}"

build_section() {
  local title="$1"
  shift
  local entries=("$@")
  if [[ ${#entries[@]} -gt 0 ]]; then
    echo "### ${title}"
    echo ""
    for entry in "${entries[@]}"; do
      echo "$entry"
    done
    echo ""
  fi
}

SECTION=""
if [[ "$INCLUDE_UNRELEASED" == "true" || -n "$NEW_VERSION" ]]; then
  if [[ -n "$REPO_URL" && -n "$FROM_TAG" ]]; then
    COMPARE_URL="${REPO_URL}/compare/${FROM_TAG}...${TO_REF}"
    SECTION+="## [${NEW_VERSION}](${COMPARE_URL}) - ${DATE}\n\n"
  else
    SECTION+="## [${NEW_VERSION}] - ${DATE}\n\n"
  fi
fi

[[ ${#BREAKING[@]}  -gt 0 ]] && SECTION+="$(build_section '⚠ Breaking Changes' "${BREAKING[@]}")\n"
[[ ${#FEAT[@]}      -gt 0 ]] && SECTION+="$(build_section 'Features' "${FEAT[@]}")\n"
[[ ${#FIX[@]}       -gt 0 ]] && SECTION+="$(build_section 'Bug Fixes' "${FIX[@]}")\n"
[[ ${#PERF[@]}      -gt 0 ]] && SECTION+="$(build_section 'Performance Improvements' "${PERF[@]}")\n"
[[ ${#REFACTOR[@]}  -gt 0 ]] && SECTION+="$(build_section 'Refactoring' "${REFACTOR[@]}")\n"
[[ ${#DOCS[@]}      -gt 0 ]] && SECTION+="$(build_section 'Documentation' "${DOCS[@]}")\n"
[[ ${#TEST[@]}      -gt 0 ]] && SECTION+="$(build_section 'Tests' "${TEST[@]}")\n"
[[ ${#CHORE[@]}     -gt 0 ]] && SECTION+="$(build_section 'Chores' "${CHORE[@]}")\n"

# ─── Write / preview ──────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  log "Dry-run mode — changelog section that would be written:"
  echo -e "$SECTION"
  exit 0
fi

if [[ -f "$CHANGELOG_FILE" ]]; then
  EXISTING=$(cat "$CHANGELOG_FILE")
  # Insert new section after the first heading (# Changelog) if present
  if echo "$EXISTING" | grep -qE '^# '; then
    HEADER=$(echo "$EXISTING" | head -n1)
    REST=$(echo "$EXISTING" | tail -n +2)
    printf '%s\n\n%b\n%s\n' "$HEADER" "$SECTION" "$REST" > "$CHANGELOG_FILE"
  else
    printf '%b\n%s\n' "$SECTION" "$EXISTING" > "$CHANGELOG_FILE"
  fi
else
  printf '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n%b\n' "$SECTION" > "$CHANGELOG_FILE"
fi

log "Changelog updated: $CHANGELOG_FILE"
