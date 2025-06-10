#Requires -Version 5.1
<#
.SYNOPSIS
    LaunchScript Manager - PowerShell orchestrator for app installations
    
.DESCRIPTION
    This script coordinates the execution of individual app installation scripts
    located in the scripts/ directory. It provides centralized logging, error
    handling, and progress reporting for batch app installations.
    
.PARAMETER Scripts
    Comma-separated list of script filenames to execute (without .ps1 extension)
    
.PARAMETER ScriptsPath
    Path to the directory containing app installation scripts (default: ./scripts/)
    
.PARAMETER LogPath
    Path for log file output (default: ./logs/launchScript.log)
    
.PARAMETER Verbose
    Enable verbose logging output
    
.PARAMETER WhatIf
    Show what would be executed without actually running the scripts
    
.EXAMPLE
    .\launchScript.ps1 -Scripts "NotePad++,VSCode,Chrome"
    
.EXAMPLE
    .\launchScript.ps1 -Scripts "NotePad++" -Verbose -WhatIf
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requires:
    - PowerShell 5.1 or later
    - Administrator privileges for most installations
    - Internet connection for downloading applications
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Comma-separated list of script names to execute")]
    [ValidateNotNullOrEmpty()]
    [string]$Scripts,
    
    [Parameter(HelpMessage = "Path to scripts directory")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$ScriptsPath = "./scripts/",
    
    [Parameter(HelpMessage = "Path for log file")]
    [string]$LogPath = "./logs/launchScript.log",

    [Parameter(HelpMessage = "Enable verbose output")]
    [switch]$VerboseLogging,

    [Parameter(HelpMessage = "Show what would be executed without running")]
    [switch]$TestRun
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Global variables
$script:LogFile = $LogPath
$script:StartTime = Get-Date
$script:ErrorCount = 0
$script:SuccessCount = 0
$script:SkippedCount = 0

#region Logging Functions

function Initialize-Logging {
    <#
    .SYNOPSIS
        Initialize logging system and create log directory if needed
    #>
    try {
        $logDir = Split-Path -Path $script:LogFile -Parent
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            Write-Verbose "Created log directory: $logDir"
        }
        
        # Create or append to log file
        $logHeader = @"
================================================================================
LaunchScript Manager Execution Log
Started: $($script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
User: $env:USERNAME
Computer: $env:COMPUTERNAME
PowerShell Version: $($PSVersionTable.PSVersion)
Scripts Requested: $Scripts
================================================================================

"@
        Add-Content -Path $script:LogFile -Value $logHeader -Encoding UTF8
        if ($VerboseLogging) { Write-Host "Logging initialized: $script:LogFile" -ForegroundColor Cyan }
    }
    catch {
        Write-Warning "Failed to initialize logging: $($_.Exception.Message)"
        $script:LogFile = $null
    }
}

function Write-Log {
    <#
    .SYNOPSIS
        Write a message to both console and log file with timestamp
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (INFO, WARN, ERROR, SUCCESS)
    .PARAMETER NoConsole
        Skip console output (log file only)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter()]
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file if available
    if ($script:LogFile) {
        try {
            Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
    
    # Write to console unless suppressed
    if (-not $NoConsole) {
        switch ($Level) {
            'ERROR' { Write-Host $logEntry -ForegroundColor Red }
            'WARN' { Write-Host $logEntry -ForegroundColor Yellow }
            'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
            'DEBUG' { if ($VerboseLogging) { Write-Host $logEntry -ForegroundColor Cyan } }
            default { Write-Host $logEntry -ForegroundColor White }
        }
    }
}

#endregion

#region Validation Functions

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validate system prerequisites and environment
    .OUTPUTS
        Boolean indicating if all prerequisites are met
    #>
    $isValid = $true
    
    Write-Log "Checking system prerequisites..." -Level INFO
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Log "PowerShell 5.1 or later is required. Current version: $($PSVersionTable.PSVersion)" -Level ERROR
        $isValid = $false
    }
    else {
        Write-Log "PowerShell version check passed: $($PSVersionTable.PSVersion)" -Level SUCCESS
    }
    
    # Check if running as administrator (recommended for most installations)
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Log "Warning: Not running as Administrator. Some installations may fail." -Level WARN
    }
    else {
        Write-Log "Administrator privileges confirmed" -Level SUCCESS
    }
    
    # Check scripts directory
    if (-not (Test-Path -Path $ScriptsPath -PathType Container)) {
        Write-Log "Scripts directory not found: $ScriptsPath" -Level ERROR
        $isValid = $false
    }
    else {
        Write-Log "Scripts directory found: $ScriptsPath" -Level SUCCESS
    }
    
    # Check internet connectivity
    try {
        $testConnection = Test-NetConnection -ComputerName "8.8.8.8" -Port 53 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($testConnection) {
            Write-Log "Internet connectivity confirmed" -Level SUCCESS
        }
        else {
            Write-Log "Warning: Internet connectivity test failed. Downloads may not work." -Level WARN
        }
    }
    catch {
        Write-Log "Warning: Could not test internet connectivity: $($_.Exception.Message)" -Level WARN
    }
    
    return $isValid
}

