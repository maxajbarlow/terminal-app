import Foundation
import Network
import CryptoKit
import CommonCrypto

// MARK: - SSH Protocol Constants

public enum SSH2MessageType: UInt8 {
    case disconnect = 1
    case ignore = 2
    case unimplemented = 3
    case debug = 4
    case serviceRequest = 5
    case serviceAccept = 6
    case kexInit = 20
    case newKeys = 21
    case kexdhInit = 30
    case kexdhReply = 31
    case userAuthRequest = 50
    case userAuthFailure = 51
    case userAuthSuccess = 52
    case userAuthBanner = 53
    case globalRequest = 80
    case requestSuccess = 81
    case requestFailure = 82
    case channelOpen = 90
    case channelOpenConfirmation = 91
    case channelOpenFailure = 92
    case channelWindowAdjust = 93
    case channelData = 94
    case channelExtendedData = 95
    case channelEof = 96
    case channelClose = 97
    case channelRequest = 98
    case channelSuccess = 99
    case channelFailure = 100
}

public enum SSH2DisconnectReason: UInt32 {
    case hostNotAllowedToConnect = 1
    case protocolError = 2
    case keyExchangeFailed = 3
    case reserved = 4
    case macError = 5
    case compressionError = 6
    case serviceNotAvailable = 7
    case protocolVersionNotSupported = 8
    case hostKeyNotVerifiable = 9
    case connectionLost = 10
    case byApplication = 11
    case tooManyConnections = 12
    case authCancelledByUser = 13
    case noMoreAuthMethodsAvailable = 14
    case illegalUserName = 15
}

public enum SSH2AuthMethod: String, CaseIterable {
    case none = "none"
    case password = "password"
    case publickey = "publickey"
    case hostbased = "hostbased"
    case keyboardInteractive = "keyboard-interactive"
}

// MARK: - SSH2 Packet Structure

public struct SSH2Packet {
    let length: UInt32
    let paddingLength: UInt8
    let payload: Data
    let padding: Data
    let mac: Data?
    
    init(payload: Data, paddingLength: UInt8? = nil, mac: Data? = nil) {
        self.payload = payload
        
        // Calculate padding length if not provided
        let minPadding: UInt8 = 4
        let blockSize: UInt8 = 8 // Minimum block size before encryption
        let payloadLen = UInt32(payload.count)
        
        if let providedPadding = paddingLength {
            self.paddingLength = max(providedPadding, minPadding)
        } else {
            let totalLen = payloadLen + 1 // +1 for padding length field
            let remainder = (totalLen + UInt32(minPadding)) % UInt32(blockSize)
            self.paddingLength = remainder == 0 ? minPadding : UInt8(UInt32(blockSize) - remainder + UInt32(minPadding))
        }
        
        self.length = payloadLen + UInt32(self.paddingLength) + 1 // +1 for padding length field
        self.padding = Data(repeating: 0, count: Int(self.paddingLength))
        self.mac = mac
    }
    
    func serialize() -> Data {
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: length.bigEndian) { Data($0) })
        data.append(paddingLength)
        data.append(payload)
        data.append(padding)
        if let mac = mac {
            data.append(mac)
        }
        return data
    }
    
    static func deserialize(from data: Data) -> SSH2Packet? {
        guard data.count >= 5 else { return nil }
        
        let length = data.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).bigEndian }
        let paddingLength = data[4]
        
        let headerSize = 5
        let payloadSize = Int(length) - Int(paddingLength) - 1
        let totalPacketSize = headerSize + Int(length)
        
        guard data.count >= totalPacketSize,
              payloadSize >= 0 else { return nil }
        
        let payload = data.subdata(in: headerSize..<(headerSize + payloadSize))
        _ = data.subdata(in: (headerSize + payloadSize)..<(headerSize + Int(length))) // padding data (not used)
        
        return SSH2Packet(payload: payload, paddingLength: paddingLength)
    }
}

// MARK: - SSH2 Message Builder

public class SSH2MessageBuilder {
    private var data = Data()
    
    func addByte(_ value: UInt8) -> SSH2MessageBuilder {
        data.append(value)
        return self
    }
    
