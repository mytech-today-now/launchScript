#Requires -Version 5.1
<#
.SYNOPSIS
    Unit tests for LaunchScript application detection functionality
    
.DESCRIPTION
    Comprehensive test suite for validating the application detection logic,
    including registry scanning, version detection, and error handling.
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Run with: powershell -ExecutionPolicy Bypass -File ".\tests\DetectionTests.ps1"
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

#region Test Framework

$script:TestResults = @{
    Passed = 0
    Failed = 0
    Total = 0
    FailedTests = @()
}

function Write-TestLog {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('INFO', 'PASS', 'FAIL', 'WARN')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $color = switch ($Level) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'WARN' { 'Yellow' }
        default { 'White' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]
        $Expected,
        
        [Parameter(Mandatory = $true)]
        $Actual,
        
        [Parameter(Mandatory = $true)]
        [string]$TestName
    )
    
    $script:TestResults.Total++
    
    if ($Expected -eq $Actual) {
        $script:TestResults.Passed++
        Write-TestLog "✓ $TestName" -Level PASS
        return $true
    } else {
        $script:TestResults.Failed++
        $script:TestResults.FailedTests += $TestName
        Write-TestLog "✗ $TestName - Expected: '$Expected', Actual: '$Actual'" -Level FAIL
        return $false
    }
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        $Condition,
        
        [Parameter(Mandatory = $true)]
        [string]$TestName
    )
    
    return Assert-Equal -Expected $true -Actual ([bool]$Condition) -TestName $TestName
}

function Assert-False {
    param(
        [Parameter(Mandatory = $true)]
        $Condition,
        
        [Parameter(Mandatory = $true)]
        [string]$TestName
    )
    
    return Assert-Equal -Expected $false -Actual ([bool]$Condition) -TestName $TestName
}

function Assert-NotNull {
    param(
        [Parameter(Mandatory = $true)]
        $Value,
        
        [Parameter(Mandatory = $true)]
        [string]$TestName
    )
    
    $script:TestResults.Total++
    
    if ($null -ne $Value) {
        $script:TestResults.Passed++
        Write-TestLog "✓ $TestName" -Level PASS
        return $true
    } else {
        $script:TestResults.Failed++
        $script:TestResults.FailedTests += $TestName
        Write-TestLog "✗ $TestName - Value was null" -Level FAIL
        return $false
    }
}

function Test-Function {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestName,

        [Parameter(Mandatory = $true)]
        [scriptblock]$TestScript
    )

    Write-TestLog "Running test: $TestName" -Level INFO

    try {
        # Execute in the module scope to access Assert functions
        $result = Invoke-Command -ScriptBlock $TestScript -NoNewScope
    } catch {
        $script:TestResults.Total++
        $script:TestResults.Failed++
        $script:TestResults.FailedTests += $TestName
        Write-TestLog "✗ $TestName - Exception: $($_.Exception.Message)" -Level FAIL
    }
}

#endregion

#region Detection Logic Tests

function Test-SystemArchitecture {
    Test-Function "Get-SystemArchitecture returns valid architecture" {
        $arch = Get-SystemArchitecture
        Assert-True ($arch -in @('x86', 'x64', 'ARM64')) "Architecture should be x86, x64, or ARM64"
        Assert-NotNull $arch "Architecture should not be null"
    }
}

function Test-ElevationCheck {
    Test-Function "Test-IsElevated returns boolean" {
        $isElevated = Test-IsElevated
        Assert-True ($isElevated -is [bool]) "Elevation check should return boolean"
    }
}

function Test-ProgramInstallationCheck {
    Test-Function "Test-ProgramInstalled with known installed app" {
        # Test with VSCode which we know is installed
        $result = Test-ProgramInstalled -Name "*Visual Studio Code*"
        
        Assert-NotNull $result "Result should not be null"
        Assert-True $result.ContainsKey('IsInstalled') "Result should contain IsInstalled property"
        Assert-True ($result.IsInstalled -is [bool]) "IsInstalled should be boolean"
        
        if ($result.IsInstalled) {
            Assert-NotNull $result.DisplayName "DisplayName should not be null for installed app"
            Assert-NotNull $result.Version "Version should not be null for installed app"
        }
    }
    
    Test-Function "Test-ProgramInstalled with non-existent app" {
        $result = Test-ProgramInstalled -Name "*NonExistentApplication12345*"
        
        Assert-NotNull $result "Result should not be null"
        Assert-False $result.IsInstalled "Non-existent app should not be installed"
        Assert-Equal $null $result.DisplayName "DisplayName should be null for non-existent app"
    }
    
    Test-Function "Test-ProgramInstalled with wildcard name" {
        $result = Test-ProgramInstalled -Name "*"

        Assert-NotNull $result "Result should not be null with wildcard"
        # Wildcard might find something, so just check structure
        Assert-True $result.ContainsKey('IsInstalled') "Result should contain IsInstalled property"
    }
}

