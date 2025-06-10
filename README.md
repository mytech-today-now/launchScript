# LaunchScript Manager

A comprehensive web-based management system for PowerShell app installation scripts with accessibility, inclusiveness, and robust error handling.

## Overview

LaunchScript Manager provides a modern web interface for managing and executing PowerShell scripts that automate software installations. The system consists of a responsive HTML5 web page that coordinates with PowerShell scripts to provide a seamless app installation experience.

## Features

### Web Interface (index.html)
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Accessibility**: WCAG 2.1 compliant with ARIA labels, keyboard navigation, and screen reader support
- **Real-time Validation**: Automatically checks if applications are already installed
- **Search Functionality**: Quick filtering of available applications
- **Command Generation**: Builds PowerShell commands for selected applications
- **Help System**: Built-in usage documentation and guidance

### PowerShell Backend
- **Centralized Orchestration**: `launchScript.ps1` coordinates all app installations
- **Shared Utilities**: Common functions in `scripts/shared/HelperFunctions.ps1`
- **Robust Error Handling**: Comprehensive logging and fallback mechanisms
- **Version Detection**: Automatic detection of latest software versions
- **Silent Installation**: Unattended installation with progress reporting

### App Scripts
- **Modular Design**: Individual PowerShell scripts for each application
- **Version Management**: Automatic latest version detection and installation
- **Architecture Detection**: Supports x86, x64, and ARM64 systems
- **Digital Signature Verification**: Security validation of downloaded installers
- **Installation Validation**: Post-installation verification

## System Requirements

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or PowerShell 7+
- **Privileges**: Administrator rights recommended for most installations
- **Network**: Internet connection for downloading applications
- **Browser**: Modern web browser with JavaScript enabled

## Quick Start

1. **Clone or download** this repository to your local machine
2. **Open** `index.html` in your web browser
3. **Browse** available applications in the grid
4. **Select** applications you want to install by checking the boxes
5. **Click** "Generate Command" to create the PowerShell command
6. **Copy** the generated command and run it in PowerShell as Administrator

## File Structure

```
launchScript/
├── index.html                     # Main web interface
├── launchScript.ps1              # PowerShell orchestrator script
├── README.md                     # This documentation file
├── scripts/                      # App installation scripts directory
│   ├── shared/
│   │   └── HelperFunctions.ps1   # Shared utility functions
│   └── NotePad++.ps1             # Example: Notepad++ installation script
└── logs/                         # Log files (created automatically)
    └── launchScript.log          # Execution logs
```

## Usage Examples

### Basic Usage
```powershell
# Install a single application
.\launchScript.ps1 -Scripts "NotePad++"

# Install multiple applications
.\launchScript.ps1 -Scripts "NotePad++,VSCode,Chrome"
```

### Advanced Usage
```powershell
# Verbose output with test run mode
.\launchScript.ps1 -Scripts "NotePad++" -VerboseLogging -TestRun

# Custom scripts directory
.\launchScript.ps1 -Scripts "NotePad++" -ScriptsPath "C:\MyScripts"

# Custom log location
.\launchScript.ps1 -Scripts "NotePad++" -LogPath "C:\Logs\install.log"
```

## Creating New App Scripts

To add a new application, create a PowerShell script in the `scripts/` directory:

1. **Create** a new `.ps1` file named after your application
2. **Import** shared functions: `. "$PSScriptRoot\shared\HelperFunctions.ps1"`
3. **Implement** version detection, download, and installation logic
4. **Follow** the pattern established in `NotePad++.ps1`

### App Script Template
```powershell
#Requires -Version 5.1
# Import shared functions
. "$PSScriptRoot\shared\HelperFunctions.ps1"

# Configuration
$script:AppConfig = @{
    Name = "YourApp"
    DisplayName = "Your Application*"
    # ... other config
}

# Implementation functions
function Get-YourAppLatestVersion { }
function Install-YourApp { }

# Main execution
try {
    # Your installation logic here
}
catch {
    Write-AppLog "Error: $($_.Exception.Message)" -Level ERROR
    exit 1
}
```

## API Documentation

### Shared Helper Functions

#### Logging Functions
- `Write-AppLog`: Consistent logging with timestamps and levels
- Parameters: `Message`, `Level` (INFO/WARN/ERROR/SUCCESS/DEBUG), `Component`

#### System Information
- `Get-SystemArchitecture`: Returns system architecture (x86/x64/ARM64)
- `Test-IsElevated`: Checks if running with administrator privileges
- `Get-InstalledPrograms`: Retrieves list of installed programs
- `Test-ProgramInstalled`: Checks if specific program is installed

