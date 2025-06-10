#Requires -Version 5.1
<#
.SYNOPSIS
    Silent installation script for ChatGPT Desktop App
    
.DESCRIPTION
    This script automatically downloads and installs the latest stable version of
    the ChatGPT Desktop application. Since ChatGPT is primarily a web application,
    this script creates a desktop shortcut to the web version and optionally installs
    a third-party desktop wrapper if available.
    
.PARAMETER Force
    Force reinstallation even if ChatGPT shortcut already exists
    
.PARAMETER Version
    Specific version to install (default: latest)
    
.PARAMETER CreateShortcut
    Create desktop and start menu shortcuts to ChatGPT web app (default: true)
    
.EXAMPLE
    .\ChatGPT.ps1
    
.EXAMPLE
    .\ChatGPT.ps1 -Force -CreateShortcut
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Internet connection
    - Web browser (for web app access)
    
    Official Website: https://chat.openai.com/
    Note: This script creates shortcuts to the web version since ChatGPT is primarily web-based
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Force reinstallation even if already installed")]
    [switch]$Force,
    
    [Parameter(HelpMessage = "Specific version to install")]
    [string]$Version,
    
    [Parameter(HelpMessage = "Create desktop and start menu shortcuts")]
    [switch]$CreateShortcut = $true
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
    Name = "ChatGPT"
    DisplayName = "ChatGPT*"
    Publisher = "OpenAI"
    OfficialWebsite = "https://chat.openai.com/"
    WebAppUrl = "https://chat.openai.com/"
    IconUrl = "https://chat.openai.com/favicon.ico"
    ShortcutName = "ChatGPT"
    Description = "ChatGPT - AI Assistant by OpenAI"
}

#endregion

#region Shortcut Functions

function New-WebAppShortcut {
    <#
    .SYNOPSIS
        Create desktop and start menu shortcuts for ChatGPT web app
    .OUTPUTS
        Boolean indicating shortcut creation success
    #>
    try {
        Write-AppLog "Creating ChatGPT web app shortcuts..." -Level INFO -Component $script:AppConfig.Name
        
        # Get default browser
        $defaultBrowser = Get-DefaultBrowser
        if (-not $defaultBrowser) {
            $defaultBrowser = "msedge.exe"  # Fallback to Edge
            Write-AppLog "Could not detect default browser, using Edge as fallback" -Level WARN -Component $script:AppConfig.Name
        }
        
        # Create desktop shortcut
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $desktopShortcut = Join-Path $desktopPath "$($script:AppConfig.ShortcutName).lnk"
        
        # Create start menu shortcut
        $startMenuPath = [Environment]::GetFolderPath("StartMenu")
        $startMenuShortcut = Join-Path $startMenuPath "Programs\$($script:AppConfig.ShortcutName).lnk"
        
        # Create shortcuts using COM object
        $shell = New-Object -ComObject WScript.Shell
        
        # Desktop shortcut
        $shortcut = $shell.CreateShortcut($desktopShortcut)
        $shortcut.TargetPath = $defaultBrowser
        $shortcut.Arguments = "--app=$($script:AppConfig.WebAppUrl)"
        $shortcut.Description = $script:AppConfig.Description
        $shortcut.WorkingDirectory = [Environment]::GetFolderPath("UserProfile")
        
        # Try to download and set icon
        try {
            $iconPath = Join-Path $env:TEMP "chatgpt.ico"
            Invoke-WebRequestWithRetry -Uri $script:AppConfig.IconUrl -OutFile $iconPath
            $shortcut.IconLocation = $iconPath
        }
        catch {
            Write-AppLog "Could not download icon, using default browser icon" -Level WARN -Component $script:AppConfig.Name
        }
        
        $shortcut.Save()
        Write-AppLog "Created desktop shortcut: $desktopShortcut" -Level SUCCESS -Component $script:AppConfig.Name
        
        # Start menu shortcut
        $startMenuDir = Split-Path $startMenuShortcut -Parent
        if (-not (Test-Path $startMenuDir)) {
            New-Item -Path $startMenuDir -ItemType Directory -Force | Out-Null
        }
        
        $shortcut = $shell.CreateShortcut($startMenuShortcut)
        $shortcut.TargetPath = $defaultBrowser
        $shortcut.Arguments = "--app=$($script:AppConfig.WebAppUrl)"
        $shortcut.Description = $script:AppConfig.Description
        $shortcut.WorkingDirectory = [Environment]::GetFolderPath("UserProfile")
        
        # Try to set icon again
        try {
            $iconPath = Join-Path $env:TEMP "chatgpt.ico"
            if (Test-Path $iconPath) {
                $shortcut.IconLocation = $iconPath
            }
        }
        catch {
            # Ignore icon errors for start menu
        }
        
        $shortcut.Save()
        Write-AppLog "Created start menu shortcut: $startMenuShortcut" -Level SUCCESS -Component $script:AppConfig.Name
        
        # Release COM object
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
        
        return $true
    }
    catch {
        Write-AppLog "Failed to create shortcuts: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        return $false
    }
}

