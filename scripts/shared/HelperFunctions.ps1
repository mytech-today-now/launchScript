#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helper functions for LaunchScript app installation scripts
    
.DESCRIPTION
    This module provides common functionality used across multiple app installation
    scripts, including download management, version detection, installation validation,
    and logging utilities.
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    This file should be dot-sourced by individual app installation scripts:
    . "$PSScriptRoot\shared\HelperFunctions.ps1"
#>

# Set strict mode for better error handling
Set-StrictMode -Version Latest

#region Global Variables and Configuration

$script:HelperConfig = @{
    UserAgent = "LaunchScript-Manager/1.0.0 (Windows NT; PowerShell)"
    DownloadTimeout = 300  # 5 minutes
    RetryAttempts = 3
    RetryDelay = 2  # seconds
    TempDirectory = $env:TEMP
    LogLevel = "INFO"
}

#endregion

#region Logging Functions

function Write-AppLog {
    <#
    .SYNOPSIS
        Write a log message with consistent formatting
    .PARAMETER Message
        The message to log
    .PARAMETER Level
        Log level (INFO, WARN, ERROR, SUCCESS, DEBUG)
    .PARAMETER Component
        Component name (usually the app name)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')]
        [string]$Level = 'INFO',
        
        [Parameter()]
        [string]$Component = 'Helper'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Component] [$Level] $Message"
    
    switch ($Level) {
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'WARN' { Write-Host $logEntry -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        'DEBUG' { if ($VerbosePreference -eq 'Continue' -or $script:HelperConfig.LogLevel -eq 'DEBUG') { Write-Host $logEntry -ForegroundColor Cyan } }
        default { Write-Host $logEntry -ForegroundColor White }
    }
}

#endregion

#region System Information Functions

function Get-SystemArchitecture {
    <#
    .SYNOPSIS
        Get the system architecture (x86, x64, ARM64)
    .OUTPUTS
        String representing the system architecture
    #>
    try {
        $arch = $env:PROCESSOR_ARCHITECTURE
        switch ($arch) {
            'AMD64' { return 'x64' }
            'x86' { return 'x86' }
            'ARM64' { return 'ARM64' }
            default { 
                Write-AppLog "Unknown architecture: $arch, defaulting to x64" -Level WARN
                return 'x64' 
            }
        }
    }
    catch {
        Write-AppLog "Failed to detect architecture: $($_.Exception.Message)" -Level ERROR
        return 'x64'  # Safe default
    }
}

