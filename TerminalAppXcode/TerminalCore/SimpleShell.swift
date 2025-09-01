import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// Helper for timeout functionality
struct TimeoutError: Error {
    let message: String = "Operation timed out"
}

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

public class SimpleShell: ObservableObject {
    public var onOutput: ((String) -> Void)?
    public var onLargeOutput: ((String) -> Void)? // For large output chunks
    public var onDirectoryChange: ((String) -> Void)?
    public var onCommandCompleted: (() -> Void)?
    public var onAppCommand: ((String, [String]) -> Bool)?
    public var onConfigurationRequested: (() -> Void)?
    private var currentWorkingDirectory: String
    private var isSSHConnected: Bool = false
    private var currentSSHConnection: ConnectionInfo?
    #if canImport(AppKit)
    private var currentTask: Process?
    #endif
    
    // Buffer for accumulating output
    private var outputBuffer = ""
    private let outputBufferLock = NSLock()
    private let bufferFlushThreshold = 4096 // 4KB threshold
    
    public init() {
        #if canImport(AppKit)
        currentWorkingDirectory = FileManager.default.currentDirectoryPath
        #else
        // On iOS, use the app's documents directory as the default
        currentWorkingDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        #endif
    }
    
    // MARK: - Output Buffer Management
    
    private func addToOutputBuffer(_ output: String) {
        outputBufferLock.lock()
        defer { outputBufferLock.unlock() }
        
        outputBuffer += output
        
        // Flush buffer if it exceeds threshold
        if outputBuffer.utf8.count >= bufferFlushThreshold {
            flushOutputBuffer()
        }
    }
    
    private func flushOutputBuffer() {
        guard !outputBuffer.isEmpty else { return }
        
        let bufferedOutput = outputBuffer
        outputBuffer = ""
        
        // Use large output handler if available, otherwise fall back to regular output
        if let onLargeOutput = onLargeOutput {
            onLargeOutput(bufferedOutput)
        } else {
            onOutput?(bufferedOutput)
        }
    }
    
    private func finalizeOutput() {
        outputBufferLock.lock()
        defer { outputBufferLock.unlock() }
        flushOutputBuffer()
    }
    
