#Requires -Version 5.1
<#
.SYNOPSIS
    Silent installation script for Brave Browser
    
.DESCRIPTION
    This script automatically downloads and installs the latest stable version of
    Brave Browser from the official website. It detects the system architecture and
    downloads the appropriate installer, then performs a silent installation.
    
.PARAMETER Force
    Force reinstallation even if Brave is already installed
    
.PARAMETER Version
    Specific version to install (default: latest)
    
.PARAMETER InstallPath
    Custom installation path (default: Program Files)
    
.EXAMPLE
    .\Brave.ps1
    
.EXAMPLE
    .\Brave.ps1 -Force
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Internet connection
    - Administrator privileges (recommended)
    
    Official Website: https://brave.com/
    Download Page: https://brave.com/download/
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Force reinstallation even if already installed")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Specific version to install")]
    [string]$Version,
    
    [Parameter(HelpMessage = "Custom installation path")]
    [string]$InstallPath
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
    Name = "Brave Browser"
    DisplayName = "Brave*"
    Publisher = "Brave Software Inc"
    OfficialWebsite = "https://brave.com/"
    DownloadPage = "https://brave.com/download/"
    VersionCheckUrl = "https://api.github.com/repos/brave/brave-browser/releases/latest"
    GitHubRepo = "brave/brave-browser"
    DirectDownloadUrl = "https://laptop-updates.brave.com/latest/winx64"
    SilentArgs = @("/silent", "/install")  # Brave installer silent arguments
    ValidExitCodes = @(0, 3010)  # 0 = success, 3010 = success with reboot required
}

#endregion

#region Version Detection Functions

function Get-BraveLatestVersion {
    <#
    .SYNOPSIS
        Get the latest stable version of Brave from GitHub releases or direct download
    .OUTPUTS
        Hashtable containing version information and download URLs
    #>
    try {
        Write-AppLog "Fetching latest Brave version information..." -Level INFO -Component $script:AppConfig.Name
        
        # Get system architecture
        $arch = Get-SystemArchitecture
        
        # Try to get version from GitHub API first
        try {
            $releaseInfo = Get-LatestVersionFromGitHub -Repository $script:AppConfig.GitHubRepo
            $version = $releaseInfo.Version -replace '^v', ''
        }
        catch {
            Write-AppLog "Could not get version from GitHub, using direct download" -Level WARN -Component $script:AppConfig.Name
            $version = "Latest"
        }
        
        # Construct download URL based on architecture
        $downloadUrl = if ($arch -eq 'x64') {
            "https://laptop-updates.brave.com/latest/winx64"
        } else {
            "https://laptop-updates.brave.com/latest/winia32"
        }
        
        $fileName = "BraveBrowserSetup-$arch.exe"
        
        $versionInfo = @{
            Version = $version
            DownloadUrl = $downloadUrl
            FileName = $fileName
            FileSize = 0  # Size not available from direct download
            Architecture = $arch
            ReleaseDate = if ($releaseInfo) { $releaseInfo.PublishedAt } else { (Get-Date).ToString() }
        }
        
        Write-AppLog "Latest version: $($versionInfo.Version) ($($versionInfo.Architecture))" -Level SUCCESS -Component $script:AppConfig.Name
        Write-AppLog "Download URL: $($versionInfo.DownloadUrl)" -Level DEBUG -Component $script:AppConfig.Name
        
        return $versionInfo
    }
    catch {
        Write-AppLog "Failed to get latest version: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        throw
    }
}

function Get-InstalledBraveVersion {
    <#
    .SYNOPSIS
        Get the currently installed version of Brave
    .OUTPUTS
        String containing the installed version, or $null if not installed
    #>
    try {
        $installedPrograms = Get-InstalledPrograms -Name $script:AppConfig.DisplayName
        
        if ($installedPrograms.Count -gt 0) {
            $installedVersion = $installedPrograms[0].DisplayVersion
            Write-AppLog "Currently installed version: $installedVersion" -Level INFO -Component $script:AppConfig.Name
            return $installedVersion
        }
        else {
            Write-AppLog "Brave is not currently installed" -Level INFO -Component $script:AppConfig.Name
            return $null
        }
    }
    catch {
        Write-AppLog "Failed to check installed version: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        return $null
    }
}

#endregion

#region Installation Functions