    func addUInt32(_ value: UInt32) -> SSH2MessageBuilder {
        data.append(contentsOf: withUnsafeBytes(of: value.bigEndian) { Data($0) })
        return self
    }
    
    func addString(_ value: String) -> SSH2MessageBuilder {
        let stringData = value.data(using: .utf8) ?? Data()
        _ = addUInt32(UInt32(stringData.count))
        data.append(stringData)
        return self
    }
    
    func addData(_ value: Data) -> SSH2MessageBuilder {
        _ = addUInt32(UInt32(value.count))
        data.append(value)
        return self
    }
    
    func addRawData(_ value: Data) -> SSH2MessageBuilder {
        data.append(value)
        return self
    }
    
    func addStringList(_ values: [String]) -> SSH2MessageBuilder {
        let joinedString = values.joined(separator: ",")
        return addString(joinedString)
    }
    
    func build() -> Data {
        return data
    }
}

// MARK: - SSH2 Message Parser

public class SSH2MessageParser {
    private var data: Data
    private var offset: Int = 0
    
    init(data: Data) {
        self.data = data
    }
    
    func readByte() -> UInt8? {
        guard offset < data.count else { return nil }
        let value = data[offset]
        offset += 1
        return value
    }
    
    func readUInt32() -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let value = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
        offset += 4
        return value
    }
    
    func readString() -> String? {
        guard let length = readUInt32(),
              offset + Int(length) <= data.count else { return nil }
        
        let stringData = data.subdata(in: offset..<(offset + Int(length)))
        offset += Int(length)
        return String(data: stringData, encoding: .utf8)
    }
    
    func readData() -> Data? {
        guard let length = readUInt32(),
              offset + Int(length) <= data.count else { return nil }
        
        let result = data.subdata(in: offset..<(offset + Int(length)))
        offset += Int(length)
        return result
    }
    
    func readRemainingData() -> Data {
        let result = data.subdata(in: offset..<data.count)
        offset = data.count
        return result
    }
    
    func readStringList() -> [String] {
        guard let listString = readString() else { return [] }
        return listString.components(separatedBy: ",").filter { !$0.isEmpty }
    }
}

// MARK: - Cryptographic Support

public class SSH2Crypto {
    // Key Exchange Algorithms
    static let supportedKexAlgorithms = [
        "curve25519-sha256",
        "curve25519-sha256@libssh.org",
        "ecdh-sha2-nistp256",
        "ecdh-sha2-nistp384",
        "ecdh-sha2-nistp521",
        "diffie-hellman-group14-sha256"
    ]
    
    // Host Key Algorithms
    static let supportedHostKeyAlgorithms = [
        "ssh-ed25519",
        "ecdsa-sha2-nistp256",
        "ecdsa-sha2-nistp384",
        "ecdsa-sha2-nistp521",
        "ssh-rsa"
    ]
    
    // Encryption Algorithms
    static let supportedEncryptionAlgorithms = [
        "chacha20-poly1305@openssh.com",
        "aes256-gcm@openssh.com",
        "aes128-gcm@openssh.com",
        "aes256-ctr",
        "aes192-ctr",
        "aes128-ctr"
    ]
    
    // MAC Algorithms
    static let supportedMacAlgorithms = [
        "umac-128-etm@openssh.com",
        "hmac-sha2-256-etm@openssh.com",
        "hmac-sha2-512-etm@openssh.com",
        "hmac-sha2-256",
        "hmac-sha2-512"
    ]
    
    // Compression Algorithms
    static let supportedCompressionAlgorithms = [
        "none",
        "zlib@openssh.com"
    ]
    
