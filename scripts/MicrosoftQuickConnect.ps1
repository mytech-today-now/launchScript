#Requires -Version 5.1
<#
.SYNOPSIS
    Silent installation script for Microsoft Quick Assist
    
.DESCRIPTION
    This script automatically downloads and installs Microsoft Quick Assist from the
    Microsoft Store or official sources. Quick Assist is a remote assistance tool
    that allows users to give and receive assistance over a remote connection.
    
.PARAMETER Force
    Force reinstallation even if Quick Assist is already installed
    
.PARAMETER Version
    Specific version to install (default: latest)
    
.PARAMETER UseStore
    Install from Microsoft Store (default: true)
    
.EXAMPLE
    .\MicrosoftQuickConnect.ps1
    
.EXAMPLE
    .\MicrosoftQuickConnect.ps1 -Force
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Internet connection
    - Windows 10 version 1607 or later
    - Microsoft Store (for Store installation)
    
    Official Website: https://support.microsoft.com/en-us/windows/solve-pc-problems-over-a-remote-connection-b077e31a-16f4-2529-1a47-21f6a9040bf3
    Store Page: https://www.microsoft.com/store/apps/9nblggh5s4g7
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Force reinstallation even if already installed")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Specific version to install")]
    [string]$Version,
    
    [Parameter(HelpMessage = "Install from Microsoft Store")]
    [switch]$UseStore = $true
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Import shared helper functions
$sharedPath = Join-Path $PSScriptRoot "shared\HelperFunctions.ps1"
if (Test-Path $sharedPath) {
    . $sharedPath
}
else {
    Write-Error "Shared helper functions not found: $sharedPath"
    exit 1
}

#region Configuration

$script:AppConfig = @{
    Name = "Microsoft Quick Assist"
    DisplayName = "Quick Assist*"
    Publisher = "Microsoft Corporation"
    OfficialWebsite = "https://support.microsoft.com/en-us/windows/solve-pc-problems-over-a-remote-connection-b077e31a-16f4-2529-1a47-21f6a9040bf3"
    StoreUrl = "ms-windows-store://pdp/?productid=9nblggh5s4g7"
    StoreWebUrl = "https://www.microsoft.com/store/apps/9nblggh5s4g7"
    AppxPackageName = "MicrosoftCorporationII.QuickAssist"
}

#endregion

#region Version Detection Functions

function Get-QuickAssistLatestVersion {
    <#
    .SYNOPSIS
        Get the latest stable version of Quick Assist
    .OUTPUTS
        Hashtable containing version information
    #>
    try {
        Write-AppLog "Fetching Quick Assist version information..." -Level INFO -Component $script:AppConfig.Name
        
        # Quick Assist is typically pre-installed on Windows 10/11 or available through Store
        # Version information is not easily accessible via API
        $version = "Latest"
        
        $versionInfo = @{
            Version = $version
            InstallMethod = if ($UseStore) { "Microsoft Store" } else { "Built-in Windows Feature" }
            Architecture = Get-SystemArchitecture
            ReleaseDate = (Get-Date).ToString()
        }
        
        Write-AppLog "Target version: $($versionInfo.Version) via $($versionInfo.InstallMethod)" -Level SUCCESS -Component $script:AppConfig.Name
        
        return $versionInfo
    }
    catch {
        Write-AppLog "Failed to get version information: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        throw
    }
}

function Get-InstalledQuickAssistVersion {
    <#
    .SYNOPSIS
        Get the currently installed version of Quick Assist
    .OUTPUTS
        String containing the installed version, or $null if not installed
    #>
    try {
        # Check for Quick Assist as an installed program
        $installedPrograms = Get-InstalledPrograms -Name $script:AppConfig.DisplayName
        
        if ($installedPrograms.Count -gt 0) {
            $installedVersion = $installedPrograms[0].DisplayVersion
            Write-AppLog "Currently installed version: $installedVersion" -Level INFO -Component $script:AppConfig.Name
            return $installedVersion
        }
        
        # Check for Quick Assist as an AppX package (Windows Store app)
        try {
            $appxPackage = Get-AppxPackage -Name $script:AppConfig.AppxPackageName -ErrorAction SilentlyContinue
            if ($appxPackage) {
                $installedVersion = $appxPackage.Version
                Write-AppLog "Currently installed AppX version: $installedVersion" -Level INFO -Component $script:AppConfig.Name
                return $installedVersion
            }
        }
        catch {
            Write-AppLog "Could not check AppX packages: $($_.Exception.Message)" -Level DEBUG -Component $script:AppConfig.Name
        }
        
        # Check if Quick Assist executable exists (built-in Windows feature)
        $quickAssistPath = Join-Path $env:SystemRoot "System32\quickassist.exe"
        if (Test-Path $quickAssistPath) {
            Write-AppLog "Quick Assist found as built-in Windows feature" -Level INFO -Component $script:AppConfig.Name
            return "Built-in"
        }
        
        Write-AppLog "Quick Assist is not currently installed" -Level INFO -Component $script:AppConfig.Name
        return $null
    }
    catch {
        Write-AppLog "Failed to check installed version: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        return $null
    }
}

#endregion

#region Installation Functions