function Get-ValidScripts {
    <#
    .SYNOPSIS
        Validate and return list of available script files
    .PARAMETER RequestedScripts
        Array of script names requested by user
    .OUTPUTS
        Array of validated script file paths
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$RequestedScripts
    )
    
    $validScripts = @()
    $availableScripts = @(Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" | Where-Object { $_.Name -ne "shared" })

    Write-Log "Found $($availableScripts.Count) available scripts in $ScriptsPath" -Level INFO
    
    foreach ($scriptName in $RequestedScripts) {
        $scriptName = $scriptName.Trim()
        if ([string]::IsNullOrWhiteSpace($scriptName)) {
            continue
        }
        
        # Add .ps1 extension if not present
        if (-not $scriptName.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase)) {
            $scriptName += '.ps1'
        }
        
        $scriptPath = Join-Path -Path $ScriptsPath -ChildPath $scriptName
        
        if (Test-Path -Path $scriptPath -PathType Leaf) {
            $validScripts += $scriptPath
            Write-Log "Validated script: $scriptName" -Level SUCCESS
        }
        else {
            Write-Log "Script not found: $scriptName" -Level ERROR
            $script:ErrorCount++
        }
    }
    
    return $validScripts
}

#endregion

#region Script Execution Functions

function Invoke-AppScript {
    <#
    .SYNOPSIS
        Execute a single app installation script with error handling
    .PARAMETER ScriptPath
        Full path to the PowerShell script to execute
    .OUTPUTS
        Boolean indicating success or failure
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$ScriptPath
    )
    
    $scriptName = Split-Path -Path $ScriptPath -Leaf
    $startTime = Get-Date
    
    Write-Log "Starting execution of: $scriptName" -Level INFO
    
    if ($TestRun) {
        Write-Log "TESTRUN: Would execute script: $ScriptPath" -Level INFO
        return $true
    }
    
    try {
        # Create a new PowerShell session for isolation
        $scriptBlock = {
            param($Path, $VerbosePreference)

            # Set execution policy for this session
            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

            # Execute the script using absolute path
            $absolutePath = Resolve-Path $Path -ErrorAction SilentlyContinue
            if ($absolutePath) {
                & $absolutePath.Path
            } else {
                & $Path
            }

            # Return exit code
            return $LASTEXITCODE
        }

        # Convert to absolute path before passing to job
        $absoluteScriptPath = Resolve-Path $ScriptPath -ErrorAction SilentlyContinue
        $pathToUse = if ($absoluteScriptPath) { $absoluteScriptPath.Path } else { $ScriptPath }

        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $pathToUse, $(if ($VerboseLogging) { 'Continue' } else { 'SilentlyContinue' })
        
        # Wait for completion with timeout (30 minutes max per script)
        $timeout = 1800 # 30 minutes in seconds
        $completed = Wait-Job -Job $job -Timeout $timeout
        
        if ($completed) {
            $result = Receive-Job -Job $job
            $exitCode = $result | Select-Object -Last 1
            
            if ($exitCode -eq 0 -or $null -eq $exitCode) {
                $duration = (Get-Date) - $startTime
                Write-Log "Successfully completed: $scriptName (Duration: $($duration.ToString('mm\:ss')))" -Level SUCCESS
                $script:SuccessCount++
                return $true
            }
            else {
                Write-Log "Script failed with exit code: $exitCode - $scriptName" -Level ERROR
                $script:ErrorCount++
                return $false
            }
        }
        else {
            Write-Log "Script timed out after $timeout seconds: $scriptName" -Level ERROR
            Stop-Job -Job $job -Force
            $script:ErrorCount++
            return $false
        }
    }
    catch {
        Write-Log "Exception executing script $scriptName`: $($_.Exception.Message)" -Level ERROR
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG
        $script:ErrorCount++
        return $false
    }
    finally {
        # Clean up job
        if ($job) {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-ScriptBatch {
    <#
    .SYNOPSIS
        Execute multiple scripts in sequence with progress reporting
    .PARAMETER ScriptPaths
        Array of script file paths to execute
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ScriptPaths
    )
    
    $totalScripts = $ScriptPaths.Count
    $currentScript = 0
    
    Write-Log "Beginning batch execution of $totalScripts scripts" -Level INFO
    
    foreach ($scriptPath in $ScriptPaths) {
        $currentScript++
        $scriptName = Split-Path -Path $scriptPath -Leaf
        
        Write-Progress -Activity "Installing Applications" -Status "Processing $scriptName" -PercentComplete (($currentScript / $totalScripts) * 100)
        
        Write-Log "[$currentScript/$totalScripts] Processing: $scriptName" -Level INFO
        
        $success = Invoke-AppScript -ScriptPath $scriptPath
        
        if (-not $success) {
            Write-Log "Failed to execute: $scriptName" -Level ERROR
            
            # Ask user if they want to continue on error
            if (-not $TestRun) {
                $choice = Read-Host "Continue with remaining scripts? (Y/N)"
                if ($choice -notmatch '^[Yy]') {
                    Write-Log "User chose to abort batch execution" -Level WARN
                    break
                }
            }
        }
    }
    
    Write-Progress -Activity "Installing Applications" -Completed
}

#endregion

#region Main Execution

function Write-ExecutionSummary {
    <#
    .SYNOPSIS
        Write final execution summary to log and console
    #>
    $endTime = Get-Date
    $duration = $endTime - $script:StartTime
    $totalProcessed = $script:SuccessCount + $script:ErrorCount + $script:SkippedCount
    
    $summary = @"

================================================================================
EXECUTION SUMMARY
================================================================================
Start Time: $($script:StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))
Total Duration: $($duration.ToString('hh\:mm\:ss'))

Scripts Processed: $totalProcessed
Successful: $script:SuccessCount
Failed: $script:ErrorCount
Skipped: $script:SkippedCount

Overall Status: $(if ($script:ErrorCount -eq 0) { 'SUCCESS' } else { 'COMPLETED WITH ERRORS' })
================================================================================

"@
    
    Write-Log $summary -Level INFO
    
    if ($script:ErrorCount -eq 0) {
        Write-Log "All scripts completed successfully!" -Level SUCCESS
    }
    else {
        Write-Log "$script:ErrorCount script(s) failed. Check log for details: $script:LogFile" -Level ERROR
    }
}

