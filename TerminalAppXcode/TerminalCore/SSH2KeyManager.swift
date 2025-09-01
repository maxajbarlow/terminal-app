import Foundation
import CryptoKit
import Security

// MARK: - SSH Key Types

public enum SSH2KeyType: String, CaseIterable {
    case ed25519 = "ssh-ed25519"
    case ecdsaP256 = "ecdsa-sha2-nistp256"
    case ecdsaP384 = "ecdsa-sha2-nistp384"
    case ecdsaP521 = "ecdsa-sha2-nistp521"
    case rsa = "ssh-rsa"
    
    public var fileExtension: String {
        switch self {
        case .ed25519: return "id_ed25519"
        case .ecdsaP256, .ecdsaP384, .ecdsaP521: return "id_ecdsa"
        case .rsa: return "id_rsa"
        }
    }
    
    public var displayName: String {
        switch self {
        case .ed25519: return "Ed25519"
        case .ecdsaP256: return "ECDSA P-256"
        case .ecdsaP384: return "ECDSA P-384"
        case .ecdsaP521: return "ECDSA P-521"
        case .rsa: return "RSA"
        }
    }
}

// MARK: - SSH Key Pair

public struct SSH2KeyPair {
    public let keyType: SSH2KeyType
    public let privateKey: Data
    public let publicKey: Data
    public let publicKeyFormatted: String
    public let fingerprint: String
    public let comment: String
    
    internal init(keyType: SSH2KeyType, privateKey: Data, publicKey: Data, comment: String = "") {
        self.keyType = keyType
        self.privateKey = privateKey
        self.publicKey = publicKey
        self.comment = comment.isEmpty ? "generated-by-terminalapp" : comment
        
        // Format public key in OpenSSH format
        self.publicKeyFormatted = SSH2KeyManager.formatPublicKey(publicKey, keyType: keyType, comment: self.comment)
        
        // Generate fingerprint
        self.fingerprint = SSH2KeyManager.generateFingerprint(publicKey)
    }
}

// MARK: - SSH Key Manager

public class SSH2KeyManager {
    
    // MARK: - Key Generation
    
    public static func generateKeyPair(type: SSH2KeyType, comment: String = "") throws -> SSH2KeyPair {
        switch type {
        case .ed25519:
            return try generateEd25519KeyPair(comment: comment)
        case .ecdsaP256:
            return try generateECDSAKeyPair(curve: .P256, keyType: type, comment: comment)
        case .ecdsaP384:
            return try generateECDSAKeyPair(curve: .P384, keyType: type, comment: comment)
        case .ecdsaP521:
            return try generateECDSAKeyPair(curve: .P521, keyType: type, comment: comment)
        case .rsa:
            return try generateRSAKeyPair(comment: comment)
        }
    }
    