function Install-QuickAssistFromStore {
    <#
    .SYNOPSIS
        Install Quick Assist from Microsoft Store
    .OUTPUTS
        Boolean indicating installation success
    #>
    try {
        Write-AppLog "Installing Quick Assist from Microsoft Store..." -Level INFO -Component $script:AppConfig.Name
        
        # Check if Microsoft Store is available
        try {
            $storeApp = Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue
            if (-not $storeApp) {
                throw "Microsoft Store is not available on this system"
            }
        }
        catch {
            Write-AppLog "Microsoft Store check failed: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
            return $false
        }
        
        # Try to launch the Store URL
        Write-AppLog "Opening Microsoft Store for Quick Assist installation..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "Store URL: $($script:AppConfig.StoreUrl)" -Level DEBUG -Component $script:AppConfig.Name
        
        try {
            Start-Process $script:AppConfig.StoreUrl
            Write-AppLog "Microsoft Store opened. Please complete the installation manually." -Level INFO -Component $script:AppConfig.Name
            Write-AppLog "The installation will continue automatically once you click 'Install' in the Store." -Level INFO -Component $script:AppConfig.Name
            
            # Wait for user to complete installation
            Write-AppLog "Waiting for installation to complete..." -Level INFO -Component $script:AppConfig.Name
            
            $timeout = 300  # 5 minutes timeout
            $elapsed = 0
            $checkInterval = 10  # Check every 10 seconds
            
            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds $checkInterval
                $elapsed += $checkInterval
                
                # Check if Quick Assist is now installed
                $currentVersion = Get-InstalledQuickAssistVersion
                if ($currentVersion) {
                    Write-AppLog "Quick Assist installation detected!" -Level SUCCESS -Component $script:AppConfig.Name
                    return $true
                }
                
                Write-AppLog "Still waiting for installation... ($elapsed/$timeout seconds)" -Level INFO -Component $script:AppConfig.Name
            }
            
            Write-AppLog "Installation timeout reached. Please verify installation manually." -Level WARN -Component $script:AppConfig.Name
            return $false
        }
        catch {
            Write-AppLog "Failed to open Microsoft Store: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
            return $false
        }
    }
    catch {
        Write-AppLog "Exception during Store installation: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        return $false
    }
}

function Enable-QuickAssistFeature {
    <#
    .SYNOPSIS
        Enable Quick Assist as a Windows feature (if available)
    .OUTPUTS
        Boolean indicating success
    #>
    try {
        Write-AppLog "Checking for Quick Assist as built-in Windows feature..." -Level INFO -Component $script:AppConfig.Name
        
        # Check if Quick Assist executable exists
        $quickAssistPath = Join-Path $env:SystemRoot "System32\quickassist.exe"
        if (Test-Path $quickAssistPath) {
            Write-AppLog "Quick Assist is already available as a built-in Windows feature" -Level SUCCESS -Component $script:AppConfig.Name
            return $true
        }
        
        # Try to enable Windows optional feature (if applicable)
        try {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName "QuickAssist" -ErrorAction SilentlyContinue
            if ($feature -and $feature.State -eq "Disabled") {
                Write-AppLog "Enabling Quick Assist Windows feature..." -Level INFO -Component $script:AppConfig.Name
                Enable-WindowsOptionalFeature -Online -FeatureName "QuickAssist" -All -NoRestart
                return $true
            }
        }
        catch {
            Write-AppLog "Quick Assist is not available as a Windows optional feature" -Level INFO -Component $script:AppConfig.Name
        }
        
        Write-AppLog "Quick Assist is not available as a built-in feature on this system" -Level WARN -Component $script:AppConfig.Name
        return $false
    }
    catch {
        Write-AppLog "Exception while checking Windows features: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        return $false
    }
}

function Test-InstallationRequired {
    <#
    .SYNOPSIS
        Determine if installation is required based on current state and parameters
    .OUTPUTS
        Boolean indicating if installation should proceed
    #>
    # Check if already installed
    $installedVersion = Get-InstalledQuickAssistVersion
    
    if (-not $installedVersion) {
        Write-AppLog "Installation required: Quick Assist is not installed" -Level INFO -Component $script:AppConfig.Name
        return $true
    }
    
    if ($Force) {
        Write-AppLog "Installation forced by user parameter" -Level INFO -Component $script:AppConfig.Name
        return $true
    }
    
    Write-AppLog "Quick Assist is already available: $installedVersion" -Level SUCCESS -Component $script:AppConfig.Name
    return $false
}

#endregion

#region Main Execution

try {
    Write-AppLog "=== Microsoft Quick Assist Installation Script v1.0.0 ===" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Official website: $($script:AppConfig.OfficialWebsite)" -Level INFO -Component $script:AppConfig.Name
    
    # Get version information
    $versionInfo = Get-QuickAssistLatestVersion
    
    # Check if installation is required
    if (-not (Test-InstallationRequired)) {
        Write-AppLog "No installation required. Use -Force to reinstall." -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    
    # Try different installation methods
    $installResult = $false
    
    if ($UseStore) {
        Write-AppLog "Attempting installation from Microsoft Store..." -Level INFO -Component $script:AppConfig.Name
        $installResult = Install-QuickAssistFromStore
    }
    
    if (-not $installResult) {
        Write-AppLog "Attempting to enable as Windows feature..." -Level INFO -Component $script:AppConfig.Name
        $installResult = Enable-QuickAssistFeature
    }
    
    if ($installResult) {
        Write-AppLog "Quick Assist setup completed successfully!" -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    else {
        Write-AppLog "Quick Assist installation failed!" -Level ERROR -Component $script:AppConfig.Name
        Write-AppLog "Note: Quick Assist may need to be installed manually from the Microsoft Store." -Level INFO -Component $script:AppConfig.Name
        exit 1
    }
}
catch {
    Write-AppLog "Fatal error: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component $script:AppConfig.Name
    exit 1
}

#endregion
