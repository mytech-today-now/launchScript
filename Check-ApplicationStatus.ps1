#Requires -Version 5.1
<#
.SYNOPSIS
    Application status detection service for LaunchScript Manager
    
.DESCRIPTION
    This script provides real-time application installation status checking
    for the LaunchScript Manager web interface. It scans the host computer
    for installed applications and returns results in JSON format.
    
.PARAMETER Scripts
    Comma-separated list of script names to check (without .ps1 extension)
    If not provided, checks all available scripts
    
.PARAMETER OutputFormat
    Output format: JSON, CSV, or Object (default: JSON)
    
.PARAMETER IncludeWindowsStore
    Include Windows Store apps in detection
    
.PARAMETER IncludePortable
    Include portable application detection
    
.PARAMETER ScriptsPath
    Path to the scripts directory (default: ./scripts/)
    
.EXAMPLE
    .\Check-ApplicationStatus.ps1
    
.EXAMPLE
    .\Check-ApplicationStatus.ps1 -Scripts "VSCode,Firefox,Chrome" -IncludeWindowsStore
    
.EXAMPLE
    .\Check-ApplicationStatus.ps1 -OutputFormat CSV
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    This script is designed to be called by the web interface to provide
    real-time application installation status instead of simulated data.
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Comma-separated list of script names to check")]
    [string]$Scripts,
    
    [Parameter(HelpMessage = "Output format")]
    [ValidateSet('JSON', 'CSV', 'Object')]
    [string]$OutputFormat = 'JSON',
    
    [Parameter(HelpMessage = "Include Windows Store apps")]
    [switch]$IncludeWindowsStore,
    
    [Parameter(HelpMessage = "Include portable applications")]
    [switch]$IncludePortable,
    
    [Parameter(HelpMessage = "Path to scripts directory")]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$ScriptsPath = "./scripts/"
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import shared helper functions
$sharedPath = Join-Path $ScriptsPath "shared\HelperFunctions.ps1"
if (Test-Path $sharedPath) {
    . $sharedPath
}
else {
    Write-Error "Shared helper functions not found: $sharedPath"
    exit 1
}

#region Configuration

# Application metadata mapping for enhanced detection
$script:AppDetectionConfig = @{
    'AngryIPScanner.ps1' = @{
        SearchNames = @('*Angry IP Scanner*', '*AngryIPScanner*')
        CommonPaths = @('AngryIPScanner', 'Angry IP Scanner')
        ExecutableNames = @('ipscan.exe', 'AngryIPScanner.exe')
    }
    'Audacity.ps1' = @{
        SearchNames = @('*Audacity*')
        CommonPaths = @('Audacity')
        ExecutableNames = @('audacity.exe')
    }
    'BelarcAdvisor.ps1' = @{
        SearchNames = @('*Belarc Advisor*', '*BelarcAdvisor*')
        CommonPaths = @('Belarc', 'BelarcAdvisor')
        ExecutableNames = @('advisor.exe', 'BelarcAdvisor.exe')
    }
    'Blender.ps1' = @{
        SearchNames = @('*Blender*')
        CommonPaths = @('Blender Foundation\Blender', 'Blender')
        ExecutableNames = @('blender.exe')
    }
    'Brave.ps1' = @{
        SearchNames = @('*Brave*')
        CommonPaths = @('BraveSoftware\Brave-Browser', 'Brave')
        ExecutableNames = @('brave.exe')
    }
    'ChatGPT.ps1' = @{
        SearchNames = @('*ChatGPT*', '*OpenAI*')
        CommonPaths = @('ChatGPT', 'OpenAI')
        ExecutableNames = @('ChatGPT.exe', 'OpenAI.exe')
    }
    'ClipGrab.ps1' = @{
        SearchNames = @('*ClipGrab*')
        CommonPaths = @('ClipGrab')
        ExecutableNames = @('ClipGrab.exe')
    }
    'Firefox.ps1' = @{
        SearchNames = @('*Mozilla Firefox*', '*Firefox*')
        CommonPaths = @('Mozilla Firefox')
        ExecutableNames = @('firefox.exe')
    }
    'GIMP.ps1' = @{
        SearchNames = @('*GIMP*', '*GNU Image Manipulation Program*')
        CommonPaths = @('GIMP 2', 'GIMP')
        ExecutableNames = @('gimp-2.*.exe', 'gimp.exe')
    }
    'MicrosoftQuickConnect.ps1' = @{
        SearchNames = @('*Quick Connect*', '*Microsoft Quick Connect*')
        CommonPaths = @('Microsoft', 'QuickConnect')
        ExecutableNames = @('QuickConnect.exe')
    }
    'NotePad++.ps1' = @{
        SearchNames = @('*Notepad++*', '*Notepad+*')
        CommonPaths = @('Notepad++')
        ExecutableNames = @('notepad++.exe')
    }
    'OpenOfficeSuite.ps1' = @{
        SearchNames = @('*OpenOffice*', '*Apache OpenOffice*')
        CommonPaths = @('OpenOffice 4', 'OpenOffice')
        ExecutableNames = @('soffice.exe', 'swriter.exe')
    }
    'OpenShot.ps1' = @{
        SearchNames = @('*OpenShot*')
        CommonPaths = @('OpenShot Video Editor')
        ExecutableNames = @('openshot-qt.exe')
    }
    'Opera.ps1' = @{
        SearchNames = @('*Opera*')
        CommonPaths = @('Opera')
        ExecutableNames = @('opera.exe')
    }
    'RenameIt.ps1' = @{
        SearchNames = @('*Rename It*', '*RenameIt*')
        CommonPaths = @('RenameIt')
        ExecutableNames = @('RenameIt.exe')
    }
    'Signal.ps1' = @{
        SearchNames = @('*Signal*')
        CommonPaths = @('Signal')
        ExecutableNames = @('Signal.exe')
    }
    'Telegram.ps1' = @{
        SearchNames = @('*Telegram*')
        CommonPaths = @('Telegram Desktop')
        ExecutableNames = @('Telegram.exe')
    }
    'TestApp.ps1' = @{
        SearchNames = @('*TestApp*', '*Test Application*')
        CommonPaths = @('TestApp')
        ExecutableNames = @('TestApp.exe')
    }
    'TreeSizeFree.ps1' = @{
        SearchNames = @('*TreeSize*')
        CommonPaths = @('JAM Software\TreeSize')
        ExecutableNames = @('TreeSize.exe', 'TreeSizeFree.exe')
    }
    'VSCode.ps1' = @{
        SearchNames = @('*Microsoft Visual Studio Code*', '*Visual Studio Code*', '*VSCode*')
        CommonPaths = @('Microsoft VS Code')
        ExecutableNames = @('Code.exe')
    }
    'WiseDuplicateFinder.ps1' = @{
        SearchNames = @('*Wise Duplicate Finder*', '*WiseDuplicateFinder*')
        CommonPaths = @('Wise\Wise Duplicate Finder')
        ExecutableNames = @('WiseDuplicateFinder.exe')
    }
}