#### Download and Web Functions
- `Invoke-WebRequestWithRetry`: Downloads with retry logic and error handling
- `Get-LatestVersionFromGitHub`: Gets latest release from GitHub API
- `Get-LatestVersionFromWebsite`: Generic version detection from websites

#### Installation Functions
- `Invoke-SilentInstaller`: Executes installers with silent parameters
- `New-TempDirectory`: Creates temporary directories for downloads
- `Remove-TempDirectory`: Cleans up temporary files

#### Validation Functions
- `Test-FileHash`: Verifies file integrity using hash comparison
- `Test-ExecutableSignature`: Validates digital signatures

### Web Interface API

#### JavaScript Module: LaunchScriptManager
- `state`: Application state management
- `config`: Configuration settings
- `utils`: Utility functions (logging, debouncing, sanitization)
- `appManager`: App discovery and status checking
- `commandGenerator`: PowerShell command generation
- `search`: Search and filtering functionality

## Accessibility Features

- **Keyboard Navigation**: Full keyboard support for all interactive elements
- **Screen Reader Support**: ARIA labels and semantic HTML structure
- **High Contrast**: CSS custom properties for easy theme customization
- **Focus Management**: Visible focus indicators and logical tab order
- **Alternative Text**: Descriptive labels for all icons and status indicators
- **Responsive Design**: Adapts to different screen sizes and orientations

## Error Handling

### Logging Levels
- **INFO**: General information and progress updates
- **SUCCESS**: Successful operations and completions
- **WARN**: Warnings that don't prevent execution
- **ERROR**: Errors that may cause failures
- **DEBUG**: Detailed debugging information (verbose mode only)

### Error Recovery
- **Retry Logic**: Automatic retries for network operations
- **Graceful Degradation**: Fallback mechanisms for failed operations
- **User Feedback**: Clear error messages and suggested actions
- **Cleanup**: Automatic cleanup of temporary files and resources

## Security Considerations

- **Digital Signature Verification**: Validates downloaded executables
- **HTTPS Downloads**: Secure download connections
- **Input Validation**: Sanitizes user inputs and parameters
- **Execution Policy**: Respects PowerShell execution policies
- **Privilege Checking**: Warns about elevation requirements

## Performance Optimization

- **Debounced Search**: Prevents excessive filtering operations
- **Lazy Loading**: Loads app information on demand
- **Caching**: Caches version information and status checks
- **Parallel Processing**: Concurrent status checking for multiple apps
- **Resource Cleanup**: Automatic cleanup of temporary resources

## Version History

### v1.0.0 (2024-12-19)
**Initial Release**

#### Features Added
- ✅ Complete web interface with responsive design
- ✅ PowerShell orchestrator script with comprehensive logging
- ✅ Shared helper functions library
- ✅ NotePad++ installation script with latest version detection
- ✅ Accessibility compliance (WCAG 2.1)
- ✅ Real-time app status validation
- ✅ Search and filtering functionality
- ✅ Command generation and execution
- ✅ Error handling and recovery mechanisms
- ✅ Digital signature verification
- ✅ Multi-architecture support (x86/x64/ARM64)
- ✅ Comprehensive documentation

#### Components
- `index.html` v1.0.0: Web interface with jQuery and CSS3
- `launchScript.ps1` v1.0.0: PowerShell orchestrator
- `scripts/shared/HelperFunctions.ps1` v1.0.0: Shared utilities
- `scripts/NotePad++.ps1` v1.0.0: Notepad++ installation script
- `README.md` v1.0.0: Complete documentation

#### Technical Details
- HTML5 semantic markup with ARIA accessibility
- CSS3 with custom properties and responsive grid
- JavaScript ES5+ with jQuery 3.7.1
- PowerShell 5.1+ compatibility
- GitHub API integration for version detection
- NSIS installer support with silent installation
- Comprehensive error logging and recovery

## Contributing

1. **Fork** the repository
2. **Create** a feature branch
3. **Add** your app installation script following the established patterns
4. **Test** thoroughly on different systems
5. **Update** documentation as needed
6. **Submit** a pull request

## License

This project is provided as-is for educational and automation purposes. Individual app installation scripts should respect the licensing terms of their respective software packages.

## Support

For issues, questions, or contributions:
1. Check the built-in help system in the web interface
2. Review the error logs in the `logs/` directory
3. Consult this documentation
4. Create an issue in the repository

---

**LaunchScript Manager** - Simplifying software installation through automation and accessibility.
