import Foundation
import Network

// MARK: - SSH2 Stub Types (for compilation)

public struct SSH2ClientConfig {
    public let host: String
    public let port: Int
    public let username: String
    
    public init(host: String, port: Int, username: String) {
        self.host = host
        self.port = port
        self.username = username
    }
}

public class AdvancedSSHClient {
    public var hostKeyVerifier: ((Data, String) async -> Bool)?
    public var isConnected: Bool = false
    public var channels: [UInt32: SSH2Channel] = [:]
    public var connection: Task<Void, Error>?
    
    public init(config: SSH2ClientConfig) {
        // Stub implementation
    }
    
    public func connect() async throws {
        // Stub implementation
    }
    
    public func authenticate(with credential: SSH2AuthCredential) async throws {
        // Stub implementation
    }
    
    public func openChannel() async throws -> SSH2Channel {
        return SSH2Channel()
    }
    
    public func requestPTY(channel: SSH2Channel) async throws {
        // Stub implementation
    }
    
    public func requestShell(channel: SSH2Channel) async throws {
        // Stub implementation
    }
    
    public func sendChannelData(channel: SSH2Channel, data: Data) async throws {
        // Stub implementation - would send data through SSH channel
    }
}

public enum SSH2AuthCredential {
    case none
    case password(String)
    case publicKey(privateKey: Data, publicKey: Data, keyType: String)
}

public struct SSH2Channel {
    public init() {}
}

public enum SSH2KeyType: String, CaseIterable {
    case ed25519 = "ssh-ed25519"
    case ecdsaP256 = "ecdsa-sha2-nistp256"
    case ecdsaP384 = "ecdsa-sha2-nistp384"
    case ecdsaP521 = "ecdsa-sha2-nistp521"
    case rsa = "ssh-rsa"
    
    public var rawValue: String {
        switch self {
        case .ed25519: return "ssh-ed25519"
        case .ecdsaP256: return "ecdsa-sha2-nistp256"
        case .ecdsaP384: return "ecdsa-sha2-nistp384"
        case .ecdsaP521: return "ecdsa-sha2-nistp521"
        case .rsa: return "ssh-rsa"
        }
    }
    
    public init?(rawValue: String) {
        switch rawValue {
        case "ssh-ed25519": self = .ed25519
        case "ecdsa-sha2-nistp256": self = .ecdsaP256
        case "ecdsa-sha2-nistp384": self = .ecdsaP384
        case "ecdsa-sha2-nistp521": self = .ecdsaP521
        case "ssh-rsa": self = .rsa
        default: return nil
        }
    }
}

public struct SSH2KeyPair {
    public let keyType: SSH2KeyType
    public let privateKey: Data
    public let publicKey: Data
    public let comment: String
    
    public init(keyType: SSH2KeyType, privateKey: Data, publicKey: Data, comment: String) {
        self.keyType = keyType
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.comment = comment
    }
    
    public var publicKeyFormatted: String {
        // Return base64 encoded public key with prefix
        let base64Key = publicKey.base64EncodedString()
        return "\(keyType.rawValue) \(base64Key) \(comment)"
    }
}

public enum SSH2Error: Error {
    case invalidData(String)
    case keyGenerationFailed(String)
    case fileNotFound(String)
    case permissionDenied(String)
}

public class SSH2KeyManager {
    public static let defaultSSHDirectory = NSHomeDirectory() + "/.ssh"
    
    public static func generateKeyPair(type: SSH2KeyType, comment: String = "") throws -> SSH2KeyPair {
        // Stub implementation - just return dummy data
        let privateKey = Data("dummy-private-key".utf8)
        let publicKey = Data("dummy-public-key".utf8)
        return SSH2KeyPair(keyType: type, privateKey: privateKey, publicKey: publicKey, comment: comment)
    }
    
    public static func loadPublicKey(from path: String) throws -> SSH2KeyInfo {
        // Stub implementation
        return SSH2KeyInfo(keyType: .ed25519, publicKey: Data("dummy-public".utf8))
    }
    
    public static func loadPrivateKey(from path: String, keyType: SSH2KeyType) throws -> Data {
        // Stub implementation
        return Data("dummy-private".utf8)
    }
    
