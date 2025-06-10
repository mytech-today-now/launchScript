#Requires -Version 5.1
<#
.SYNOPSIS
    Silent installation script for GIMP (GNU Image Manipulation Program)
    
.DESCRIPTION
    This script automatically downloads and installs the latest stable version of
    GIMP from the official website. GIMP is a free and open-source raster graphics
    editor used for image retouching and editing, free-form drawing, converting
    between different image formats, and more specialized tasks.
    
.PARAMETER Force
    Force reinstallation even if GIMP is already installed
    
.PARAMETER Version
    Specific version to install (default: latest)
    
.PARAMETER InstallPath
    Custom installation path (default: Program Files)
    
.EXAMPLE
    .\GIMP.ps1
    
.EXAMPLE
    .\GIMP.ps1 -Force
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Internet connection
    - Administrator privileges (recommended)
    - Minimum 1GB RAM recommended
    
    Official Website: https://www.gimp.org/
    Download Page: https://www.gimp.org/downloads/
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
    Name = "GIMP"
    DisplayName = "GIMP*"
    Publisher = "The GIMP Team"
    OfficialWebsite = "https://www.gimp.org/"
    DownloadPage = "https://www.gimp.org/downloads/"
    VersionCheckUrl = "https://www.gimp.org/downloads/"
    DirectDownloadUrl = "https://download.gimp.org/mirror/pub/gimp/"
    SilentArgs = @("/VERYSILENT", "/NORESTART")  # Inno Setup installer silent arguments
    ValidExitCodes = @(0, 3010)  # 0 = success, 3010 = success with reboot required
}

#endregion

#region Version Detection Functions

function Get-GIMPLatestVersion {
    <#
    .SYNOPSIS
        Get the latest stable version of GIMP from the download page
    .OUTPUTS
        Hashtable containing version information and download URLs
    #>
    try {
        Write-AppLog "Fetching latest GIMP version information..." -Level INFO -Component $script:AppConfig.Name
        
        # Try to get version information from the download page
        try {
            $response = Invoke-WebRequestWithRetry -Uri $script:AppConfig.DownloadPage
            $content = $response.Content
            
            # Try to extract version from the page
            if ($content -match 'GIMP (\d+\.\d+(?:\.\d+)?)' -or $content -match 'Version (\d+\.\d+(?:\.\d+)?)') {
                $version = $matches[1]
            }
            else {
                $version = "2.10.36"  # Fallback to known stable version
            }
        }
        catch {
            Write-AppLog "Could not parse version from download page, using fallback version" -Level WARN -Component $script:AppConfig.Name
            $version = "2.10.36"
        }
        
        # Get system architecture
        $arch = Get-SystemArchitecture
        
        # Construct download URL based on architecture and version
        $majorMinor = $version -replace '(\d+\.\d+).*', '$1'
        $archSuffix = if ($arch -eq 'x64') { 'x86_64' } else { 'i686' }
        
        # GIMP download URL pattern
        $downloadUrl = "https://download.gimp.org/mirror/pub/gimp/v$majorMinor/windows/gimp-$version-setup.exe"
        $fileName = "gimp-$version-setup.exe"
        
        $versionInfo = @{
            Version = $version
            DownloadUrl = $downloadUrl
            FileName = $fileName
            FileSize = 0  # Size not available from direct download
            Architecture = $arch
            ReleaseDate = (Get-Date).ToString()
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

function Get-InstalledGIMPVersion {
    <#
    .SYNOPSIS
        Get the currently installed version of GIMP
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
            Write-AppLog "GIMP is not currently installed" -Level INFO -Component $script:AppConfig.Name
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

function Install-GIMP {
    <#
    .SYNOPSIS
        Download and install GIMP
    .PARAMETER VersionInfo
        Version information hashtable from Get-GIMPLatestVersion
    .OUTPUTS
        Boolean indicating installation success
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VersionInfo
    )
    
    $tempDir = $null
    
    try {
        Write-AppLog "Starting GIMP installation process..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "Note: GIMP installation may take several minutes due to its size" -Level INFO -Component $script:AppConfig.Name
        
        # Create temporary directory
        $tempDir = New-TempDirectory -Prefix "GIMP"
        $installerPath = Join-Path $tempDir $VersionInfo.FileName
        
        # Download installer
        Write-AppLog "Downloading GIMP installer..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "File: $($VersionInfo.FileName) (approximately 200+ MB)" -Level INFO -Component $script:AppConfig.Name
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
            $installArgs += "/DIR=`"$InstallPath`""
            Write-AppLog "Custom installation path: $InstallPath" -Level INFO -Component $script:AppConfig.Name
        }
        
        # Check if elevation is recommended
        if (-not (Test-IsElevated)) {
            Write-AppLog "Warning: Not running as Administrator. Installation may fail or install to user directory." -Level WARN -Component $script:AppConfig.Name
        }
        
        # Execute silent installation
        Write-AppLog "Executing silent installation..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "This may take 10-15 minutes depending on system performance..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "Command: $installerPath $($installArgs -join ' ')" -Level DEBUG -Component $script:AppConfig.Name
        
        $installSuccess = Invoke-SilentInstaller -FilePath $installerPath -Arguments $installArgs -TimeoutMinutes 20
        
        if ($installSuccess) {
            Write-AppLog "Installation completed successfully" -Level SUCCESS -Component $script:AppConfig.Name
            
            # Verify installation
            Start-Sleep -Seconds 5  # Give Windows time to update registry
            $newVersion = Get-InstalledGIMPVersion
            
            if ($newVersion) {
                Write-AppLog "Installation verified: GIMP v$newVersion is now installed" -Level SUCCESS -Component $script:AppConfig.Name
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
    $installedVersion = Get-InstalledGIMPVersion
    
    if (-not $installedVersion) {
        Write-AppLog "Installation required: GIMP is not installed" -Level INFO -Component $script:AppConfig.Name
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
    Write-AppLog "=== GIMP Installation Script v1.0.0 ===" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Official website: $($script:AppConfig.OfficialWebsite)" -Level INFO -Component $script:AppConfig.Name
    
    # Get version information
    if ($Version) {
        Write-AppLog "Specific version requested: $Version" -Level INFO -Component $script:AppConfig.Name
        throw "Specific version installation not implemented in this example. Use latest version."
    }
    else {
        $versionInfo = Get-GIMPLatestVersion
    }
    
    # Check if installation is required
    if (-not (Test-InstallationRequired -LatestVersion $versionInfo.Version)) {
        Write-AppLog "No installation required. Use -Force to reinstall." -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    
    # Perform installation
    $installResult = Install-GIMP -VersionInfo $versionInfo
    
    if ($installResult) {
        Write-AppLog "GIMP installation completed successfully!" -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    else {
        Write-AppLog "GIMP installation failed!" -Level ERROR -Component $script:AppConfig.Name
        exit 1
    }
}
catch {
    Write-AppLog "Fatal error: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component $script:AppConfig.Name
    exit 1
}

#endregion
