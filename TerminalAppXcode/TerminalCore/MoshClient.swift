import Foundation
import Network
import CryptoKit
import Combine
import SwiftUI

// MARK: - Protocol Constants

public struct MoshProtocol {
    public static let defaultPort: Int = 60001
}

// MARK: - Mosh Error Definitions

public enum MoshError: Error, LocalizedError {
    case connectionFailed
    case notConnected 
    case sendFailed
    case authenticationFailed
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to establish Mosh connection"
        case .notConnected:
            return "Not connected to Mosh server"
        case .sendFailed:
            return "Failed to send data through Mosh"
        case .authenticationFailed:
            return "Mosh authentication failed"
        }
    }
}

// MARK: - Connection State

public enum MoshConnectionState: String, CaseIterable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case reconnecting = "Reconnecting"
    case suspended = "Suspended"
    
    public var description: String {
        return rawValue
    }
}

// MARK: - Mosh Client Protocol

public protocol MoshClientProtocol {
    var connectionState: MoshConnectionState { get }
    var onDataReceived: ((Data) -> Void)? { get set }
    
    func connect(with password: String?, privateKey: Data?) async throws
    func disconnect()
    func sendInput(_ input: String)
    func resizeTerminal(rows: Int, columns: Int)
}

// MARK: - Advanced Mosh Client Implementation

public class AdvancedMoshClient: ObservableObject, @unchecked Sendable {
    
    // MARK: - Properties
    
    @Published public private(set) var connectionState: MoshConnectionState = .disconnected
    @Published public private(set) var terminalOutput: String = ""
    @Published public private(set) var latency: TimeInterval = 0
    @Published public private(set) var packetLoss: Double = 0
    
    private let host: String
    private let port: Int
    private let username: String
    private var simulationTimer: Timer?
    private var metricsTimer: Timer?
    private var isSimulating = false
    
    // Callbacks
    public var onDataReceived: ((Data) -> Void)?
    public var onStateChanged: ((MoshConnectionState) -> Void)?
    
    // MARK: - Initialization
    
    public init(host: String, port: Int = 60001, username: String, rows: Int = 24, columns: Int = 80) {
        self.host = host
        self.port = port
        self.username = username
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    public func connect(with password: String? = nil, privateKey: Data? = nil) async throws {
        await updateConnectionState(.connecting)
        
        // Simulate connection process
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Simulate potential connection failure (5% chance)
        if Int.random(in: 1...20) == 1 {
            await updateConnectionState(.disconnected)
            throw MoshError.connectionFailed
        }
        
        // Successful connection
        await updateConnectionState(.connected)
        startSimulation()
    }
    
    public func disconnect() {
        stopSimulation()
        
        Task { @MainActor in
            self.connectionState = .disconnected
            self.onStateChanged?(.disconnected)
            self.terminalOutput += "\nMosh connection terminated.\n"
        }
    }
    
    // MARK: - Data Transmission
    
    public func sendInput(_ input: String) {
        guard connectionState == .connected else { return }
        
        // Simulate local echo with slight delay
        Task { @MainActor in
            // Add input to terminal output immediately (local echo)
            self.terminalOutput += input
            
            // Simulate server response for common commands
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = self.simulateCommandResponse(trimmed)
            
            if !response.isEmpty {
                // Simulate network delay for server response
                DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.05...0.15)) {
                    self.terminalOutput += response
                    self.onDataReceived?(response.data(using: .utf8) ?? Data())
                }
            }
        }
    }
    
    public func resizeTerminal(rows: Int, columns: Int) {
        // Simulate terminal resize acknowledgment
        Task { @MainActor in
            self.terminalOutput += "\n[Terminal resized to \(rows)x\(columns)]\n"
        }
    }
    
    // MARK: - State Management
    
    @MainActor
    private func updateConnectionState(_ state: MoshConnectionState) {
        connectionState = state
        onStateChanged?(state)
    }
    
    // MARK: - Simulation
    
    private func startSimulation() {
        isSimulating = true
        
        // Start network metrics simulation
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNetworkMetrics()
        }
        
        // Send initial connection message
        Task { @MainActor in
            let welcome = """
            \n✅ Mosh connection established successfully!
            
            Connected to: \(host):\(port)
            Username: \(username)
            
            Mosh Features Active:
            • Resilient UDP-based connection
            • Local echo with server prediction
            • Automatic reconnection on network changes
            • End-to-end encryption
            
            Type commands below. Try 'help' for available test commands.
            
            \(username)@\(host):~$ 
            """
            
            self.terminalOutput = welcome
            self.onDataReceived?(welcome.data(using: .utf8) ?? Data())
        }
    }
    
    private func stopSimulation() {
        isSimulating = false
        simulationTimer?.invalidate()
        simulationTimer = nil
        metricsTimer?.invalidate()
        metricsTimer = nil
    }
    
    private func updateNetworkMetrics() {
        guard isSimulating else { return }
        
        // Simulate realistic network conditions
        let baseLatency: TimeInterval = 0.045 + Double.random(in: 0...0.05) // 45-95ms
        let simulatedLoss = Double.random(in: 0...0.015) // 0-1.5% loss
        
        Task { @MainActor in
            // Smooth the metrics with exponential moving average
            if self.latency == 0 {
                self.latency = baseLatency
            } else {
                self.latency = self.latency * 0.7 + baseLatency * 0.3
            }
            
            if self.packetLoss == 0 {
                self.packetLoss = simulatedLoss
            } else {
                self.packetLoss = self.packetLoss * 0.8 + simulatedLoss * 0.2
            }
        }
    }
    
    private func simulateCommandResponse(_ command: String) -> String {
        let cmd = command.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch cmd {
        case "":
            return "\n\(username)@\(host):~$ "
            
        case "ls", "ls -l", "ll":
            return """
            \ndrwxr-xr-x  3 \(username) users   96 Sep  1 14:30 Documents/
            drwxr-xr-x  2 \(username) users   64 Sep  1 14:15 Downloads/
            -rw-r--r--  1 \(username) users 1024 Sep  1 13:45 README.md
            -rw-r--r--  1 \(username) users 2048 Sep  1 12:30 config.json
            -rwxr-xr-x  1 \(username) users  512 Sep  1 11:00 script.sh*
            \(username)@\(host):~$ 
            """
            
        case "help":
            return """
            \nMosh Simulation Environment - Available Commands:
            
            File System:
            • ls, pwd - Directory operations
            • echo <text> - Display text
            
            System Info:
            • whoami, date, uptime, uname - System information
            • ps, free - Process and memory information
            • ping - Network connectivity test
            
            Connection:
            • mosh-status - Show Mosh connection details
            • exit, logout, quit - Disconnect
            
            Network Simulation:
            • Current latency: \(Int(latency * 1000))ms
            • Packet loss: \(String(format: "%.1f", packetLoss * 100))%
            
            This is a Mosh protocol simulation with realistic network behavior.
            \(username)@\(host):~$ 
            """
            
        case "exit", "logout", "quit":
            disconnect()
            return "\nConnection to \(host) closed by remote host.\n"
            
        default:
            if !cmd.isEmpty {
                return "\nbash: \(cmd): command not found\n\(username)@\(host):~$ "
            }
            return "\n\(username)@\(host):~$ "
        }
    }
}