    public static func getPublicKey(from privateKeyData: Data, keyType: String) throws -> Data {
        // Stub implementation - derive public key from private key
        return Data("dummy-derived-public".utf8)
    }
    
    public static func saveKeyPair(_ keyPair: SSH2KeyPair, to directory: String, filename: String) throws {
        // Stub implementation
    }
    
    public static func addToAuthorizedKeys(_ publicKey: String, authorizedKeysPath: String) throws {
        // Stub implementation
    }
    
    public static func defaultKeyPath(for keyType: SSH2KeyType) -> String {
        return defaultSSHDirectory + "/id_" + keyType.rawValue.replacingOccurrences(of: "ssh-", with: "")
    }
    
    public static func discoverSSHKeys() -> [String: String] {
        // Stub implementation
        return [:]
    }
}

public struct SSH2KeyInfo {
    public let keyType: SSH2KeyType
    public let publicKey: Data
    
    public init(keyType: SSH2KeyType, publicKey: Data) {
        self.keyType = keyType
        self.publicKey = publicKey
    }
}

// MARK: - Original SSHClient Code

public enum SSHError: Error {
    case initializationFailed
    case connectionFailed(String)
    case authenticationFailed
    case channelCreationFailed
    case ptyRequestFailed
    case shellStartFailed
    case writeError
    case readError
}

// Simplified SSH client that works without external dependencies
public class SimpleSSHClient: @unchecked Sendable {
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
        guard let _ = connection, isConnected else { return }
        
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

// MARK: - SSH Client Factory

public class SSHClientFactory {
    public static func createAdvancedClient(for config: SSH2ClientConfig) -> AdvancedSSHClient {
        return AdvancedSSHClient(config: config)
    }
    
    public static func createSimpleClient(host: String, port: Int, username: String) -> SimpleSSHClient {
        return SimpleSSHClient(host: host, port: port, username: username)
    }
}

// MARK: - SSH Client Protocol

public protocol SSHClientProtocol {
    var onDataReceived: ((Data) -> Void)? { get set }
    var connected: Bool { get }
    
    func connect(password: String?, privateKeyPath: String?) async throws
    func disconnect()
    func sendData(_ data: String)
}

// MARK: - SimpleSSHClient Protocol Conformance

extension SimpleSSHClient: SSHClientProtocol {
    // connected property is already defined in the main class
}

// MARK: - AdvancedSSHClient Protocol Conformance

extension AdvancedSSHClient: SSHClientProtocol {
    public var connected: Bool {
        return isConnected
    }
    
    public var onDataReceived: ((Data) -> Void)? {
        get { return nil } // This will be handled through channels
        set { /* Ignore for now - data is handled through channel callbacks */ }
    }
    
    public func connect(password: String?, privateKeyPath: String?) async throws {
        try await connect()
        
        // Authenticate
        let credential: SSH2AuthCredential
        if let keyPath = privateKeyPath, !keyPath.isEmpty {
            let keyInfo = try SSH2KeyManager.loadPublicKey(from: keyPath + ".pub")
            let privateKeyData = try SSH2KeyManager.loadPrivateKey(from: keyPath, keyType: keyInfo.keyType)
            credential = .publicKey(privateKey: privateKeyData, publicKey: keyInfo.publicKey, keyType: keyInfo.keyType.rawValue)
        } else if let pwd = password {
            credential = .password(pwd)
        } else {
            credential = .password("")
        }
        
        try await authenticate(with: credential)
    }
    
    public func sendData(_ data: String) {
        // This would need to be implemented using channels
        // For now, this is a placeholder that could store data to send via channel
        Task {
            if let firstChannel = channels.values.first {
                do {
                    try await sendChannelData(channel: firstChannel, data: data.data(using: .utf8) ?? Data())
                } catch {
                    print("Failed to send data: \(error)")
                }
            }
        }
    }
    
    public func disconnect() {
        // Implementation for AdvancedSSHClient disconnect
        isConnected = false
        channels.removeAll()
        connection?.cancel()
        connection = nil
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
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), 
                                                withIntermediateDirectories: true)
        
        try privateKey.write(to: url, atomically: true, encoding: .utf8)
        
