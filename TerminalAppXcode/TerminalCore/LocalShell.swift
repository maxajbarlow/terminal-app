import Foundation

public class LocalShell: ObservableObject {
    #if canImport(AppKit)
    private var shellProcess: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var currentDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    #else
    // iOS: No shell process, use Documents directory
    private var currentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
    #endif
    
    public var onOutput: ((String) -> Void)?
    
    public init() {}
    
    deinit {
        terminateShell()
    }
    
    public func startShell() {
        onOutput?("Starting local shell...\n")
        setupShellProcess()
    }
    
    private func setupShellProcess() {
        #if canImport(AppKit)
        shellProcess = Process()
        inputPipe = Pipe()
        outputPipe = Pipe()
        
        guard let shellProcess = shellProcess,
              let inputPipe = inputPipe,
              let outputPipe = outputPipe else { 
            onOutput?("Failed to create pipes\n")
            return 
        }
        
        // Use the user's default shell
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        
        shellProcess.executableURL = URL(fileURLWithPath: shell)
        shellProcess.arguments = ["-i"] // Interactive shell only (not login)
        shellProcess.standardInput = inputPipe
        shellProcess.standardOutput = outputPipe
        shellProcess.standardError = outputPipe
        shellProcess.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        
        // Set up environment
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "dumb" // Simple terminal
        shellProcess.environment = environment
        
        // Monitor output
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty {
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.onOutput?(output)
                    }
                } else {
                    // Try other encodings
                    if let output = String(data: data, encoding: .ascii) {
                        DispatchQueue.main.async {
                            self?.onOutput?(output)
                        }
                    }
                }
            }
        }
        
        // Monitor termination
        shellProcess.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.onOutput?("\nShell terminated with status: \(process.terminationStatus)\n")
            }
        }
        
        do {
            try shellProcess.run()
            
            // Check if process is running
            if shellProcess.isRunning {
                onOutput?("Shell started successfully (PID: \(shellProcess.processIdentifier))\n")
            } else {
                onOutput?("Shell failed to start properly\n")
            }
        } catch {
            onOutput?("Failed to start shell: \(error)\n")
        }
        #else
        // iOS: No shell process support, just indicate we're ready
        onOutput?("iOS Terminal ready - using built-in commands only\n")
        #endif
    }
    
    public func executeCommand(_ command: String) {
        // Handle clear command specially
        if command.trimmingCharacters(in: .whitespaces) == "clear" {
            onOutput?("\u{001B}[2J\u{001B}[H") // ANSI escape codes to clear screen
            return
        }
        
        #if canImport(AppKit)
        guard let inputPipe = inputPipe else { 
            onOutput?("Error: Shell not initialized\n")
            return 
        }
        
        guard let shellProcess = shellProcess, shellProcess.isRunning else {
            onOutput?("Error: Shell is not running\n")
            return
        }
        
        onOutput?("Executing: \(command)\n")
        
        let commandData = (command + "\n").data(using: .utf8)!
        
        inputPipe.fileHandleForWriting.write(commandData)
        onOutput?("Command sent to shell\n")
        #else
        // iOS: Commands are handled by SimpleShell instead
        onOutput?("iOS does not support shell processes. Use built-in commands.\n")
        #endif
    }
    
    public func terminateShell() {
        #if canImport(AppKit)
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        shellProcess?.terminate()
        shellProcess = nil
        inputPipe = nil
        outputPipe = nil
        #else
        // iOS: Nothing to terminate
        #endif
    }
    
    public func changeDirectory(_ path: String) {
        #if canImport(AppKit)
        executeCommand("cd \(path)")
        #else
        // iOS: Directory changes are handled by SimpleShell
        onOutput?("Directory change not supported on iOS\n")
        #endif
    }
}