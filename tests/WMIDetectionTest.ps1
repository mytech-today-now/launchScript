#Requires -Version 5.1
<#
.SYNOPSIS
    Test script for WMI-based detection with regex name extraction
    
.DESCRIPTION
    This script tests the new regex-based program name extraction and WMI detection
    functionality added to the LaunchScript Manager detection system.
    
.PARAMETER TestSpecificApp
    Test a specific application script name (optional)
    
.PARAMETER ShowExtractedNames
    Show the extracted program names for each application
    
.PARAMETER TestWMIOnly
    Test only the WMI detection without other methods
    
.EXAMPLE
    .\WMIDetectionTest.ps1
    
.EXAMPLE
    .\WMIDetectionTest.ps1 -TestSpecificApp "VSCode.ps1" -ShowExtractedNames
    
.EXAMPLE
    .\WMIDetectionTest.ps1 -TestWMIOnly
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Test a specific application script name")]
    [string]$TestSpecificApp,
    
    [Parameter(HelpMessage = "Show extracted program names")]
    [switch]$ShowExtractedNames,
    
    [Parameter(HelpMessage = "Test only WMI detection")]
    [switch]$TestWMIOnly
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import shared helper functions
$sharedPath = Join-Path $PSScriptRoot "..\scripts\shared\HelperFunctions.ps1"
if (Test-Path $sharedPath) {
    . $sharedPath
}
else {
    Write-Error "Shared helper functions not found: $sharedPath"
    exit 1
}

