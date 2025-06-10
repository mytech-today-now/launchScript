/**
 * LaunchScript Manager - Local Web Server
 * 
 * This Node.js server provides a bridge between the web interface and PowerShell scripts.
 * It serves the static HTML file and provides an API endpoint to execute the application
 * detection service.
 * 
 * Requirements:
 * - Node.js 14+ 
 * - PowerShell 5.1+ or PowerShell 7+
 * 
 * Usage:
 *   node server.js
 *   
 * Then open: http://localhost:3000
 */

'use strict';

const express = require('express');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs').promises;

// Configuration
const CONFIG = {
    port: 3000,
    host: 'localhost',
    powershellTimeout: 60000, // 60 seconds
    maxScripts: 50,
    logLevel: 'INFO'
};

// Create Express app
const app = express();

// Middleware
app.use(express.json());
app.use(express.static('.', { 
    index: 'index.html',
    dotfiles: 'deny'
}));

// Logging utility
function log(level, message, component = 'Server') {
    const timestamp = new Date().toLocaleTimeString('en-US', { 
        hour12: true, 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit' 
    });
    console.log(`[${timestamp}] [${component}] [${level}] ${message}`);
}

// Validate script names to prevent injection attacks
function validateScriptNames(scripts) {
    if (!scripts || typeof scripts !== 'string') {
        return { valid: false, error: 'Scripts parameter must be a string' };
    }
    
    const scriptArray = scripts.split(',').map(s => s.trim());
    
    if (scriptArray.length > CONFIG.maxScripts) {
        return { valid: false, error: `Too many scripts requested (max: ${CONFIG.maxScripts})` };
    }
    
    // Check for valid script names (alphanumeric, +, -, space only)
    const validNamePattern = /^[a-zA-Z0-9\+\-\s]+$/;
    for (const script of scriptArray) {
        if (!validNamePattern.test(script)) {
            return { valid: false, error: `Invalid script name: ${script}` };
        }
    }
    
    return { valid: true, scripts: scriptArray };
}

// Execute PowerShell detection service
async function executeDetectionService(scripts, includeWindowsStore = false, includePortable = false) {
    return new Promise((resolve, reject) => {
        log('INFO', `Executing detection service for scripts: ${scripts}`);
        
        // Build PowerShell command arguments
        const args = [
            '-ExecutionPolicy', 'Bypass',
            '-File', './Check-ApplicationStatus.ps1',
            '-Scripts', scripts,
            '-OutputFormat', 'JSON'
        ];
        
        if (includeWindowsStore) {
            args.push('-IncludeWindowsStore');
        }
        
        if (includePortable) {
            args.push('-IncludePortable');
        }
        
        log('DEBUG', `PowerShell command: powershell ${args.join(' ')}`);
        
        // Spawn PowerShell process
        const ps = spawn('powershell', args, {
            cwd: process.cwd(),
            stdio: ['pipe', 'pipe', 'pipe']
        });
        
        let stdout = '';
        let stderr = '';
        
        // Collect output
        ps.stdout.on('data', (data) => {
            stdout += data.toString();
        });
        
        ps.stderr.on('data', (data) => {
            stderr += data.toString();
        });
        
        // Handle process completion
        ps.on('close', (code) => {
            log('DEBUG', `PowerShell process exited with code: ${code}`);
            
            if (code === 0) {
                try {
                    // Extract JSON from stdout (may contain other log messages and progress indicators)
                    // Look for the last complete JSON object in the output
                    const lines = stdout.split('\n');
                    let jsonString = '';
                    let braceCount = 0;
                    let inJson = false;

                    for (const line of lines) {
                        const trimmedLine = line.trim();
                        if (trimmedLine.startsWith('{')) {
                            inJson = true;
                            jsonString = trimmedLine;
                            braceCount = (trimmedLine.match(/\{/g) || []).length - (trimmedLine.match(/\}/g) || []).length;
                        } else if (inJson) {
                            jsonString += '\n' + trimmedLine;
                            braceCount += (trimmedLine.match(/\{/g) || []).length - (trimmedLine.match(/\}/g) || []).length;

                            if (braceCount === 0) {
                                // Complete JSON object found
                                break;
                            }
                        }
                    }

                    if (jsonString && braceCount === 0) {
                        const result = JSON.parse(jsonString);
                        log('SUCCESS', `Detection completed: ${result.InstalledCount}/${result.TotalApps} apps installed`);
                        resolve(result);
                    } else {
                        log('ERROR', 'No valid JSON found in PowerShell output');
                        log('DEBUG', `stdout: ${stdout}`);
                        reject(new Error('No valid JSON output from PowerShell script'));
                    }
                } catch (parseError) {
                    log('ERROR', `Failed to parse PowerShell output: ${parseError.message}`);
                    log('DEBUG', `stdout: ${stdout}`);
                    reject(new Error(`JSON parse error: ${parseError.message}`));
                }
            } else {
                log('ERROR', `PowerShell script failed with code ${code}: ${stderr}`);
                reject(new Error(`PowerShell execution failed: ${stderr || 'Unknown error'}`));
            }
        });
        
        // Handle process errors
        ps.on('error', (error) => {
            log('ERROR', `PowerShell process error: ${error.message}`);
            reject(new Error(`Failed to start PowerShell: ${error.message}`));
        });
        
        // Set timeout
        const timeout = setTimeout(() => {
            ps.kill();
            reject(new Error('PowerShell execution timed out'));
        }, CONFIG.powershellTimeout);
        
        ps.on('close', () => {
            clearTimeout(timeout);
        });
    });
}

