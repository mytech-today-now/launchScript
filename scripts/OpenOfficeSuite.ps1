#Requires -Version 5.1
<#
.SYNOPSIS
    Silent installation script for Apache OpenOffice Suite
    
.DESCRIPTION
    This script automatically downloads and installs the latest stable version of
    Apache OpenOffice Suite from the official website. OpenOffice is a free and
    open-source office productivity suite that includes word processing, spreadsheets,
    presentations, graphics, databases, and more.
    
.PARAMETER Force
    Force reinstallation even if OpenOffice is already installed
    
.PARAMETER Version
    Specific version to install (default: latest)
    
.PARAMETER InstallPath
    Custom installation path (default: Program Files)
    
.EXAMPLE
    .\OpenOfficeSuite.ps1
    
.EXAMPLE
    .\OpenOfficeSuite.ps1 -Force
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Internet connection
    - Administrator privileges (recommended)
    - Minimum 650 MB disk space
    
    Official Website: https://www.openoffice.org/
    Download Page: https://www.openoffice.org/download/
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
    Name = "Apache OpenOffice"
    DisplayName = "OpenOffice*"
    Publisher = "Apache Software Foundation"
    OfficialWebsite = "https://www.openoffice.org/"
    DownloadPage = "https://www.openoffice.org/download/"
    VersionCheckUrl = "https://www.openoffice.org/download/"
    DirectDownloadUrl = "https://sourceforge.net/projects/openofficeorg.mirror/files/latest/download"
    SilentArgs = @("/S", "/v/qn")  # MSI installer silent arguments
    ValidExitCodes = @(0, 3010)  # 0 = success, 3010 = success with reboot required
}

#endregion

#region Version Detection Functions

function Get-OpenOfficeLatestVersion {
    <#
    .SYNOPSIS
        Get the latest stable version of OpenOffice from the download page
    .OUTPUTS
        Hashtable containing version information and download URLs
    #>
    try {
        Write-AppLog "Fetching latest OpenOffice version information..." -Level INFO -Component $script:AppConfig.Name
        
        # Try to get version information from the download page
        try {
            $response = Invoke-WebRequestWithRetry -Uri $script:AppConfig.DownloadPage
            $content = $response.Content
            
            # Try to extract version from the page
            if ($content -match 'Apache OpenOffice (\d+\.\d+(?:\.\d+)?)' -or $content -match 'Version (\d+\.\d+(?:\.\d+)?)') {
                $version = $matches[1]
            }
            else {
                $version = "4.1.15"  # Fallback to known stable version
            }
        }
        catch {
            Write-AppLog "Could not parse version from download page, using fallback version" -Level WARN -Component $script:AppConfig.Name
            $version = "4.1.15"
        }
        
        # Get system architecture
        $arch = Get-SystemArchitecture
        
        # Construct download URL based on architecture and version
        $archSuffix = if ($arch -eq 'x64') { 'x86-64' } else { 'x86' }
        $downloadUrl = "https://sourceforge.net/projects/openofficeorg.mirror/files/$version/binaries/en-US/Apache_OpenOffice_${version}_Win_${archSuffix}_install_en-US.exe/download"
        $fileName = "Apache_OpenOffice_${version}_Win_${archSuffix}_install_en-US.exe"
        
        $versionInfo = @{
            Version = $version
            DownloadUrl = $downloadUrl
            FileName = $fileName
            FileSize = 0  # Size not available from SourceForge direct download
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

function Get-InstalledOpenOfficeVersion {
    <#
    .SYNOPSIS
        Get the currently installed version of OpenOffice
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
            Write-AppLog "OpenOffice is not currently installed" -Level INFO -Component $script:AppConfig.Name
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

function Install-OpenOffice {
    <#
    .SYNOPSIS
        Download and install OpenOffice
    .PARAMETER VersionInfo
        Version information hashtable from Get-OpenOfficeLatestVersion
    .OUTPUTS
        Boolean indicating installation success
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$VersionInfo
    )
    
    $tempDir = $null
    
    try {
        Write-AppLog "Starting OpenOffice installation process..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "Note: OpenOffice installation may take several minutes due to its size" -Level INFO -Component $script:AppConfig.Name
        
        # Create temporary directory
        $tempDir = New-TempDirectory -Prefix "OpenOffice"
        $installerPath = Join-Path $tempDir $VersionInfo.FileName
        
        # Download installer
        Write-AppLog "Downloading OpenOffice installer..." -Level INFO -Component $script:AppConfig.Name
        Write-AppLog "File: $($VersionInfo.FileName) (approximately 150+ MB)" -Level INFO -Component $script:AppConfig.Name
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
            $installArgs += "INSTALLDIR=`"$InstallPath`""
            Write-AppLog "Custom installation path: $InstallPath" -Level INFO -Component $script:AppConfig.Name
        }
        
        # Check if elevation is recommended
        if (-not (Test-IsElevated)) {
            Write-AppLog "Warning: Not running as Administrator. Installation may fail." -Level WARN -Component $script:AppConfig.Name
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
            $newVersion = Get-InstalledOpenOfficeVersion
            
            if ($newVersion) {
                Write-AppLog "Installation verified: OpenOffice v$newVersion is now installed" -Level SUCCESS -Component $script:AppConfig.Name
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
    $installedVersion = Get-InstalledOpenOfficeVersion
    
    if (-not $installedVersion) {
        Write-AppLog "Installation required: OpenOffice is not installed" -Level INFO -Component $script:AppConfig.Name
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
    Write-AppLog "=== OpenOffice Suite Installation Script v1.0.0 ===" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Official website: $($script:AppConfig.OfficialWebsite)" -Level INFO -Component $script:AppConfig.Name
    
    # Get version information
    if ($Version) {
        Write-AppLog "Specific version requested: $Version" -Level INFO -Component $script:AppConfig.Name
        throw "Specific version installation not implemented in this example. Use latest version."
    }
    else {
        $versionInfo = Get-OpenOfficeLatestVersion
    }
    
    # Check if installation is required
    if (-not (Test-InstallationRequired -LatestVersion $versionInfo.Version)) {
        Write-AppLog "No installation required. Use -Force to reinstall." -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    
    # Perform installation
    $installResult = Install-OpenOffice -VersionInfo $versionInfo
    
    if ($installResult) {
        Write-AppLog "OpenOffice installation completed successfully!" -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    else {
        Write-AppLog "OpenOffice installation failed!" -Level ERROR -Component $script:AppConfig.Name
        exit 1
    }
}
catch {
    Write-AppLog "Fatal error: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component $script:AppConfig.Name
    exit 1
}

#endregion
