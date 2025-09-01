# Terminal App

A modern terminal emulator for macOS with GPU acceleration, SSH/Mosh support, and advanced shell features.

## Features

- **GPU Accelerated Rendering** - Smooth scrolling with Metal
- **SSH & Mosh Support** - Built-in clients with automatic key management
- **Advanced Shell** - Environment variables, redirection, tab completion
- **Customizable Interface** - Themes, fonts, and layout options
- **Command History** - Persistent history with search
- **Native macOS** - SwiftUI with system integration

## Installation

### Requirements
- macOS 13.0+ (Ventura or later)
- Xcode 14.0+ (for building from source)

### Building
```bash
git clone https://github.com/maxajbarlow/terminal-app.git
cd terminal-app
open TerminalApp.xcodeproj
```

Build and run in Xcode (⌘R)

## Usage

### Basic Terminal
- Launch the app to get a local shell
- All standard shell commands work
- Environment variables (`$HOME`, `$PATH`) are supported
- File redirection: `echo "text" > file.txt`

### SSH Connections
- SSH keys are automatically managed
- No hanging on authentication prompts
- GitHub integration: `ssh -T git@github.com`

### GPU Acceleration
- Enabled automatically on supported systems
- Toggle via right-click context menu
- Fallback to CPU rendering when needed

## Configuration

Access settings through the app preferences:
- **Performance**: GPU acceleration and frame rate
- **Appearance**: Colors, fonts, and themes
- **Terminal**: Shell behavior and history

## Contributing

1. Fork the repository
2. Create your feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file for details.