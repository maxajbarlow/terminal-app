import Foundation
import Combine

public class TerminalSession: ObservableObject, @unchecked Sendable {
    @Published public var output: String = ""
    @Published public var isConnected: Bool = false
    @Published public var currentPath: String = ""
    
    public var onLiveOutput: ((String) -> Void)?
    public var onCommandCompleted: (() -> Void)?
    public var onConfigurationRequested: (() -> Void)?
    public var historyManager: CommandHistoryManager?
    
    // Multithreaded output processing
    private var outputProcessor = MultithreadedTerminalProcessor()
    @Published public var isProcessingOutput: Bool = false
    @Published public var processingStats: MultithreadedTerminalProcessor.ProcessingStats = MultithreadedTerminalProcessor.ProcessingStats()
    
    // Connection handling
    private var connectionInfo: ConnectionInfo?
    private var simpleShell: SimpleShell?
    private var sshClient: SSHClient?
    private var _sessionId: String
    public var sessionId: String { return _sessionId }
    private var currentCommandStartTime: Date?
    
    public init() {
        self._sessionId = UUID().uuidString
        setupOutputProcessorBindings()
        startSimpleShell()
    }
    
    public init(connectionInfo: ConnectionInfo) {
        self._sessionId = UUID().uuidString
        self.connectionInfo = connectionInfo
        setupOutputProcessorBindings()
        startConnection()
    }
    
    private func setupOutputProcessorBindings() {
        // Bind output processor state to published properties
        outputProcessor.$isProcessing
            .assign(to: &$isProcessingOutput)
        
        outputProcessor.$processingStats
            .assign(to: &$processingStats)
        
        outputProcessor.$processedOutput
            .receive(on: DispatchQueue.main)
            .assign(to: &$output)
    }
    
    private func startSimpleShell() {
        // Get initial current directory - platform appropriate
        #if canImport(AppKit)
        currentPath = FileManager.default.currentDirectoryPath
        #else
        // On iOS, use the app's documents directory
        currentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "/tmp"
        #endif
        
        output = """
Terminal App v1.0.0 - Ready

Type 'help' for available commands or use any standard shell command.

"""
        simpleShell = SimpleShell()
        simpleShell?.onOutput = { [weak self] newOutput in
            // Process output using live processing for immediate feedback
            self?.outputProcessor.processLiveOutput(newOutput)
            self?.onLiveOutput?(newOutput)
        }
        simpleShell?.onLargeOutput = { [weak self] largeOutput in
            // Process large output chunks using optimized multithreaded processing
            self?.outputProcessor.processLargeOutput(largeOutput)
            self?.onLiveOutput?(largeOutput)
        }
        simpleShell?.onDirectoryChange = { [weak self] newPath in
            DispatchQueue.main.async {
                self?.currentPath = newPath
            }
        }
        simpleShell?.onCommandCompleted = { [weak self] in
            self?.onCommandCompleted?()
            
            // Send notification if enabled
            if let historyManager = self?.historyManager,
               historyManager.history.count > 0 {
                let settings = SettingsManager.shared
                if settings.notifyOnCommandComplete {
                    let lastCommand = historyManager.history[0]
                    settings.sendNotification(
                        title: "Command Completed",
                        body: "Finished: \(lastCommand.displayText)"
                    )
                }
            }
        }
        simpleShell?.onConfigurationRequested = { [weak self] in
            self?.onConfigurationRequested?()
        }
        isConnected = true
    }
    
    private func startConnection() {
        guard let connectionInfo = connectionInfo else {
            startSimpleShell()
            return
        }
        
        switch connectionInfo.type {
        case .ssh:
            startSSHConnection(connectionInfo)
        case .mosh:
            startMoshConnection(connectionInfo)
        }
    }
    
