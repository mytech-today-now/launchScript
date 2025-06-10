#Requires -Version 5.1
<#
.SYNOPSIS
    Simple validation test for LaunchScript application detection functionality
    
.DESCRIPTION
    Basic test to verify the application detection logic is working correctly
    and can detect installed applications with proper version information.
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Run with: powershell -ExecutionPolicy Bypass -File ".\tests\SimpleDetectionTest.ps1"
#>

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import the modules we're testing
$scriptRoot = Split-Path -Parent $PSScriptRoot
$sharedPath = Join-Path $scriptRoot "scripts\shared\HelperFunctions.ps1"
if (Test-Path $sharedPath) {
    . $sharedPath
} else {
    Write-Error "Cannot find shared helper functions at: $sharedPath"
    exit 1
}

# Test counters
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsTotal = 0

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $script:TestsTotal++
    $timestamp = Get-Date -Format 'HH:mm:ss'
    
    if ($Passed) {
        $script:TestsPassed++
        Write-Host "[$timestamp] [PASS] ✓ $TestName" -ForegroundColor Green
    } else {
        $script:TestsFailed++
        Write-Host "[$timestamp] [FAIL] ✗ $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "    $Message" -ForegroundColor Yellow
        }
    }
}

function Test-BasicDetection {
    Write-Host "`n=== Basic Detection Tests ===" -ForegroundColor Cyan
    
    # Test 1: Check if Test-ProgramInstalled function exists and works
    try {
        $result = Test-ProgramInstalled -Name "*Visual Studio Code*"
        $passed = ($null -ne $result) -and ($result -is [hashtable]) -and ($result.ContainsKey('IsInstalled'))
        Write-TestResult "Test-ProgramInstalled function works" $passed
        
        if ($passed -and $result.IsInstalled) {
            Write-Host "    Found: $($result.DisplayName) v$($result.Version)" -ForegroundColor Gray
        }
    } catch {
        Write-TestResult "Test-ProgramInstalled function works" $false $_.Exception.Message
    }
    
    # Test 2: Check for non-existent application
    try {
        $result = Test-ProgramInstalled -Name "*NonExistentApp12345*"
        $passed = ($null -ne $result) -and (-not $result.IsInstalled)
        Write-TestResult "Non-existent app returns false" $passed
    } catch {
        Write-TestResult "Non-existent app returns false" $false $_.Exception.Message
    }
    
    # Test 3: Check Get-InstalledPrograms function
    try {
        $programs = Get-InstalledPrograms -Name "*Microsoft*"
        $passed = ($null -ne $programs)
        Write-TestResult "Get-InstalledPrograms function works" $passed
        
        if ($passed -and $programs.Count -gt 0) {
            Write-Host "    Found $($programs.Count) Microsoft programs" -ForegroundColor Gray
        }
    } catch {
        Write-TestResult "Get-InstalledPrograms function works" $false $_.Exception.Message
    }
}

function Test-VersionDetection {
    Write-Host "`n=== Version Detection Tests ===" -ForegroundColor Cyan
    
    # Test version detection for known installed apps
    $knownApps = @("*Visual Studio Code*", "*Microsoft*", "*Windows*")
    
    foreach ($appPattern in $knownApps) {
        try {
            $result = Test-ProgramInstalled -Name $appPattern
            if ($result.IsInstalled) {
                $hasVersion = ($null -ne $result.Version) -and ($result.Version -ne "")
                Write-TestResult "Version detected for $appPattern" $hasVersion
                
                if ($hasVersion) {
                    Write-Host "    Version: $($result.Version)" -ForegroundColor Gray
                }
            } else {
                Write-TestResult "Version detected for $appPattern" $true "App not installed (expected)"
            }
        } catch {
            Write-TestResult "Version detected for $appPattern" $false $_.Exception.Message
        }
    }
}

function Test-IntegrationWithMainScript {
    Write-Host "`n=== Integration Tests ===" -ForegroundColor Cyan
    
    # Test the main detection script
    $checkScriptPath = Join-Path $scriptRoot "Check-ApplicationStatus.ps1"
    
    if (Test-Path $checkScriptPath) {
        try {
            Write-Host "Running main detection script..." -ForegroundColor Gray
            $result = & powershell -ExecutionPolicy Bypass -File $checkScriptPath -Scripts "VSCode" -OutputFormat JSON
            
            if ($result) {
                try {
                    $jsonResult = $result | ConvertFrom-Json
                    $hasApps = ($null -ne $jsonResult.Applications) -and ($jsonResult.Applications.Count -gt 0)
                    Write-TestResult "Main script returns valid JSON" $hasApps
                    
                    if ($hasApps) {
                        $app = $jsonResult.Applications[0]
                        $hasRequiredFields = ($null -ne $app.ScriptName) -and ($null -ne $app.IsInstalled)
                        Write-TestResult "JSON contains required fields" $hasRequiredFields
                        
                        if ($app.IsInstalled -and $app.Version) {
                            Write-Host "    Detected: $($app.ScriptName) v$($app.Version)" -ForegroundColor Gray
                        }
                    }
                } catch {
                    Write-TestResult "Main script returns valid JSON" $false "JSON parsing failed: $($_.Exception.Message)"
                }
            } else {
                Write-TestResult "Main script returns valid JSON" $false "No output received"
            }
        } catch {
            Write-TestResult "Main script execution" $false $_.Exception.Message
        }
    } else {
        Write-TestResult "Main script exists" $false "Check-ApplicationStatus.ps1 not found"
    }
}

function Test-PerformanceBasic {
    Write-Host "`n=== Performance Tests ===" -ForegroundColor Cyan
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Test detection of a few apps
        $testApps = @("*Visual Studio Code*", "*Microsoft*")
        
        foreach ($app in $testApps) {
            $result = Test-ProgramInstalled -Name $app
        }
        
        $stopwatch.Stop()
        $elapsedMs = $stopwatch.ElapsedMilliseconds
        
        $passed = $elapsedMs -lt 5000  # Should complete within 5 seconds
        Write-TestResult "Detection performance acceptable" $passed "Took $elapsedMs ms"
        
    } catch {
        $stopwatch.Stop()
        Write-TestResult "Detection performance acceptable" $false $_.Exception.Message
    }
}

function Show-TestSummary {
    Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
    Write-Host "Total Tests: $script:TestsTotal" -ForegroundColor White
    Write-Host "Passed: $script:TestsPassed" -ForegroundColor Green
    Write-Host "Failed: $script:TestsFailed" -ForegroundColor $(if ($script:TestsFailed -eq 0) { 'Green' } else { 'Red' })
    
    $successRate = if ($script:TestsTotal -gt 0) { 
        [math]::Round(($script:TestsPassed / $script:TestsTotal) * 100, 2) 
    } else { 
        0 
    }
    
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { 'Green' } else { 'Yellow' })
    
    return $script:TestsFailed -eq 0
}

# Main execution
Write-Host "=== LaunchScript Detection Validation v1.0.0 ===" -ForegroundColor Cyan
Write-Host "Testing application detection functionality..." -ForegroundColor White

Test-BasicDetection
Test-VersionDetection
Test-IntegrationWithMainScript
Test-PerformanceBasic

$success = Show-TestSummary

if ($success) {
    Write-Host "`n✓ All tests passed! Detection logic is working correctly." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some tests failed. Please review the detection logic." -ForegroundColor Red
    exit 1
}