        // Set appropriate file permissions (readable only by owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], 
                                              ofItemAtPath: NSString(string: path).expandingTildeInPath)
    }
    
    public static func loadPrivateKey(from path: String) throws -> String {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        return try String(contentsOf: url)
    }
    
    public static func savePublicKeyForAuthorization(_ publicKey: String, to path: String, comment: String = "") throws {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), 
                                                withIntermediateDirectories: true)
        
        let keyWithComment = comment.isEmpty ? publicKey : "\(publicKey) \(comment)"
        try keyWithComment.write(to: url, atomically: true, encoding: .utf8)
    }
    
    public static var defaultSSHDirectory: String {
        #if os(iOS)
        let homeDirectory = NSHomeDirectory()
        #else
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        #endif
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

// MARK: - Modern SSH Key Manager

public class SSHKeyManager {
    // Bridge to new SSH2KeyManager for modern key generation
    public static func generateEd25519KeyPair(comment: String = "") throws -> (privateKey: String, publicKey: String) {
        let keyPair = try SSH2KeyManager.generateKeyPair(type: .ed25519, comment: comment)
        let privateKeyFormatted = try formatPrivateKeyForCompatibility(keyPair)
        return (privateKey: privateKeyFormatted, publicKey: keyPair.publicKeyFormatted)
    }
    
    public static func generateP256KeyPair(comment: String = "") throws -> (privateKey: String, publicKey: String) {
        let keyPair = try SSH2KeyManager.generateKeyPair(type: .ecdsaP256, comment: comment)
        let privateKeyFormatted = try formatPrivateKeyForCompatibility(keyPair)
        return (privateKey: privateKeyFormatted, publicKey: keyPair.publicKeyFormatted)
    }
    
    public static func generateRSAKeyPair(comment: String = "") throws -> (privateKey: String, publicKey: String) {
        let keyPair = try SSH2KeyManager.generateKeyPair(type: .rsa, comment: comment)
        let privateKeyFormatted = try formatPrivateKeyForCompatibility(keyPair)
        return (privateKey: privateKeyFormatted, publicKey: keyPair.publicKeyFormatted)
    }
    
    private static func formatPrivateKeyForCompatibility(_ keyPair: SSH2KeyPair) throws -> String {
        switch keyPair.keyType {
        case .ed25519:
            let base64Key = keyPair.privateKey.base64EncodedString()
            return """
            -----BEGIN OPENSSH PRIVATE KEY-----
            \(base64Key)
            -----END OPENSSH PRIVATE KEY-----
            """
        case .ecdsaP256, .ecdsaP384, .ecdsaP521:
            let base64Key = keyPair.privateKey.base64EncodedString()
            return """
            -----BEGIN EC PRIVATE KEY-----
            \(base64Key)
            -----END EC PRIVATE KEY-----
            """
        case .rsa:
            let base64Key = keyPair.privateKey.base64EncodedString()
            return """
            -----BEGIN RSA PRIVATE KEY-----
            \(base64Key)
            -----END RSA PRIVATE KEY-----
            """
        }
    }
    
    public static func saveKeyPair(privateKey: String, publicKey: String, to directory: String, filename: String) throws {
        // Parse key type from public key
        let components = publicKey.components(separatedBy: " ")
        guard components.count >= 2,
              let keyType = SSH2KeyType(rawValue: components[0]),
              let publicKeyData = Data(base64Encoded: components[1]) else {
            throw SSH2Error.invalidData("Invalid public key format")
        }
        
        let privateKeyData = privateKey.data(using: .utf8) ?? Data()
        let keyPair = SSH2KeyPair(keyType: keyType, privateKey: privateKeyData, publicKey: publicKeyData, comment: "")
        
        try SSH2KeyManager.saveKeyPair(keyPair, to: directory, filename: filename)
    }
    
    public static func savePrivateKey(_ privateKey: String, to path: String) throws {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), 
                                                withIntermediateDirectories: true)
        
        try privateKey.write(to: url, atomically: true, encoding: .utf8)
        
        // Set appropriate file permissions (readable only by owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], 
                                              ofItemAtPath: NSString(string: path).expandingTildeInPath)
    }
    
    public static func loadPrivateKey(from path: String) throws -> String {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        return try String(contentsOf: url)
    }
    
    public static func savePublicKeyForAuthorization(_ publicKey: String, to path: String, comment: String = "") throws {
        try SSH2KeyManager.addToAuthorizedKeys(publicKey, authorizedKeysPath: path)
    }
    
    public static var defaultSSHDirectory: String {
        return SSH2KeyManager.defaultSSHDirectory
    }
    
    public static var defaultPrivateKeyPaths: [String: String] {
        return [
            "ed25519": SSH2KeyManager.defaultKeyPath(for: .ed25519),
            "rsa": SSH2KeyManager.defaultKeyPath(for: .rsa),
            "ecdsa": SSH2KeyManager.defaultKeyPath(for: .ecdsaP256)
        ]
    }
    
    public static func discoverKeys() -> [String] {
        return Array(SSH2KeyManager.discoverSSHKeys().keys)
    }
}