# Main execution flow
try {
    Write-Host "LaunchScript Manager v1.0.0" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    
    # Initialize logging
    Initialize-Logging
    
    # Validate prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Log "Prerequisites check failed. Aborting execution." -Level ERROR
        exit 1
    }
    
    # Parse and validate requested scripts
    $requestedScripts = @($Scripts -split ',' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    if ($requestedScripts.Count -eq 0) {
        Write-Log "No valid scripts specified. Use -Scripts parameter with comma-separated script names." -Level ERROR
        exit 1
    }
    
    Write-Log "Requested scripts: $($requestedScripts -join ', ')" -Level INFO
    
    # Get valid script paths
    $validScripts = @(Get-ValidScripts -RequestedScripts $requestedScripts)

    if ($validScripts.Count -eq 0) {
        Write-Log "No valid scripts found to execute." -Level ERROR
        exit 1
    }
    
    # Execute scripts
    Invoke-ScriptBatch -ScriptPaths $validScripts
    
    # Write summary
    Write-ExecutionSummary
    
    # Set exit code based on results
    if ($script:ErrorCount -gt 0) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-Log "Fatal error in main execution: $($_.Exception.Message)" -Level ERROR
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG
    exit 1
}
finally {
    # Cleanup
    if ($script:LogFile) {
        Write-Log "Log file saved: $script:LogFile" -Level INFO
    }
}

#endregion
