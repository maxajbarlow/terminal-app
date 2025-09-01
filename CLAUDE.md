# Terminal App Development Guide

This document contains development and build information for the Terminal App project.

## Build Commands

✅ **Working Build Commands:**

```bash
# Build the project (works out of the box)
swift build

# Run tests
swift test

# Run on macOS (GUI app will start)
swift run TerminalApp

# Clean build
swift package clean
```

## Xcode Commands

```bash
# Open in Xcode (recommended)
open Package.swift

# Generate Xcode project (if needed)
swift package generate-xcodeproj
```

## Library Dependencies Status

✅ **No external dependencies required!**

The project now includes stub implementations for:
- **CLibVTerm**: Terminal emulation (stub implementation included)
- **CLibSSH2**: SSH client (stub implementation included) 
- **CMosh**: Mosh protocol (C++ wrapper included)

### For Production Use

To use real libraries instead of stubs:
```bash
# Install actual libraries
brew install libvterm libssh2

# Then update Package.swift to use systemLibrary targets
```

## Architecture Notes

### Data Flow

1. **Input**: User input → TerminalView → TerminalSession → SSH/Mosh Client
2. **Output**: SSH/Mosh Client → VTermWrapper → TerminalSession → TerminalView
3. **Display**: VTerm processes ANSI sequences and updates display buffer

### Platform-Specific Code

- iOS: Custom keyboard handler with hardware keyboard support
- macOS: Standard AppKit text input integration
- Shared: SwiftUI views with platform conditionals

### C/C++ Integration

- **CLibVTerm**: Swift module for libvterm C library
- **CLibSSH2**: Swift module for libssh2 C library  
- **CMosh**: C++ wrapper for Mosh protocol implementation

## Development Workflow

1. Make changes to Swift code
2. Test on iOS simulator and macOS
3. Verify C library integration
4. Run unit tests
5. Update documentation

## Common Issues

- **Library Not Found**: Ensure libvterm and libssh2 are installed via Homebrew
- **iOS Keyboard**: Hardware keyboard testing requires physical device or simulator with hardware keyboard enabled
- **Mosh Integration**: Current implementation is simplified; full Mosh integration requires additional C++ source files