    private func startMoshConnection(_ connectionInfo: ConnectionInfo) {
        currentPath = "~" // Mosh connections start in home directory
        
        output = """
Mosh Terminal - Connecting...

Establishing Mosh connection to \(connectionInfo.username)@\(connectionInfo.host):\(connectionInfo.port)

"""
        
        Task {
            do {
                // Create Mosh session
                let moshSession = MoshSession(host: connectionInfo.host, 
                                             port: connectionInfo.port, 
                                             username: connectionInfo.username)
                
                // Copy callbacks
                moshSession.onLiveOutput = self.onLiveOutput
                moshSession.onCommandCompleted = self.onCommandCompleted
                moshSession.onConfigurationRequested = self.onConfigurationRequested
                moshSession.historyManager = self.historyManager
                
                // Connect
                try await moshSession.connectMosh(password: connectionInfo.password, 
                                                 privateKeyPath: nil)
                
                // Update connection state
                await MainActor.run {
                    self.isConnected = true
                    self.output = moshSession.output
                    self.onCommandCompleted?()
                }
                
                // Monitor connection quality
                Task {
                    while moshSession.isConnected {
                        await MainActor.run {
                            let quality = moshSession.connectionQuality
                            let status = moshSession.statusMessage
                            
                            // Could update UI with connection quality indicator
                            print("Mosh: \(status) - Quality: \(quality)")
                        }
                        
                        try await Task.sleep(nanoseconds: 5_000_000_000) // Check every 5 seconds
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.output += "Mosh connection failed: \(error.localizedDescription)\n"
                    self.output += "Falling back to local shell...\n\n"
                    
                    // Send notification about connection failure
                    let settings = SettingsManager.shared
                    if settings.notifyOnConnectionLost {
                        settings.sendNotification(
                            title: "Mosh Connection Failed",
                            body: "Connection to \(connectionInfo.host) failed: \(error.localizedDescription)"
                        )
                    }
                    
                    self.startSimpleShell() // Fallback to local shell
                }
            }
        }
    }
    
    private func startSSHConnection(_ connectionInfo: ConnectionInfo) {
        currentPath = "~" // SSH connections start in home directory
        
        output = """
SSH Terminal - Connecting...

Connecting to \(connectionInfo.username)@\(connectionInfo.host):\(connectionInfo.port)

"""
        
        Task {
            do {
                sshClient = try SSHClient(host: connectionInfo.host, port: connectionInfo.port, username: connectionInfo.username)
                
                sshClient?.onDataReceived = { [weak self] data in
                    if let output = String(data: data, encoding: .utf8) {
                        // Process output using live processing for real-time SSH output
                        self?.outputProcessor.processLiveOutput(output)
                        self?.onLiveOutput?(output)
                    }
                }
                
                try await sshClient?.connect(password: connectionInfo.password)
                
                await MainActor.run {
                    self.isConnected = true
                    self.output += "Connected to \(connectionInfo.host)\n\n"
                    self.onCommandCompleted?()
                }
                
            } catch {
                await MainActor.run {
                    self.output += "SSH connection failed: \(error.localizedDescription)\n"
                    self.output += "Falling back to local shell...\n\n"
                    
                    // Send notification about connection failure
                    let settings = SettingsManager.shared
                    if settings.notifyOnConnectionLost {
                        settings.sendNotification(
                            title: "SSH Connection Lost",
                            body: "Connection to \(connectionInfo.host) failed: \(error.localizedDescription)"
                        )
                    }
                    
                    self.startSimpleShell() // Fallback to local shell
                }
            }
        }
    }
    
    public func disconnect() {
        simpleShell = nil
        sshClient?.disconnect()
        sshClient = nil
        isConnected = false
    }
    
    public func sendInput(_ input: String) {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Don't record empty commands or commands that are just newlines
        if !trimmedInput.isEmpty {
            // Record command start time for duration tracking
            currentCommandStartTime = Date()
            
            // Add command to history
            historyManager?.addCommand(trimmedInput, workingDirectory: currentPath, sessionId: sessionId)
        }
        
        if let sshClient = sshClient {
            // SSH connection - send input directly to SSH client
            sshClient.sendData(input + "\n")
        } else {
            // Local shell - execute command through SimpleShell
            simpleShell?.executeCommand(input)
        }
    }
    
    public func executeCommand(_ command: String) {
        if command == "clear" {
            outputProcessor.clearOutput()
            // Don't record "clear" commands in history as they don't have meaningful output
        } else {
            sendInput(command)
        }
    }
    
    public func interruptCurrentCommand() {
        if let sshClient = sshClient {
            // SSH connection - send Ctrl+C
            sshClient.sendData("\u{03}") // ASCII 3 = Ctrl+C
        } else {
            // Local shell
            simpleShell?.interruptCurrentCommand()
        }
    }
    
    public var isSSHConnection: Bool {
        return sshClient != nil
    }
    
    public var connectionDisplayName: String {
        if let connectionInfo = connectionInfo {
            return "\(connectionInfo.username)@\(connectionInfo.host)"
        } else {
            return "Local"
        }
    }
    
    public func setAppCommandHandler(_ handler: @escaping (String, [String]) -> Bool) {
        simpleShell?.onAppCommand = handler
    }
    
    // MARK: - Multithreaded Processing Interface
    
    /// Get current output processing performance statistics
    public var outputProcessingStats: MultithreadedTerminalProcessor.ProcessingStats {
        return outputProcessor.processingStats
    }
    
    /// Check if terminal is currently processing output in background
    public var isOutputProcessing: Bool {
        return outputProcessor.isProcessing
    }
}

public struct ConnectionInfo {
    public let type: ConnectionType
    public let host: String
    public let port: Int
    public let username: String
    public let password: String?
    
    public init(type: ConnectionType, host: String, port: Int, username: String, password: String? = nil) {
        self.type = type
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }
}

public enum ConnectionType {
    case ssh
    case mosh
}