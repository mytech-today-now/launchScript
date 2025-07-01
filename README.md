# LaunchScript Manager

A comprehensive web-based management system for PowerShell app installation scripts with accessibility, inclusiveness, and robust error handling.

## 🎉 Latest Updates - Real-time Application Detection

### ✅ Enhanced Application Detection System (December 2024)
The LaunchScript Manager now features **real-time application detection** that scans your host computer to determine which applications are actually installed, replacing the previous simulated detection.

#### 🔍 New Detection Features
- **Real-time Status Checking**: Automatically detects installed applications using multiple methods
- **Registry Scanning**: Comprehensive Windows registry analysis (HKLM, HKCU, WOW6432Node)
- **Windows Store Apps**: Detection of AppX packages and modern Windows applications
- **Portable Applications**: File system scanning for portable app installations
- **Web Server Integration**: Node.js server provides API endpoints for PowerShell integration
- **Enhanced Helper Functions**: Improved detection logic with fallback mechanisms

#### 🚀 New Components
- `Check-ApplicationStatus.ps1` - PowerShell service for real-time application detection
- `server.js` - Node.js web server with RESTful API endpoints
- `start-server.ps1` - Automated server startup with dependency checking
- Enhanced `HelperFunctions.ps1` with comprehensive detection methods

### ✅ All Scripts Now Validated and Integrated (December 2024)
The LaunchScript Manager properly processes **all 21 application scripts** in the `scripts/` directory:

**Available Applications:**
- AngryIPScanner - Network scanner for device discovery
- Audacity - Audio recording and editing software
- BelarcAdvisor - System information and inventory tool
- Blender - 3D creation suite for modeling and animation
- Brave - Privacy-focused web browser
- ChatGPT - Desktop application for OpenAI ChatGPT
- ClipGrab - Video downloader and converter
- Firefox - Mozilla web browser
- GIMP - GNU Image Manipulation Program
- MicrosoftQuickConnect - Device connectivity utility
- NotePad++ - Advanced text editor
- OpenOfficeSuite - Free office productivity suite
- OpenShot - Open-source video editor
- Opera - Web browser with built-in VPN
- RenameIt - Batch file renaming utility
- Signal - Private messenger with encryption
- Telegram - Cloud-based messaging app
- TestApp - Test application for validation
- TreeSizeFree - Disk space analyzer
- VSCode - Visual Studio Code editor
- WiseDuplicateFinder - Duplicate file finder

### 🔧 Technical Improvements
- **Dynamic Script Discovery**: Web interface automatically loads all available scripts
- **Enhanced Metadata**: Each script includes category, description, and version information
- **Improved Search**: Search now includes application categories
- **Comprehensive Testing**: Integration tests verify all components work together
- **Robust Error Handling**: Detailed logging with timestamp format `[HH:MM:SS AM/PM]`

## Overview

LaunchScript Manager provides a modern web interface for managing and executing PowerShell scripts that automate software installations. The system consists of a responsive HTML5 web page that coordinates with PowerShell scripts to provide a seamless app installation experience.

## Features

### Web Interface (index.html)
- **Responsive Design**: Works on desktop, tablet, and mobile devices
- **Accessibility**: WCAG 2.1 compliant with ARIA labels, keyboard navigation, and screen reader support
- **Enhanced Detection**: Real-time validation with accurate version display ("Current Version: X.X.X")
- **Comprehensive Coverage**: Detects applications from registry, Windows Store, and portable installations
- **Search Functionality**: Quick filtering of available applications
- **Command Generation**: Builds PowerShell commands for selected applications
- **Help System**: Built-in usage documentation and guidance

### PowerShell Backend
- **Centralized Orchestration**: `launchScript.ps1` coordinates all app installations
- **Enhanced Detection Service**: `Check-ApplicationStatus.ps1` provides real-time application scanning
- **Shared Utilities**: Comprehensive functions in `scripts/shared/HelperFunctions.ps1`
- **Robust Error Handling**: Advanced error handling with specific log formats and fallback mechanisms
- **Version Detection**: Accurate detection of installed versions from registry and file system
- **Silent Installation**: Unattended installation with progress reporting
- **Multi-source Detection**: Registry, Windows Store, and portable application support

### App Scripts
- **Modular Design**: Individual PowerShell scripts for each application
- **Version Management**: Automatic latest version detection and installation
- **Architecture Detection**: Supports x86, x64, and ARM64 systems
- **Digital Signature Verification**: Security validation of downloaded installers
- **Installation Validation**: Post-installation verification

## System Requirements

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**:
  - **Windows**: PowerShell 5.1+ or PowerShell 7+
  - **macOS/Linux**: PowerShell 7+ (pwsh)
- **Node.js**: Version 14+ (for web server functionality)
- **Privileges**: Administrator rights recommended for most installations
- **Network**: Internet connection for downloading applications
- **Browser**: Modern web browser with JavaScript enabled

