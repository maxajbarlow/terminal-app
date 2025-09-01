import Foundation
import CryptoKit

// MARK: - Host Key Entry

public struct SSH2HostKeyEntry {
    public let hostname: String
    public let port: Int
    public let keyType: String
    public let publicKey: Data
    public let fingerprint: String
    public let addedDate: Date
    
    public init(hostname: String, port: Int, keyType: String, publicKey: Data) {
        self.hostname = hostname
        self.port = port
        self.keyType = keyType
        self.publicKey = publicKey
        self.fingerprint = SSH2KeyManager.generateFingerprint(publicKey)
        self.addedDate = Date()
    }
    
    public var hostIdentifier: String {
        return port == 22 ? hostname : "\(hostname):\(port)"
    }
    
    public var knownHostsLine: String {
        let base64Key = publicKey.base64EncodedString()
        return "\(hostIdentifier) \(keyType) \(base64Key)"
    }
}

// MARK: - Host Key Verification Result

public enum SSH2HostKeyVerificationResult {
    case trusted // Key matches known host
    case unknown // Host not in known_hosts
    case changed // Key has changed (potential MITM)
    case error(String) // Verification error
}

// MARK: - Host Key Manager

public class SSH2HostKeyManager {
    private let knownHostsPath: String
    private var knownHosts: [SSH2HostKeyEntry] = []
    private let fileManager = FileManager.default
    
    public init(knownHostsPath: String = "~/.ssh/known_hosts") {
        self.knownHostsPath = NSString(string: knownHostsPath).expandingTildeInPath
        loadKnownHosts()
    }
    
    // MARK: - Host Key Verification
    
    public func verifyHostKey(hostname: String, port: Int, keyType: String, publicKey: Data) -> SSH2HostKeyVerificationResult {
        let hostIdentifier = port == 22 ? hostname : "\(hostname):\(port)"
        
        // Look for existing entry
        if let existingEntry = knownHosts.first(where: { $0.hostIdentifier == hostIdentifier && $0.keyType == keyType }) {
            if existingEntry.publicKey == publicKey {
                return .trusted
            } else {
                return .changed
            }
        }
        
        return .unknown
    }
    
    public func addHostKey(hostname: String, port: Int, keyType: String, publicKey: Data) throws {
        let entry = SSH2HostKeyEntry(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
        
        // Remove any existing entry for this host/keytype
        knownHosts.removeAll { $0.hostIdentifier == entry.hostIdentifier && $0.keyType == keyType }
        
        // Add new entry
        knownHosts.append(entry)
        
        // Save to file
        try saveKnownHosts()
    }
    
    public func removeHostKey(hostname: String, port: Int, keyType: String? = nil) throws {
        let hostIdentifier = port == 22 ? hostname : "\(hostname):\(port)"
        
        if let keyType = keyType {
            knownHosts.removeAll { $0.hostIdentifier == hostIdentifier && $0.keyType == keyType }
        } else {
            knownHosts.removeAll { $0.hostIdentifier == hostIdentifier }
        }
        
        try saveKnownHosts()
    }
    
    public func getHostKeys(for hostname: String, port: Int = 22) -> [SSH2HostKeyEntry] {
        let hostIdentifier = port == 22 ? hostname : "\(hostname):\(port)"
        return knownHosts.filter { $0.hostIdentifier == hostIdentifier }
    }
    
    // MARK: - Known Hosts File Management
    
    private func loadKnownHosts() {
        knownHosts.removeAll()
        
        guard fileManager.fileExists(atPath: knownHostsPath) else {
            return
        }
        
        do {
            let content = try String(contentsOfFile: knownHostsPath)
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip empty lines and comments
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                if let entry = parseKnownHostsLine(trimmedLine) {
                    knownHosts.append(entry)
                }
            }
        } catch {
            print("Error loading known_hosts: \(error)")
        }
    }
    
