# WMI-Based Application Detection

## Overview

The LaunchScript Manager now includes enhanced application detection using Windows Management Instrumentation (WMI) with regex-based program name extraction. This feature provides an additional detection method that can find installed software that might be missed by traditional registry and file system scanning.

## How It Works

### 1. Regex-based Name Extraction

The system extracts core program names from the existing `SearchNames` patterns using intelligent regex processing:

- **Wildcard Removal**: Strips `*` characters from search patterns
- **Word Splitting**: Splits on common separators (space, dash, underscore, dot)
- **Filtering**: Removes common words like "the", "and", "application", "software"
- **CamelCase Extraction**: Breaks down camelCase names (e.g., "AngryIPScanner" → "Angry", "IP", "Scanner")
- **Deduplication**: Returns unique, meaningful program names

### 2. WMI Querying

The extracted names are used to query the `Win32_Product` WMI class:

- **Exact Matching**: First tries exact substring matches
- **Regex Matching**: Falls back to flexible regex pattern matching
- **Caching**: WMI results are cached to improve performance
- **Error Handling**: Graceful fallback when WMI is unavailable

## Examples

### Name Extraction Examples

| Original Search Pattern | Extracted Names |
|-------------------------|-----------------|
| `*Visual Studio Code*`, `*VSCode*` | Visual, Studio, Code, VSCode |
| `*Angry IP Scanner*`, `*AngryIPScanner*` | Angry, IP, Scanner, AngryIPScanner |
| `*GNU Image Manipulation Program*`, `*GIMP*` | GNU, Image, Manipulation, Program, GIMP |
| `*Wise Duplicate Finder*` | Wise, Duplicate, Finder |

### Detection Flow

1. **Registry Detection**: Traditional registry scanning (existing method)
2. **File System Detection**: Portable app scanning (existing method)
3. **WMI Detection**: New regex-based WMI querying (fallback method)

## Configuration

### PowerShell Parameters

The `Check-ApplicationStatus.ps1` script now supports:

```powershell
# Enable WMI detection (default: enabled)
.\Check-ApplicationStatus.ps1 -Scripts "VSCode" -IncludeWMI

# Disable WMI detection
.\Check-ApplicationStatus.ps1 -Scripts "VSCode" -IncludeWMI:$false

# Combine with other detection methods
.\Check-ApplicationStatus.ps1 -Scripts "VSCode" -IncludeWindowsStore -IncludePortable -IncludeWMI
```

### API Parameters

The web server API now accepts:

```javascript
// POST /api/detect
{
    "scripts": "VSCode,Firefox",
    "includeWindowsStore": false,
    "includePortable": true,
    "includeWMI": true  // New parameter (default: true)
}
```

## Performance Considerations

### WMI Query Performance

- **Initial Query**: First WMI query can take 5-15 seconds
- **Caching**: Subsequent queries use cached results
- **Memory Usage**: WMI results are cached in memory during script execution
- **Administrator Privileges**: Some WMI queries may require elevated privileges

### Optimization Features

- **Lazy Loading**: WMI queries only execute when needed
- **Result Caching**: `$script:CachedWMIProducts` variable caches results
- **Timeout Handling**: Graceful handling of slow WMI responses
- **Error Recovery**: Continues with other detection methods if WMI fails

## Testing

### Test Scripts

Two test scripts are provided:

1. **RegexExtractionDemo.ps1**: Demonstrates name extraction logic
   ```powershell
   .\tests\RegexExtractionDemo.ps1
   ```

2. **WMIDetectionTest.ps1**: Tests full WMI detection functionality
   ```powershell
   # Test all applications
   .\tests\WMIDetectionTest.ps1
   
   # Test specific application
   .\tests\WMIDetectionTest.ps1 -TestSpecificApp "VSCode.ps1" -ShowExtractedNames
   
   # Test only WMI functionality
   .\tests\WMIDetectionTest.ps1 -TestWMIOnly
   ```

### Manual Testing

```powershell
# Test name extraction
$names = Get-ExtractedProgramNames -SearchNames @('*Visual Studio Code*', '*VSCode*')
Write-Host "Extracted: $($names -join ', ')"

# Test WMI detection
$result = Find-SimilarSoftwareViaWMI -ProgramNames $names -ScriptName "VSCode.ps1"
Write-Host "Found: $($result.IsInstalled) - $($result.DisplayName)"
```

## Troubleshooting

### Common Issues

1. **WMI Unavailable**
   - **Symptom**: "WMI product query failed or returned no results"
   - **Solution**: Run PowerShell as Administrator or check WMI service status

2. **Slow Performance**
   - **Symptom**: Detection takes longer than expected
   - **Solution**: WMI queries are cached; subsequent runs will be faster

3. **No Results Found**
   - **Symptom**: WMI detection returns no matches
   - **Solution**: Check if software was installed via Windows Installer (MSI)

### Debugging

Enable debug logging to see detailed information:

```powershell
# Enable verbose output (non-JSON mode)
.\Check-ApplicationStatus.ps1 -Scripts "VSCode" -OutputFormat "Object"
```

Debug messages include:
- Extracted program names
- WMI query results
- Cache status
- Match patterns used

## Limitations

### WMI Limitations

- **MSI Only**: `Win32_Product` only shows software installed via Windows Installer
- **Performance**: Initial WMI queries can be slow
- **Privileges**: May require administrator rights for complete results
- **Platform**: Windows-only feature

### Detection Scope

- **Portable Apps**: WMI won't detect portable applications
- **Store Apps**: WMI doesn't include Windows Store applications
- **Manual Installs**: Software installed without MSI may not appear

## Integration

### Existing Detection Methods

WMI detection is integrated as a fallback method:

1. **Primary**: Registry scanning (fastest, most comprehensive)
2. **Secondary**: File system scanning (for portable apps)
3. **Tertiary**: WMI scanning (for MSI-installed software)

### Backward Compatibility

- **Default Enabled**: WMI detection is enabled by default
- **Optional**: Can be disabled without affecting other detection methods
- **Non-Breaking**: Existing API calls continue to work unchanged

## Future Enhancements

### Planned Improvements

- **Smart Caching**: Persistent cache across script executions
- **Parallel Queries**: Concurrent WMI queries for better performance
- **Enhanced Patterns**: Machine learning-based name extraction
- **Cross-Platform**: Similar functionality for macOS and Linux

### Configuration Options

- **Cache Duration**: Configurable cache expiration
- **Query Timeout**: Adjustable WMI query timeouts
- **Pattern Weights**: Scoring system for match quality
