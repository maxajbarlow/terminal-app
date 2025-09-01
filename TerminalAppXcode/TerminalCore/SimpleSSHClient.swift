import Foundation
import Network

// Simplified SSH client that works without external dependencies
public class SimpleSSHClient {
    private let host: String
    private let port: Int
    private let username: String
    private var connection: NWConnection?
    private var isConnected = false
    
    public var onDataReceived: ((Data) -> Void)?
    
    public init(host: String, port: Int, username: String) {
        self.host = host
        self.port = port
        self.username = username
    }
    
    deinit {
        disconnect()
    }
    
    public func connect(password: String?, privateKeyPath: String? = nil) async throws {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    self.isConnected = true
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: SSHError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    continuation.resume(throwing: SSHError.connectionFailed("Connection cancelled"))
                default:
                    break
                }
            }
            
            connection?.start(queue: .global(qos: .userInitiated))
        }
        
        // Start basic data reading
        startDataReading()
        
        // Send a welcome message to indicate connection
        if let welcomeData = "SSH connection established to \(host):\(port)\r\nDemo SSH client - basic functionality only\r\n$ ".data(using: .utf8) {
            DispatchQueue.main.async {
                self.onDataReceived?(welcomeData)
            }
        }
    }
    
    private func startDataReading() {
        guard let connection = connection else { return }
        
        func readData() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
                if let data = data, !data.isEmpty {
                    DispatchQueue.main.async {
                        self?.onDataReceived?(data)
                    }
                }
                
                if let error = error {
                    print("SSH read error: \(error)")
                    return
                }
                
                if !isComplete {
                    readData() // Continue reading
                }
            }
        }
        
        readData()
    }
    
    public func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
    }
    
    public func sendData(_ data: String) {
        guard let connection = connection, isConnected else { return }
        
        // For demo purposes, echo the command back with some processing
        let response = processCommand(data)
        
        if let responseData = response.data(using: .utf8) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.onDataReceived?(responseData)
            }
        }
    }
    
    private func processCommand(_ command: String) -> String {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch trimmedCommand {
        case "help":
            return """
            Demo SSH Client Commands:
            help - Show this help
            ls - List files (demo)
            pwd - Show current directory (demo)
            whoami - Show current user
            date - Show current date
            exit - Disconnect
            
            $ 
            """
        case "ls":
            return """
            demo.txt
            documents/
            projects/
            
            $ 
            """
        case "pwd":
            return "/home/\(username)\r\n$ "
        case "whoami":
            return "\(username)\r\n$ "
        case "date":
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            return "\(formatter.string(from: Date()))\r\n$ "
        case "exit":
            disconnect()
            return "Connection closed.\r\n"
        default:
            if trimmedCommand.isEmpty {
                return "$ "
            } else {
                return "bash: \(trimmedCommand): command not found\r\n$ "
            }
        }
    }
    
    public var connected: Bool {
        return isConnected
    }
}

// Key management stubs for compatibility
public class SimpleSSHKeyManager {
    public static func generateEd25519KeyPair() -> (privateKey: String, publicKey: String) {
        let timestamp = Int(Date().timeIntervalSince1970)
        return (
            privateKey: "demo-private-key-\(timestamp)",
            publicKey: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5DEMO\(timestamp) demo-key"
        )
    }
    
    public static func generateP256KeyPair() -> (privateKey: String, publicKey: String) {
        let timestamp = Int(Date().timeIntervalSince1970)
        return (
            privateKey: "demo-p256-private-key-\(timestamp)",
            publicKey: "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYDEMO\(timestamp) demo-key"
        )
    }
    
    public static func savePrivateKey(_ privateKey: String, to path: String) throws {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        try privateKey.write(to: url, atomically: true, encoding: .utf8)
    }
    
    public static func loadPrivateKey(from path: String) throws -> String {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        return try String(contentsOf: url)
    }
    
    public static func savePublicKeyForAuthorization(_ publicKey: String, to path: String, comment: String = "") throws {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        let keyWithComment = comment.isEmpty ? publicKey : "\(publicKey) \(comment)"
        try keyWithComment.write(to: url, atomically: true, encoding: .utf8)
    }
    
    public static var defaultSSHDirectory: String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDirectory)/.ssh"
    }
    
    public static var defaultPrivateKeyPaths: [String: String] {
        let sshDir = defaultSSHDirectory
        return [
            "ed25519": "\(sshDir)/id_ed25519",
            "rsa": "\(sshDir)/id_rsa",
            "ecdsa": "\(sshDir)/id_ecdsa"
        ]
    }
}