# Quick test for LaunchScript detection functionality
Set-StrictMode -Version Latest

# Import helper functions
$scriptRoot = Split-Path -Parent $PSScriptRoot
$sharedPath = Join-Path $scriptRoot "scripts\shared\HelperFunctions.ps1"
if (Test-Path $sharedPath) {
    . $sharedPath
} else {
    Write-Error "Cannot find shared helper functions at: $sharedPath"
    exit 1
}

Write-Host "=== LaunchScript Detection Quick Test ===" -ForegroundColor Cyan

# Test 1: Basic function test
Write-Host "`nTest 1: Testing basic detection function..." -ForegroundColor Yellow
try {
    $result = Test-ProgramInstalled -Name "*Visual Studio Code*"
    if ($result -and $result.ContainsKey('IsInstalled')) {
        Write-Host "✓ Test-ProgramInstalled function works" -ForegroundColor Green
        if ($result.IsInstalled) {
            Write-Host "  Found: $($result.DisplayName) v$($result.Version)" -ForegroundColor Gray
        }
    } else {
        Write-Host "✗ Test-ProgramInstalled function failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Test-ProgramInstalled function error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 2: Version detection
Write-Host "`nTest 2: Testing version detection..." -ForegroundColor Yellow
try {
    $result = Test-ProgramInstalled -Name "*Visual Studio Code*"
    if ($result.IsInstalled -and $result.Version) {
        Write-Host "✓ Version detection works: $($result.Version)" -ForegroundColor Green
    } else {
        Write-Host "✗ Version detection failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Version detection error: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Main script integration
Write-Host "`nTest 3: Testing main detection script..." -ForegroundColor Yellow
$checkScriptPath = Join-Path $scriptRoot "Check-ApplicationStatus.ps1"
if (Test-Path $checkScriptPath) {
    try {
        $result = & powershell -ExecutionPolicy Bypass -File $checkScriptPath -Scripts "VSCode" -OutputFormat JSON
        if ($result) {
            $jsonResult = $result | ConvertFrom-Json
            if ($jsonResult.Applications -and $jsonResult.Applications.Count -gt 0) {
                Write-Host "✓ Main script integration works" -ForegroundColor Green
                $app = $jsonResult.Applications[0]
                Write-Host "  Detected: $($app.ScriptName) - Installed: $($app.IsInstalled) - Version: $($app.Version)" -ForegroundColor Gray
            } else {
                Write-Host "✗ Main script returned no applications" -ForegroundColor Red
            }
        } else {
            Write-Host "✗ Main script returned no output" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Main script error: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Main script not found" -ForegroundColor Red
}

Write-Host "`n=== Test Complete ===" -ForegroundColor Cyan