#endregion

#region Detection Functions

function Get-ApplicationInstallationStatus {
    <#
    .SYNOPSIS
        Check installation status for a specific application script
    .PARAMETER ScriptName
        Name of the script file (with .ps1 extension)
    .OUTPUTS
        Hashtable containing installation status and details
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName
    )
    
    try {
        Write-AppLog "Checking installation status for: $ScriptName" -Level INFO -Component "StatusChecker"
        
        # Get detection configuration for this app
        $config = $script:AppDetectionConfig[$ScriptName]
        if (-not $config) {
            Write-AppLog "No detection configuration found for: $ScriptName" -Level WARN -Component "StatusChecker"
            return @{
                ScriptName = $ScriptName
                AppName = $ScriptName -replace '\.ps1$', ''
                IsInstalled = $false
                Version = $null
                Publisher = $null
                InstallLocation = $null
                Source = $null
                InstallDate = $null
                Error = "No detection configuration"
                CheckedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
        
        # Try each search name pattern with proper error handling
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
            try {
                $result = Test-ProgramInstalled -Name $searchName -IncludeWindowsStore:$IncludeWindowsStore -IncludePortable:$IncludePortable

                # Ensure result has required properties
                if ($result -and $result.ContainsKey('IsInstalled') -and $result.IsInstalled) {
                    $installationFound = $result
                    Write-AppLog "Found installation using search pattern: $searchName" -Level DEBUG -Component "StatusChecker"
                    break
                }
            }
            catch {
                Write-AppLog "Error searching with pattern '$searchName': $($_.Exception.Message)" -Level WARN -Component "StatusChecker"
                continue
            }
        }

        # If not found in registry, try file system detection
        if (-not $installationFound.IsInstalled -and $IncludePortable) {
            try {
                $fileSystemResult = Test-FileSystemInstallation -Config $config -ScriptName $ScriptName
                if ($fileSystemResult -and $fileSystemResult.ContainsKey('IsInstalled') -and $fileSystemResult.IsInstalled) {
                    $installationFound = $fileSystemResult
                    Write-AppLog "Found installation via file system detection" -Level DEBUG -Component "StatusChecker"
                }
            }
            catch {
                Write-AppLog "File system detection failed: $($_.Exception.Message)" -Level WARN -Component "StatusChecker"
            }
        }
        
        $status = @{
            ScriptName = $ScriptName
            AppName = $ScriptName -replace '\.ps1$', ''
            IsInstalled = $installationFound.IsInstalled
            Version = $installationFound.Version
            Publisher = $installationFound.Publisher
            InstallLocation = $installationFound.InstallLocation
            Source = $installationFound.Source
            InstallDate = $installationFound.InstallDate
            Error = $null
            CheckedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
        
        $statusText = if ($status.IsInstalled) { "INSTALLED" } else { "NOT INSTALLED" }
        Write-AppLog "$($status.AppName): $statusText" -Level $(if ($status.IsInstalled) { "SUCCESS" } else { "INFO" }) -Component "StatusChecker"
        
        return $status
    }
    catch {
        Write-AppLog "Error checking status for $ScriptName`: $($_.Exception.Message)" -Level ERROR -Component "StatusChecker"
        return @{
            ScriptName = $ScriptName
            AppName = $ScriptName -replace '\.ps1$', ''
            IsInstalled = $false
            Version = $null
            Publisher = $null
            InstallLocation = $null
            Source = $null
            InstallDate = $null
            Error = $_.Exception.Message
            CheckedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        }
    }
}

function Test-FileSystemInstallation {
    <#
    .SYNOPSIS
        Check for application installation via file system scanning
    .PARAMETER Config
        Application detection configuration
    .PARAMETER ScriptName
        Script name for logging
    .OUTPUTS
        Installation status hashtable
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptName
    )
    
    try {
        Write-AppLog "Performing file system detection for: $ScriptName" -Level DEBUG -Component "StatusChecker"
        
        # Common installation directories
        $searchPaths = @(
            $env:ProgramFiles,
            ${env:ProgramFiles(x86)},
            "$env:LOCALAPPDATA\Programs",
            $env:APPDATA
        )
        
        foreach ($basePath in $searchPaths) {
            if (-not (Test-Path $basePath)) { continue }
            
            foreach ($commonPath in $Config.CommonPaths) {
                $fullPath = Join-Path $basePath $commonPath
                if (Test-Path $fullPath) {
                    # Look for executable files
                    foreach ($exeName in $Config.ExecutableNames) {
                        $exePath = Join-Path $fullPath $exeName
                        if (Test-Path $exePath) {
                            try {
                                $versionInfo = (Get-Item $exePath).VersionInfo
                                return @{
                                    IsInstalled = $true
                                    DisplayName = $versionInfo.ProductName
                                    Version = $versionInfo.ProductVersion
                                    Publisher = $versionInfo.CompanyName
                                    InstallLocation = $fullPath
                                    Source = 'FileSystem'
                                    InstallDate = (Get-Item $exePath).CreationTime.ToString('yyyyMMdd')
                                }
                            }
                            catch {
                                # Return basic info if version info fails
                                return @{
                                    IsInstalled = $true
                                    DisplayName = $ScriptName -replace '\.ps1$', ''
                                    Version = 'Unknown'
                                    Publisher = 'Unknown'
                                    InstallLocation = $fullPath
                                    Source = 'FileSystem'
                                    InstallDate = (Get-Item $exePath).CreationTime.ToString('yyyyMMdd')
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return @{
            IsInstalled = $false
            DisplayName = $null
            Version = $null
            Publisher = $null
            InstallLocation = $null
            Source = $null
            InstallDate = $null
        }
    }
    catch {
        Write-AppLog "File system detection failed for $ScriptName`: $($_.Exception.Message)" -Level DEBUG -Component "StatusChecker"
        return @{
            IsInstalled = $false
            DisplayName = $null
            Version = $null
            Publisher = $null
            InstallLocation = $null
            Source = $null
            InstallDate = $null
        }
    }
}

#endregion

#region Main Execution

function Get-AvailableScripts {
    <#
    .SYNOPSIS
        Get list of available PowerShell scripts in the scripts directory
    .OUTPUTS
        Array of script filenames
    #>
    try {
        $scriptFiles = Get-ChildItem -Path $ScriptsPath -Filter "*.ps1" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne "shared" -and $_.Name -notlike "*Helper*" } |
            Select-Object -ExpandProperty Name

        Write-AppLog "Found $($scriptFiles.Count) available scripts" -Level INFO -Component "StatusChecker"
        return $scriptFiles
    }
    catch {
        Write-AppLog "Failed to get available scripts: $($_.Exception.Message)" -Level ERROR -Component "StatusChecker"
        return @()
    }
}

function Format-Output {
    <#
    .SYNOPSIS
        Format the results according to the specified output format
    .PARAMETER Results
        Array of application status results
    .PARAMETER Format
        Output format (JSON, CSV, Object)
    .OUTPUTS
        Formatted output string or object
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Results,

        [Parameter(Mandatory = $true)]
        [string]$Format
    )

    try {
        switch ($Format.ToUpper()) {
            'JSON' {
                $resultsArray = @($Results)
                $installedApps = @($resultsArray | Where-Object { $_.IsInstalled })
                $notInstalledApps = @($resultsArray | Where-Object { -not $_.IsInstalled })

                $jsonOutput = @{
                    Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    TotalApps = $resultsArray.Count
                    InstalledCount = $installedApps.Count
                    NotInstalledCount = $notInstalledApps.Count
                    IncludeWindowsStore = $IncludeWindowsStore.IsPresent
                    IncludePortable = $IncludePortable.IsPresent
                    Applications = $resultsArray
                } | ConvertTo-Json -Depth 10 -Compress:$false

                return $jsonOutput
            }
            'CSV' {
                return $Results | ConvertTo-Csv -NoTypeInformation
            }
            'OBJECT' {
                return $Results
            }
            default {
                throw "Unsupported output format: $Format"
            }
        }
    }
    catch {
        Write-AppLog "Failed to format output: $($_.Exception.Message)" -Level ERROR -Component "StatusChecker"
        throw
    }
}

# Main execution
try {
    Write-AppLog "=== Application Status Detection Service v1.0.0 ===" -Level INFO -Component "StatusChecker"
    Write-AppLog "Scripts Path: $ScriptsPath" -Level INFO -Component "StatusChecker"
    Write-AppLog "Include Windows Store: $($IncludeWindowsStore.IsPresent)" -Level INFO -Component "StatusChecker"
    Write-AppLog "Include Portable: $($IncludePortable.IsPresent)" -Level INFO -Component "StatusChecker"
    Write-AppLog "Output Format: $OutputFormat" -Level INFO -Component "StatusChecker"

    # Determine which scripts to check
    if ($Scripts) {
        $scriptsToCheck = @($Scripts -split ',' | ForEach-Object {
            $scriptName = $_.Trim()
            if (-not $scriptName.EndsWith('.ps1')) {
                $scriptName += '.ps1'
            }
            $scriptName
        })
        Write-AppLog "Checking specific scripts: $($scriptsToCheck -join ', ')" -Level INFO -Component "StatusChecker"
    }
    else {
        $scriptsToCheck = Get-AvailableScripts
        Write-AppLog "Checking all available scripts" -Level INFO -Component "StatusChecker"
    }

    if ($scriptsToCheck.Count -eq 0) {
        Write-AppLog "No scripts found to check" -Level WARN -Component "StatusChecker"
        $emptyResult = @{
            Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            TotalApps = 0
            InstalledCount = 0
            NotInstalledCount = 0
            IncludeWindowsStore = $IncludeWindowsStore.IsPresent
            IncludePortable = $IncludePortable.IsPresent
            Applications = @()
            Error = "No scripts found to check"
        }

        if ($OutputFormat -eq 'JSON') {
            Write-Output ($emptyResult | ConvertTo-Json -Depth 10)
        }
        else {
            Write-Output $emptyResult
        }
        exit 0
    }

    # Check installation status for each script
    $results = @()
    $currentScript = 0

    foreach ($scriptName in $scriptsToCheck) {
        $currentScript++
        Write-Progress -Activity "Checking Application Status" -Status "Processing $scriptName" -PercentComplete (($currentScript / $scriptsToCheck.Count) * 100)

        $status = Get-ApplicationInstallationStatus -ScriptName $scriptName
        $results += @($status)  # Ensure it's always treated as an array
    }

    Write-Progress -Activity "Checking Application Status" -Completed

    # Format and output results
    $output = Format-Output -Results $results -Format $OutputFormat
    Write-Output $output

    # Log summary
    $installedCount = ($results | Where-Object { $_.IsInstalled }).Count
    $totalCount = $results.Count
    Write-AppLog "Status check completed: $installedCount/$totalCount applications installed" -Level SUCCESS -Component "StatusChecker"

    exit 0
}
catch {
    Write-AppLog "Fatal error in status detection: $($_.Exception.Message)" -Level ERROR -Component "StatusChecker"
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component "StatusChecker"

    # Return error in requested format
    $errorResult = @{
        Timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        TotalApps = 0
        InstalledCount = 0
        NotInstalledCount = 0
        IncludeWindowsStore = $IncludeWindowsStore.IsPresent
        IncludePortable = $IncludePortable.IsPresent
        Applications = @()
        Error = $_.Exception.Message
    }

    if ($OutputFormat -eq 'JSON') {
        Write-Output ($errorResult | ConvertTo-Json -Depth 10)
    }
    else {
        Write-Output $errorResult
    }

    exit 1
}

#endregion