    // Generate random bytes
    static func randomBytes(count: Int) -> Data {
        var bytes = Data(count: count)
        let result = bytes.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return errSecParam
            }
            return SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        guard result == errSecSuccess else {
            fatalError("Failed to generate random bytes")
        }
        return bytes
    }
    
    // Curve25519 Key Exchange
    static func curve25519KeyExchange() -> (privateKey: Data, publicKey: Data) {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation
        let privateKeyData = privateKey.rawRepresentation
        return (privateKeyData, publicKeyData)
    }
    
    // Compute shared secret for Curve25519
    static func curve25519ComputeSharedSecret(privateKey: Data, peerPublicKey: Data) throws -> Data {
        let ourPrivateKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        let peerPublicKeyObj = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        let sharedSecret = try ourPrivateKey.sharedSecretFromKeyAgreement(with: peerPublicKeyObj)
        return sharedSecret.withUnsafeBytes { Data($0) }
    }
    
    // ECDH Key Exchange
    static func ecdhKeyExchange(curve: String) -> (privateKey: Data, publicKey: Data)? {
        switch curve {
        case "ecdh-sha2-nistp256":
            let privateKey = P256.KeyAgreement.PrivateKey()
            return (privateKey.rawRepresentation, privateKey.publicKey.rawRepresentation)
        case "ecdh-sha2-nistp384":
            let privateKey = P384.KeyAgreement.PrivateKey()
            return (privateKey.rawRepresentation, privateKey.publicKey.rawRepresentation)
        case "ecdh-sha2-nistp521":
            let privateKey = P521.KeyAgreement.PrivateKey()
            return (privateKey.rawRepresentation, privateKey.publicKey.rawRepresentation)
        default:
            return nil
        }
    }
    
    // Compute ECDH shared secret
    static func ecdhComputeSharedSecret(privateKey: Data, peerPublicKey: Data, curve: String) throws -> Data {
        switch curve {
        case "ecdh-sha2-nistp256":
            let ourPrivateKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
            let peerPublicKeyObj = try P256.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
            let sharedSecret = try ourPrivateKey.sharedSecretFromKeyAgreement(with: peerPublicKeyObj)
            return sharedSecret.withUnsafeBytes { Data($0) }
        case "ecdh-sha2-nistp384":
            let ourPrivateKey = try P384.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
            let peerPublicKeyObj = try P384.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
            let sharedSecret = try ourPrivateKey.sharedSecretFromKeyAgreement(with: peerPublicKeyObj)
            return sharedSecret.withUnsafeBytes { Data($0) }
        case "ecdh-sha2-nistp521":
            let ourPrivateKey = try P521.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
            let peerPublicKeyObj = try P521.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
            let sharedSecret = try ourPrivateKey.sharedSecretFromKeyAgreement(with: peerPublicKeyObj)
            return sharedSecret.withUnsafeBytes { Data($0) }
        default:
            throw SSH2Error.unsupportedAlgorithm("Unsupported ECDH curve: \(curve)")
        }
    }
    
    // Hash functions for different algorithms
    static func hash(data: Data, algorithm: String) -> Data {
        switch algorithm {
        case "curve25519-sha256", "curve25519-sha256@libssh.org", "diffie-hellman-group14-sha256", "ecdh-sha2-nistp256":
            return Data(SHA256.hash(data: data))
        case "ecdh-sha2-nistp384":
            return Data(SHA384.hash(data: data))
        case "ecdh-sha2-nistp521":
            return Data(SHA512.hash(data: data))
        default:
            return Data(SHA256.hash(data: data))
        }
    }
    
    // HMAC computation
    static func hmac(key: Data, data: Data, algorithm: String) -> Data {
        switch algorithm {
        case "hmac-sha2-256", "hmac-sha2-256-etm@openssh.com":
            let hmac = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
            return Data(hmac)
        case "hmac-sha2-512", "hmac-sha2-512-etm@openssh.com":
            let hmac = HMAC<SHA512>.authenticationCode(for: data, using: SymmetricKey(data: key))
            return Data(hmac)
        default:
            let hmac = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
            return Data(hmac)
        }
    }
}

// MARK: - SSH2 Error Types

public enum SSH2Error: Error, LocalizedError {
    case connectionFailed(String)
    case protocolError(String)
    case authenticationFailed
    case keyExchangeFailed(String)
    case unsupportedAlgorithm(String)
    case channelError(String)
    case cryptoError(String)
    case invalidData(String)
    case networkError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .protocolError(let message):
            return "Protocol error: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        case .keyExchangeFailed(let message):
            return "Key exchange failed: \(message)"
        case .unsupportedAlgorithm(let algorithm):
            return "Unsupported algorithm: \(algorithm)"
        case .channelError(let message):
            return "Channel error: \(message)"
        case .cryptoError(let message):
            return "Cryptographic error: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}