function Test-IsElevated {
    <#
    .SYNOPSIS
        Check if the current PowerShell session is running with elevated privileges
    .OUTPUTS
        Boolean indicating if running as administrator
    #>
    try {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        Write-AppLog "Failed to check elevation status: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Get-InstalledPrograms {
    <#
    .SYNOPSIS
        Get list of installed programs from Windows registry with enhanced detection
    .PARAMETER Name
        Optional filter by program name (supports wildcards)
    .PARAMETER IncludeWindowsStore
        Include Windows Store apps in the search
    .PARAMETER IncludePortable
        Include portable app detection via common paths
    .OUTPUTS
        Array of installed program objects with enhanced metadata
    #>
    param(
        [Parameter()]
        [string]$Name = '*',

        [Parameter()]
        [switch]$IncludeWindowsStore,

        [Parameter()]
        [switch]$IncludePortable
    )

    try {
        Write-AppLog "Scanning for installed programs: $Name" -Level DEBUG

        # Enhanced registry paths including more locations
        $registryPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )

        # Add Windows Installer registry paths
        $registryPaths += @(
            'HKLM:\SOFTWARE\Classes\Installer\Products\*',
            'HKCU:\SOFTWARE\Classes\Installer\Products\*'
        )

        $installedPrograms = @()

        foreach ($path in $registryPaths) {
            try {
                Write-AppLog "Scanning registry path: $path" -Level DEBUG

                $programs = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
                    Where-Object {
                        # Enhanced filtering with null checks
                        $_.DisplayName -and
                        $_.DisplayName.Trim() -ne '' -and
                        $_.DisplayName -like $Name -and
                        $_.DisplayName -notmatch '^(KB\d+|Update for|Security Update|Hotfix)' -and
                        # Filter out system components and empty entries
                        $_.DisplayName -notmatch '^Microsoft Visual C\+\+ \d+ Redistributable' -and
                        $_.DisplayName -notmatch '^Microsoft \.NET Framework'
                    } |
                    Select-Object @{
                        Name = 'DisplayName'
                        Expression = { if ($_.DisplayName) { $_.DisplayName.Trim() } else { 'Unknown' } }
                    }, @{
                        Name = 'DisplayVersion'
                        Expression = { if ($_.DisplayVersion) { $_.DisplayVersion.Trim() } else { if ($_.Version) { $_.Version.Trim() } else { 'Unknown' } } }
                    }, @{
                        Name = 'Publisher'
                        Expression = { if ($_.Publisher) { $_.Publisher.Trim() } else { 'Unknown' } }
                    }, @{
                        Name = 'InstallDate'
                        Expression = { if ($_.InstallDate) { $_.InstallDate } else { $null } }
                    }, @{
                        Name = 'UninstallString'
                        Expression = { if ($_.UninstallString) { $_.UninstallString } else { $null } }
                    }, @{
                        Name = 'InstallLocation'
                        Expression = { if ($_.InstallLocation) { $_.InstallLocation.TrimEnd('\') } else { $null } }
                    }, @{
                        Name = 'Source'
                        Expression = { 'Registry' }
                    }, @{
                        Name = 'RegistryPath'
                        Expression = { $_.PSPath }
                    }

                if ($programs) {
                    $installedPrograms += $programs
                    Write-AppLog "Found $(@($programs).Count) programs in registry path: $path" -Level DEBUG
                }
            }
            catch {
                Write-AppLog "Could not access registry path: $path - $($_.Exception.Message)" -Level DEBUG
                continue
            }
        }

        # Windows Store apps detection
        if ($IncludeWindowsStore) {
            try {
                $storeApps = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like $Name -or $_.PackageFullName -like $Name } |
                    Select-Object @{
                        Name = 'DisplayName'
                        Expression = { $_.Name }
                    }, @{
                        Name = 'DisplayVersion'
                        Expression = { $_.Version }
                    }, @{
                        Name = 'Publisher'
                        Expression = { $_.Publisher }
                    }, @{
                        Name = 'InstallDate'
                        Expression = { $_.InstallDate }
                    }, @{
                        Name = 'UninstallString'
                        Expression = { "Get-AppxPackage $($_.PackageFullName) | Remove-AppxPackage" }
                    }, @{
                        Name = 'InstallLocation'
                        Expression = { if ($_.InstallLocation) { $_.InstallLocation.TrimEnd('\') } else { $null } }
                    }, @{
                        Name = 'Source'
                        Expression = { 'WindowsStore' }
                    }, @{
                        Name = 'RegistryPath'
                        Expression = { $_.PackageFullName }
                    }

                $installedPrograms += $storeApps
                Write-AppLog "Found $($storeApps.Count) Windows Store apps matching: $Name" -Level DEBUG
            }
            catch {
                Write-AppLog "Could not scan Windows Store apps: $($_.Exception.Message)" -Level DEBUG
            }
        }

        # Portable apps detection in common locations
        if ($IncludePortable) {
            $portableApps = Get-PortableApplications -Name $Name
            $installedPrograms += $portableApps
        }

        # Remove duplicates and sort
        $uniquePrograms = @($installedPrograms |
            Sort-Object DisplayName, DisplayVersion -Unique |
            Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne '' })

        Write-AppLog "Found $($uniquePrograms.Count) installed programs matching: $Name" -Level DEBUG
        return $uniquePrograms
    }
    catch {
        Write-AppLog "Failed to get installed programs: $($_.Exception.Message)" -Level ERROR
        return @()
    }
}

function Get-PortableApplications {
    <#
    .SYNOPSIS
        Detect portable applications in common installation directories
    .PARAMETER Name
        Application name to search for (supports wildcards)
    .OUTPUTS
        Array of portable application objects
    #>
    param(
        [Parameter()]
        [string]$Name = '*'
    )

    try {
        Write-AppLog "Scanning for portable applications: $Name" -Level DEBUG

        # Common portable app directories
        $portablePaths = @(
            "$env:ProgramFiles\PortableApps",
            "$env:ProgramFiles(x86)\PortableApps",
            "$env:USERPROFILE\PortableApps",
            "$env:USERPROFILE\Desktop\PortableApps",
            "$env:USERPROFILE\Documents\PortableApps",
            "C:\PortableApps",
            "D:\PortableApps"
        )

        # Add common program directories for portable installs
        $portablePaths += @(
            "$env:ProgramFiles",
            "$env:ProgramFiles(x86)",
            "$env:LOCALAPPDATA\Programs",
            "$env:APPDATA"
        )

        $portableApps = @()

        foreach ($basePath in $portablePaths) {
            if (-not (Test-Path $basePath)) { continue }

            try {
                # Look for executable files that might be portable apps
                $executables = Get-ChildItem -Path $basePath -Recurse -Include "*.exe" -ErrorAction SilentlyContinue |
                    Where-Object {
                        $_.Name -like "*$Name*" -and
                        $_.Directory.Name -like "*$Name*" -and
                        $_.Length -gt 1MB  # Filter out small utility files
                    } |
                    Select-Object -First 50  # Limit results to prevent excessive scanning

                foreach ($exe in $executables) {
                    try {
                        $versionInfo = $exe.VersionInfo

                        if ($versionInfo.ProductName -and $versionInfo.ProductName -like "*$Name*") {
                            $portableApp = [PSCustomObject]@{
                                DisplayName = $versionInfo.ProductName
                                DisplayVersion = $versionInfo.ProductVersion
                                Publisher = $versionInfo.CompanyName
                                InstallDate = $exe.CreationTime.ToString('yyyyMMdd')
                                UninstallString = "Manual removal required"
                                InstallLocation = $exe.DirectoryName
                                Source = 'Portable'
                                RegistryPath = $exe.FullName
                            }

                            $portableApps += $portableApp
                        }
                    }
                    catch {
                        # Skip files that can't be analyzed
                        continue
                    }
                }
            }
            catch {
                Write-AppLog "Could not scan portable path: $basePath" -Level DEBUG
                continue
            }
        }

        Write-AppLog "Found $($portableApps.Count) portable applications matching: $Name" -Level DEBUG
        return $portableApps
    }
    catch {
        Write-AppLog "Failed to scan for portable applications: $($_.Exception.Message)" -Level ERROR
        return @()
    }
}

function Test-ProgramInstalled {
    <#
    .SYNOPSIS
        Check if a specific program is installed with enhanced detection
    .PARAMETER Name
        Program name to search for (supports wildcards)
    .PARAMETER IncludeWindowsStore
        Include Windows Store apps in the search
    .PARAMETER IncludePortable
        Include portable app detection
    .OUTPUTS
        Hashtable with installation details - always returns a consistent structure
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [switch]$IncludeWindowsStore,

        [Parameter()]
        [switch]$IncludePortable
    )

    # Initialize default return structure to ensure consistency
    $defaultResult = @{
        IsInstalled = $false
        DisplayName = $null
        Version = $null
        Publisher = $null
        InstallLocation = $null
        Source = $null
        InstallDate = $null
    }

    try {
        Write-AppLog "Searching for program: $Name" -Level DEBUG

        $installed = @(Get-InstalledPrograms -Name $Name -IncludeWindowsStore:$IncludeWindowsStore -IncludePortable:$IncludePortable)

        if ($installed -and $installed.Count -gt 0) {
            $app = $installed[0]  # Take the first match

            # Ensure all required properties exist with safe access
            $result = @{
                IsInstalled = $true
                DisplayName = if ($app.DisplayName) { $app.DisplayName } else { $Name }
                Version = if ($app.DisplayVersion) { $app.DisplayVersion } else { 'Unknown' }
                Publisher = if ($app.Publisher) { $app.Publisher } else { 'Unknown' }
                InstallLocation = if ($app.InstallLocation) { $app.InstallLocation.TrimEnd('\') } else { $null }
                Source = if ($app.Source) { $app.Source } else { 'Registry' }
                InstallDate = if ($app.InstallDate) { $app.InstallDate } else { $null }
            }

            Write-AppLog "Found installed program: $($result.DisplayName) v$($result.Version) (Source: $($result.Source))" -Level SUCCESS
            return $result
        }
        else {
            Write-AppLog "Program not found: $Name" -Level INFO
            return $defaultResult
        }
    }
    catch {
        Write-AppLog "Failed to check if program is installed: $($_.Exception.Message)" -Level ERROR
        Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG
        return $defaultResult
    }
}

#endregion

#region Download and Web Functions

function Invoke-WebRequestWithRetry {
    <#
    .SYNOPSIS
        Download content with retry logic and proper error handling
    .PARAMETER Uri
        The URI to download from
    .PARAMETER OutFile
        Optional output file path
    .PARAMETER MaxRetries
        Maximum number of retry attempts
    .OUTPUTS
        Web response content or file path if OutFile specified
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        
        [Parameter()]
        [string]$OutFile,
        
        [Parameter()]
        [int]$MaxRetries = $script:HelperConfig.RetryAttempts
    )
    
    $attempt = 0
    $lastError = $null
    
    while ($attempt -lt $MaxRetries) {
        $attempt++
        
        try {
            Write-AppLog "Downloading from: $Uri (Attempt $attempt/$MaxRetries)" -Level INFO
            
            $webRequestParams = @{
                Uri = $Uri
                UserAgent = $script:HelperConfig.UserAgent
                TimeoutSec = $script:HelperConfig.DownloadTimeout
                UseBasicParsing = $true
            }
            
            if ($OutFile) {
                $webRequestParams.OutFile = $OutFile
                Invoke-WebRequest @webRequestParams
                
                if (Test-Path $OutFile) {
                    $fileSize = (Get-Item $OutFile).Length
                    Write-AppLog "Downloaded successfully: $OutFile ($([math]::Round($fileSize / 1MB, 2)) MB)" -Level SUCCESS
                    return $OutFile
                }
                else {
                    throw "File was not created: $OutFile"
                }
            }
            else {
                $response = Invoke-WebRequest @webRequestParams
                Write-AppLog "Web request completed successfully" -Level SUCCESS
                return $response
            }
        }
        catch {
            $lastError = $_.Exception
            Write-AppLog "Download attempt $attempt failed: $($_.Exception.Message)" -Level WARN
            
            if ($attempt -lt $MaxRetries) {
                Write-AppLog "Retrying in $($script:HelperConfig.RetryDelay) seconds..." -Level INFO
                Start-Sleep -Seconds $script:HelperConfig.RetryDelay
            }
        }
    }
    
    Write-AppLog "All download attempts failed. Last error: $($lastError.Message)" -Level ERROR
    throw $lastError
}

function Get-LatestVersionFromGitHub {
    <#
    .SYNOPSIS
        Get the latest release version from a GitHub repository
    .PARAMETER Repository
        GitHub repository in format "owner/repo"
    .PARAMETER IncludePrerelease
        Include pre-release versions
    .OUTPUTS
        Hashtable with version info and download URLs
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,
        
        [Parameter()]
        [switch]$IncludePrerelease
    )
    
    try {
        $apiUrl = if ($IncludePrerelease) {
            "https://api.github.com/repos/$Repository/releases"
        } else {
            "https://api.github.com/repos/$Repository/releases/latest"
        }
        
        Write-AppLog "Fetching latest version from GitHub: $Repository" -Level INFO
        
        $response = Invoke-WebRequestWithRetry -Uri $apiUrl
        $releaseData = $response.Content | ConvertFrom-Json
        
        if ($IncludePrerelease -and $releaseData -is [array]) {
            $releaseData = $releaseData[0]  # Get the most recent release
        }
        
        $versionInfo = @{
            Version = $releaseData.tag_name -replace '^v', ''
            TagName = $releaseData.tag_name
            Name = $releaseData.name
            PublishedAt = $releaseData.published_at
            Assets = $releaseData.assets
            DownloadUrl = $releaseData.assets | Where-Object { $_.browser_download_url } | Select-Object -First 1 -ExpandProperty browser_download_url
        }
        
        Write-AppLog "Latest version found: $($versionInfo.Version)" -Level SUCCESS
        return $versionInfo
    }
    catch {
        Write-AppLog "Failed to get latest version from GitHub: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Get-LatestVersionFromWebsite {
    <#
    .SYNOPSIS
        Get the latest version by parsing a website (generic implementation)
    .PARAMETER Url
        URL to parse for version information
    .PARAMETER VersionPattern
        Regex pattern to extract version number
    .OUTPUTS
        String containing the latest version
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string]$VersionPattern
    )
    
    try {
        Write-AppLog "Fetching version information from: $Url" -Level INFO
        
        $response = Invoke-WebRequestWithRetry -Uri $Url
        $content = $response.Content
        
        if ($content -match $VersionPattern) {
            $version = $matches[1]
            Write-AppLog "Latest version found: $version" -Level SUCCESS
            return $version
        }
        else {
            throw "Version pattern not found in response"
        }
    }
    catch {
        Write-AppLog "Failed to get latest version from website: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

#endregion

#region Installation Functions

function Invoke-SilentInstaller {
    <#
    .SYNOPSIS
        Execute an installer with silent installation parameters
    .PARAMETER FilePath
        Path to the installer executable
    .PARAMETER Arguments
        Installation arguments for silent install
    .PARAMETER WorkingDirectory
        Working directory for the installer
    .PARAMETER TimeoutMinutes
        Timeout in minutes (default: 30)
    .OUTPUTS
        Boolean indicating installation success
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$FilePath,
        
        [Parameter()]
        [string[]]$Arguments = @(),
        
        [Parameter()]
        [string]$WorkingDirectory = (Split-Path $FilePath -Parent),
        
        [Parameter()]
        [int]$TimeoutMinutes = 30
    )
    
    try {
        $fileName = Split-Path $FilePath -Leaf
        Write-AppLog "Starting silent installation: $fileName" -Level INFO
        Write-AppLog "Arguments: $($Arguments -join ' ')" -Level DEBUG
        
        $processParams = @{
            FilePath = $FilePath
            ArgumentList = $Arguments
            WorkingDirectory = $WorkingDirectory
            Wait = $true
            PassThru = $true
            NoNewWindow = $true
        }
        
        # Start the installation process
        $process = Start-Process @processParams
        
        # Wait for completion with timeout
        $timeoutMs = $TimeoutMinutes * 60 * 1000
        if (-not $process.WaitForExit($timeoutMs)) {
            Write-AppLog "Installation timed out after $TimeoutMinutes minutes" -Level ERROR
            $process.Kill()
            return $false
        }
        
        $exitCode = $process.ExitCode
        
        if ($exitCode -eq 0) {
            Write-AppLog "Installation completed successfully (Exit code: $exitCode)" -Level SUCCESS
            return $true
        }
        else {
            Write-AppLog "Installation failed with exit code: $exitCode" -Level ERROR
            return $false
        }
    }
    catch {
        Write-AppLog "Exception during installation: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function New-TempDirectory {
    <#
    .SYNOPSIS
        Create a temporary directory for downloads and installations
    .PARAMETER Prefix
        Prefix for the temporary directory name
    .OUTPUTS
        String path to the created temporary directory
    #>
    param(
        [Parameter()]
        [string]$Prefix = 'LaunchScript'
    )
    
    try {
        $tempPath = Join-Path $script:HelperConfig.TempDirectory "$Prefix-$(Get-Random)"
        New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
        Write-AppLog "Created temporary directory: $tempPath" -Level INFO
        return $tempPath
    }
    catch {
        Write-AppLog "Failed to create temporary directory: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Remove-TempDirectory {
    <#
    .SYNOPSIS
        Clean up a temporary directory and its contents
    .PARAMETER Path
        Path to the temporary directory to remove
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    try {
        if (Test-Path $Path) {
            Remove-Item -Path $Path -Recurse -Force
            Write-AppLog "Cleaned up temporary directory: $Path" -Level INFO
        }
    }
    catch {
        Write-AppLog "Failed to clean up temporary directory: $($_.Exception.Message)" -Level WARN
    }
}

#endregion

#region Validation Functions

function Test-FileHash {
    <#
    .SYNOPSIS
        Verify file integrity using hash comparison
    .PARAMETER FilePath
        Path to the file to verify
    .PARAMETER ExpectedHash
        Expected hash value
    .PARAMETER Algorithm
        Hash algorithm to use (default: SHA256)
    .OUTPUTS
        Boolean indicating if hash matches
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$FilePath,
        
        [Parameter(Mandatory = $true)]
        [string]$ExpectedHash,
        
        [Parameter()]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')]
        [string]$Algorithm = 'SHA256'
    )
    
    try {
        Write-AppLog "Verifying file hash using $Algorithm algorithm" -Level INFO
        
        $actualHash = Get-FileHash -Path $FilePath -Algorithm $Algorithm
        $hashMatch = $actualHash.Hash -eq $ExpectedHash
        
        if ($hashMatch) {
            Write-AppLog "File hash verification successful" -Level SUCCESS
        }
        else {
            Write-AppLog "File hash verification failed. Expected: $ExpectedHash, Actual: $($actualHash.Hash)" -Level ERROR
        }
        
        return $hashMatch
    }
    catch {
        Write-AppLog "Failed to verify file hash: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Test-ExecutableSignature {
    <#
    .SYNOPSIS
        Verify the digital signature of an executable file
    .PARAMETER FilePath
        Path to the executable file
    .OUTPUTS
        Boolean indicating if signature is valid
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$FilePath
    )
    
    try {
        Write-AppLog "Verifying digital signature for: $(Split-Path $FilePath -Leaf)" -Level INFO
        
        $signature = Get-AuthenticodeSignature -FilePath $FilePath
        
        if ($signature.Status -eq 'Valid') {
            Write-AppLog "Digital signature is valid. Signer: $($signature.SignerCertificate.Subject)" -Level SUCCESS
            return $true
        }
        else {
            Write-AppLog "Digital signature verification failed. Status: $($signature.Status)" -Level WARN
            return $false
        }
    }
    catch {
        Write-AppLog "Failed to verify digital signature: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

#endregion

# Note: Functions are available when dot-sourced, no need to export