    private func parseKnownHostsLine(_ line: String) -> SSH2HostKeyEntry? {
        let components = line.components(separatedBy: " ")
        guard components.count >= 3 else { return nil }
        
        let hostPart = components[0]
        let keyType = components[1]
        let base64Key = components[2]
        
        guard let publicKey = Data(base64Encoded: base64Key) else { return nil }
        
        // Parse hostname and port
        let (hostname, port) = parseHostIdentifier(hostPart)
        
        return SSH2HostKeyEntry(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
    }
    
    private func parseHostIdentifier(_ hostPart: String) -> (hostname: String, port: Int) {
        if hostPart.contains(":") {
            let components = hostPart.components(separatedBy: ":")
            if components.count == 2, let port = Int(components[1]) {
                return (components[0], port)
            }
        }
        return (hostPart, 22)
    }
    
    private func saveKnownHosts() throws {
        let content = knownHosts.map { $0.knownHostsLine }.joined(separator: "\n")
        
        // Ensure SSH directory exists
        let sshDir = URL(fileURLWithPath: knownHostsPath).deletingLastPathComponent()
        try fileManager.createDirectory(at: sshDir, withIntermediateDirectories: true, attributes: [
            .posixPermissions: 0o700
        ])
        
        try content.write(toFile: knownHostsPath, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: knownHostsPath)
    }
    
    // MARK: - Host Key Fingerprinting
    
    public func getHostKeyFingerprints(for hostname: String, port: Int = 22) -> [String: String] {
        let entries = getHostKeys(for: hostname, port: port)
        var fingerprints: [String: String] = [:]
        
        for entry in entries {
            fingerprints[entry.keyType] = entry.fingerprint
        }
        
        return fingerprints
    }
    
    // MARK: - Host Key Scanning
    
    public func scanHostKey(hostname: String, port: Int = 22, timeout: TimeInterval = 10.0) async throws -> [SSH2HostKeyEntry] {
        // In a real implementation, this would connect to the host and retrieve its public keys
        // For now, this is a placeholder that simulates the process
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                // Simulate scanning by creating dummy entries
                let dummyEd25519Key = SSH2Crypto.randomBytes(count: 32)
                let entry = SSH2HostKeyEntry(hostname: hostname, port: port, keyType: "ssh-ed25519", publicKey: dummyEd25519Key)
                continuation.resume(returning: [entry])
            }
        }
    }
    
    // MARK: - Interactive Verification
    
    public func createHostKeyVerifier() -> (Data, String) -> Bool {
        return { [weak self] publicKey, keyType in
            guard let self = self else { return false }
            
            // For now, always accept unknown hosts (not secure for production)
            // In a real implementation, this would present a dialog to the user
            print("Host key verification - Key type: \(keyType)")
            print("Fingerprint: \(SSH2KeyManager.generateFingerprint(publicKey))")
            
            return true
        }
    }
}

// MARK: - Host Key Validation Policies

public enum SSH2HostKeyPolicy {
    case strict // Reject unknown or changed keys
    case ask // Prompt user for unknown or changed keys
    case accept // Accept all keys (insecure)
    case acceptNew // Accept unknown keys, reject changed keys
}

public class SSH2HostKeyValidator {
    private let hostKeyManager: SSH2HostKeyManager
    private let policy: SSH2HostKeyPolicy
    
    public init(hostKeyManager: SSH2HostKeyManager, policy: SSH2HostKeyPolicy = .ask) {
        self.hostKeyManager = hostKeyManager
        self.policy = policy
    }
    
    public func validateHostKey(hostname: String, port: Int, keyType: String, publicKey: Data, 
                               userPrompt: ((SSH2HostKeyEntry) -> Bool)? = nil) async -> Bool {
        let result = hostKeyManager.verifyHostKey(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
        
        switch result {
        case .trusted:
            return true
            
        case .unknown:
            switch policy {
            case .strict:
                return false
            case .accept, .acceptNew:
                do {
                    try hostKeyManager.addHostKey(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
                    return true
                } catch {
                    return false
                }
            case .ask:
                let entry = SSH2HostKeyEntry(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
                if let prompt = userPrompt, prompt(entry) {
                    do {
                        try hostKeyManager.addHostKey(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
                        return true
                    } catch {
                        return false
                    }
                }
                return false
            }
            
        case .changed:
            switch policy {
            case .strict, .acceptNew:
                return false
            case .accept:
                do {
                    try hostKeyManager.addHostKey(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
                    return true
                } catch {
                    return false
                }
            case .ask:
                let entry = SSH2HostKeyEntry(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
                if let prompt = userPrompt, prompt(entry) {
                    do {
                        try hostKeyManager.addHostKey(hostname: hostname, port: port, keyType: keyType, publicKey: publicKey)
                        return true
                    } catch {
                        return false
                    }
                }
                return false
            }
            
        case .error(let message):
            print("Host key verification error: \(message)")
            return false
        }
    }
}