## 🌍 Cross-Platform Support

LaunchScript Manager now supports **Windows**, **macOS**, and **Linux**:

### Platform-Specific Features
- **Windows**: Full functionality with Windows PowerShell 5.1+ or PowerShell 7+
- **macOS**: Requires PowerShell 7+ installation, automatic download links provided
- **Linux**: Requires PowerShell 7+ installation, automatic download links provided

### PowerShell Installation Detection
The application automatically detects PowerShell availability and provides:
- **Real-time system compatibility checking**
- **Automatic download links** for the correct PowerShell version and architecture
- **Installation instructions** specific to your operating system
- **Graceful fallback** when PowerShell is not available

## Quick Start

### Windows
1. **Clone or download** this repository to your local machine
2. **Open PowerShell as Administrator**
3. **Navigate** to the project directory
4. **Run the startup script**:
   ```powershell
   .\start-server.ps1
   ```
5. **Open your browser** to `http://localhost:3000`

### macOS
1. **Clone or download** this repository to your local machine
2. **Open Terminal**
3. **Navigate** to the project directory
4. **Make the script executable** (first time only):
   ```bash
   chmod +x start-server.sh
   ```
5. **Run the startup script**:
   ```bash
   ./start-server.sh
   ```
6. **Open your browser** to `http://localhost:3000`

### Linux
1. **Clone or download** this repository to your local machine
2. **Open Terminal**
3. **Navigate** to the project directory
4. **Make the script executable** (first time only):
   ```bash
   chmod +x start-server.sh
   ```
5. **Run the startup script**:
   ```bash
   ./start-server.sh
   ```
6. **Open your browser** to `http://localhost:3000`

### Alternative: Direct File Access
If you prefer not to use the web server:
1. **Open** `index.html` directly in your web browser
2. **Note**: Some features may be limited without the server

## File Structure

```
launchScript/
├── index.html                     # Main web interface
├── launchScript.ps1              # PowerShell orchestrator script
├── README.md                     # This documentation file
├── verify-integration.ps1        # Integration test script
├── scripts/                      # App installation scripts directory
│   ├── shared/
│   │   └── HelperFunctions.ps1   # Shared utility functions
│   ├── AngryIPScanner.ps1        # Network scanner installation
│   ├── Audacity.ps1              # Audio editor installation
│   ├── BelarcAdvisor.ps1         # System information tool
│   ├── Blender.ps1               # 3D creation suite
│   ├── Brave.ps1                 # Privacy browser installation
│   ├── ChatGPT.ps1               # ChatGPT desktop app
│   ├── ClipGrab.ps1              # Video downloader
│   ├── Firefox.ps1               # Mozilla Firefox browser
│   ├── GIMP.ps1                  # Image editor installation
│   ├── MicrosoftQuickConnect.ps1 # Microsoft connectivity tool
│   ├── NotePad++.ps1             # Advanced text editor
│   ├── OpenOfficeSuite.ps1       # Office productivity suite
│   ├── OpenShot.ps1              # Video editor installation
│   ├── Opera.ps1                 # Opera browser installation
│   ├── RenameIt.ps1              # File renaming utility
│   ├── Signal.ps1                # Private messenger
│   ├── Telegram.ps1              # Messaging app installation
│   ├── TestApp.ps1               # Test application script
│   ├── TreeSizeFree.ps1          # Disk space analyzer
│   ├── VSCode.ps1                # Visual Studio Code editor
│   └── WiseDuplicateFinder.ps1   # Duplicate file finder
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

## Recent Improvements (December 2024)

### 🔧 Enhanced Application Detection Logic
**Fixed Issues:**
- ✅ **Property Access Errors**: Resolved PowerShell property access errors in `Test-ProgramInstalled` function
- ✅ **Version Display**: Fixed frontend to show "Current Version: X.X.X" instead of "Version: Latest Stable" for installed apps
- ✅ **Detection Coverage**: Improved application detection to find more installed applications
- ✅ **Error Handling**: Added robust error handling with consistent return structures
- ✅ **Registry Scanning**: Enhanced registry scanning with better filtering and null checks

**Technical Improvements:**
- **Consistent Return Structure**: All detection functions now return consistent hashtable structures
- **Safe Property Access**: Added null checks and safe property access patterns
- **Enhanced Logging**: Improved debug logging with component-specific messages
- **Performance Optimization**: Faster detection with efficient registry scanning
- **Fallback Mechanisms**: Multiple detection methods with graceful fallbacks

**Testing:**
- ✅ Created comprehensive test suite (`tests/DetectionTests.ps1`)
- ✅ Added simple validation test (`tests/QuickTest.ps1`)
- ✅ Verified detection accuracy for multiple applications
- ✅ Performance testing shows sub-5-second detection times

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
