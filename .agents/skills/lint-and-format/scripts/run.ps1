# Lint and Format Skill - PowerShell Script
# Runs linting and formatting checks on the codebase using ruff and pyright

param(
    [switch]$Fix,
    [switch]$CheckOnly,
    [string]$Path = "."
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "=" * 60 -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

$OverallSuccess = $true

# Check for required tools
Write-Header "Checking Required Tools"

$tools = @("ruff", "pyright")
foreach ($tool in $tools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Failure "$tool is not installed or not in PATH"
        Write-Info "Install with: pip install $tool"
        exit 1
    }
    Write-Success "$tool found"
}

# Run ruff linting
Write-Header "Running Ruff Linter"

if ($Fix -and -not $CheckOnly) {
    Write-Info "Running ruff with auto-fix enabled"
    $ruffArgs = @("check", "--fix", $Path)
} else {
    Write-Info "Running ruff in check-only mode"
    $ruffArgs = @("check", $Path)
}

try {
    & ruff @ruffArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Ruff linting passed"
    } else {
        Write-Failure "Ruff linting found issues"
        $OverallSuccess = $false
    }
} catch {
    Write-Failure "Ruff linting failed with error: $_"
    $OverallSuccess = $false
}

# Run ruff formatting
Write-Header "Running Ruff Formatter"

if ($Fix -and -not $CheckOnly) {
    Write-Info "Running ruff format (applying fixes)"
    $ruffFmtArgs = @("format", $Path)
} else {
    Write-Info "Running ruff format in check mode"
    $ruffFmtArgs = @("format", "--check", $Path)
}

try {
    & ruff @ruffFmtArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Ruff formatting passed"
    } else {
        Write-Failure "Ruff formatting found issues (run with -Fix to auto-fix)"
        $OverallSuccess = $false
    }
} catch {
    Write-Failure "Ruff formatting failed with error: $_"
    $OverallSuccess = $false
}

# Run pyright type checking
Write-Header "Running Pyright Type Checker"

try {
    & pyright $Path
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Pyright type checking passed"
    } else {
        Write-Failure "Pyright type checking found issues"
        $OverallSuccess = $false
    }
} catch {
    Write-Failure "Pyright type checking failed with error: $_"
    $OverallSuccess = $false
}

# Summary
Write-Header "Summary"

if ($OverallSuccess) {
    Write-Success "All lint and format checks passed!"
    exit 0
} else {
    Write-Failure "One or more lint/format checks failed."
    if (-not $Fix) {
        Write-Info "Tip: Run with -Fix flag to automatically fix formatting and lint issues."
    }
    exit 1
}
