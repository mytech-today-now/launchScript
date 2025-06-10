#Requires -Version 5.1
<#
.SYNOPSIS
    Silent installation script for Angry IP Scanner
    
.DESCRIPTION
    This script automatically downloads and installs the latest stable version of
    Angry IP Scanner from the official website. Angry IP Scanner is a fast and
    friendly network scanner that can scan IP addresses and ports.
    
.PARAMETER Force
    Force reinstallation even if Angry IP Scanner is already installed
    
.PARAMETER Version
    Specific version to install (default: latest)
    
.PARAMETER InstallPath
    Custom installation path (default: Program Files)
    
.EXAMPLE
    .\AngryIPScanner.ps1
    
.EXAMPLE
    .\AngryIPScanner.ps1 -Force
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Internet connection
    - Administrator privileges (recommended)
    - Java Runtime Environment (JRE) may be required
    
    Official Website: https://angryip.org/
    Download Page: https://angryip.org/download/
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
    Name = "Angry IP Scanner"
    DisplayName = "Angry IP Scanner*"
    Publisher = "Anton Keks"
    OfficialWebsite = "https://angryip.org/"
    DownloadPage = "https://angryip.org/download/"
    VersionCheckUrl = "https://api.github.com/repos/angryip/ipscan/releases/latest"
    GitHubRepo = "angryip/ipscan"
    SilentArgs = @("/S")  # NSIS installer silent arguments
    ValidExitCodes = @(0, 3010)  # 0 = success, 3010 = success with reboot required
}

#endregion

#region Version Detection Functions

function Get-AngryIPScannerLatestVersion {
    <#
    .SYNOPSIS
        Get the latest stable version of Angry IP Scanner from GitHub releases
    .OUTPUTS
        Hashtable containing version information and download URLs
    #>
    try {
        Write-AppLog "Fetching latest Angry IP Scanner version information..." -Level INFO -Component $script:AppConfig.Name
        
        # Get latest release from GitHub API
        $releaseInfo = Get-LatestVersionFromGitHub -Repository $script:AppConfig.GitHubRepo
        
        # Parse version number (remove 'v' prefix if present)
        $version = $releaseInfo.Version -replace '^v', ''
        
        # Get system architecture
        $arch = Get-SystemArchitecture
        
        # Find appropriate installer based on architecture
        $installerAsset = $releaseInfo.Assets | Where-Object {
            $_.name -match "ipscan-.*-setup\.exe$"
        } | Select-Object -First 1
        
        if (-not $installerAsset) {
            # Fallback: try to find any Windows installer
            $installerAsset = $releaseInfo.Assets | Where-Object {
                $_.name -match "setup\.exe$" -or $_.name -match "windows.*\.exe$"
            } | Select-Object -First 1
        }
        
        if (-not $installerAsset) {
            throw "No suitable installer found in release assets"
        }
        
        $versionInfo = @{
            Version = $version
            DownloadUrl = $installerAsset.browser_download_url
            FileName = $installerAsset.name
            FileSize = $installerAsset.size
            Architecture = $arch
            ReleaseDate = $releaseInfo.PublishedAt
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

function Get-InstalledAngryIPScannerVersion {
    <#
    .SYNOPSIS
        Get the currently installed version of Angry IP Scanner
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
            Write-AppLog "Angry IP Scanner is not currently installed" -Level INFO -Component $script:AppConfig.Name
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

function Install-AngryIPScanner {
    <#
    .SYNOPSIS
        Download and install Angry IP Scanner
    .PARAMETER VersionInfo
        Version information hashtable from Get-AngryIPScannerLatestVersion
    .OUTPUTS
        Boolean indicating installation success
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VersionInfo
    )
    
    $tempDir = $null
    
    try {
        Write-AppLog "Starting Angry IP Scanner installation process..." -Level INFO -Component $script:AppConfig.Name
        
        # Check for Java requirement
        Write-AppLog "Note: Angry IP Scanner requires Java Runtime Environment (JRE)" -Level INFO -Component $script:AppConfig.Name
        
        # Create temporary directory
        $tempDir = New-TempDirectory -Prefix "AngryIPScanner"
        $installerPath = Join-Path $tempDir $VersionInfo.FileName
        
        # Download installer
        Write-AppLog "Downloading Angry IP Scanner installer..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "File: $($VersionInfo.FileName) ($([math]::Round($VersionInfo.FileSize / 1MB, 2)) MB)" -Level INFO -Component $script:AppConfig.Name
        
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
            $installArgs += "/D=$InstallPath"
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
            Start-Sleep -Seconds 3  # Give Windows time to update registry
            $newVersion = Get-InstalledAngryIPScannerVersion
            
            if ($newVersion) {
                Write-AppLog "Installation verified: Angry IP Scanner v$newVersion is now installed" -Level SUCCESS -Component $script:AppConfig.Name
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
    $installedVersion = Get-InstalledAngryIPScannerVersion
    
    if (-not $installedVersion) {
        Write-AppLog "Installation required: Angry IP Scanner is not installed" -Level INFO -Component $script:AppConfig.Name
        return $true
    }
    
    if ($Force) {
        Write-AppLog "Installation forced by user parameter" -Level INFO -Component $script:AppConfig.Name
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
    Write-AppLog "=== Angry IP Scanner Installation Script v1.0.0 ===" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Official website: $($script:AppConfig.OfficialWebsite)" -Level INFO -Component $script:AppConfig.Name
    
    # Get version information
    if ($Version) {
        Write-AppLog "Specific version requested: $Version" -Level INFO -Component $script:AppConfig.Name
        throw "Specific version installation not implemented in this example. Use latest version."
    }
    else {
        $versionInfo = Get-AngryIPScannerLatestVersion
    }
    
    # Check if installation is required
    if (-not (Test-InstallationRequired -LatestVersion $versionInfo.Version)) {
        Write-AppLog "No installation required. Use -Force to reinstall." -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    
    # Perform installation
    $installResult = Install-AngryIPScanner -VersionInfo $versionInfo
    
    if ($installResult) {
        Write-AppLog "Angry IP Scanner installation completed successfully!" -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    else {
        Write-AppLog "Angry IP Scanner installation failed!" -Level ERROR -Component $script:AppConfig.Name
        exit 1
    }
}
catch {
    Write-AppLog "Fatal error: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component $script:AppConfig.Name
    exit 1
}

#endregion