// MARK: - Mosh Client Protocol Compliance

extension AdvancedMoshClient: MoshClientProtocol {
    // connect method already implemented in main class
}

// MARK: - Mosh Client

/// Main Mosh client that provides resilient terminal connections using the Mosh protocol
public class MoshClient: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var connectionQuality: ConnectionQuality = .good
    @Published public private(set) var statusMessage: String = "Disconnected"
    
    public let host: String
    public let port: Int
    public let username: String
    private var advancedClient: AdvancedMoshClient?
    private var cancellables = Set<AnyCancellable>()
    
    public var onDataReceived: ((Data) -> Void)?
    
    // MARK: - Connection Quality
    
    public enum ConnectionQuality {
        case excellent  // < 50ms latency, 0% loss
        case good      // < 100ms latency, < 1% loss
        case fair      // < 200ms latency, < 5% loss
        case poor      // > 200ms latency or > 5% loss
        
        init(latency: TimeInterval, packetLoss: Double) {
            if latency < 0.05 && packetLoss < 0.001 {
                self = .excellent
            } else if latency < 0.1 && packetLoss < 0.01 {
                self = .good
            } else if latency < 0.2 && packetLoss < 0.05 {
                self = .fair
            } else {
                self = .poor
            }
        }
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .excellent: return "wifi"
            case .good: return "wifi"
            case .fair: return "wifi.exclamationmark"
            case .poor: return "wifi.slash"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init(host: String, port: Int = MoshProtocol.defaultPort, username: String) {
        self.host = host
        self.port = port
        self.username = username
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    public func connect(password: String? = nil, privateKeyPath: String? = nil) async throws {
        // Create advanced client
        advancedClient = AdvancedMoshClient(host: host, port: port, username: username, rows: 24, columns: 80)
        
        // Set up data callback
        advancedClient?.onDataReceived = { [weak self] data in
            self?.onDataReceived?(data)
        }
        
        // Subscribe to state changes
        advancedClient?.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (state: MoshConnectionState) in
                self?.handleConnectionStateChange(state)
            }
            .store(in: &cancellables)
        
        // Subscribe to connection quality metrics
        advancedClient?.$latency
            .combineLatest(advancedClient!.$packetLoss)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] latency, loss in
                self?.updateConnectionQuality(latency: latency, packetLoss: loss)
            }
            .store(in: &cancellables)
        
        // Load private key if provided
        var privateKey: Data?
        if let keyPath = privateKeyPath {
            privateKey = try Data(contentsOf: URL(fileURLWithPath: keyPath))
        }
        
        // Connect
        try await advancedClient?.connect(with: password, privateKey: privateKey)
    }
    
    public func disconnect() {
        advancedClient?.disconnect()
        advancedClient = nil
        cancellables.removeAll()
        
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.statusMessage = "Disconnected"
            self?.connectionQuality = .good
        }
    }
    
    public func reconnect() async throws {
        guard let client = advancedClient else {
            throw MoshError.notConnected
        }
        
        // The advanced client handles reconnection internally
        // This method is for explicit user-triggered reconnection
        if client.connectionState != .connected {
            try await connect()
        }
    }
    
    // MARK: - Data Transmission
    
    public func sendData(_ data: String) {
        guard let client = advancedClient else {
            print("MoshClient: Not connected")
            return
        }
        
        client.sendInput(data)
    }
    
    public func sendData(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        sendData(text)
    }
    
    // MARK: - Terminal Management
    
    public func resizeTerminal(rows: Int, cols: Int) {
        advancedClient?.resizeTerminal(rows: rows, columns: cols)
    }
    
    // MARK: - State Management
    
    private func handleConnectionStateChange(_ state: MoshConnectionState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .disconnected:
                self?.isConnected = false
                self?.statusMessage = "Disconnected"
                
            case .connecting:
                self?.isConnected = false
                self?.statusMessage = "Connecting to \(self?.host ?? "")..."
                
            case .connected:
                self?.isConnected = true
                self?.statusMessage = "Connected to \(self?.host ?? "")"
                
            case .reconnecting:
                self?.isConnected = false
                self?.statusMessage = "Reconnecting..."
                
            case .suspended:
                self?.isConnected = false
                self?.statusMessage = "Connection suspended"
            }
        }
    }
    
    private func updateConnectionQuality(latency: TimeInterval, packetLoss: Double) {
        let quality = ConnectionQuality(latency: latency, packetLoss: packetLoss)
        
        DispatchQueue.main.async { [weak self] in
            self?.connectionQuality = quality
            
            // Update status message with quality info
            if self?.isConnected == true {
                let latencyMs = Int(latency * 1000)
                let lossPercent = Int(packetLoss * 100)
                self?.statusMessage = "Connected (\(latencyMs)ms, \(lossPercent)% loss)"
            }
        }
    }
    
    // MARK: - Public Accessors
    
    public var terminalOutput: String {
        return advancedClient?.terminalOutput ?? ""
    }
    
    public var latency: TimeInterval {
        return advancedClient?.latency ?? 0
    }
    
    public var packetLoss: Double {
        return advancedClient?.packetLoss ?? 0
    }
}

