# Test Coverage Script for Windows PowerShell
# Runs test suite with coverage reporting and enforces minimum thresholds

param(
    [string]$MinCoverage = "80",
    [string]$ReportDir = "coverage_report",
    [switch]$OpenReport = $false,
    [switch]$FailUnderThreshold = $true
)

$ErrorActionPreference = "Stop"

Write-Host "=== Test Coverage Runner ==="  -ForegroundColor Cyan
Write-Host "Minimum coverage threshold: $MinCoverage%" -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "pyproject.toml")) {
    Write-Error "pyproject.toml not found. Please run from the project root."
    exit 1
}

# Check for required tools
$requiredTools = @("python", "pip")
foreach ($tool in $requiredTools) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        Write-Error "Required tool '$tool' not found in PATH."
        exit 1
    }
}

# Install dependencies if needed
Write-Host "`nChecking dependencies..." -ForegroundColor Yellow
try {
    python -m pytest --version | Out-Null
    python -m coverage --version | Out-Null
} catch {
    Write-Host "Installing test dependencies..." -ForegroundColor Yellow
    pip install pytest pytest-asyncio pytest-cov coverage[toml] | Out-Null
}

# Clean previous coverage data
Write-Host "`nCleaning previous coverage data..." -ForegroundColor Yellow
if (Test-Path ".coverage") {
    Remove-Item ".coverage" -Force
}
if (Test-Path $ReportDir) {
    Remove-Item $ReportDir -Recurse -Force
}

# Run tests with coverage
Write-Host "`nRunning tests with coverage..." -ForegroundColor Yellow
$testArgs = @(
    "-m", "pytest",
    "tests/",
    "--cov=src",
    "--cov-report=term-missing",
    "--cov-report=html:$ReportDir",
    "--cov-report=xml:coverage.xml",
    "-v",
    "--tb=short"
)

try {
    $testProcess = Start-Process -FilePath "python" -ArgumentList $testArgs -NoNewWindow -PassThru -Wait
    $testExitCode = $testProcess.ExitCode
} catch {
    Write-Error "Failed to run tests: $_"
    exit 1
}

if ($testExitCode -ne 0) {
    Write-Host "`nTests failed with exit code: $testExitCode" -ForegroundColor Red
    exit $testExitCode
}

# Parse coverage percentage from XML report
Write-Host "`nParsing coverage results..." -ForegroundColor Yellow
$coveragePercent = 0

if (Test-Path "coverage.xml") {
    try {
        [xml]$coverageXml = Get-Content "coverage.xml"
        $lineRate = $coverageXml.coverage."line-rate"
        $coveragePercent = [math]::Round([double]$lineRate * 100, 2)
    } catch {
        Write-Warning "Could not parse coverage.xml: $_"
    }
} else {
    Write-Warning "coverage.xml not found, skipping threshold check."
}

# Report results
Write-Host "`n=== Coverage Results ==="  -ForegroundColor Cyan
Write-Host "Total coverage: $coveragePercent%" -ForegroundColor White
Write-Host "Minimum threshold: $MinCoverage%" -ForegroundColor White

if ($coveragePercent -ge [double]$MinCoverage) {
    Write-Host "`n✓ Coverage threshold met ($coveragePercent% >= $MinCoverage%)" -ForegroundColor Green
} else {
    Write-Host "`n✗ Coverage below threshold ($coveragePercent% < $MinCoverage%)" -ForegroundColor Red
    if ($FailUnderThreshold) {
        Write-Host "HTML report available at: $ReportDir/index.html" -ForegroundColor Yellow
        exit 1
    }
}

# Open HTML report if requested
if ($OpenReport -and (Test-Path "$ReportDir/index.html")) {
    Write-Host "`nOpening HTML coverage report..." -ForegroundColor Yellow
    Start-Process "$ReportDir/index.html"
}

Write-Host "`nHTML report available at: $ReportDir/index.html" -ForegroundColor Cyan
Write-Host "XML report available at: coverage.xml" -ForegroundColor Cyan
Write-Host "`n=== Test Coverage Complete ===" -ForegroundColor Cyan
exit 0