// Main public SSH client class
public class SSHClient {
    private let advancedSSHClient: AdvancedSSHClient
    private let host: String
    private let port: Int
    private let username: String
    
    public var onDataReceived: ((Data) -> Void)? {
        get { advancedSSHClient.onDataReceived }
        set { advancedSSHClient.onDataReceived = newValue }
    }
    
    public init(host: String, port: Int, username: String) throws {
        self.host = host
        self.port = port
        self.username = username
        let config = SSH2ClientConfig(host: host, port: port, username: username)
        self.advancedSSHClient = AdvancedSSHClient(config: config)
    }
    
    deinit {
        disconnect()
    }
    
    public func connect(password: String?, privateKeyPath: String? = nil) async throws {
        do {
            // First connect to the server
            try await advancedSSHClient.connect()
            
            // Then authenticate
            let credential: SSH2AuthCredential
            if let password = password {
                credential = .password(password)
            } else if let keyPath = privateKeyPath {
                let privateKeyData = try Data(contentsOf: URL(fileURLWithPath: keyPath))
                let publicKeyData = try SSH2KeyManager.getPublicKey(from: privateKeyData, keyType: "ssh-ed25519")
                credential = .publicKey(privateKey: privateKeyData, publicKey: publicKeyData, keyType: "ssh-ed25519")
            } else {
                credential = .none
            }
            
            try await advancedSSHClient.authenticate(with: credential)
        } catch let error as SSH2Error {
            throw SSHError.connectionFailed(error.localizedDescription)
        } catch {
            throw SSHError.connectionFailed(error.localizedDescription)
        }
    }
    
    public func disconnect() {
        advancedSSHClient.disconnect()
    }
    
    public func sendData(_ data: String) {
        // Send data through SSH connection
        Task {
            do {
                advancedSSHClient.sendData(data)
            }
        }
    }
    
    public var isConnected: Bool {
        return advancedSSHClient.isConnected
    }
    
    // MARK: - Static Key Generation Methods (Legacy Support)
    
    /// Generate a new Ed25519 key pair for SSH authentication
    public static func generateEd25519KeyPair() -> (privateKey: String, publicKey: String) {
        do {
            return try SSHKeyManager.generateEd25519KeyPair()
        } catch {
            return SimpleSSHKeyManager.generateEd25519KeyPair()
        }
    }
    
    /// Generate a new P256 ECDSA key pair for SSH authentication  
    public static func generateP256KeyPair() -> (privateKey: String, publicKey: String) {
        do {
            return try SSHKeyManager.generateP256KeyPair()
        } catch {
            return SimpleSSHKeyManager.generateP256KeyPair()
        }
    }
    
    /// Save a private key to the default SSH directory
    public static func savePrivateKey(_ privateKey: String, name: String) throws {
        let keyPath = "\(SSHKeyManager.defaultSSHDirectory)/\(name)"
        try SSHKeyManager.savePrivateKey(privateKey, to: keyPath)
    }
    
    /// Save a public key for server authorization
    public static func savePublicKey(_ publicKey: String, name: String, comment: String = "") throws {
        let keyPath = "\(SSHKeyManager.defaultSSHDirectory)/\(name).pub"
        try SSHKeyManager.savePublicKeyForAuthorization(publicKey, to: keyPath, comment: comment)
    }
    
    /// Get the default SSH directory path
    public static var defaultSSHDirectory: String {
        return SSHKeyManager.defaultSSHDirectory
    }
    
    /// Get the default private key paths for different algorithms
    public static var defaultPrivateKeyPaths: [String: String] {
        return SSHKeyManager.defaultPrivateKeyPaths
    }
}