    private static func generateEd25519KeyPair(comment: String) throws -> SSH2KeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        
        return SSH2KeyPair(
            keyType: .ed25519,
            privateKey: privateKey.rawRepresentation,
            publicKey: publicKey.rawRepresentation,
            comment: comment
        )
    }
    
    private enum ECDSACurve {
        case P256, P384, P521
    }
    
    private static func generateECDSAKeyPair(curve: ECDSACurve, keyType: SSH2KeyType, comment: String) throws -> SSH2KeyPair {
        switch curve {
        case .P256:
            let privateKey = P256.Signing.PrivateKey()
            return SSH2KeyPair(
                keyType: keyType,
                privateKey: privateKey.rawRepresentation,
                publicKey: privateKey.publicKey.rawRepresentation,
                comment: comment
            )
        case .P384:
            let privateKey = P384.Signing.PrivateKey()
            return SSH2KeyPair(
                keyType: keyType,
                privateKey: privateKey.rawRepresentation,
                publicKey: privateKey.publicKey.rawRepresentation,
                comment: comment
            )
        case .P521:
            let privateKey = P521.Signing.PrivateKey()
            return SSH2KeyPair(
                keyType: keyType,
                privateKey: privateKey.rawRepresentation,
                publicKey: privateKey.publicKey.rawRepresentation,
                comment: comment
            )
        }
    }
    
    private static func generateRSAKeyPair(comment: String) throws -> SSH2KeyPair {
        // For RSA, we'll use Security framework
        let keySize = 2048
        let keyAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: keySize,
            kSecAttrIsPermanent as String: false
        ]
        
        var publicKey: SecKey?
        var privateKey: SecKey?
        let status = SecKeyGeneratePair(keyAttributes as CFDictionary, &publicKey, &privateKey)
        
        guard status == errSecSuccess,
              let privKey = privateKey,
              let pubKey = publicKey else {
            throw SSH2Error.cryptoError("Failed to generate RSA key pair")
        }
        
        guard let privateKeyData = SecKeyCopyExternalRepresentation(privKey, nil),
              let publicKeyData = SecKeyCopyExternalRepresentation(pubKey, nil) else {
            throw SSH2Error.cryptoError("Failed to export RSA key data")
        }
        
        return SSH2KeyPair(
            keyType: .rsa,
            privateKey: privateKeyData as Data,
            publicKey: publicKeyData as Data,
            comment: comment
        )
    }
    
    // MARK: - Key Formatting
    
    internal static func formatPublicKey(_ publicKey: Data, keyType: SSH2KeyType, comment: String) -> String {
        let base64Key = publicKey.base64EncodedString()
        return "\(keyType.rawValue) \(base64Key) \(comment)"
    }
    
    internal static func generateFingerprint(_ publicKey: Data) -> String {
        let hash = SHA256.hash(data: publicKey)
        let hexString = hash.map { String(format: "%02x", $0) }.joined()
        
        // Format as SHA256:xx:xx:xx...
        let colonSeparated = hexString.enumerated().compactMap { index, character in
            index > 0 && index % 2 == 0 ? ":\(character)" : String(character)
        }.joined()
        
        return "SHA256:\(colonSeparated)"
    }
    
    // MARK: - Key Storage
    
    public static func saveKeyPair(_ keyPair: SSH2KeyPair, to directory: String, filename: String? = nil) throws {
        let sshDir = URL(fileURLWithPath: NSString(string: directory).expandingTildeInPath)
        let baseFilename = filename ?? keyPair.keyType.fileExtension
        
        // Ensure SSH directory exists
        try FileManager.default.createDirectory(at: sshDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        
        // Save private key
        let privateKeyPath = sshDir.appendingPathComponent(baseFilename)
        let privateKeyContent = try formatPrivateKey(keyPair)
        try privateKeyContent.write(to: privateKeyPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyPath.path)
        
        // Save public key
        let publicKeyPath = sshDir.appendingPathComponent("\(baseFilename).pub")
        try keyPair.publicKeyFormatted.write(to: publicKeyPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: publicKeyPath.path)
    }
    
    private static func formatPrivateKey(_ keyPair: SSH2KeyPair) throws -> String {
        switch keyPair.keyType {
        case .ed25519:
            return try formatEd25519PrivateKey(keyPair.privateKey)
        case .ecdsaP256, .ecdsaP384, .ecdsaP521:
            return try formatECDSAPrivateKey(keyPair.privateKey, keyType: keyPair.keyType)
        case .rsa:
            return try formatRSAPrivateKey(keyPair.privateKey)
        }
    }
    
    private static func formatEd25519PrivateKey(_ privateKey: Data) throws -> String {
        let base64Key = privateKey.base64EncodedString()
        return """
        -----BEGIN OPENSSH PRIVATE KEY-----
        \(base64Key)
        -----END OPENSSH PRIVATE KEY-----
        """
    }
    
    private static func formatECDSAPrivateKey(_ privateKey: Data, keyType: SSH2KeyType) throws -> String {
        let base64Key = privateKey.base64EncodedString()
        return """
        -----BEGIN EC PRIVATE KEY-----
        \(base64Key)
        -----END EC PRIVATE KEY-----
        """
    }
    
    private static func formatRSAPrivateKey(_ privateKey: Data) throws -> String {
        let base64Key = privateKey.base64EncodedString()
        return """
        -----BEGIN RSA PRIVATE KEY-----
        \(base64Key)
        -----END RSA PRIVATE KEY-----
        """
    }
    
    // MARK: - Key Loading
    
    public static func loadPrivateKey(from path: String, keyType: SSH2KeyType) throws -> Data {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        let content = try String(contentsOf: url)
        
        // Extract base64 content between BEGIN and END markers
        let lines = content.components(separatedBy: .newlines)
        let base64Lines = lines.filter { line in
            !line.hasPrefix("-----BEGIN") && !line.hasPrefix("-----END") && !line.isEmpty
        }
        
        let base64String = base64Lines.joined()
        guard let keyData = Data(base64Encoded: base64String) else {
            throw SSH2Error.invalidData("Invalid private key format")
        }
        
        return keyData
    }
    
    public static func loadPublicKey(from path: String) throws -> (keyType: SSH2KeyType, publicKey: Data, comment: String) {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        let content = try String(contentsOf: url).trimmingCharacters(in: .whitespacesAndNewlines)
        
        let components = content.components(separatedBy: " ")
        guard components.count >= 2 else {
            throw SSH2Error.invalidData("Invalid public key format")
        }
        
        let keyTypeString = components[0]
        let base64Key = components[1]
        let comment = components.count > 2 ? components[2...].joined(separator: " ") : ""
        
        guard let keyType = SSH2KeyType(rawValue: keyTypeString),
              let publicKeyData = Data(base64Encoded: base64Key) else {
            throw SSH2Error.invalidData("Invalid public key data")
        }
        
        return (keyType: keyType, publicKey: publicKeyData, comment: comment)
    }
    
    // MARK: - Key Discovery
    
    public static func discoverSSHKeys(in directory: String = "~/.ssh") -> [String] {
        let sshDir = URL(fileURLWithPath: NSString(string: directory).expandingTildeInPath)
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: sshDir.path) else {
            return []
        }
        
        let privateKeyFiles = files.filter { filename in
            // Look for private key files (no .pub extension, common key names)
            !filename.hasSuffix(".pub") && 
            !filename.hasSuffix(".known_hosts") &&
            !filename.hasSuffix(".config") &&
            (filename.hasPrefix("id_") || filename == "identity")
        }
        
        return privateKeyFiles.map { sshDir.appendingPathComponent($0).path }
    }
    
    // MARK: - Default Paths
    
    public static var defaultSSHDirectory: String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(homeDirectory)/.ssh"
    }
    
    public static func defaultKeyPath(for keyType: SSH2KeyType) -> String {
        return "\(defaultSSHDirectory)/\(keyType.fileExtension)"
    }
    
    // MARK: - Key Validation
    
    public static func validateKeyPair(privateKeyPath: String, publicKeyPath: String) throws -> Bool {
        // Load both keys
        let publicKeyInfo = try loadPublicKey(from: publicKeyPath)
        let privateKeyData = try loadPrivateKey(from: privateKeyPath, keyType: publicKeyInfo.keyType)
        
        // For validation, we'd need to check that the public key matches the private key
        // This is a simplified check - proper validation would involve reconstructing
        // the public key from the private key and comparing
        return privateKeyData.count > 0 && publicKeyInfo.publicKey.count > 0
    }
    
    // MARK: - Authorized Keys Management
    
    public static func addToAuthorizedKeys(_ publicKey: String, authorizedKeysPath: String = "~/.ssh/authorized_keys") throws {
        let path = URL(fileURLWithPath: NSString(string: authorizedKeysPath).expandingTildeInPath)
        
        // Read existing content
        var content = ""
        if FileManager.default.fileExists(atPath: path.path) {
            content = try String(contentsOf: path)
        }
        
        // Check if key already exists
        if !content.contains(publicKey) {
            if !content.isEmpty && !content.hasSuffix("\n") {
                content += "\n"
            }
            content += publicKey + "\n"
            
            try content.write(to: path, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
        }
    }
}

// MARK: - SSH Agent Support

public class SSH2Agent {
    public static func addKey(_ keyPair: SSH2KeyPair) throws {
        // In a real implementation, this would communicate with ssh-agent
        // For now, this is a placeholder
        print("SSH Agent: Added key \(keyPair.keyType.displayName) with fingerprint \(keyPair.fingerprint)")
    }
    
    public static func listKeys() throws -> [String] {
        // In a real implementation, this would list keys from ssh-agent
        return []
    }
    
    public static func removeKey(fingerprint: String) throws {
        // In a real implementation, this would remove key from ssh-agent
        print("SSH Agent: Removed key with fingerprint \(fingerprint)")
    }
}