    public func executeCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        
        // Skip empty commands
        if trimmedCommand.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        // Handle app commands (multiple access methods)
        if trimmedCommand.hasPrefix("..") {
            handleAppCommand(String(trimmedCommand.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            return
        }
        
        // Handle app commands with vim-style colon prefix
        if trimmedCommand.hasPrefix(":") {
            handleAppCommand(String(trimmedCommand.dropFirst(1)).trimmingCharacters(in: .whitespaces))
            return
        }
        
        // Handle custom commands first
        if handleCustomCommand(trimmedCommand) {
            return
        }
        
        // Handle cd command specially to maintain directory state
        if trimmedCommand.hasPrefix("cd ") {
            handleCdCommand(String(trimmedCommand.dropFirst(3)).trimmingCharacters(in: .whitespaces))
            return
        }
        
        // Handle cd with no arguments (cd to home)
        if trimmedCommand == "cd" {
            handleCdCommand("")
            return
        }
        
        // Handle SSH commands - but only for connections, not other ssh-* tools
        if trimmedCommand.hasPrefix("ssh ") && !trimmedCommand.hasPrefix("ssh-") {
            handleSSHCommand(trimmedCommand)
            return
        }
        
        // Handle Mosh commands
        if trimmedCommand.hasPrefix("mosh ") {
            handleMoshCommand(trimmedCommand)
            return
        }
        
        // If SSH is connected, forward commands to SSH session
        if isSSHConnected {
            #if canImport(AppKit)
            // Handle exit command to close SSH connection
            if trimmedCommand == "exit" {
                if let task = currentTask, task.isRunning {
                    onOutput?("Closing SSH connection...\n")
                    task.terminate()
                    // Termination handler will clean up
                } else {
                    onOutput?("No active SSH connection to close.\n")
                    isSSHConnected = false
                    currentSSHConnection = nil
                }
                DispatchQueue.main.async { [weak self] in
                    self?.onCommandCompleted?()
                }
                return
            }
            
            // Forward command to SSH process
            if let task = currentTask, task.isRunning {
                if let inputHandle = task.standardInput as? Pipe {
                    let commandData = Data((trimmedCommand + "\n").utf8)
                    inputHandle.fileHandleForWriting.write(commandData)
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
            #endif
        }
        
        #if canImport(AppKit)
        // macOS: Execute commands using Process
        
        // Modify potentially infinite commands to be finite
        var modifiedCommand = command
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("ping ") && !trimmed.contains("-c") && !trimmed.contains(" -") {
            // Only auto-limit simple ping commands without any flags
            modifiedCommand = command + " -c 4"  // Limit ping to 4 packets
            onOutput?("[Modified command to limit output: \(modifiedCommand)]\n")
        }
        
        let task = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.standardInput = inputPipe
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Execute command directly without stdbuf (not available on macOS)
        task.arguments = ["-c", "cd '\(currentWorkingDirectory)' && \(modifiedCommand)"]
        
        // Handle ssh-keygen specially to prevent hanging
        if trimmed.hasPrefix("ssh-keygen") {
            handleSSHKeygenCommand(modifiedCommand)
            return
        }
        
        // Handle ssh-add specially to manage SSH agent
        if trimmed.hasPrefix("ssh-add") {
            handleSSHAddCommand(modifiedCommand)
            return
        }
        
        // Store the current task so it can be interrupted
        currentTask = task
        
        do {
            try task.run()
            
            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading
            
            // Set up notification for output data availability with buffering
            outputHandle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        self?.addToOutputBuffer(output)
                    }
                } else {
                    // End of file - flush remaining buffer
                    self?.finalizeOutput()
                    handle.readabilityHandler = nil
                }
            }
            
            // Set up notification for error data availability with buffering
            errorHandle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        self?.addToOutputBuffer(output)
                    }
                } else {
                    // End of file
                    handle.readabilityHandler = nil
                }
            }
            
            task.waitUntilExit()
            
            // Clean up the readability handlers
            outputHandle.readabilityHandler = nil
            errorHandle.readabilityHandler = nil
            
        } catch {
            onOutput?("Error executing command: \(error)\n")
        }
        
        // Clear the current task reference
        currentTask = nil
        #else
        // iOS: Can't execute external processes, so provide helpful alternatives
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        let firstWord = trimmed.components(separatedBy: " ").first ?? ""
        
        // Check if it's a common Unix command and suggest alternatives
        switch firstWord.lowercased() {
        case "ls", "dir":
            onOutput?("iOS limitation: Cannot execute '\(firstWord)' directly.\nUse the Files app or SSH to a remote system.\n")
        case "ping", "traceroute", "nslookup", "dig":
            onOutput?("iOS limitation: Network diagnostic tools require SSH to a remote system.\nTry: ssh user@host\n")
        case "git", "npm", "python", "node", "gcc", "make":
            onOutput?("iOS limitation: Development tools require SSH to a remote system.\nTry: ssh user@host\n")
        case "curl", "wget":
            onOutput?("iOS limitation: '\(firstWord)' requires SSH to a remote system.\nAlternatively, use the built-in web browser.\n")
        default:
            onOutput?("iOS limitation: '\(command)' cannot be executed locally.\n\nAvailable options:\n• Use app commands: split, config, theme, close, next, prev\n• Use 'ssh user@host' to connect to a remote system\n• Use 'help' to see all available built-in commands\n")
        }
        #endif
        
        // Notify that command completed on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    private func handleAppCommand(_ command: String) {
        let parts = command.components(separatedBy: " ")
        guard let cmd = parts.first?.lowercased() else {
            showAppCommandHelp()
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        let args = Array(parts.dropFirst())
        
        // Try to delegate to the app command handler first (for split management)
        if let onAppCommand = onAppCommand, onAppCommand(cmd, args) {
            // Command was handled by the app (e.g., split management)
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        // Handle local app commands
        switch cmd {
        case "help", "":
            showAppCommandHelp()
        case "config", "settings":
            showConfig()
        case "theme":
            handleThemeCommand(args)
        case "about":
            showAbout()
        case "version":
            showVersion()
        case "clear":
            onOutput?("")  // Send clear signal
        default:
            onOutput?("Unknown command: \(cmd)\nType 'help' for available commands.\n")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    private func showAppCommandHelp() {
        onOutput?("""
App Management Commands:

💡 NEW: Multiple command formats supported!

Direct Commands (recommended):
  split h/v       - Split horizontally/vertically
  close           - Close current pane
  next/prev       - Switch to next/previous pane
  pane [1-9]      - Switch to specific pane
  config          - Open settings
  theme           - Theme management
  about/version   - App information

Vim-style Commands:
  :split h        - Split horizontally
  :close          - Close pane
  :config         - Open settings

Classic Commands (still supported):
  ..split h       - Split horizontally
  ..close         - Close pane
  ..config        - Open settings

Split Management:
  split h         - Create horizontal split
  split v         - Create vertical split
  split toggle    - Toggle split direction
  close           - Close current pane
  next            - Switch to next pane
  prev            - Switch to previous pane
  pane [1-9]      - Switch to pane number

Theme Management:
  theme list      - Show available themes
  theme set <name> - Change theme
  theme font      - Font settings
  theme reset     - Reset to defaults

Examples:
  split h         - Create horizontal split
  pane 2          - Switch to pane 2
  config          - Open settings
  :split v        - Create vertical split (vim-style)
  theme set dracula - Switch to Dracula theme

Note: Tab management is handled through UI tabs.

""")
    }
    
    private func handleCustomCommand(_ command: String) -> Bool {
        let parts = command.components(separatedBy: " ")
        guard let cmd = parts.first?.lowercased() else { return false }
        
        switch cmd {
        case "help":
            if parts.count > 1 {
                // Show help for specific command
                let commandName = parts[1]
                showSpecificHelp(for: commandName)
            } else {
                // Show general help
                showHelp()
            }
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        // Direct app commands (no prefix needed)
        case "split":
            if parts.count > 1 {
                handleAppCommand("split " + parts[1...].joined(separator: " "))
            } else {
                handleAppCommand("split")
            }
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        case "config", "settings":
            handleAppCommand("config")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        case "theme":
            if parts.count > 1 {
                handleAppCommand("theme " + parts[1...].joined(separator: " "))
            } else {
                handleAppCommand("theme")
            }
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        case "close":
            handleAppCommand("close")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        case "next":
            handleAppCommand("next")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        case "prev", "previous":
            handleAppCommand("prev")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        case "pane":
            if parts.count > 1 {
                handleAppCommand("pane " + parts[1])
            } else {
                onOutput?("Usage: pane [1-9]\nExample: pane 2\n")
                DispatchQueue.main.async { [weak self] in
                    self?.onCommandCompleted?()
                }
            }
            return true
            
        case "about":
            handleAppCommand("about")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        case "version":
            handleAppCommand("version")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        case "ls":
            handleLsCommand(Array(parts.dropFirst()))
            return true
            
        case "pwd":
            handlePwdCommand()
            return true
            
        case "cat":
            if parts.count > 1 {
                handleCatCommand(String(parts.dropFirst().joined(separator: " ")))
            } else {
                onOutput?("cat: missing file name\n")
                DispatchQueue.main.async { [weak self] in
                    self?.onCommandCompleted?()
                }
            }
            return true
            
        case "echo":
            handleEchoCommand(Array(parts.dropFirst()))
            return true
            
        case "mkdir":
            if parts.count > 1 {
                handleMkdirCommand(Array(parts.dropFirst()))
            } else {
                onOutput?("mkdir: missing directory name\n")
                DispatchQueue.main.async { [weak self] in
                    self?.onCommandCompleted?()
                }
            }
            return true
            
        case "touch":
            if parts.count > 1 {
                handleTouchCommand(Array(parts.dropFirst()))
            } else {
                onOutput?("touch: missing file name\n")
                DispatchQueue.main.async { [weak self] in
                    self?.onCommandCompleted?()
                }
            }
            return true
            
        case "rm":
            if parts.count > 1 {
                handleRmCommand(Array(parts.dropFirst()))
            } else {
                onOutput?("rm: missing file name\n")
                DispatchQueue.main.async { [weak self] in
                    self?.onCommandCompleted?()
                }
            }
            return true
            
        // Removed duplicate cases - already handled above
            
        case "connect":
            showConnect()
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return true
            
        default:
            return false
        }
    }
    
    private func showSpecificHelp(for commandName: String) {
        // Simple built-in command help
        
        let helpText: String
        switch commandName.lowercased() {
        case "reference":
            helpText = """
            Complete Command Reference:
            See 'help' for full list of available commands.
            """
        case "ssh":
            helpText = """
            SSH - Secure Shell Connection
            Usage: ssh [user@]hostname [options]
            Options:
              -p port    Specify port (default: 22)
            Example: ssh user@example.com -p 2222
            """
        case "ls":
            helpText = """
            LS - List Directory Contents  
            Usage: ls [options] [path]
            Options:
              -l    Long format
              -a    Show hidden files
            """
        case "cd":
            helpText = """
            CD - Change Directory
            Usage: cd [path]
            Examples:
              cd ~       Go to home directory
              cd ..      Go up one level
            """
        default:
            helpText = "No help available for '\(commandName)'.\nType 'help' to see all available commands."
        }
        onOutput?(helpText + "\n")
    }
    
    private func showHelp() {
        onOutput?("""
Terminal App - Available Commands:

Quick Start:
  help [command]  - Get help for specific command (e.g., 'help git')
  ssh user@host   - Connect to SSH server
  config          - Open settings
  split h         - Create horizontal split

Basic Commands (iOS/macOS):
  ls, pwd, cd     - File navigation
  echo, cat       - Text display
  clear           - Clear terminal
  history         - Show command history

Connection Commands:
  ssh user@host   - SSH connection (creates new tab)

App Management Commands:
  split h/v       - Create horizontal/vertical splits
  close           - Close current pane
  next, prev      - Navigate between panes
  pane [1-9]      - Switch to specific pane
  config          - Open settings
  theme           - Theme management
  about, version  - App information

Alternative Command Formats:
  Direct:    split h, config, theme set monokai
  Vim-style: :split h, :config, :theme set monokai  
  Classic:   ..split h, ..config, ..theme set monokai

Examples:
  help ls         - Show 'ls' command help
  ssh user@server - Connect to SSH server
  split h         - Split horizontally
  theme list      - Show available themes
  :config         - Open settings (vim-style)

For full command reference: help reference

""")
    }
    
    private func showConfig() {
        // Use direct AppState approach
        onOutput?("Opening configuration...\n")
        AppState.shared.openConfiguration()
    }
    
    private func showConnect() {
        onOutput?("""
Connection Menu:

Current Mode: Local Terminal

Available Connection Types:
  1. Local Shell (current)
  2. SSH Connection (use 'ssh user@host')
  3. Mosh Connection (coming soon)

Note: Remote connections not yet implemented.
Type 'help' for available commands.

""")
    }
    
    private func showAbout() {
        #if canImport(AppKit)
        let platform = "macOS"
        let version = "13.0+"
        #else
        let platform = "iOS/iPadOS"
        let version = "16.0+"
        #endif
        
        onOutput?("""
Terminal App
Version 1.0.0

A native \(platform) terminal emulator built with Swift and SwiftUI.

Features:
  • SSH connections
  • Theme customization
  • Split pane support
  • Command history
  • Real-time output display
  • Custom command support
  • Native \(platform) integration

Created with Swift
Built for \(platform) \(version)

""")
    }
    
    private func showVersion() {
        onOutput?("""
Terminal App v1.0.0
Build Date: August 2025
Swift Version: 5.9+
Platform: macOS 13.0+

""")
    }
    
    private func handleThemeCommand(_ args: [String]) {
        guard !args.isEmpty else {
            showThemeHelp()
            return
        }
        
        let command = args[0].lowercased()
        
        switch command {
        case "list", "ls":
            showAvailableThemes()
        case "current", "show":
            showCurrentTheme()
        case "set":
            if args.count > 1 {
                setTheme(args[1])
            } else {
                onOutput?("Usage: ..theme set <theme_name>\n")
                showAvailableThemes()
            }
        case "font":
            handleFontCommand(Array(args.dropFirst()))
        case "opacity":
            if args.count > 1, let opacity = Double(args[1]) {
                setOpacity(opacity)
            } else {
                onOutput?("Usage: ..theme opacity <0.5-1.0>\nCurrent opacity: \(TerminalTheme.shared.opacity)\n")
            }
        case "reset":
            resetTheme()
        default:
            showThemeHelp()
        }
    }
    
    private func showThemeHelp() {
        onOutput?("""
Theme Commands:
  ..theme list              - Show available color schemes
  ..theme current           - Show current theme settings
  ..theme set <name>        - Set color scheme (e.g., "Solarized Dark")
  ..theme font <family> <size>  - Set font (e.g., "Menlo" 12)
  ..theme opacity <value>   - Set opacity (0.5-1.0)
  ..theme reset             - Reset to default theme

Examples:
  ..theme set "Monokai"
  ..theme font "SF Mono" 14
  ..theme opacity 0.9

""")
    }
    
    private func showAvailableThemes() {
        onOutput?("Available Color Schemes:\n")
        for (index, scheme) in TerminalColorScheme.allSchemes.enumerated() {
            let current = scheme.name == TerminalTheme.shared.colorScheme.name ? " (current)" : ""
            onOutput?("  \(index + 1). \(scheme.name)\(current)\n")
        }
        onOutput?("\n")
    }
    
    private func showCurrentTheme() {
        let theme = TerminalTheme.shared
        onOutput?("""
Current Theme Settings:
  Color Scheme: \(theme.colorScheme.name)
  Font Family: \(theme.font.family)
  Font Size: \(Int(theme.font.size))pt
  Font Weight: \(theme.font.weight.stringValue)
  Opacity: \(String(format: "%.1f", theme.opacity * 100))%
  Blur Effect: \(theme.blurEffect ? "On" : "Off")
  Cursor Blink Rate: \(String(format: "%.1f", theme.cursorBlinkRate))s
  Line Spacing: \(String(format: "%.1f", theme.lineSpacing))

""")
    }
    
    private func setTheme(_ themeName: String) {
        let normalizedName = themeName.replacingOccurrences(of: "\"", with: "")
        
        if let scheme = TerminalColorScheme.allSchemes.first(where: { $0.name.lowercased() == normalizedName.lowercased() }) {
            TerminalTheme.shared.updateColorScheme(scheme)
            onOutput?("Theme changed to '\(scheme.name)'\n")
        } else {
            onOutput?("Theme '\(normalizedName)' not found.\n")
            showAvailableThemes()
        }
    }
    
    private func handleFontCommand(_ args: [String]) {
        guard args.count >= 2 else {
            onOutput?("Usage: ..theme font <family> <size>\nExample: ..theme font \"Menlo\" 12\n")
            showAvailableFonts()
            return
        }
        
        let fontFamily = args[0].replacingOccurrences(of: "\"", with: "")
        guard let fontSizeValue = Double(args[1]) else {
            onOutput?("Invalid font size: \(args[1])\n")
            return
        }
        let fontSize = CGFloat(fontSizeValue)
        
        TerminalTheme.shared.updateFont(family: fontFamily, size: fontSize)
        onOutput?("Font changed to '\(fontFamily)' \(Int(fontSize))pt\n")
    }
    
    private func showAvailableFonts() {
        onOutput?("Available Fonts:\n")
        for font in TerminalTheme.availableFonts {
            let current = font.family == TerminalTheme.shared.font.family ? " (current)" : ""
            onOutput?("  \(font.family)\(current)\n")
        }
        onOutput?("\nAvailable Sizes: \(TerminalTheme.fontSizes.map(String.init).joined(separator: ", "))\n")
    }
    
    private func setOpacity(_ opacity: Double) {
        let clampedOpacity = max(0.5, min(1.0, opacity))
        TerminalTheme.shared.updateOpacity(clampedOpacity)
        onOutput?("Opacity set to \(String(format: "%.1f", clampedOpacity * 100))%\n")
    }
    
    private func resetTheme() {
        TerminalTheme.shared.updateFont(family: TerminalFont.defaultMonospace.family, size: TerminalFont.defaultMonospace.size, weight: TerminalFont.defaultMonospace.weight)
        TerminalTheme.shared.updateColorScheme(.defaultDark)
        TerminalTheme.shared.updateOpacity(0.95)
        TerminalTheme.shared.updateBlurEffect(true)
        TerminalTheme.shared.updateCursorBlinkRate(0.5)
        TerminalTheme.shared.updateLineSpacing(1.2)
        onOutput?("Theme reset to defaults\n")
    }
    
    private func handleSSHCommand(_ command: String) {
        // Parse SSH command: ssh [options] user@host [command]
        let parts = command.components(separatedBy: " ")
        guard parts.count >= 2 else {
            onOutput?("Usage: ssh [options] user@host\n")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        // Find the user@host part
        var userHost: String?
        var port: Int = 22
        
        for i in 1..<parts.count {
            let part = parts[i]
            
            // Check for port option
            if part == "-p" && i + 1 < parts.count {
                if let p = Int(parts[i + 1]) {
                    port = p
                }
                continue
            }
            
            // Look for user@host pattern
            if part.contains("@") && userHost == nil {
                userHost = part
                break
            }
        }
        
        guard let userHostStr = userHost else {
            onOutput?("ssh: Invalid format. Use: ssh user@host\n")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        // Parse user@host
        let userHostParts = userHostStr.components(separatedBy: "@")
        guard userHostParts.count == 2 else {
            onOutput?("ssh: Invalid format. Use: ssh user@host\n")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        let username = userHostParts[0]
        let host = userHostParts[1]
        
        // Output connection message
        onOutput?("Connecting to \(host) as \(username) on port \(port)...\n")
        
        // Create ConnectionInfo for inline SSH connection
        let connectionInfo = ConnectionInfo(
            type: .ssh,
            host: host,
            port: port,
            username: username,
            password: nil // Will prompt for password if needed
        )
        
        // Start production SSH connection using system ssh client
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.onOutput?("Starting SSH connection to \(username)@\(host):\(port)...\n")
            
            #if canImport(AppKit)
            // macOS: Use real SSH client via Process
            let task = Process()
            task.launchPath = "/usr/bin/ssh"
            
            var args = ["-p", "\(port)", "\(username)@\(host)"]
            
            // Add SSH options for better compatibility
            args += [
                "-o", "StrictHostKeyChecking=ask",  // Ask user about unknown hosts  
                "-o", "ConnectTimeout=30",
                "-o", "LogLevel=ERROR"  // Reduce verbose output
            ]
            
            // Only use BatchMode for non-interactive git services
            if host.contains("github.com") || host.contains("gitlab.com") || host.contains("bitbucket.org") {
                args += ["-o", "BatchMode=yes"]  // Don't prompt for passwords on git services
            }
            
            // Only add -T for non-interactive services like git@github.com
            if host.contains("github.com") || host.contains("gitlab.com") || host.contains("bitbucket.org") {
                args.append("-T")  // Disable pseudo-terminal allocation for Git services
            } else {
                args.append("-t")  // Force pseudo-terminal allocation for interactive sessions
            }
            
            task.arguments = args
            task.currentDirectoryPath = self.currentWorkingDirectory
            
            let pipe = Pipe()
            let inputPipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            task.standardInput = inputPipe
            
            // Set up output handling
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self?.onOutput?(output)
                        }
                    }
                }
            }
            
            // Set up termination handling
            task.terminationHandler = { [weak self] task in
                DispatchQueue.main.async {
                    self?.onOutput?("SSH connection closed (exit code: \(task.terminationStatus))\n")
                    self?.isSSHConnected = false
                    self?.currentSSHConnection = nil
                    self?.currentTask = nil
                    self?.onCommandCompleted?()
                }
            }
            
            do {
                try task.run()
                self.currentTask = task
                self.isSSHConnected = true
                self.currentSSHConnection = connectionInfo
                
                // Don't show "connection established" immediately - let SSH output speak for itself
                self.onCommandCompleted?()
            } catch {
                self.onOutput?("❌ Failed to start SSH client: \(error.localizedDescription)\n")
                self.onCommandCompleted?()
            }
            
            #else
            // iOS: SSH not available - show error
            self.onOutput?("❌ SSH is not available on iOS\n")
            self.onOutput?("SSH requires access to system utilities not available in sandboxed iOS apps.\n")
            self.onCommandCompleted?()
            #endif
        }
    }
    
    private func handleSSHKeygenCommand(_ command: String) {
        // Parse ssh-keygen command and provide a non-interactive version
        onOutput?("Generating SSH key pair...\n")
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        
        // Parse the original command to extract arguments
        let parts = Array(command.components(separatedBy: " ").dropFirst()) // Remove "ssh-keygen"
        
        var finalArgs: [String] = []
        var hasFile = false
        var hasPassphrase = false
        var i = 0
        
        // Parse existing arguments
        while i < parts.count {
            let part = parts[i]
            finalArgs.append(part)
            
            if part == "-f" && i + 1 < parts.count {
                hasFile = true
                i += 1
                finalArgs.append(parts[i]) // Add the file path
            } else if part == "-N" && i + 1 < parts.count {
                hasPassphrase = true
                i += 1  
                finalArgs.append(parts[i]) // Add the passphrase
            }
            i += 1
        }
        
        // Add default file if not specified
        if !hasFile {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
            finalArgs += ["-f", "\(homeDir)/.ssh/id_ed25519"]
            onOutput?("Using default key file: ~/.ssh/id_ed25519\n")
        }
        
        // Add empty passphrase if not specified  
        if !hasPassphrase {
            finalArgs.append("-N")
            finalArgs.append("")  // Empty string as separate argument
            onOutput?("Using empty passphrase for non-interactive generation\n")
        }
        
        // Check if key file already exists and remove it to avoid prompts
        let keyPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.ssh/id_ed25519"
        let publicKeyPath = "\(keyPath).pub"
        
        if FileManager.default.fileExists(atPath: keyPath) {
            onOutput?("⚠️  SSH key already exists at ~/.ssh/id_ed25519\n")
            onOutput?("Removing existing key files to avoid prompts...\n")
            
            // Remove existing private key
            do {
                try FileManager.default.removeItem(atPath: keyPath)
                onOutput?("Removed existing private key\n")
            } catch {
                onOutput?("Warning: Could not remove existing private key: \(error.localizedDescription)\n")
            }
            
            // Remove existing public key if it exists
            if FileManager.default.fileExists(atPath: publicKeyPath) {
                do {
                    try FileManager.default.removeItem(atPath: publicKeyPath)
                    onOutput?("Removed existing public key\n")
                } catch {
                    onOutput?("Warning: Could not remove existing public key: \(error.localizedDescription)\n")
                }
            }
        }
        
        // Add quiet mode to reduce output
        if !finalArgs.contains("-q") {
            finalArgs.append("-q")
        }
        
        onOutput?("ssh-keygen arguments: \(finalArgs.joined(separator: " "))\n")
        
        task.arguments = finalArgs
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.standardInput = inputPipe
        
        // Don't send any automatic input - let user handle prompts manually
        inputPipe.fileHandleForWriting.closeFile()
        
        // Set up output handling
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.onOutput?(output)
                    }
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.onOutput?(output)
                    }
                }
            }
        }
        
        task.terminationHandler = { [weak self] task in
            DispatchQueue.main.async {
                if task.terminationStatus == 0 {
                    // Verify both key files were created
                    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                    let privateKeyPath = "\(homeDir)/.ssh/id_ed25519"
                    let publicKeyPath = "\(homeDir)/.ssh/id_ed25519.pub"
                    
                    let privateKeyExists = FileManager.default.fileExists(atPath: privateKeyPath)
                    let publicKeyExists = FileManager.default.fileExists(atPath: publicKeyPath)
                    
                    if privateKeyExists && publicKeyExists {
                        self?.onOutput?("✅ SSH key pair generated successfully!\n")
                        self?.onOutput?("📁 Private key: ~/.ssh/id_ed25519\n")
                        self?.onOutput?("📁 Public key: ~/.ssh/id_ed25519.pub\n")
                        self?.onOutput?("\nNext steps:\n")
                        self?.onOutput?("1. Add to SSH agent: ssh-add ~/.ssh/id_ed25519\n")
                        self?.onOutput?("2. Copy public key: cat ~/.ssh/id_ed25519.pub\n")
                        self?.onOutput?("3. Add to GitHub Settings → SSH and GPG keys\n")
                    } else {
                        self?.onOutput?("⚠️  SSH key generation completed but files missing:\n")
                        self?.onOutput?("   Private key exists: \(privateKeyExists ? "✅" : "❌")\n")
                        self?.onOutput?("   Public key exists: \(publicKeyExists ? "✅" : "❌")\n")
                        if !publicKeyExists && privateKeyExists {
                            self?.onOutput?("💡 Try regenerating public key from private key:\n")
                            self?.onOutput?("   ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub\n")
                        }
                    }
                } else {
                    self?.onOutput?("❌ SSH key generation failed (exit code: \(task.terminationStatus))\n")
                }
                self?.currentTask = nil
                self?.onCommandCompleted?()
            }
        }
        
        do {
            try task.run()
            currentTask = task
        } catch {
            onOutput?("❌ Failed to run ssh-keygen: \(error.localizedDescription)\n")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
        }
    }
    
    private func handleSSHAddCommand(_ command: String) {
        // Check if SSH agent is running, start it if needed
        onOutput?("Checking SSH agent status...\n")
        
        // Always try to start SSH agent first to ensure it's running
        onOutput?("Starting SSH agent...\n")
        startSSHAgent { [weak self] success in
            if success {
                self?.executeSSHAdd(command)
            } else {
                self?.onOutput?("❌ Failed to start SSH agent\n")
                self?.onCommandCompleted?()
            }
        }
    }
    
    private func startSSHAgent(completion: @escaping (Bool) -> Void) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-agent")
        task.arguments = ["-s"]  // Shell format output
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        var outputData = Data()
        var errorData = Data()
        
        // Collect all output data
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                outputData.append(data)
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty {
                errorData.append(data)
            }
        }
        
        task.terminationHandler = { [weak self] task in
            // Stop reading handlers
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            DispatchQueue.main.async {
                if task.terminationStatus == 0 {
                    if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                        self?.onOutput?("SSH agent output: \(output)\n")
                        self?.parseSSHAgentOutput(output)
                        self?.onOutput?("✅ SSH agent started successfully\n")
                        completion(true)
                    } else {
                        self?.onOutput?("❌ SSH agent produced no output\n")
                        completion(false)
                    }
                } else {
                    if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
                        self?.onOutput?("SSH agent error: \(error)\n")
                    }
                    self?.onOutput?("❌ SSH agent failed with exit code: \(task.terminationStatus)\n")
                    completion(false)
                }
            }
        }
        
        do {
            try task.run()
            onOutput?("SSH agent process started...\n")
        } catch {
            onOutput?("Failed to start SSH agent process: \(error.localizedDescription)\n")
            completion(false)
        }
    }
    
    private func parseSSHAgentOutput(_ output: String) {
        // Parse ssh-agent output like:
        // SSH_AUTH_SOCK=/tmp/ssh-XXXX/agent.12345; export SSH_AUTH_SOCK;
        // SSH_AGENT_PID=12345; export SSH_AGENT_PID;
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("SSH_AUTH_SOCK=") {
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2 {
                    let sockPath = parts[1].components(separatedBy: ";")[0]
                    setenv("SSH_AUTH_SOCK", sockPath, 1)
                    onOutput?("Set SSH_AUTH_SOCK=\(sockPath)\n")
                }
            }
            if line.contains("SSH_AGENT_PID=") {
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2 {
                    let pid = parts[1].components(separatedBy: ";")[0]
                    setenv("SSH_AGENT_PID", pid, 1)
                    onOutput?("Set SSH_AGENT_PID=\(pid)\n")
                }
            }
        }
    }
    
    private func executeSSHAdd(_ command: String) {
        // Parse arguments from command
        let parts = command.components(separatedBy: " ").dropFirst() // Remove "ssh-add"
        let args = Array(parts)
        
        // Check if this is just listing keys or other operations
        let isListingCommand = args.contains("-l") || args.contains("-L")
        var keysToAdd: [String] = []
        
        if !isListingCommand {
            // If no arguments provided, try to add default keys
            
            if args.isEmpty {
                // No arguments - try default key locations
                let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
                let defaultKeys = [
                    "\(homeDir)/.ssh/id_ed25519",
                    "\(homeDir)/.ssh/id_rsa",
                    "\(homeDir)/.ssh/id_ecdsa",
                    "\(homeDir)/.ssh/id_dsa"
                ]
                
                for keyPath in defaultKeys {
                    if FileManager.default.fileExists(atPath: keyPath) {
                        keysToAdd.append(keyPath)
                        onOutput?("Found SSH key: \(keyPath)\n")
                        break // Only add the first found key by default
                    }
                }
                
                if keysToAdd.isEmpty {
                    onOutput?("❌ No SSH keys found in default locations\n")
                    onOutput?("💡 Generate an SSH key first:\n")
                    onOutput?("   ssh-keygen -t ed25519 -C \"your.email@example.com\"\n")
                    onOutput?("   Then run: ssh-add\n")
                    DispatchQueue.main.async { [weak self] in
                        self?.onCommandCompleted?()
                    }
                    return
                }
            } else {
                // Check specific key files mentioned in arguments
                for arg in args {
                    if !arg.hasPrefix("-") {
                        let expandedPath = NSString(string: arg).expandingTildeInPath
                        
                        if !FileManager.default.fileExists(atPath: expandedPath) {
                            onOutput?("❌ SSH key file not found: \(expandedPath)\n")
                            onOutput?("💡 Generate an SSH key first:\n")
                            onOutput?("   ssh-keygen -t ed25519 -C \"your.email@example.com\"\n")
                            onOutput?("   Then run: ssh-add \(arg)\n")
                            DispatchQueue.main.async { [weak self] in
                                self?.onCommandCompleted?()
                            }
                            return
                        } else {
                            onOutput?("Found SSH key file: \(expandedPath)\n")
                            keysToAdd.append(expandedPath)
                        }
                    }
                }
            }
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-add")
        
        // Prepare arguments for ssh-add
        var finalArgs: [String] = []
        
        if isListingCommand {
            // For listing commands, pass through all arguments
            finalArgs = args
        } else {
            // For adding keys, use the processed key paths or original flags
            for arg in args {
                if arg.hasPrefix("-") {
                    finalArgs.append(arg)
                } else {
                    // Expand file paths
                    let expandedArg = NSString(string: arg).expandingTildeInPath
                    finalArgs.append(expandedArg)
                    onOutput?("Expanded \(arg) → \(expandedArg)\n")
                }
            }
            
            // If no arguments and we found default keys, add them
            if args.isEmpty && !keysToAdd.isEmpty {
                finalArgs.append(contentsOf: keysToAdd)
                onOutput?("Adding default key: \(keysToAdd.first!)\n")
            }
        }
        
        task.arguments = finalArgs
        onOutput?("ssh-add command: ssh-add \(finalArgs.joined(separator: " "))\n")
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        task.standardInput = nil
        
        // Set up output handling
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.onOutput?(output)
                    }
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.onOutput?(output)
                    }
                }
            }
        }
        
        task.terminationHandler = { [weak self] task in
            DispatchQueue.main.async {
                if task.terminationStatus == 0 {
                    self?.onOutput?("✅ SSH key added to agent successfully!\n")
                    self?.onOutput?("You can now use SSH without entering your passphrase\n")
                } else {
                    self?.onOutput?("❌ Failed to add SSH key to agent (exit code: \(task.terminationStatus))\n")
                }
                self?.currentTask = nil
                self?.onCommandCompleted?()
            }
        }
        
        do {
            try task.run()
            currentTask = task
        } catch {
            onOutput?("❌ Failed to run ssh-add: \(error.localizedDescription)\n")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
        }
    }
    
    // MARK: - Production Mosh Command Handler
    
    private func handleMoshCommand(_ command: String) {
        // Parse Mosh command: mosh [options] user@host [command]
        let parts = command.components(separatedBy: " ")
        guard parts.count >= 2 else {
            onOutput?("Usage: mosh [options] user@host\n")
            onOutput?("Examples:\n")
            onOutput?("  mosh user@example.com\n")
            onOutput?("  mosh -p 60001 user@example.com\n")
            onOutput?("  mosh --ssh='ssh -p 2222' user@example.com\n")
            onOutput?("Note: Mosh requires mosh-server to be installed on the remote host\n")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        // Extract user@host and determine if it's valid
        var userHost: String?
        for part in parts.dropFirst() {
            if part.contains("@") && !part.hasPrefix("-") {
                userHost = part
                break
            }
        }
        
        guard let userHostStr = userHost else {
            onOutput?("mosh: No user@host specified\n")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        let userHostParts = userHostStr.components(separatedBy: "@")
        guard userHostParts.count == 2 else {
            onOutput?("mosh: Invalid format. Use: mosh user@host\n")
            DispatchQueue.main.async { [weak self] in
                self?.onCommandCompleted?()
            }
            return
        }
        
        let username = userHostParts[0]
        let host = userHostParts[1]
        
        onOutput?("Starting Mosh connection to \(username)@\(host)...\n")
        
        // Check if SSH agent is available for key-based authentication
        if ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] == nil {
            onOutput?("⚠️  SSH agent not detected. You may need to enter a password.\n")
            onOutput?("💡 Run 'ssh-add' first for key-based authentication.\n")
        }
        
        #if canImport(AppKit)
        // macOS: Use real Mosh client via Process
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            
            // Try common mosh locations
            let moshPaths = [
                "/opt/homebrew/bin/mosh",  // Homebrew on Apple Silicon
                "/usr/local/bin/mosh",     // Homebrew on Intel
                "/usr/bin/mosh",           // System install
                "mosh"                     // PATH lookup
            ]
            
            var moshPath: String?
            for path in moshPaths {
                if path == "mosh" || FileManager.default.fileExists(atPath: path) {
                    moshPath = path
                    break
                }
            }
            
            guard let executablePath = moshPath else {
                self.onOutput?("❌ Mosh not found. Install with: brew install mosh\n")
                self.onCommandCompleted?()
                return
            }
            
            if executablePath != "mosh" {
                task.executableURL = URL(fileURLWithPath: executablePath)
            } else {
                task.launchPath = "mosh"
            }
            
            // Build arguments - pass through all original arguments except 'mosh'
            var args = Array(parts.dropFirst())
            
            // Add helpful Mosh options for better experience
            let hasVerbose = args.contains("-v") || args.contains("--verbose")
            if !hasVerbose {
                args.insert("--verbose", at: 0)  // Add verbose output
            }
            
            task.arguments = args
            task.currentDirectoryPath = self.currentWorkingDirectory
            
            // Set up environment - inherit from parent and ensure SSH agent is available
            var environment = ProcessInfo.processInfo.environment
            
            // Ensure TERM is set for proper terminal emulation
            environment["TERM"] = "xterm-256color"
            
            // Set locale for proper character handling
            environment["LC_ALL"] = "en_US.UTF-8"
            environment["LANG"] = "en_US.UTF-8"
            
            task.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            task.standardInput = inputPipe
            
            // Simplified output handling to avoid memory issues
            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self?.onOutput?(output)
                        }
                    }
                } else {
                    // End of data - clean up handler
                    handle.readabilityHandler = nil
                }
            }
            
            errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    if let output = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            self?.onOutput?(output)
                        }
                    }
                } else {
                    // End of data - clean up handler
                    handle.readabilityHandler = nil
                }
            }
            
            task.terminationHandler = { [weak self] terminatedTask in
                DispatchQueue.main.async {
                    // Clean up handlers immediately on main queue
                    outputPipe.fileHandleForReading.readabilityHandler = nil
                    errorPipe.fileHandleForReading.readabilityHandler = nil
                    
                    guard let self = self else { return }
                    
                    if terminatedTask.terminationStatus == 0 {
                        self.onOutput?("\n✅ Mosh connection ended normally\n")
                    } else {
                        self.onOutput?("\n❌ Mosh connection ended with status: \(terminatedTask.terminationStatus)\n")
                        
                        // Provide helpful error messages for common issues
                        switch terminatedTask.terminationStatus {
                        case 255:
                            self.onOutput?("💡 This usually means SSH connection failed.\n")
                            self.onOutput?("   Check: host reachability, SSH keys, username, firewall\n")
                        case 1:
                            self.onOutput?("💡 This may indicate mosh-server is not installed on remote host.\n")
                            self.onOutput?("   Run on remote host: sudo apt-get install mosh (Ubuntu/Debian)\n")
                            self.onOutput?("   Or: sudo yum install mosh (CentOS/RHEL)\n")
                        case 127:
                            self.onOutput?("💡 Command not found - check if mosh is installed locally.\n")
                        default:
                            self.onOutput?("💡 Check mosh documentation for exit code \(terminatedTask.terminationStatus)\n")
                        }
                    }
                    
                    self.currentTask = nil
                    self.isSSHConnected = false
                    self.onCommandCompleted?()
                }
            }
            
            self.onOutput?("🚀 Executing: \(executablePath) \(args.joined(separator: " "))\n")
            
            do {
                try task.run()
                self.currentTask = task
                self.isSSHConnected = true  // Treat Mosh like SSH for command forwarding
                
                self.onOutput?("📡 Mosh client started (PID: \(task.processIdentifier))\n")
                self.onOutput?("💡 Mosh features: UDP-based, survives network changes, local echo\n")
                self.onOutput?("⌨️  Type 'exit' to close the Mosh connection\n\n")
                
            } catch {
                self.onOutput?("❌ Failed to start Mosh: \(error.localizedDescription)\n")
                self.onCommandCompleted?()
            }
        }
        #else
        // iOS: Mosh not supported
        onOutput?("❌ Mosh is not supported on iOS\n")
        onOutput?("💡 Use SSH instead: ssh user@host\n")
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
        #endif
    }
    
    private func handleCdCommand(_ path: String) {
        var targetPath = path
        
        // Handle special cases
        if targetPath.isEmpty || targetPath == "~" {
            targetPath = NSHomeDirectory()
        } else if targetPath.hasPrefix("~/") {
            targetPath = NSHomeDirectory() + String(targetPath.dropFirst(1))
        } else if !targetPath.hasPrefix("/") {
            // Relative path - make it relative to current directory
            targetPath = (currentWorkingDirectory as NSString).appendingPathComponent(targetPath)
        }
        
        // Resolve path (handle .. and . components)
        let resolvedPath = (targetPath as NSString).standardizingPath
        
        // Check if the directory exists
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDirectory) && isDirectory.boolValue {
            currentWorkingDirectory = resolvedPath
            onDirectoryChange?(resolvedPath)
            onOutput?("")  // No output for successful cd
        } else {
            onOutput?("cd: no such file or directory: \(path)\n")
        }
        
        // Notify that command completed on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    public func interruptCurrentCommand() {
        // Terminate the currently running task if there is one
        #if canImport(AppKit)
        if let task = currentTask, task.isRunning {
            task.interrupt()
            onOutput?("\n^C\n")
            currentTask = nil
        }
        #else
        // iOS: No external processes, so just show interrupt message
        onOutput?("\n^C\n")
        #endif
    }
    
    // MARK: - Built-in Command Implementations
    
    private func handleLsCommand(_ args: [String]) {
        let showHidden = args.contains("-a") || args.contains("-la") || args.contains("-al")
        let longFormat = args.contains("-l") || args.contains("-la") || args.contains("-al")
        
        // Get the target directory (last non-flag argument or current directory)
        let targetPath = args.last(where: { !$0.hasPrefix("-") }) ?? currentWorkingDirectory
        let fullPath = targetPath.hasPrefix("/") ? targetPath : (currentWorkingDirectory as NSString).appendingPathComponent(targetPath)
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: fullPath)
            let filteredContents = showHidden ? contents : contents.filter { !$0.hasPrefix(".") }
            let sortedContents = filteredContents.sorted()
            
            var output = ""
            
            if longFormat {
                for item in sortedContents {
                    let itemPath = (fullPath as NSString).appendingPathComponent(item)
                    let attributes = try? FileManager.default.attributesOfItem(atPath: itemPath)
                    
                    let isDirectory = (try? FileManager.default.contentsOfDirectory(atPath: itemPath)) != nil
                    let fileType = isDirectory ? "d" : "-"
                    let permissions = "rwxr-xr-x" // Simplified permissions
                    let size = attributes?[.size] as? Int64 ?? 0
                    let date = (attributes?[.modificationDate] as? Date)?.formatted() ?? "Unknown"
                    
                    output += "\(fileType)\(permissions)  1 user  staff  \(size)  \(date)  \(item)\n"
                }
            } else {
                // Simple format - multiple columns
                let columns = 4
                for (index, item) in sortedContents.enumerated() {
                    let itemPath = (fullPath as NSString).appendingPathComponent(item)
                    let isDirectory = (try? FileManager.default.contentsOfDirectory(atPath: itemPath)) != nil
                    let displayName = isDirectory ? "\(item)/" : item
                    
                    output += displayName.padding(toLength: 20, withPad: " ", startingAt: 0)
                    if (index + 1) % columns == 0 {
                        output += "\n"
                    }
                }
                if sortedContents.count % columns != 0 {
                    output += "\n"
                }
            }
            
            onOutput?(output)
        } catch {
            onOutput?("ls: \(fullPath): \(error.localizedDescription)\n")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    private func handlePwdCommand() {
        onOutput?("\(currentWorkingDirectory)\n")
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    private func handleCatCommand(_ filename: String) {
        // Expand ~ to home directory
        var expandedPath = filename
        if filename.hasPrefix("~/") {
            expandedPath = filename.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
        } else if filename == "~" {
            expandedPath = FileManager.default.homeDirectoryForCurrentUser.path
        }
        
        let fullPath = expandedPath.hasPrefix("/") ? expandedPath : (currentWorkingDirectory as NSString).appendingPathComponent(expandedPath)
        
        do {
            let contents = try String(contentsOfFile: fullPath)
            onOutput?(contents)
            if !contents.hasSuffix("\n") {
                onOutput?("\n")
            }
        } catch {
            onOutput?("cat: \(filename): \(error.localizedDescription)\n")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    private func handleEchoCommand(_ args: [String]) {
        let fullArgs = args.joined(separator: " ")
        
        // Check for redirection operator
        if let redirectIndex = fullArgs.range(of: " > ") {
            let text = String(fullArgs[..<redirectIndex.lowerBound])
            let fileName = String(fullArgs[redirectIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Expand environment variables in text
            let expandedText = expandEnvironmentVariables(text)
            
            // Handle path expansion for filename
            let expandedFileName = expandPath(fileName)
            
            do {
                try expandedText.write(toFile: expandedFileName, atomically: true, encoding: .utf8)
                // Success - no output for redirection
            } catch {
                onOutput?("echo: \(error.localizedDescription)\n")
            }
        } else {
            // Normal echo without redirection - expand environment variables
            let text = args.joined(separator: " ")
            let expandedText = expandEnvironmentVariables(text)
            onOutput?("\(expandedText)\n")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    private func handleMkdirCommand(_ args: [String]) {
        for dirName in args {
            guard !dirName.hasPrefix("-") else { continue } // Skip flags
            
            let fullPath = dirName.hasPrefix("/") ? dirName : (currentWorkingDirectory as NSString).appendingPathComponent(dirName)
            
            do {
                try FileManager.default.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: nil)
                onOutput?("") // Silent success like real mkdir
            } catch {
                onOutput?("mkdir: \(dirName): \(error.localizedDescription)\n")
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    private func handleTouchCommand(_ args: [String]) {
        for fileName in args {
            guard !fileName.hasPrefix("-") else { continue } // Skip flags
            
            let fullPath = fileName.hasPrefix("/") ? fileName : (currentWorkingDirectory as NSString).appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: fullPath) {
                // Update modification time
                do {
                    let attributes = [FileAttributeKey.modificationDate: Date()]
                    try FileManager.default.setAttributes(attributes, ofItemAtPath: fullPath)
                } catch {
                    onOutput?("touch: \(fileName): \(error.localizedDescription)\n")
                }
            } else {
                // Create new file
                FileManager.default.createFile(atPath: fullPath, contents: Data(), attributes: nil)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    private func handleRmCommand(_ args: [String]) {
        let recursive = args.contains("-r") || args.contains("-rf")
        let force = args.contains("-f") || args.contains("-rf")
        
        for fileName in args {
            guard !fileName.hasPrefix("-") else { continue } // Skip flags
            
            let fullPath = fileName.hasPrefix("/") ? fileName : (currentWorkingDirectory as NSString).appendingPathComponent(fileName)
            
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)
            
            if !exists {
                if !force {
                    onOutput?("rm: \(fileName): No such file or directory\n")
                }
                continue
            }
            
            if isDirectory.boolValue && !recursive {
                onOutput?("rm: \(fileName): is a directory (use -r to remove)\n")
                continue
            }
            
            do {
                try FileManager.default.removeItem(atPath: fullPath)
            } catch {
                if !force {
                    onOutput?("rm: \(fileName): \(error.localizedDescription)\n")
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.onCommandCompleted?()
        }
    }
    
    // MARK: - Utility Functions
    
    private func expandPath(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return NSHomeDirectory() + String(path.dropFirst(1))
        } else if path == "~" {
            return NSHomeDirectory()
        } else if path.hasPrefix("/") {
            return path // Already absolute path
        } else {
            // Relative path - resolve against current working directory
            return (currentWorkingDirectory as NSString).appendingPathComponent(path)
        }
    }
    
    private func expandEnvironmentVariables(_ text: String) -> String {
        var result = text
        
        // Handle environment variables in the format $VAR or ${VAR}
        let envVarPattern = #/\$\{?([A-Z_][A-Z0-9_]*)\}?/#
        
        result = result.replacing(envVarPattern) { match in
            let varName = String(match.1)
            
            // Get environment variable value
            if let value = ProcessInfo.processInfo.environment[varName] {
                return value
            } else {
                // Variable not found - return empty string (standard shell behavior)
                return ""
            }
        }
        
        return result
    }
}