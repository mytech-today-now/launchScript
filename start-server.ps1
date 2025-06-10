#Requires -Version 5.1
<#
.SYNOPSIS
    Startup script for LaunchScript Manager web server
    
.DESCRIPTION
    This script checks prerequisites and starts the LaunchScript Manager web server.
    It will install Node.js dependencies if needed and launch the server.
    
.PARAMETER Port
    Port number for the web server (default: 3000)
    
.PARAMETER SkipDependencyCheck
    Skip checking and installing Node.js dependencies
    
.PARAMETER OpenBrowser
    Automatically open the web browser after starting the server
    
.EXAMPLE
    .\start-server.ps1
    
.EXAMPLE
    .\start-server.ps1 -Port 8080 -OpenBrowser
    
.NOTES
    Version: 1.0.0
    Author: LaunchScript Manager
    Created: 2024
    
    Requirements:
    - PowerShell 5.1 or later
    - Node.js 14+ (will prompt to install if missing)
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Port number for the web server")]
    [int]$Port = 3000,
    
    [Parameter(HelpMessage = "Skip dependency check")]
    [switch]$SkipDependencyCheck,
    
    [Parameter(HelpMessage = "Open browser automatically")]
    [switch]$OpenBrowser
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

#region Utility Functions

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'WARN' { Write-Host $logEntry -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry -ForegroundColor White }
    }
}

function Test-NodeJS {
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion) {
            Write-Log "Node.js found: $nodeVersion" -Level SUCCESS
            return $true
        }
    }
    catch {
        # Node.js not found
    }
    
    Write-Log "Node.js not found or not in PATH" -Level WARN
    return $false
}

function Test-NPM {
    try {
        $npmVersion = npm --version 2>$null
        if ($npmVersion) {
            Write-Log "npm found: v$npmVersion" -Level SUCCESS
            return $true
        }
    }
    catch {
        # npm not found
    }
    
    Write-Log "npm not found or not in PATH" -Level WARN
    return $false
}

function Install-Dependencies {
    Write-Log "Installing Node.js dependencies..." -Level INFO
    
    try {
        if (-not (Test-Path "package.json")) {
            Write-Log "package.json not found in current directory" -Level ERROR
            return $false
        }
        
        Write-Log "Running npm install..." -Level INFO
        $npmProcess = Start-Process -FilePath "npm" -ArgumentList "install" -Wait -PassThru -NoNewWindow
        
        if ($npmProcess.ExitCode -eq 0) {
            Write-Log "Dependencies installed successfully" -Level SUCCESS
            return $true
        }
        else {
            Write-Log "npm install failed with exit code: $($npmProcess.ExitCode)" -Level ERROR
            return $false
        }
    }
    catch {
        Write-Log "Failed to install dependencies: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Start-WebServer {
    Write-Log "Starting LaunchScript Manager web server..." -Level INFO
    
    try {
        # Set environment variable for port if different from default
        if ($Port -ne 3000) {
            $env:PORT = $Port
        }
        
        Write-Log "Server will start on port: $Port" -Level INFO
        Write-Log "Press Ctrl+C to stop the server" -Level INFO
        Write-Log "Starting Node.js server..." -Level INFO
        
        # Start the server
        Start-Process -FilePath "node" -ArgumentList "server.js" -NoNewWindow -Wait
    }
    catch {
        Write-Log "Failed to start web server: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

#endregion

#region Main Execution

try {
    Write-Host "LaunchScript Manager - Web Server Startup" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    
    # Check if we're in the correct directory
    if (-not (Test-Path "server.js")) {
        Write-Log "server.js not found. Please run this script from the LaunchScript Manager directory." -Level ERROR
        exit 1
    }
    
    # Check Node.js prerequisites
    if (-not (Test-NodeJS)) {
        Write-Log "Node.js is required but not found." -Level ERROR
        Write-Log "Please install Node.js from https://nodejs.org/" -Level INFO
        Write-Log "Minimum version required: 14.0.0" -Level INFO
        
        $choice = Read-Host "Would you like to open the Node.js download page? (Y/N)"
        if ($choice -match '^[Yy]') {
            Start-Process "https://nodejs.org/en/download/"
        }
        exit 1
    }
    
    if (-not (Test-NPM)) {
        Write-Log "npm is required but not found." -Level ERROR
        Write-Log "npm should be installed with Node.js. Please reinstall Node.js." -Level INFO
        exit 1
    }
    
    # Install dependencies if needed
    if (-not $SkipDependencyCheck) {
        if (-not (Test-Path "node_modules")) {
            Write-Log "node_modules directory not found. Installing dependencies..." -Level INFO
            if (-not (Install-Dependencies)) {
                Write-Log "Failed to install dependencies. Cannot start server." -Level ERROR
                exit 1
            }
        }
        else {
            Write-Log "Dependencies already installed (node_modules found)" -Level SUCCESS
        }
    }
    
    # Check if PowerShell detection script exists
    if (-not (Test-Path "Check-ApplicationStatus.ps1")) {
        Write-Log "Check-ApplicationStatus.ps1 not found. Application detection will not work." -Level WARN
    }
    else {
        Write-Log "Application detection service found" -Level SUCCESS
    }
    
    # Check if scripts directory exists
    if (-not (Test-Path "scripts")) {
        Write-Log "scripts directory not found. No applications will be available." -Level WARN
    }
    else {
        $scriptCount = (Get-ChildItem -Path "scripts" -Filter "*.ps1" | Where-Object { $_.Name -ne "shared" }).Count
        Write-Log "Found $scriptCount application scripts" -Level SUCCESS
    }
    
    # Open browser if requested
    if ($OpenBrowser) {
        Write-Log "Browser will open automatically after server starts" -Level INFO
        Start-Sleep -Seconds 2
        Start-Process "http://localhost:$Port"
    }
    
    # Start the web server
    Write-Log "All prerequisites met. Starting web server..." -Level SUCCESS
    Start-WebServer
    
}
catch {
    Write-Log "Fatal error: $($_.Exception.Message)" -Level ERROR
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR
    exit 1
}

#endregion