function Get-DefaultBrowser {
    <#
    .SYNOPSIS
        Get the default web browser executable path
    .OUTPUTS
        String containing the browser executable path
    #>
    try {
        # Try to get default browser from registry
        $browserKey = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice" -ErrorAction SilentlyContinue
        
        if ($browserKey -and $browserKey.ProgId) {
            $progId = $browserKey.ProgId
            $commandKey = Get-ItemProperty -Path "HKCR:\$progId\shell\open\command" -ErrorAction SilentlyContinue
            
            if ($commandKey -and $commandKey.'(default)') {
                $command = $commandKey.'(default)'
                # Extract executable path from command
                if ($command -match '^"([^"]+)"') {
                    return $matches[1]
                }
                elseif ($command -match '^([^\s]+)') {
                    return $matches[1]
                }
            }
        }
        
        # Fallback: try common browsers
        $commonBrowsers = @(
            "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles}\Mozilla Firefox\firefox.exe",
            "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe",
            "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe",
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        )
        
        foreach ($browser in $commonBrowsers) {
            if (Test-Path $browser) {
                return $browser
            }
        }
        
        return $null
    }
    catch {
        Write-AppLog "Failed to detect default browser: $($_.Exception.Message)" -Level WARN -Component $script:AppConfig.Name
        return $null
    }
}

function Test-ChatGPTShortcutExists {
    <#
    .SYNOPSIS
        Check if ChatGPT shortcuts already exist
    .OUTPUTS
        Boolean indicating if shortcuts exist
    #>
    try {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $desktopShortcut = Join-Path $desktopPath "$($script:AppConfig.ShortcutName).lnk"
        
        $startMenuPath = [Environment]::GetFolderPath("StartMenu")
        $startMenuShortcut = Join-Path $startMenuPath "Programs\$($script:AppConfig.ShortcutName).lnk"
        
        $desktopExists = Test-Path $desktopShortcut
        $startMenuExists = Test-Path $startMenuShortcut
        
        if ($desktopExists -or $startMenuExists) {
            Write-AppLog "ChatGPT shortcuts found (Desktop: $desktopExists, Start Menu: $startMenuExists)" -Level INFO -Component $script:AppConfig.Name
            return $true
        }
        else {
            Write-AppLog "ChatGPT shortcuts not found" -Level INFO -Component $script:AppConfig.Name
            return $false
        }
    }
    catch {
        Write-AppLog "Failed to check for existing shortcuts: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
        return $false
    }
}

function Test-InternetConnectivity {
    <#
    .SYNOPSIS
        Test connectivity to ChatGPT website
    .OUTPUTS
        Boolean indicating if ChatGPT is accessible
    #>
    try {
        Write-AppLog "Testing connectivity to ChatGPT..." -Level INFO -Component $script:AppConfig.Name
        
        $response = Invoke-WebRequestWithRetry -Uri $script:AppConfig.WebAppUrl -MaxRetries 1
        
        if ($response.StatusCode -eq 200) {
            Write-AppLog "ChatGPT website is accessible" -Level SUCCESS -Component $script:AppConfig.Name
            return $true
        }
        else {
            Write-AppLog "ChatGPT website returned status code: $($response.StatusCode)" -Level WARN -Component $script:AppConfig.Name
            return $false
        }
    }
    catch {
        Write-AppLog "Failed to connect to ChatGPT: $($_.Exception.Message)" -Level WARN -Component $script:AppConfig.Name
        return $false
    }
}

#endregion

#region Main Execution

try {
    Write-AppLog "=== ChatGPT Web App Setup Script v1.0.0 ===" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Official website: $($script:AppConfig.OfficialWebsite)" -Level INFO -Component $script:AppConfig.Name
    Write-AppLog "Note: ChatGPT is a web application. This script creates shortcuts for easy access." -Level INFO -Component $script:AppConfig.Name
    
    # Test internet connectivity
    $isConnected = Test-InternetConnectivity
    if (-not $isConnected) {
        Write-AppLog "Warning: Could not verify ChatGPT accessibility. Shortcuts will still be created." -Level WARN -Component $script:AppConfig.Name
    }
    
    # Check if shortcuts already exist
    $shortcutsExist = Test-ChatGPTShortcutExists
    
    if ($shortcutsExist -and -not $Force) {
        Write-AppLog "ChatGPT shortcuts already exist. Use -Force to recreate them." -Level SUCCESS -Component $script:AppConfig.Name
        exit 0
    }
    
    if ($Force -and $shortcutsExist) {
        Write-AppLog "Force parameter specified, recreating shortcuts..." -Level INFO -Component $script:AppConfig.Name
    }
    
    # Create shortcuts if requested
    if ($CreateShortcut) {
        $shortcutResult = New-WebAppShortcut
        
        if ($shortcutResult) {
            Write-AppLog "ChatGPT web app shortcuts created successfully!" -Level SUCCESS -Component $script:AppConfig.Name
            Write-AppLog "You can now access ChatGPT from your desktop or start menu." -Level INFO -Component $script:AppConfig.Name
            exit 0
        }
        else {
            Write-AppLog "Failed to create ChatGPT shortcuts!" -Level ERROR -Component $script:AppConfig.Name
            exit 1
        }
    }
    else {
        Write-AppLog "Shortcut creation skipped by user parameter." -Level INFO -Component $script:AppConfig.Name
        exit 0
    }
}
catch {
    Write-AppLog "Fatal error: $($_.Exception.Message)" -Level ERROR -Component $script:AppConfig.Name
    Write-AppLog "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG -Component $script:AppConfig.Name
    exit 1
}

#endregion