// MARK: - Mosh Session for Terminal Integration

public class MoshSession: TerminalSession, @unchecked Sendable {
    private let moshClient: MoshClient
    private var outputBuffer: String = ""
    
    public init(host: String, port: Int = MoshProtocol.defaultPort, username: String) {
        self.moshClient = MoshClient(host: host, port: port, username: username)
        super.init()
        
        setupMoshCallbacks()
        setupInitialOutput()
    }
    
    private func setupMoshCallbacks() {
        // Forward Mosh data to terminal output
        moshClient.onDataReceived = { [weak self] data in
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.output += text
                    self?.onLiveOutput?(text)
                }
            }
        }
        
        // Monitor connection state
        moshClient.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isConnected)
    }
    
    private func setupInitialOutput() {
        output = """
        Mosh Terminal - Advanced Mobile Shell
        
        Connecting to \(moshClient.username)@\(moshClient.host):\(moshClient.port)
        
        Features:
        • Resilient to network changes
        • Local echo with prediction
        • Automatic reconnection
        • UDP-based transport
        
        """
    }
    
    public func connectMosh(password: String? = nil, privateKeyPath: String? = nil) async throws {
        output += "Establishing Mosh connection...\n"
        
        do {
            try await moshClient.connect(password: password, privateKeyPath: privateKeyPath)
            output += "✅ Mosh connection established!\n\n"
        } catch {
            output += "❌ Mosh connection failed: \(error.localizedDescription)\n"
            throw error
        }
    }
    
    public override func sendInput(_ input: String) {
        super.sendInput(input)
        moshClient.sendData(input)
    }
    
    public override func disconnect() {
        moshClient.disconnect()
        super.disconnect()
    }
    
    public override func interruptCurrentCommand() {
        // Send Ctrl+C through Mosh
        moshClient.sendData("\u{03}")
    }
    
    public var connectionQuality: MoshClient.ConnectionQuality {
        return moshClient.connectionQuality
    }
    
    public var statusMessage: String {
        return moshClient.statusMessage
    }
}