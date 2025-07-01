# Cross-Platform Refactoring Documentation

## Overview
The LaunchScript Manager has been successfully refactored to support **Windows**, **macOS**, and **Linux** operating systems. This document outlines the changes made and how the application now handles cross-platform compatibility.

## Key Changes Made

### 1. **Server-Side Enhancements (server.js)**

#### OS Detection and System Information
- Added `os` module import for platform detection
- Created `getSystemInfo()` function to detect:
  - Operating system (Windows, macOS, Linux)
  - System architecture (x64, arm64, x86)
  - OS release version
  - Platform-specific flags

#### PowerShell Command Detection
- **Windows**: Uses `powershell` command (PowerShell 5.1+ or 7+)
- **macOS/Linux**: Uses `pwsh` command (PowerShell 7+ only)
- Automatic command selection based on detected OS

#### PowerShell Download URLs
- **Windows**: Direct links to MSI installers (x64/x86)
- **macOS**: Direct links to PKG installers (Intel/Apple Silicon)
- **Linux**: Documentation link for distribution-specific installation

#### New API Endpoints
- **`/api/system`**: Returns system information and PowerShell availability
- Enhanced error handling for cross-platform compatibility

### 2. **Client-Side Enhancements (index.html)**

#### System Compatibility Checking
- Added `checkSystemCompatibility()` function
- Real-time PowerShell availability detection
- Automatic system information display

#### Dynamic UI Adaptation
- **PowerShell Available**: Full functionality with success message
- **PowerShell Missing**: Warning message with download links
- **System Error**: Error handling with retry options

#### Enhanced User Experience
- Platform-specific download links with `target="_blank"`
- Installation instructions tailored to detected OS
- Graceful degradation when PowerShell is unavailable

### 3. **Cross-Platform Startup Scripts**

#### Windows (start-server.ps1)
- **Existing**: PowerShell-based startup script
- **Enhanced**: Better error handling and dependency checking

#### macOS/Linux (start-server.sh)
- **New**: Bash-based startup script
- **Features**:
  - Node.js version checking
  - PowerShell availability detection
  - Automatic browser opening
  - Colored console output
  - Command-line argument parsing

## Platform-Specific Features

### Windows
- **PowerShell Support**: Both Windows PowerShell 5.1+ and PowerShell 7+
- **Registry Detection**: Full Windows registry scanning
- **Windows Store Apps**: AppX package detection
- **File System Detection**: Portable application scanning

### macOS
- **PowerShell Support**: PowerShell 7+ (pwsh) required
- **Package Detection**: Limited to file system scanning
- **Browser Integration**: Automatic opening with `open` command
- **Installation**: PKG installer with architecture detection (Intel/Apple Silicon)

### Linux
- **PowerShell Support**: PowerShell 7+ (pwsh) required
- **Package Detection**: Limited to file system scanning
- **Browser Integration**: Automatic opening with `xdg-open`
- **Installation**: Distribution-specific package managers

## User Interface Enhancements

### System Status Alerts
- **Success Alert**: Green badge when PowerShell is available
- **Warning Alert**: Orange badge when PowerShell is missing
- **Error Alert**: Red badge when system check fails

### Download Integration
- **Automatic Detection**: Correct PowerShell version for OS and architecture
- **Direct Links**: One-click download to appropriate installer
- **Installation Instructions**: Platform-specific guidance

### Responsive Design
- **Cross-Platform Styling**: Consistent appearance across all platforms
- **Accessibility**: Full keyboard navigation and screen reader support
- **Mobile Friendly**: Responsive design for tablets and mobile devices

## Technical Implementation

### PowerShell Execution
```javascript
// Automatic command selection
const psCommand = systemInfo.isWindows ? 'powershell' : 'pwsh';

// Cross-platform process spawning
const ps = spawn(psCommand, args, {
    cwd: process.cwd(),
    stdio: ['pipe', 'pipe', 'pipe']
});
```

### System Detection
```javascript
// OS and architecture detection
const systemInfo = {
    platform: os.platform(),
    architecture: os.arch(),
    isWindows: platform === 'win32',
    isMacOS: platform === 'darwin',
    isLinux: platform === 'linux'
};
```

### Download URL Generation
```javascript
// Platform-specific PowerShell downloads
function getPowerShellDownloadUrl(platform, arch) {
    switch (platform) {
        case 'win32':
            return arch === 'x64' 
                ? 'PowerShell-7.4.6-win-x64.msi'
                : 'PowerShell-7.4.6-win-x86.msi';
        case 'darwin':
            return arch === 'arm64'
                ? 'powershell-7.4.6-osx-arm64.pkg'
                : 'powershell-7.4.6-osx-x64.pkg';
        // ... etc
    }
}
```

## Usage Examples

### Windows
```powershell
# Start server
.\start-server.ps1

# With options
.\start-server.ps1 -Port 8080 -OpenBrowser
```

### macOS/Linux
```bash
# Make executable (first time)
chmod +x start-server.sh

# Start server
./start-server.sh

# With options
./start-server.sh --port 8080 --open-browser
```

## Error Handling and Fallbacks

### PowerShell Not Available
1. **Detection**: System automatically detects missing PowerShell
2. **User Notification**: Clear warning message with download link
3. **Graceful Degradation**: Limited functionality mode
4. **Recovery**: Recheck system button for post-installation verification

### Network Issues
1. **API Fallbacks**: Graceful handling of network failures
2. **Offline Mode**: Basic functionality without server
3. **Error Messages**: Clear user feedback for connection issues

### Platform Limitations
1. **Feature Detection**: Automatic disabling of unsupported features
2. **Alternative Methods**: Fallback detection methods where possible
3. **User Guidance**: Clear instructions for platform-specific requirements

## Testing and Validation

### Automated Testing
- **System Detection**: Validates OS and architecture detection
- **PowerShell Availability**: Tests command availability across platforms
- **API Endpoints**: Verifies cross-platform API responses

### Manual Testing
- **Windows 10/11**: Full functionality testing
- **macOS**: PowerShell installation and detection testing
- **Linux**: Various distributions testing

## Future Enhancements

### Planned Features
1. **Package Manager Integration**: Native package manager support per platform
2. **Enhanced Detection**: Platform-specific application detection methods
3. **Containerization**: Docker support for consistent environments
4. **CI/CD Integration**: Automated testing across multiple platforms

### Considerations
1. **Performance**: Platform-specific optimizations
2. **Security**: Cross-platform security best practices
3. **Maintenance**: Unified codebase with platform-specific branches

## Conclusion

The cross-platform refactoring successfully enables LaunchScript Manager to run on Windows, macOS, and Linux while maintaining full functionality where PowerShell is available and providing graceful degradation where it's not. The application now automatically detects system capabilities and guides users through any required setup steps.
