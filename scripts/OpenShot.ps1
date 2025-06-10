#Requires -Version 5.1
<#
.SYNOPSIS
    Silent installation script for OpenShot Video Editor
    
.DESCRIPTION
    This script automatically downloads and installs the latest stable version of
    OpenShot Video Editor from the official website. OpenShot is a free, open-source
    video editor for Linux, Mac, and Windows.
    
.PARAMETER Force
    Force reinstallation even if OpenShot is already installed
    
.PARAMETER Version
    Specific version to install (default: latest)
    
.PARAMETER InstallPath
    Custom installation path (default: Program Files)
    
.EXAMPLE
    .\OpenShot.ps1
    
.EXAMPLE
    .\OpenShot.ps1 -Force
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Internet connection
    - Administrator privileges (recommended)
    - Minimum 4GB RAM recommended
    
    Official Website: https://www.openshot.org/
    Download Page: https://www.openshot.org/download/
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
    Name = "OpenShot Video Editor"
    DisplayName = "OpenShot*"
    Publisher = "OpenShot Studios, LLC"
    OfficialWebsite = "https://www.openshot.org/"
    DownloadPage = "https://www.openshot.org/download/"
    VersionCheckUrl = "https://api.github.com/repos/OpenShot/openshot-qt/releases/latest"
    GitHubRepo = "OpenShot/openshot-qt"
    SilentArgs = @("/S")  # NSIS installer silent arguments
    ValidExitCodes = @(0, 3010)  # 0 = success, 3010 = success with reboot required
}

#endregion

#region Version Detection Functions

function Get-OpenShotLatestVersion {
    <#
    .SYNOPSIS
        Get the latest stable version of OpenShot from GitHub releases
    .OUTPUTS
        Hashtable containing version information and download URLs
    #>
    try {
        Write-AppLog "Fetching latest OpenShot version information..." -Level INFO -Component $script:AppConfig.Name
        
        # Get latest release from GitHub API
        $releaseInfo = Get-LatestVersionFromGitHub -Repository $script:AppConfig.GitHubRepo
        
        # Parse version number (remove 'v' prefix if present)
        $version = $releaseInfo.Version -replace '^v', ''
        
        # Get system architecture
        $arch = Get-SystemArchitecture
        
        # Find appropriate installer based on architecture
        $installerAsset = $releaseInfo.Assets | Where-Object {
            $_.name -match "OpenShot-v.*-x86_64\.exe$" -and $arch -eq 'x64'
        } | Select-Object -First 1
        
        if (-not $installerAsset -and $arch -eq 'x86') {
            # Try to find x86 version
            $installerAsset = $releaseInfo.Assets | Where-Object {
                $_.name -match "OpenShot-v.*-x86\.exe$"
            } | Select-Object -First 1
        }
        
        if (-not $installerAsset) {
            # Fallback: try to find any Windows installer
            $installerAsset = $releaseInfo.Assets | Where-Object {
                $_.name -match "OpenShot.*\.exe$"
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

function Get-InstalledOpenShotVersion {
    <#
    .SYNOPSIS
        Get the currently installed version of OpenShot
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
            Write-AppLog "OpenShot is not currently installed" -Level INFO -Component $script:AppConfig.Name
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

function Install-OpenShot {
    <#
    .SYNOPSIS
        Download and install OpenShot
    .PARAMETER VersionInfo
        Version information hashtable from Get-OpenShotLatestVersion
    .OUTPUTS
        Boolean indicating installation success
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VersionInfo
    )
    
    $tempDir = $null
    
    try {
        Write-AppLog "Starting OpenShot installation process..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "Note: OpenShot installation may take several minutes due to its size" -Level INFO -Component $script:AppConfig.Name
        
        # Create temporary directory
        $tempDir = New-TempDirectory -Prefix "OpenShot"
        $installerPath = Join-Path $tempDir $VersionInfo.FileName
        
        # Download installer
        Write-AppLog "Downloading OpenShot installer..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "File: $($VersionInfo.FileName) ($([math]::Round($VersionInfo.FileSize / 1MB, 2)) MB)" -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "This may take several minutes depending on your internet connection..." -Level INFO -Component $script:AppConfig.Name
        
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
        Write-AppLog "This may take 5-10 minutes depending on system performance..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "Command: $installerPath $($installArgs -join ' ')" -Level DEBUG -Component $script:AppConfig.Name
        
        $installSuccess = Invoke-SilentInstaller -FilePath $installerPath -Arguments $installArgs -TimeoutMinutes 15
        
        if ($installSuccess) {
            Write-AppLog "Installation completed successfully" -Level SUCCESS -Component $script:AppConfig.Name
            
            # Verify installation
            Start-Sleep -Seconds 5  # Give Windows time to update registry
            $newVersion = Get-InstalledOpenShotVersion
            
            if ($newVersion) {
                Write-AppLog "Installation verified: OpenShot v$newVersion is now installed" -Level SUCCESS -Component $script:AppConfig.Name
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
    $installedVersion = Get-InstalledOpenShotVersion
    
    if (-not $installedVersion) {
        Write-AppLog "Installation required: OpenShot is not installed" -Level INFO -Component $script:AppConfig.Name
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
    Write-AppLog "=== OpenShot Video Editor Installation Script v1.0.0 ===" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Official website: $($script:AppConfig.OfficialWebsite)" -Level INFO -Component $script:AppConfig.Name
    
    # Get version information
    if ($Version) {
        Write-AppLog "Specific version requested: $Version" -Level INFO -Component $script:AppConfig.Name
        throw "Specific version installation not implemented in this example. Use latest version."
    }
    else {
        $versionInfo = Get-OpenShotLatestVersion
    }
    
    # Check if installation is required
    if (-not (Test-InstallationRequired -LatestVersion $versionInfo.Version)) {
        Write-AppLog "No installation required. Use -Force to reinstall." -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    
    # Perform installation
    $installResult = Install-OpenShot -VersionInfo $versionInfo
    
    if ($installResult) {
        Write-AppLog "OpenShot installation completed successfully!" -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    else {
        Write-AppLog "OpenShot installation failed!" -Level ERROR -Component $script:AppConfig.Name
        exit 1
    }
}
catch {
    Write-AppLog "Fatal error: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component $script:AppConfig.Name
    exit 1
}

#endregion
