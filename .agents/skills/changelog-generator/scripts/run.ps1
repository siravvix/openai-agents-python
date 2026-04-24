# Changelog Generator Script (PowerShell)
# Generates or updates CHANGELOG.md based on git history and conventional commits

param(
    [string]$OutputFile = "CHANGELOG.md",
    [string]$FromTag = "",
    [string]$ToRef = "HEAD",
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Get the latest git tag if not specified
if (-not $FromTag) {
    try {
        $FromTag = git describe --tags --abbrev=0 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $FromTag) {
            Write-Warning "No previous tag found. Generating changelog from first commit."
            $FromTag = git rev-list --max-parents=0 HEAD 2>$null
        } else {
            Write-Info "Using latest tag as base: $FromTag"
        }
    } catch {
        Write-Warning "Could not determine base tag. Using all commits."
        $FromTag = ""
    }
}

# Collect commits
Write-Info "Collecting commits from $FromTag to $ToRef..."

$gitLogFormat = "%H|%s|%an|%ad"
$gitDateFormat = "--date=short"

if ($FromTag) {
    $commits = git log "${FromTag}..${ToRef}" --pretty=format:$gitLogFormat $gitDateFormat 2>$null
} else {
    $commits = git log $ToRef --pretty=format:$gitLogFormat $gitDateFormat 2>$null
}

if (-not $commits) {
    Write-Warning "No commits found in the specified range."
    exit 0
}

# Parse commits into categories
$features = @()
$fixes = @()
$breaking = @()
$docs = @()
$chores = @()
$other = @()

foreach ($line in ($commits -split "`n")) {
    if (-not $line.Trim()) { continue }

    $parts = $line -split "\|", 4
    if ($parts.Count -lt 2) { continue }

    $hash = $parts[0].Substring(0, [Math]::Min(7, $parts[0].Length))
    $subject = $parts[1]
    $author = if ($parts.Count -gt 2) { $parts[2] } else { "Unknown" }
    $date = if ($parts.Count -gt 3) { $parts[3] } else { "" }

    $entry = "- $subject ($hash)"

    if ($subject -match "BREAKING CHANGE" -or $subject -match "^.*!:") {
        $breaking += $entry
    } elseif ($subject -match "^feat(\(.+\))?:") {
        $features += $entry
    } elseif ($subject -match "^fix(\(.+\))?:") {
        $fixes += $entry
    } elseif ($subject -match "^docs(\(.+\))?:") {
        $docs += $entry
    } elseif ($subject -match "^(chore|ci|build|refactor|test|style|perf)(\(.+\))?:") {
        $chores += $entry
    } else {
        $other += $entry
    }
}

# Build changelog content
$today = Get-Date -Format "yyyy-MM-dd"
$version = try { git describe --tags --abbrev=0 2>$null } catch { "Unreleased" }
if (-not $version) { $version = "Unreleased" }

$newContent = @()
$newContent += "## [$version] - $today"
$newContent += ""

if ($breaking.Count -gt 0) {
    $newContent += "### ⚠ Breaking Changes"
    $newContent += $breaking
    $newContent += ""
}

if ($features.Count -gt 0) {
    $newContent += "### Features"
    $newContent += $features
    $newContent += ""
}

if ($fixes.Count -gt 0) {
    $newContent += "### Bug Fixes"
    $newContent += $fixes
    $newContent += ""
}

if ($docs.Count -gt 0) {
    $newContent += "### Documentation"
    $newContent += $docs
    $newContent += ""
}

if ($chores.Count -gt 0) {
    $newContent += "### Maintenance"
    $newContent += $chores
    $newContent += ""
}

if ($other.Count -gt 0) {
    $newContent += "### Other Changes"
    $newContent += $other
    $newContent += ""
}

$newSection = $newContent -join "`n"

if ($DryRun) {
    Write-Info "Dry run mode — changelog output:"
    Write-Host $newSection
    exit 0
}

# Prepend to existing changelog or create new one
if (Test-Path $OutputFile) {
    $existing = Get-Content $OutputFile -Raw
    # Insert after the header (first # line) if present
    if ($existing -match "^# ") {
        $headerEnd = $existing.IndexOf("`n")
        $header = $existing.Substring(0, $headerEnd + 1)
        $rest = $existing.Substring($headerEnd + 1)
        $finalContent = $header + "`n" + $newSection + $rest
    } else {
        $finalContent = $newSection + "`n" + $existing
    }
} else {
    $header = "# Changelog`n`nAll notable changes to this project will be documented in this file.`n`n"
    $finalContent = $header + $newSection
}

Set-Content -Path $OutputFile -Value $finalContent -Encoding UTF8
Write-Success "Changelog updated: $OutputFile"