// API Routes

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        version: '1.0.0'
    });
});

// Application detection endpoint
app.post('/api/detect', async (req, res) => {
    try {
        log('INFO', 'Received detection request', 'API');

        const { scripts, includeWindowsStore = false, includePortable = false } = req.body;

        // Validate input
        const validation = validateScriptNames(scripts);
        if (!validation.valid) {
            log('WARN', `Invalid request: ${validation.error}`, 'API');
            return res.status(400).json({
                error: validation.error,
                timestamp: new Date().toISOString()
            });
        }

        // Execute detection service with the validated scripts
        const result = await executeDetectionService(
            scripts,  // Use the original scripts parameter, not validation.scripts
            includeWindowsStore,
            includePortable
        );
        
        // Return results
        res.json({
            success: true,
            data: result,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        log('ERROR', `Detection request failed: ${error.message}`, 'API');
        res.status(500).json({
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Get available scripts endpoint
app.get('/api/scripts', async (req, res) => {
    try {
        log('INFO', 'Received scripts list request', 'API');
        
        const scriptsDir = path.join(process.cwd(), 'scripts');
        const files = await fs.readdir(scriptsDir);
        
        const scriptFiles = files
            .filter(file => file.endsWith('.ps1') && file !== 'shared')
            .map(file => ({
                filename: file,
                name: file.replace('.ps1', '').replace(/([A-Z])/g, ' $1').trim()
            }));
        
        res.json({
            success: true,
            data: {
                scripts: scriptFiles,
                count: scriptFiles.length
            },
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        log('ERROR', `Scripts list request failed: ${error.message}`, 'API');
        res.status(500).json({
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Error handling middleware
app.use((error, req, res, next) => {
    log('ERROR', `Unhandled error: ${error.message}`, 'Server');
    res.status(500).json({
        error: 'Internal server error',
        timestamp: new Date().toISOString()
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        error: 'Not found',
        timestamp: new Date().toISOString()
    });
});

// Start server
app.listen(CONFIG.port, CONFIG.host, () => {
    log('INFO', `LaunchScript Manager server started`);
    log('INFO', `Server running at http://${CONFIG.host}:${CONFIG.port}`);
    log('INFO', `Open your browser to http://${CONFIG.host}:${CONFIG.port} to use the application`);
});

// Graceful shutdown
process.on('SIGINT', () => {
    log('INFO', 'Received SIGINT, shutting down gracefully');
    process.exit(0);
});

process.on('SIGTERM', () => {
    log('INFO', 'Received SIGTERM, shutting down gracefully');
    process.exit(0);
});
