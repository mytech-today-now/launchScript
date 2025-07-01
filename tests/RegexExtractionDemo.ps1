#Requires -Version 5.1
<#
.SYNOPSIS
    Demonstration of regex-based program name extraction
    
.DESCRIPTION
    This script demonstrates how the new regex extraction function works
    by showing the extracted program names for each application in the
    detection configuration.
    
.EXAMPLE
    .\RegexExtractionDemo.ps1
#>

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

# Sample detection configuration (subset for demo)
$script:AppDetectionConfig = @{
    'AngryIPScanner.ps1' = @{
        SearchNames = @('*Angry IP Scanner*', '*AngryIPScanner*')
    }
    'Audacity.ps1' = @{
        SearchNames = @('*Audacity*')
    }
    'BelarcAdvisor.ps1' = @{
        SearchNames = @('*Belarc Advisor*', '*BelarcAdvisor*')
    }
    'Blender.ps1' = @{
        SearchNames = @('*Blender*')
    }
    'Brave.ps1' = @{
        SearchNames = @('*Brave*')
    }
    'ChatGPT.ps1' = @{
        SearchNames = @('*ChatGPT*', '*OpenAI*')
    }
    'Firefox.ps1' = @{
        SearchNames = @('*Mozilla Firefox*', '*Firefox*')
    }
    'GIMP.ps1' = @{
        SearchNames = @('*GIMP*', '*GNU Image Manipulation Program*')
    }
    'NotePad++.ps1' = @{
        SearchNames = @('*Notepad++*', '*Notepad+*')
    }
    'VSCode.ps1' = @{
        SearchNames = @('*Microsoft Visual Studio Code*', '*Visual Studio Code*', '*VSCode*')
    }
    'WiseDuplicateFinder.ps1' = @{
        SearchNames = @('*Wise Duplicate Finder*', '*WiseDuplicateFinder*')
    }
}

function Show-ExtractionDemo {
    Write-Host "Regex-based Program Name Extraction Demo" -ForegroundColor Magenta
    Write-Host "=========================================" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "This demo shows how program names are extracted from search patterns" -ForegroundColor Yellow
    Write-Host "for use in WMI queries to find similar installed software." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($appScript in $script:AppDetectionConfig.Keys | Sort-Object) {
        $config = $script:AppDetectionConfig[$appScript]
        $appName = $appScript -replace '\.ps1$', ''
        
        Write-Host "Application: " -NoNewline -ForegroundColor Cyan
        Write-Host $appName -ForegroundColor White
        
        Write-Host "  Search Patterns: " -NoNewline -ForegroundColor Gray
        Write-Host ($config.SearchNames -join ', ') -ForegroundColor Yellow
        
        try {
            $extractedNames = Get-ExtractedProgramNames -SearchNames $config.SearchNames
            
            Write-Host "  Extracted Names: " -NoNewline -ForegroundColor Gray
            if ($extractedNames.Count -gt 0) {
                Write-Host ($extractedNames -join ', ') -ForegroundColor Green
            }
            else {
                Write-Host "None" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "  Error: " -NoNewline -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        
        Write-Host ""
    }
    
    Write-Host "How it works:" -ForegroundColor Magenta
    Write-Host "1. Remove wildcards (*) from search patterns" -ForegroundColor White
    Write-Host "2. Split on common separators (space, dash, underscore, dot)" -ForegroundColor White
    Write-Host "3. Filter out common words (the, and, application, etc.)" -ForegroundColor White
    Write-Host "4. Extract camelCase components (e.g., AngryIPScanner -> Angry, IP, Scanner)" -ForegroundColor White
    Write-Host "5. Return unique, meaningful program names for WMI querying" -ForegroundColor White
    Write-Host ""
    
    Write-Host "These extracted names are then used to query Win32_Product via WMI" -ForegroundColor Yellow
    Write-Host "to find installed software that matches or is similar to the target applications." -ForegroundColor Yellow
}

function Test-ExtractionLogic {
    Write-Host "`nTesting Extraction Logic with Sample Patterns" -ForegroundColor Magenta
    Write-Host "=============================================" -ForegroundColor Magenta
    Write-Host ""
    
    $testPatterns = @(
        @('*Visual Studio Code*', '*VSCode*'),
        @('*Angry IP Scanner*', '*AngryIPScanner*'),
        @('*GNU Image Manipulation Program*', '*GIMP*'),
        @('*Microsoft Quick Connect*'),
        @('*Wise Duplicate Finder*', '*WiseDuplicateFinder*')
    )
    
    foreach ($patterns in $testPatterns) {
        Write-Host "Input patterns: " -NoNewline -ForegroundColor Cyan
        Write-Host ($patterns -join ', ') -ForegroundColor Yellow
        
        try {
            $extracted = Get-ExtractedProgramNames -SearchNames $patterns
            Write-Host "Extracted names: " -NoNewline -ForegroundColor Cyan
            Write-Host ($extracted -join ', ') -ForegroundColor Green
        }
        catch {
            Write-Host "Error: " -NoNewline -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        
        Write-Host ""
    }
}

# Main execution
try {
    Show-ExtractionDemo
    Test-ExtractionLogic
    
    Write-Host "Demo completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To test the full WMI detection functionality, run:" -ForegroundColor Yellow
    Write-Host "  .\WMIDetectionTest.ps1" -ForegroundColor White
}
catch {
    Write-Host "Demo failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