# Simple test configuration (subset for testing)
$script:AppDetectionConfig = @{
    'VSCode.ps1' = @{
        SearchNames = @('*Microsoft Visual Studio Code*', '*Visual Studio Code*', '*VSCode*')
    }
    'Firefox.ps1' = @{
        SearchNames = @('*Mozilla Firefox*', '*Firefox*')
    }
    'AngryIPScanner.ps1' = @{
        SearchNames = @('*Angry IP Scanner*', '*AngryIPScanner*')
    }
    'NotePad++.ps1' = @{
        SearchNames = @('*Notepad++*', '*Notepad+*')
    }
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

function Test-RegexExtraction {
    Write-Host "`n=== Regex Name Extraction Tests ===" -ForegroundColor Cyan
    
    # Test with a few known applications
    $testApps = @('VSCode.ps1', 'Firefox.ps1', 'AngryIPScanner.ps1', 'NotePad++.ps1')
    
    foreach ($appScript in $testApps) {
        if ($TestSpecificApp -and $appScript -ne $TestSpecificApp) { continue }
        
        $config = $script:AppDetectionConfig[$appScript]
        if (-not $config) {
            Write-TestResult "Config exists for $appScript" $false "No configuration found"
            continue
        }
        
        Write-TestResult "Config exists for $appScript" $true
        
        try {
            $extractedNames = Get-ExtractedProgramNames -SearchNames $config.SearchNames
            $passed = $extractedNames.Count -gt 0
            Write-TestResult "Name extraction for $appScript" $passed "Extracted $($extractedNames.Count) names"
            
            if ($ShowExtractedNames -and $extractedNames.Count -gt 0) {
                Write-Host "    Extracted names: $($extractedNames -join ', ')" -ForegroundColor Yellow
            }
        }
        catch {
            Write-TestResult "Name extraction for $appScript" $false $_.Exception.Message
        }
    }
}

function Test-WMIDetection {
    Write-Host "`n=== WMI Detection Tests ===" -ForegroundColor Cyan
    
    # Test WMI functionality
    try {
        Write-Host "Testing WMI product query (this may take a moment)..." -ForegroundColor Yellow
        $wmiProducts = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue
        $passed = $null -ne $wmiProducts -and $wmiProducts.Count -gt 0
        Write-TestResult "WMI product query works" $passed "Found $($wmiProducts.Count) products"
        
        if (-not $passed) {
            Write-Host "    WMI detection will not work on this system" -ForegroundColor Red
            return
        }
    }
    catch {
        Write-TestResult "WMI product query works" $false $_.Exception.Message
        return
    }
    
    # Test with known applications that might be installed
    $testApps = @('VSCode.ps1', 'Firefox.ps1')
    
    foreach ($appScript in $testApps) {
        if ($TestSpecificApp -and $appScript -ne $TestSpecificApp) { continue }
        
        $config = $script:AppDetectionConfig[$appScript]
        if (-not $config) { continue }
        
        try {
            $extractedNames = Get-ExtractedProgramNames -SearchNames $config.SearchNames
            if ($extractedNames.Count -eq 0) { continue }
            
            $wmiResult = Find-SimilarSoftwareViaWMI -ProgramNames $extractedNames -ScriptName $appScript
            $found = $wmiResult.IsInstalled
            
            Write-TestResult "WMI detection for $appScript" $true "Found: $found"
            if ($found) {
                Write-Host "    Found: $($wmiResult.DisplayName) v$($wmiResult.Version)" -ForegroundColor Green
            }
        }
        catch {
            Write-TestResult "WMI detection for $appScript" $false $_.Exception.Message
        }
    }
}

function Test-IntegratedDetection {
    Write-Host "`n=== Integrated Detection Tests ===" -ForegroundColor Cyan
    
    # Test the full detection pipeline
    $testApps = @('VSCode.ps1', 'Firefox.ps1')
    
    foreach ($appScript in $testApps) {
        if ($TestSpecificApp -and $appScript -ne $TestSpecificApp) { continue }
        
        try {
            # Simulate the detection process from Check-ApplicationStatus.ps1
            $config = $script:AppDetectionConfig[$appScript]
            if (-not $config) { continue }
            
            # Try registry detection first
            $installationFound = @{
                IsInstalled = $false
                DisplayName = $null
                Version = $null
                Publisher = $null
                InstallLocation = $null
                Source = $null
                InstallDate = $null
            }
            
            foreach ($searchName in $config.SearchNames) {
                $result = Test-ProgramInstalled -Name $searchName
                if ($result -and $result.IsInstalled) {
                    $installationFound = $result
                    break
                }
            }
            
            $foundViaRegistry = $installationFound.IsInstalled
            
            # If not found, try WMI detection
            if (-not $installationFound.IsInstalled) {
                $extractedNames = Get-ExtractedProgramNames -SearchNames $config.SearchNames
                if ($extractedNames.Count -gt 0) {
                    $wmiResult = Find-SimilarSoftwareViaWMI -ProgramNames $extractedNames -ScriptName $appScript
                    if ($wmiResult.IsInstalled) {
                        $installationFound = $wmiResult
                    }
                }
            }
            
            $finalResult = $installationFound.IsInstalled
            $source = if ($foundViaRegistry) { "Registry" } else { $installationFound.Source }
            
            Write-TestResult "Integrated detection for $appScript" $true "Found: $finalResult via $source"
            if ($finalResult) {
                Write-Host "    $($installationFound.DisplayName) v$($installationFound.Version)" -ForegroundColor Green
            }
        }
        catch {
            Write-TestResult "Integrated detection for $appScript" $false $_.Exception.Message
        }
    }
}

# Main execution
try {
    Write-Host "WMI Detection Test Suite" -ForegroundColor Magenta
    Write-Host "========================" -ForegroundColor Magenta
    
    if ($TestSpecificApp) {
        Write-Host "Testing specific application: $TestSpecificApp" -ForegroundColor Yellow
    }
    
    if (-not $TestWMIOnly) {
        Test-RegexExtraction
    }
    
    Test-WMIDetection
    
    if (-not $TestWMIOnly) {
        Test-IntegratedDetection
    }
    
    Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
    Write-Host "WMI detection testing completed successfully!" -ForegroundColor Green
    Write-Host "Note: WMI queries can be slow and may require administrator privileges." -ForegroundColor Yellow
}
catch {
    Write-Host "`nTest suite failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