function Install-Brave {
    <#
    .SYNOPSIS
        Download and install Brave
    .PARAMETER VersionInfo
        Version information hashtable from Get-BraveLatestVersion
    .OUTPUTS
        Boolean indicating installation success
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VersionInfo
    )
    
    $tempDir = $null
    
    try {
        Write-AppLog "Starting Brave installation process..." -Level INFO -Component $script:AppConfig.Name
        
        # Create temporary directory
        $tempDir = New-TempDirectory -Prefix "Brave"
        $installerPath = Join-Path $tempDir $VersionInfo.FileName
        
        # Download installer
        Write-AppLog "Downloading Brave installer..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "File: $($VersionInfo.FileName)" -Level INFO -Component $script:AppConfig.Name
        
        Invoke-WebRequestWithRetry -Uri $VersionInfo.DownloadUrl -OutFile $installerPath
        
        # Verify download
        if (-not (Test-Path $installerPath)) {
            throw "Downloaded installer not found: $installerPath"
        }
        
        $downloadedSize = (Get-Item $installerPath).Length
        Write-AppLog "Download completed: $([math]::Round($downloadedSize / 1MB, 2)) MB" -Level SUCCESS -Component $script:AppConfig.Name
        
        # Verify digital signature (optional but recommended)
        try {
            $signatureValid = Test-ExecutableSignature -FilePath $installerPath
            if ($signatureValid) {
                Write-AppLog "Digital signature verification passed" -Level SUCCESS -Component $script:AppConfig.Name
            }
            else {
                Write-AppLog "Digital signature verification failed - proceeding anyway" -Level WARN -Component $script:AppConfig.Name
            }
        }
        catch {
            Write-AppLog "Could not verify digital signature: $($_.Exception.Message)" -Level WARN -Component $script:AppConfig.Name
        }
        
        # Prepare installation arguments
        $installArgs = $script:AppConfig.SilentArgs
        
        # Add custom install path if specified
        if ($InstallPath) {
            $installArgs += "--install-path=`"$InstallPath`""
            Write-AppLog "Custom installation path: $InstallPath" -Level INFO -Component $script:AppConfig.Name
        }
        
        # Check if elevation is recommended
        if (-not (Test-IsElevated)) {
            Write-AppLog "Warning: Not running as Administrator. Installation may fail or install to user directory." -Level WARN -Component $script:AppConfig.Name
        }
        
        # Execute silent installation
        Write-AppLog "Executing silent installation..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "Command: $installerPath $($installArgs -join ' ')" -Level DEBUG -Component $script:AppConfig.Name
        
        $installSuccess = Invoke-SilentInstaller -FilePath $installerPath -Arguments $installArgs -TimeoutMinutes 10
        
        if ($installSuccess) {
            Write-AppLog "Installation completed successfully" -Level SUCCESS -Component $script:AppConfig.Name
            
            # Verify installation
            Start-Sleep -Seconds 5  # Give Windows time to update registry
            $newVersion = Get-InstalledBraveVersion
            
            if ($newVersion) {
                Write-AppLog "Installation verified: Brave v$newVersion is now installed" -Level SUCCESS -Component $script:AppConfig.Name
                return $true
            }
            else {
                Write-AppLog "Installation may have failed - program not found in registry" -Level WARN -Component $script:AppConfig.Name
                return $false
            }
        }
        else {
            Write-AppLog "Installation failed" -Level ERROR -Component $script:AppConfig.Name
            return $false
        }
    }
    catch {
        Write-AppLog "Exception during installation: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        return $false
    }
    finally {
        # Clean up temporary files
        if ($tempDir) {
            Remove-TempDirectory -Path $tempDir
        }
    }
}

function Test-InstallationRequired {
    <#
    .SYNOPSIS
        Determine if installation is required based on current state and parameters
    .PARAMETER LatestVersion
        Latest available version
    .OUTPUTS
        Boolean indicating if installation should proceed
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LatestVersion
    )
    
    # Check if already installed
    $installedVersion = Get-InstalledBraveVersion
    
    if (-not $installedVersion) {
        Write-AppLog "Installation required: Brave is not installed" -Level INFO -Component $script:AppConfig.Name
        return $true
    }
    
    if ($Force) {
        Write-AppLog "Installation forced by user parameter" -Level INFO -Component $script:AppConfig.Name
        return $true
    }
    
    # For Brave, if we can't determine exact version, assume update is needed
    if ($LatestVersion -eq "Latest") {
        Write-AppLog "Cannot compare versions, proceeding with installation" -Level INFO -Component $script:AppConfig.Name
        return $true
    }
    
    # Compare versions (simple string comparison should work for most cases)
    try {
        $installedVer = [version]$installedVersion
        $latestVer = [version]$LatestVersion
        
        if ($latestVer -gt $installedVer) {
            Write-AppLog "Update available: $installedVersion -> $LatestVersion" -Level INFO -Component $script:AppConfig.Name
            return $true
        }
        elseif ($latestVer -eq $installedVer) {
            Write-AppLog "Latest version already installed: $installedVersion" -Level SUCCESS -Component $script:AppConfig.Name
            return $false
        }
        else {
            Write-AppLog "Newer version already installed: $installedVersion (latest: $LatestVersion)" -Level INFO -Component $script:AppConfig.Name
            return $false
        }
    }
    catch {
        # Fallback to string comparison if version parsing fails
        if ($installedVersion -ne $LatestVersion) {
            Write-AppLog "Version comparison failed, proceeding with installation" -Level WARN -Component $script:AppConfig.Name
            return $true
        }
        else {
            Write-AppLog "Same version already installed: $installedVersion" -Level SUCCESS -Component $script:AppConfig.Name
            return $false
        }
    }
}

#endregion

#region Main Execution

try {
    Write-AppLog "=== Brave Browser Installation Script v1.0.0 ===" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Official website: $($script:AppConfig.OfficialWebsite)" -Level INFO -Component $script:AppConfig.Name
    
    # Get version information
    if ($Version) {
        Write-AppLog "Specific version requested: $Version" -Level INFO -Component $script:AppConfig.Name
        throw "Specific version installation not implemented in this example. Use latest version."
    }
    else {
        $versionInfo = Get-BraveLatestVersion
    }
    
    # Check if installation is required
    if (-not (Test-InstallationRequired -LatestVersion $versionInfo.Version)) {
        Write-AppLog "No installation required. Use -Force to reinstall." -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    
    # Perform installation
    $installResult = Install-Brave -VersionInfo $versionInfo
    
    if ($installResult) {
        Write-AppLog "Brave installation completed successfully!" -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    else {
        Write-AppLog "Brave installation failed!" -Level ERROR -Component $script:AppConfig.Name
        exit 1
    }
}
catch {
    Write-AppLog "Fatal error: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component $script:AppConfig.Name
    exit 1
}

#endregion
