# Examples Auto-Run Skill - PowerShell Script
# Automatically discovers and runs Python examples in the repository,
# capturing output and reporting success/failure for each example.

param(
    [string]$ExamplesDir = "examples",
    [string]$PythonCmd = "python",
    [int]$TimeoutSeconds = 60,
    [string[]]$ExcludePatterns = @(),
    [switch]$FailFast,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$script:PassCount = 0
$script:FailCount = 0
$script:SkipCount = 0
$script:Results = @()

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Write-Status {
    param([string]$Status, [string]$Message)
    switch ($Status) {
        "PASS"  { Write-Host "  [PASS] $Message" -ForegroundColor Green }
        "FAIL"  { Write-Host "  [FAIL] $Message" -ForegroundColor Red }
        "SKIP"  { Write-Host "  [SKIP] $Message" -ForegroundColor Yellow }
        "INFO"  { Write-Host "  [INFO] $Message" -ForegroundColor Blue }
        default { Write-Host "  $Message" }
    }
}

function Test-ShouldExclude {
    param([string]$FilePath)
    foreach ($pattern in $ExcludePatterns) {
        if ($FilePath -like $pattern) {
            return $true
        }
    }
    # Exclude files that require interactive input or special env vars not set
    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if ($content -match "input\(" -or $content -match "getpass") {
        return $true
    }
    return $false
}

function Invoke-Example {
    param([string]$FilePath)

    $relativePath = $FilePath.Replace((Get-Location).Path + "\", "")

    if (Test-ShouldExclude -FilePath $FilePath) {
        Write-Status "SKIP" $relativePath
        $script:SkipCount++
        $script:Results += [PSCustomObject]@{ File = $relativePath; Status = "SKIP"; Output = ""; Error = "" }
        return
    }

    if ($Verbose) {
        Write-Status "INFO" "Running: $relativePath"
    }

    try {
        $process = Start-Process -FilePath $PythonCmd `
            -ArgumentList $FilePath `
            -NoNewWindow `
            -PassThru `
            -RedirectStandardOutput "$env:TEMP\example_stdout.txt" `
            -RedirectStandardError "$env:TEMP\example_stderr.txt"

        $completed = $process.WaitForExit($TimeoutSeconds * 1000)

        $stdout = Get-Content "$env:TEMP\example_stdout.txt" -Raw -ErrorAction SilentlyContinue
        $stderr = Get-Content "$env:TEMP\example_stderr.txt" -Raw -ErrorAction SilentlyContinue

        if (-not $completed) {
            $process.Kill()
            Write-Status "FAIL" "$relativePath (timed out after ${TimeoutSeconds}s)"
            $script:FailCount++
            $script:Results += [PSCustomObject]@{ File = $relativePath; Status = "FAIL"; Output = $stdout; Error = "Timed out" }
            if ($FailFast) { throw "Example timed out: $relativePath" }
            return
        }

        if ($process.ExitCode -eq 0) {
            Write-Status "PASS" $relativePath
            $script:PassCount++
            $script:Results += [PSCustomObject]@{ File = $relativePath; Status = "PASS"; Output = $stdout; Error = "" }
        } else {
            Write-Status "FAIL" "$relativePath (exit code: $($process.ExitCode))"
            if ($Verbose -and $stderr) {
                Write-Host "    Error: $stderr" -ForegroundColor DarkRed
            }
            $script:FailCount++
            $script:Results += [PSCustomObject]@{ File = $relativePath; Status = "FAIL"; Output = $stdout; Error = $stderr }
            if ($FailFast) { throw "Example failed: $relativePath" }
        }
    } catch {
        Write-Status "FAIL" "$relativePath (exception: $_)"
        $script:FailCount++
        $script:Results += [PSCustomObject]@{ File = $relativePath; Status = "FAIL"; Output = ""; Error = $_.ToString() }
        if ($FailFast) { throw }
    }
}

# --- Main Execution ---

Write-Header "Examples Auto-Run"

# Validate examples directory
if (-not (Test-Path $ExamplesDir)) {
    Write-Host "Examples directory '$ExamplesDir' not found." -ForegroundColor Red
    exit 1
}

# Check Python availability
try {
    $pyVersion = & $PythonCmd --version 2>&1
    Write-Status "INFO" "Using: $pyVersion"
} catch {
    Write-Host "Python command '$PythonCmd' not found." -ForegroundColor Red
    exit 1
}

# Discover example files
$exampleFiles = Get-ChildItem -Path $ExamplesDir -Recurse -Filter "*.py" |
    Where-Object { $_.Name -notlike "__*" -and $_.Name -notlike "_*" } |
    Sort-Object FullName

Write-Status "INFO" "Found $($exampleFiles.Count) example file(s) in '$ExamplesDir'"

foreach ($file in $exampleFiles) {
    Invoke-Example -FilePath $file.FullName
}

# --- Summary ---
Write-Header "Results Summary"
Write-Host "  Passed : $script:PassCount" -ForegroundColor Green
Write-Host "  Failed : $script:FailCount" -ForegroundColor $(if ($script:FailCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Skipped: $script:SkipCount" -ForegroundColor Yellow
Write-Host ""

if ($script:FailCount -gt 0) {
    Write-Host "Some examples failed. Review output above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "All examples passed successfully." -ForegroundColor Green
    exit 0
}
