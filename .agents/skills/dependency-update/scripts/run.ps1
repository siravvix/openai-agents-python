# Dependency Update Skill - PowerShell Script
# Checks for outdated dependencies and creates update PRs

param(
    [string]$WorkingDir = $PWD,
    [switch]$DryRun = $false,
    [switch]$Verbose = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

function Invoke-Command-Safe {
    param([string]$Command, [string[]]$Arguments)
    if ($Verbose) { Write-Log "Running: $Command $($Arguments -join ' ')" "DEBUG" }
    $result = & $Command @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Command failed: $Command $($Arguments -join ' ')" "ERROR"
        Write-Log "Output: $result" "ERROR"
        return $null
    }
    return $result
}

# ── Environment checks ────────────────────────────────────────────────────────

Write-Log "Starting dependency update check in: $WorkingDir"

if (-not (Test-Path (Join-Path $WorkingDir "pyproject.toml"))) {
    Write-Log "No pyproject.toml found in $WorkingDir" "ERROR"
    exit 1
}

# Check for uv
$uvPath = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uvPath) {
    Write-Log "'uv' not found. Installing via pip..." "WARN"
    pip install uv | Out-Null
}

# ── Collect outdated packages ─────────────────────────────────────────────────

Write-Log "Checking for outdated packages..."

Push-Location $WorkingDir
try {
    # Sync environment first
    $syncOut = Invoke-Command-Safe "uv" @("sync", "--all-extras")
    if ($null -eq $syncOut) {
        Write-Log "Failed to sync environment" "ERROR"
        exit 1
    }

    # Get outdated list
    $outdatedRaw = uv pip list --outdated --format=json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Could not retrieve outdated packages list" "WARN"
        $outdatedRaw = "[]"
    }

    $outdated = $outdatedRaw | ConvertFrom-Json
    Write-Log "Found $($outdated.Count) outdated package(s)"

    if ($outdated.Count -eq 0) {
        Write-Log "All dependencies are up to date. Nothing to do."
        exit 0
    }

    # ── Report ────────────────────────────────────────────────────────────────

    Write-Log "Outdated packages:"
    foreach ($pkg in $outdated) {
        Write-Log "  $($pkg.name): $($pkg.version) -> $($pkg.latest_version)"
    }

    if ($DryRun) {
        Write-Log "Dry-run mode enabled. Skipping actual updates."
        exit 0
    }

    # ── Apply updates ─────────────────────────────────────────────────────────

    Write-Log "Upgrading packages..."
    $packageNames = $outdated | ForEach-Object { $_.name }

    $upgradeArgs = @("pip", "install", "--upgrade") + $packageNames
    $upgradeOut = Invoke-Command-Safe "uv" $upgradeArgs
    if ($null -eq $upgradeOut) {
        Write-Log "Failed to upgrade packages" "ERROR"
        exit 1
    }

    # Re-lock
    Write-Log "Locking updated dependencies..."
    $lockOut = Invoke-Command-Safe "uv" @("lock")
    if ($null -eq $lockOut) {
        Write-Log "Failed to update lock file" "ERROR"
        exit 1
    }

    # ── Run tests to validate ─────────────────────────────────────────────────

    Write-Log "Running tests to validate updates..."
    $testOut = uv run pytest tests/ --tb=short -q 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Tests failed after dependency update!" "ERROR"
        Write-Log $testOut "ERROR"
        exit 1
    }

    Write-Log "All tests passed after dependency update."
    Write-Log "Dependency update complete. Files changed:"
    Write-Log "  - uv.lock"

    exit 0
} finally {
    Pop-Location
}
