# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a collection of small, focused command-line utilities:
- **jqc**: A C-based JSON processor similar to `jq`, with support for parsing JSON files with comments
- **mobile_device_probe**: A Swift-based macOS tool for detecting mobile devices (Android, iOS, HarmonyOS devices and iOS simulators)

## Build Commands

### jqc (C tool)
```bash
cd jqc
gcc jqc.c cJSON.c -o jqc
```

### mobile_device_probe (Swift tool, macOS only)
```bash
cd mobile_device_probe
swiftc mobile_device_probe.swift -o mobile_device_probe
```

**Note**: Both tools include pre-compiled Mach-O 64-bit executables for immediate use.

## Architecture

### jqc Structure
- **Main file**: `jqc/jqc.c` (276 lines)
- **Dependencies**: Uses the cJSON library (`cJSON.c`, `cJSON.h`)
- **Key features**:
  - Parses JSON with comments (supports `//` and `/* */`)
  - Colorized JSON output with syntax highlighting
  - Simple path-based filtering (e.g., `.foo.bar`)
  - Tab-to-space conversion for pretty printing
- **Command-line interface**: `jqc <filter> [json_file]` or `cat file.json | jqc <filter>`
- **Test data**: Located in `jqc/data/` directory

### mobile_device_probe Structure
- **Main file**: `mobile_device_probe/mobile_device_probe.swift` (315 lines)
- **Dependencies**: macOS frameworks (Foundation, IOKit, IOKit.usb)
- **Key features**:
  - Detects USB-connected mobile devices (Android, iOS, HarmonyOS)
  - Scans iOS simulators from `~/Library/Developer/CoreSimulator/Devices/`
  - Filters by device type via command-line arguments
  - Outputs JSON with consistent field ordering
- **Command-line interface**: `mobile_device_probe [android|ios|ios-sim|harmony|real|usb|all]`
- **Platform limitation**: macOS-specific (uses IOKit and CoreSimulator APIs)

## Development Notes

### Language Mix
- **C**: Used for jqc tool with cJSON library
- **Swift**: Used for mobile_device_probe tool (macOS only)

### Testing
- No formal test frameworks are configured
- jqc includes test JSON files in `jqc/data/` directory
- Testing is manual via command-line execution

### Agent Support
The repository includes `AGENTS.md` with specialized Gemini CLI agent configurations:
- `c_code_helper`: Expert in C programming and cJSON library
- `swift_mobile_helper`: Specialist in Swift and iOS/macOS development
- `json_data_expert`: Expert in JSON data manipulation for testing
- `cli_tool_dev`: General-purpose command-line tool developer

### Cross-Platform Considerations
- `jqc` is cross-platform (C code with standard libraries)
- `mobile_device_probe` is macOS-only due to IOKit and CoreSimulator dependencies

## Common Development Tasks

1. **Building both tools**:
   ```bash
   cd jqc && gcc jqc.c cJSON.c -o jqc
   cd ../mobile_device_probe && swiftc mobile_device_probe.swift -o mobile_device_probe
   ```

2. **Testing jqc**:
   ```bash
   cd jqc
   cat data/test_1.json | ./jqc '.'
   ./jqc '.' data/test_2.json
   ```

3. **Testing mobile_device_probe** (macOS only):
   ```bash
   cd mobile_device_probe
   ./mobile_device_probe --help
   ./mobile_device_probe android
   ./mobile_device_probe all
   ```

## Code Style

- **C code**: Follows standard C conventions with Chinese comments
- **Swift code**: Uses Foundation and IOKit frameworks with structured error handling
- Both tools include comprehensive command-line help (`--help` or `-h`)

## File Organization

```
tiny-tools/
├── AGENTS.md                    # Gemini CLI agents configuration
├── README.md                    # Main project documentation
├── jqc/                         # JSON query tool
│   ├── cJSON.c                  # cJSON library implementation
│   ├── cJSON.h                  # cJSON library header
│   ├── jqc                      # Compiled executable
│   ├── jqc.c                    # Main C source code
│   ├── README.md                # jqc documentation
│   └── data/                    # Test JSON files
└── mobile_device_probe/         # Mobile device detection tool
    ├── mobile_device_probe      # Compiled executable
    ├── mobile_device_probe.swift # Swift source code
    └── README.md                # Tool documentation
```