#!/bin/bash

# LaunchScript Manager - macOS/Linux Startup Script
# 
# This script checks prerequisites and starts the LaunchScript Manager web server
# on macOS and Linux systems.
#
# Usage: ./start-server.sh [--port PORT] [--skip-deps] [--open-browser]
#
# Requirements:
# - Node.js 14+
# - PowerShell 7+ (pwsh)

set -e  # Exit on any error

# Default configuration
PORT=3000
SKIP_DEPS=false
OPEN_BROWSER=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%H:%M:%S %p')
    
    case $level in
        "INFO")
            echo -e "${BLUE}[${timestamp}] [INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[${timestamp}] [SUCCESS]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[${timestamp}] [WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[${timestamp}] [ERROR]${NC} $message"
            ;;
    esac
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        --open-browser)
            OPEN_BROWSER=true
            shift
            ;;
        -h|--help)
            echo "LaunchScript Manager - macOS/Linux Startup Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT        Set server port (default: 3000)"
            echo "  --skip-deps        Skip dependency installation check"
            echo "  --open-browser     Open browser after starting server"
            echo "  -h, --help         Show this help message"
            echo ""
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if Node.js is installed
check_nodejs() {
    if command -v node >/dev/null 2>&1; then
        local node_version=$(node --version | sed 's/v//')
        local major_version=$(echo $node_version | cut -d. -f1)
        
        if [ "$major_version" -ge 14 ]; then
            log "SUCCESS" "Node.js $node_version found"
            return 0
        else
            log "ERROR" "Node.js version $node_version is too old. Minimum required: 14.0.0"
            return 1
        fi
    else
        log "ERROR" "Node.js is not installed"
        return 1
    fi
}

# Check if npm is installed
check_npm() {
    if command -v npm >/dev/null 2>&1; then
        local npm_version=$(npm --version)
        log "SUCCESS" "npm $npm_version found"
        return 0
    else
        log "ERROR" "npm is not installed"
        return 1
    fi
}

# Check if PowerShell is installed
check_powershell() {
    if command -v pwsh >/dev/null 2>&1; then
        local ps_version=$(pwsh -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo "Unknown")
        log "SUCCESS" "PowerShell $ps_version found"
        return 0
    else
        log "WARN" "PowerShell (pwsh) is not installed or not in PATH"
        log "INFO" "The application will show installation instructions when accessed"
        return 1
    fi
}

# Install Node.js dependencies
install_dependencies() {
    if [ "$SKIP_DEPS" = true ]; then
        log "INFO" "Skipping dependency check"
        return 0
    fi
    
    if [ ! -d "node_modules" ]; then
        log "INFO" "Installing Node.js dependencies..."
        npm install
        if [ $? -eq 0 ]; then
            log "SUCCESS" "Dependencies installed successfully"
        else
            log "ERROR" "Failed to install dependencies"
            return 1
        fi
    else
        log "SUCCESS" "Dependencies already installed"
    fi
    
    return 0
}

# Start the web server
start_server() {
    log "INFO" "Starting LaunchScript Manager web server on port $PORT..."
    
    # Set port environment variable if different from default
    if [ "$PORT" != "3000" ]; then
        export PORT=$PORT
    fi
    
    # Open browser if requested
    if [ "$OPEN_BROWSER" = true ]; then
        log "INFO" "Browser will open automatically after server starts"
        sleep 2
        
        # Detect OS and open browser accordingly
        case "$(uname -s)" in
            Darwin)
                open "http://localhost:$PORT"
                ;;
            Linux)
                if command -v xdg-open >/dev/null 2>&1; then
                    xdg-open "http://localhost:$PORT"
                elif command -v gnome-open >/dev/null 2>&1; then
                    gnome-open "http://localhost:$PORT"
                fi
                ;;
        esac &
    fi
    
    log "INFO" "Server starting at http://localhost:$PORT"
    log "INFO" "Press Ctrl+C to stop the server"
    
    # Start Node.js server
    node server.js
}

# Main execution
main() {
    log "INFO" "=== LaunchScript Manager Startup ==="
    log "INFO" "Platform: $(uname -s) $(uname -m)"
    log "INFO" "Working directory: $SCRIPT_DIR"
    
    cd "$SCRIPT_DIR"
    
    # Check prerequisites
    if ! check_nodejs; then
        log "ERROR" "Node.js is required but not found"
        log "INFO" "Please install Node.js from https://nodejs.org/"
        log "INFO" "Minimum version required: 14.0.0"
        
        # Offer to open download page
        echo -n "Would you like to open the Node.js download page? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            case "$(uname -s)" in
                Darwin)
                    open "https://nodejs.org/en/download/"
                    ;;
                Linux)
                    if command -v xdg-open >/dev/null 2>&1; then
                        xdg-open "https://nodejs.org/en/download/"
                    fi
                    ;;
            esac
        fi
        exit 1
    fi
    
    if ! check_npm; then
        log "ERROR" "npm is required but not found"
        log "INFO" "npm should be installed with Node.js. Please reinstall Node.js"
        exit 1
    fi
    
    # Check PowerShell (not required for startup, but warn if missing)
    check_powershell || true
    
    # Install dependencies
    if ! install_dependencies; then
        log "ERROR" "Failed to install dependencies. Cannot start server"
        exit 1
    fi
    
    # Check if required files exist
    if [ ! -f "server.js" ]; then
        log "ERROR" "server.js not found. Cannot start server"
        exit 1
    fi
    
    if [ ! -f "index.html" ]; then
        log "ERROR" "index.html not found. Web interface will not work"
        exit 1
    fi
    
    if [ ! -f "Check-ApplicationStatus.ps1" ]; then
        log "WARN" "Check-ApplicationStatus.ps1 not found. Application detection will not work without PowerShell"
    fi
    
    if [ ! -d "scripts" ]; then
        log "WARN" "scripts directory not found. No applications will be available"
    else
        local script_count=$(find scripts -name "*.ps1" -not -path "*/shared/*" | wc -l | tr -d ' ')
        log "SUCCESS" "Found $script_count application scripts"
    fi
    
    # Start the server
    log "SUCCESS" "All prerequisites met. Starting web server..."
    start_server
}

# Run main function
main "$@"
