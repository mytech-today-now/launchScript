#Requires -Version 5.1
<#
.SYNOPSIS
    Simple integration test to verify all scripts are discoverable
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $color = switch ($Level) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    
    Write-Host "[$timestamp] [TEST] [$Level] $Message" -ForegroundColor $color
}

try {
    Write-Host "LaunchScript Integration Test" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    # Test 1: Check scripts directory
    Write-TestLog "Testing scripts directory..." -Level INFO
    $scriptsPath = "./scripts/"
    
    if (-not (Test-Path $scriptsPath)) {
        Write-TestLog "Scripts directory not found!" -Level FAIL
        exit 1
    }
    
    # Get all PowerShell scripts
    $allScripts = @(Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | Where-Object { $_.Name -ne "shared" })
    Write-TestLog "Found $($allScripts.Count) scripts in directory" -Level INFO
    
    # List all scripts
    foreach ($script in $allScripts) {
        Write-TestLog "  - $($script.Name)" -Level INFO
    }
    
    # Test 2: Check index.html contains script references
    Write-TestLog "Testing index.html integration..." -Level INFO
    $indexPath = "./index.html"
    
    if (-not (Test-Path $indexPath)) {
        Write-TestLog "index.html not found!" -Level FAIL
        exit 1
    }
    
    $indexContent = Get-Content -Path $indexPath -Raw
    $missingFromIndex = @()
    
    foreach ($script in $allScripts) {
        $scriptName = $script.Name
        if ($indexContent -notmatch [regex]::Escape("'$scriptName'")) {
            $missingFromIndex += $scriptName
        }
    }
    
    if ($missingFromIndex.Count -gt 0) {
        Write-TestLog "Scripts missing from index.html:" -Level FAIL
        foreach ($missing in $missingFromIndex) {
            Write-TestLog "  - $missing" -Level FAIL
        }
        exit 1
    }
    
    # Test 3: Test launchScript validation
    Write-TestLog "Testing launchScript validation..." -Level INFO
    $launchScriptPath = "./launchScript.ps1"
    
    if (-not (Test-Path $launchScriptPath)) {
        Write-TestLog "launchScript.ps1 not found!" -Level FAIL
        exit 1
    }
    
    # Test with a few sample scripts
    $testScripts = @('NotePad++', 'VSCode')
    $scriptList = $testScripts -join ','
    
    Write-TestLog "Testing with scripts: $scriptList" -Level INFO
    
    # Run in test mode
    $result = & $launchScriptPath -Scripts $scriptList -TestRun 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-TestLog "LaunchScript validation PASSED" -Level PASS
    } else {
        Write-TestLog "LaunchScript validation FAILED (Exit code: $LASTEXITCODE)" -Level FAIL
        Write-TestLog "Output: $result" -Level ERROR
        exit 1
    }
    
    Write-TestLog "All integration tests PASSED!" -Level PASS
    exit 0
    
} catch {
    Write-TestLog "Test execution failed: $($_.Exception.Message)" -Level ERROR
    exit 1
}
