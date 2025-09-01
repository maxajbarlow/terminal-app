import Foundation

// MARK: - Stub implementations for SSH2 types to fix compilation

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
}

public enum SSH2AuthCredential {
    case password(String)
    case publicKey(privateKey: Data, publicKey: Data, keyType: String)
}

public struct SSH2Channel {
    public init() {}
}

public class SSH2HostKeyManager {
    public init() {}
}

public class SSH2HostKeyValidator {
    public init(hostKeyManager: SSH2HostKeyManager, policy: SSH2HostKeyPolicy) {}
    
    public func validateHostKey(hostname: String, port: Int, keyType: String, publicKey: Data) async -> Bool {
        return true // Accept all host keys for stub
    }
}

public enum SSH2HostKeyPolicy {
    case acceptNew
    case strict
}

public struct SSH2KeyInfo {
    public let keyType: SSH2KeyType
    public let publicKey: Data
    
    public init(keyType: SSH2KeyType, publicKey: Data) {
        self.keyType = keyType
        self.publicKey = publicKey
    }
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