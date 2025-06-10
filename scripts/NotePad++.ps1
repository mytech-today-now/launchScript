#Requires -Version 5.1
<#
.SYNOPSIS
    Silent installation script for Notepad++
    
.DESCRIPTION
    This script automatically downloads and installs the latest stable version of
    Notepad++ from the official website. It detects the system architecture and
    downloads the appropriate installer, then performs a silent installation.
    
.PARAMETER Force
    Force reinstallation even if Notepad++ is already installed
    
.PARAMETER Version
    Specific version to install (default: latest)
    
.PARAMETER InstallPath
    Custom installation path (default: Program Files)
    
.EXAMPLE
    .\NotePad++.ps1
    
.EXAMPLE
    .\NotePad++.ps1 -Force -Version "8.5.8"
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Internet connection
    - Administrator privileges (recommended)
    
    Official Website: https://notepad-plus-plus.org/
    Download Page: https://notepad-plus-plus.org/downloads/
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
    Name = "Notepad++"
    DisplayName = "Notepad++*"
    Publisher = "Notepad++ Team"
    OfficialWebsite = "https://notepad-plus-plus.org/"
    DownloadPage = "https://notepad-plus-plus.org/downloads/"
    VersionCheckUrl = "https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest"
    GitHubRepo = "notepad-plus-plus/notepad-plus-plus"
    SilentArgs = @("/S")  # NSIS installer silent arguments
    ValidExitCodes = @(0, 3010)  # 0 = success, 3010 = success with reboot required
}

#endregion

#region Version Detection Functions

function Get-NotepadPlusPlusLatestVersion {
    <#
    .SYNOPSIS
        Get the latest stable version of Notepad++ from GitHub releases
    .OUTPUTS
        Hashtable containing version information and download URLs
    #>
    try {
        Write-AppLog "Fetching latest Notepad++ version information..." -Level INFO -Component $script:AppConfig.Name
        
        # Get latest release from GitHub API
        $releaseInfo = Get-LatestVersionFromGitHub -Repository $script:AppConfig.GitHubRepo
        
        # Parse version number (remove 'v' prefix if present)
        $version = $releaseInfo.Version -replace '^v', ''
        
        # Get system architecture
        $arch = Get-SystemArchitecture
        
        # Find appropriate installer based on architecture
        $installerAsset = $releaseInfo.Assets | Where-Object {
            $_.name -match "npp\.$version\.Installer\.exe$" -or
            $_.name -match "npp\.$version\.Installer\.x64\.exe$" -and $arch -eq 'x64'
        } | Select-Object -First 1
        
        if (-not $installerAsset) {
            # Fallback: try to find any installer
            $installerAsset = $releaseInfo.Assets | Where-Object {
                $_.name -match "\.Installer\.exe$"
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
            Architecture = if ($installerAsset.name -match "x64") { "x64" } else { "x86" }
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

function Get-InstalledNotepadPlusPlusVersion {
    <#
    .SYNOPSIS
        Get the currently installed version of Notepad++
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
            Write-AppLog "Notepad++ is not currently installed" -Level INFO -Component $script:AppConfig.Name
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

function Install-NotepadPlusPlus {
    <#
    .SYNOPSIS
        Download and install Notepad++
    .PARAMETER VersionInfo
        Version information hashtable from Get-NotepadPlusPlusLatestVersion
    .OUTPUTS
        Boolean indicating installation success
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VersionInfo
    )
    
    $tempDir = $null
    
    try {
        Write-AppLog "Starting Notepad++ installation process..." -Level INFO -Component $script:AppConfig.Name
        
        # Create temporary directory
        $tempDir = New-TempDirectory -Prefix "NotePadPlusPlus"
        $installerPath = Join-Path $tempDir $VersionInfo.FileName
        
        # Download installer
        Write-AppLog "Downloading Notepad++ installer..." -Level INFO -Component $script:AppConfig.Name
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
            $newVersion = Get-InstalledNotepadPlusPlusVersion
            
            if ($newVersion) {
                Write-AppLog "Installation verified: Notepad++ v$newVersion is now installed" -Level SUCCESS -Component $script:AppConfig.Name
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
    $installedVersion = Get-InstalledNotepadPlusPlusVersion
    
    if (-not $installedVersion) {
        Write-AppLog "Installation required: Notepad++ is not installed" -Level INFO -Component $script:AppConfig.Name
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
    Write-AppLog "=== Notepad++ Installation Script v1.0.0 ===" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Official website: $($script:AppConfig.OfficialWebsite)" -Level INFO -Component $script:AppConfig.Name
    
    # Get version information
    if ($Version) {
        Write-AppLog "Specific version requested: $Version" -Level INFO -Component $script:AppConfig.Name
        # For specific versions, we would need to construct the download URL
        # This is a simplified implementation - in practice, you might need to
        # parse the downloads page or use a different API
        throw "Specific version installation not implemented in this example. Use latest version."
    }
    else {
        $versionInfo = Get-NotepadPlusPlusLatestVersion
    }
    
    # Check if installation is required
    if (-not (Test-InstallationRequired -LatestVersion $versionInfo.Version)) {
        Write-AppLog "No installation required. Use -Force to reinstall." -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    
    # Perform installation
    $installResult = Install-NotepadPlusPlus -VersionInfo $versionInfo
    
    if ($installResult) {
        Write-AppLog "Notepad++ installation completed successfully!" -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    else {
        Write-AppLog "Notepad++ installation failed!" -Level ERROR -Component $script:AppConfig.Name
        exit 1
    }
}
catch {
    Write-AppLog "Fatal error: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component $script:AppConfig.Name
    exit 1
}

#endregion
