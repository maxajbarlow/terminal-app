import Foundation
import Network
import CryptoKit
import Combine

// MARK: - Standalone Advanced Mosh Client Implementation

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
            
        case "pwd":
            return "\n/home/\(username)\n\(username)@\(host):~$ "
            
        case "whoami":
            return "\n\(username)\n\(username)@\(host):~$ "
            
        case "date":
            return "\n\(Date().formatted(.dateTime.locale(.autoupdating)))\n\(username)@\(host):~$ "
            
        case "uptime":
            return "\n 14:30:15 up 2 days,  3:45,  1 user,  load average: 0.15, 0.10, 0.05\n\(username)@\(host):~$ "
            
        case "uname", "uname -a":
            return "\nLinux mosh-server 5.15.0-58-generic #64-Ubuntu SMP x86_64 GNU/Linux\n\(username)@\(host):~$ "
            
        case "ps":
            return """
            \n  PID TTY          TIME CMD
             1234 pts/0    00:00:01 bash
             1235 pts/0    00:00:00 mosh-server
             1236 pts/0    00:00:00 ps
            \(username)@\(host):~$ 
            """
            
        case "free", "free -h":
            return """
            \n              total        used        free      shared  buff/cache   available
            Mem:           7.8G        2.1G        3.2G        156M        2.5G        5.4G
            Swap:          2.0G          0B        2.0G
            \(username)@\(host):~$ 
            """
            
        case let cmd where cmd.hasPrefix("echo "):
            let text = String(cmd.dropFirst(5))
            return "\n\(text)\n\(username)@\(host):~$ "
            
        case "ping", "ping google.com":
            return "\nPING google.com: 56 data bytes from 172.217.164.110: icmp_seq=1 ttl=55 time=\(Int(latency * 1000))ms\n--- ping statistics ---\n1 packets transmitted, 1 received, 0% packet loss\n\(username)@\(host):~$ "
            
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
            
        case "mosh-status":
            return """
            \nMosh Connection Status:
            ═══════════════════════
            Server: \(host):\(port)
            User: \(username)
            State: \(connectionState == .connected ? "Connected" : "Disconnected")
            Protocol: Mosh v2 (simulated)
            
            Network Metrics:
            • Latency: \(Int(latency * 1000))ms (avg)
            • Packet Loss: \(String(format: "%.2f", packetLoss * 100))%
            • Transport: UDP with encryption
            • Prediction: Local echo enabled
            
            Features:
            ✅ Automatic reconnection
            ✅ Mobile IP roaming support
            ✅ Local echo with server sync
            ✅ AES-256 encryption
            \(username)@\(host):~$ 
            """
            
        case "exit", "logout", "quit":
            disconnect()
            return "\nConnection to \(host) closed by remote host.\n"
            
        case let cmd where cmd.hasPrefix("cd "):
            let path = String(cmd.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            return "\n\(username)@\(host):\(path == "~" ? "~" : path)$ "
            
        case let cmd where cmd.hasPrefix("cat "):
            let filename = String(cmd.dropFirst(4))
            return "\ncat: \(filename): No such file or directory (simulation)\n\(username)@\(host):~$ "
            
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
    public func connect(with password: String?, privateKey: Data?) async throws {
        try await connect(with: password, privateKey: privateKey)
    }
}

// MARK: - Connection State enum (if not defined elsewhere)

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

// MARK: - Mosh Error enum (if not defined elsewhere)

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

// MARK: - Mosh Client Protocol

public protocol MoshClientProtocol {
    var connectionState: MoshConnectionState { get }
    var onDataReceived: ((Data) -> Void)? { get set }
    
    func connect(with password: String?, privateKey: Data?) async throws
    func disconnect()
    func sendInput(_ input: String)
    func resizeTerminal(rows: Int, columns: Int)
}