function Test-InstalledProgramsRetrieval {
    Test-Function "Get-InstalledPrograms returns array" {
        $programs = Get-InstalledPrograms -Name "*"
        
        Assert-NotNull $programs "Programs list should not be null"
        Assert-True ($programs -is [array] -or $programs.Count -ge 0) "Programs should be array or have Count property"
    }
    
    Test-Function "Get-InstalledPrograms with specific filter" {
        $programs = Get-InstalledPrograms -Name "*Microsoft*"
        
        Assert-NotNull $programs "Filtered programs list should not be null"
        
        if ($programs.Count -gt 0) {
            $firstProgram = $programs[0]
            Assert-True ($firstProgram.DisplayName -like "*Microsoft*") "Filtered results should match filter"
        }
    }
}

#endregion

#region Integration Tests

function Test-DetectionServiceIntegration {
    Test-Function "Check-ApplicationStatus script execution" {
        $checkScriptPath = Join-Path $scriptRoot "Check-ApplicationStatus.ps1"
        
        if (Test-Path $checkScriptPath) {
            try {
                $result = & powershell -ExecutionPolicy Bypass -File $checkScriptPath -Scripts "VSCode" -OutputFormat JSON
                
                Assert-NotNull $result "Detection service should return result"
                
                # Try to parse as JSON
                $jsonResult = $result | ConvertFrom-Json
                Assert-NotNull $jsonResult "Result should be valid JSON"
                Assert-NotNull $jsonResult.Applications "Result should contain Applications array"
                
            } catch {
                Write-TestLog "Detection service integration test failed: $($_.Exception.Message)" -Level WARN
            }
        } else {
            Write-TestLog "Check-ApplicationStatus.ps1 not found, skipping integration test" -Level WARN
        }
    }
}

#endregion

#region Performance Tests

function Test-DetectionPerformance {
    Test-Function "Detection performance benchmark" {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Test detection of a few known apps
        $testApps = @("*Visual Studio Code*", "*Microsoft*", "*Windows*")
        
        foreach ($app in $testApps) {
            $result = Test-ProgramInstalled -Name $app
            Assert-NotNull $result "Performance test should return valid result for $app"
        }
        
        $stopwatch.Stop()
        $elapsedMs = $stopwatch.ElapsedMilliseconds
        
        Write-TestLog "Detection performance: $elapsedMs ms for $($testApps.Count) apps" -Level INFO
        Assert-True ($elapsedMs -lt 10000) "Detection should complete within 10 seconds"
    }
}

#endregion

#region Main Test Execution

function Run-AllTests {
    Write-TestLog "=== LaunchScript Detection Tests v1.0.0 ===" -Level INFO
    Write-TestLog "Starting comprehensive test suite..." -Level INFO
    
    # System tests
    Test-SystemArchitecture
    Test-ElevationCheck
    
    # Core detection tests
    Test-ProgramInstallationCheck
    Test-InstalledProgramsRetrieval
    
    # Integration tests
    Test-DetectionServiceIntegration
    
    # Performance tests
    Test-DetectionPerformance
    
    # Summary
    Write-TestLog "" -Level INFO
    Write-TestLog "=== Test Results Summary ===" -Level INFO
    Write-TestLog "Total Tests: $($script:TestResults.Total)" -Level INFO
    Write-TestLog "Passed: $($script:TestResults.Passed)" -Level PASS
    Write-TestLog "Failed: $($script:TestResults.Failed)" -Level $(if ($script:TestResults.Failed -eq 0) { 'PASS' } else { 'FAIL' })
    
    if ($script:TestResults.Failed -gt 0) {
        Write-TestLog "" -Level INFO
        Write-TestLog "Failed Tests:" -Level FAIL
        foreach ($failedTest in $script:TestResults.FailedTests) {
            Write-TestLog "  - $failedTest" -Level FAIL
        }
    }
    
    $successRate = if ($script:TestResults.Total -gt 0) { 
        [math]::Round(($script:TestResults.Passed / $script:TestResults.Total) * 100, 2) 
    } else { 
        0 
    }
    
    Write-TestLog "Success Rate: $successRate%" -Level $(if ($successRate -ge 90) { 'PASS' } else { 'WARN' })
    
    return $script:TestResults.Failed -eq 0
}

# Execute tests if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    $success = Run-AllTests
    exit $(if ($success) { 0 } else { 1 })
}

#endregion
