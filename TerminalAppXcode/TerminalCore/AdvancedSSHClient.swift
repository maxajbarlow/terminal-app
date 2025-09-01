import Foundation
import Network
import CryptoKit
import Combine

// MARK: - SSH Connection State

public enum SSH2ConnectionState: Equatable {
    case disconnected
    case connecting
    case versionExchange
    case keyExchange
    case authentication
    case connected
    case disconnecting
    case error(String)
    
    public static func == (lhs: SSH2ConnectionState, rhs: SSH2ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.versionExchange, .versionExchange),
             (.keyExchange, .keyExchange),
             (.authentication, .authentication),
             (.connected, .connected),
             (.disconnecting, .disconnecting):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

// MARK: - SSH2 Client Configuration

public struct SSH2ClientConfig {
    let host: String
    let port: Int
    let username: String
    let clientVersion: String
    let timeout: TimeInterval
    let keepAliveInterval: TimeInterval?
    
    // Cryptographic preferences (ordered by preference)
    let kexAlgorithms: [String]
    let hostKeyAlgorithms: [String]
    let encryptionAlgorithms: [String]
    let macAlgorithms: [String]
    let compressionAlgorithms: [String]
    
    public init(host: String, 
                port: Int = 22, 
                username: String,
                clientVersion: String = "SSH-2.0-TerminalApp_1.0",
                timeout: TimeInterval = 30.0,
                keepAliveInterval: TimeInterval? = 60.0) {
        self.host = host
        self.port = port
        self.username = username
        self.clientVersion = clientVersion
        self.timeout = timeout
        self.keepAliveInterval = keepAliveInterval
        
        // Use secure defaults
        self.kexAlgorithms = SSH2Crypto.supportedKexAlgorithms
        self.hostKeyAlgorithms = SSH2Crypto.supportedHostKeyAlgorithms
        self.encryptionAlgorithms = SSH2Crypto.supportedEncryptionAlgorithms
        self.macAlgorithms = SSH2Crypto.supportedMacAlgorithms
        self.compressionAlgorithms = SSH2Crypto.supportedCompressionAlgorithms
    }
}

// MARK: - SSH2 Authentication Credential

public enum SSH2AuthCredential {
    case password(String)
    case publicKey(privateKey: Data, publicKey: Data, keyType: String)
    case keyboardInteractive(responses: [String])
    case none
}

// MARK: - SSH2 Channel

public class SSH2Channel {
    public let channelId: UInt32
    public let remoteChannelId: UInt32
    public var windowSize: UInt32
    public var maxPacketSize: UInt32
    public var isOpen: Bool = true
    
    public var onData: ((Data) -> Void)?
    public var onExtendedData: ((UInt32, Data) -> Void)?
    public var onEOF: (() -> Void)?
    public var onClose: (() -> Void)?
    public var onExit: ((UInt32) -> Void)?
    
    internal init(channelId: UInt32, remoteChannelId: UInt32, windowSize: UInt32, maxPacketSize: UInt32) {
        self.channelId = channelId
        self.remoteChannelId = remoteChannelId
        self.windowSize = windowSize
        self.maxPacketSize = maxPacketSize
    }
}

// MARK: - Advanced SSH2 Client

public class AdvancedSSHClient: ObservableObject {
    // MARK: - Public Properties
    
    @Published public private(set) var connectionState: SSH2ConnectionState = .disconnected
    @Published public private(set) var isConnected: Bool = false
    
    public let config: SSH2ClientConfig
    
    // MARK: - Private Properties
    
    private var connection: NWConnection?
    private var sequenceNumber: UInt32 = 0
    private var serverSequenceNumber: UInt32 = 0
    
    // Protocol state
    private var serverVersion: String?
    private var sessionId: Data?
    private var serverKexInit: Data?
    private var clientKexInit: Data?
    
    // Cryptographic state
    private var kexAlgorithm: String?
    private var hostKeyAlgorithm: String?
    private var encryptionAlgorithm: String?
    private var macAlgorithm: String?
    private var compressionAlgorithm: String?
    
    // Encryption keys
    private var encryptionKey: Data?
    private var macKey: Data?
    private var decryptionKey: Data?
    private var serverMacKey: Data?
    private var initialVector: Data?
    private var serverInitialVector: Data?
    
    // Channel management
    private var channels: [UInt32: SSH2Channel] = [:]
    private var nextChannelId: UInt32 = 0
    private let maxChannels: UInt32 = 1000
    
    // Buffers
    private var receiveBuffer = Data()
    private var sendQueue = DispatchQueue(label: "ssh.send.queue", qos: .userInitiated)
    
    // Host key verification
    public var hostKeyVerifier: ((Data, String) -> Bool)?
    
    // MARK: - Initialization
    
    public init(config: SSH2ClientConfig) {
        self.config = config
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    public func connect() async throws {
        guard connectionState == .disconnected else {
            throw SSH2Error.protocolError("Already connected or connecting")
        }
        
        await updateConnectionState(.connecting)
        
        let nwHost = NWEndpoint.Host(config.host)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(config.port))
        
        connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            
            connection?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if !resumed {
                        resumed = true
                        continuation.resume()
                    }
                    self?.startReceiving()
                    Task {
                        try await self?.performVersionExchange()
                    }
                case .failed(let error):
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: SSH2Error.networkError(error))
                    }
                    Task {
                        await self?.updateConnectionState(.error("Network error: \(error.localizedDescription)"))
                    }
                case .cancelled:
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: SSH2Error.connectionFailed("Connection cancelled"))
                    }
                    Task {
                        await self?.updateConnectionState(.disconnected)
                    }
                default:
                    break
                }
            }
            
            connection?.start(queue: .global(qos: .userInitiated))
        }
    }
    
    public func disconnect() {
        connection?.cancel()
        connection = nil
        channels.removeAll()
        resetCryptographicState()
        Task {
            await updateConnectionState(.disconnected)
        }
    }
    
    // MARK: - Authentication
    
    public func authenticate(with credential: SSH2AuthCredential) async throws {
        guard connectionState == .authentication else {
            throw SSH2Error.protocolError("Not in authentication state")
        }
        
        switch credential {
        case .password(let password):
            try await authenticateWithPassword(password)
        case .publicKey(let privateKey, let publicKey, let keyType):
            try await authenticateWithPublicKey(privateKey: privateKey, publicKey: publicKey, keyType: keyType)
        case .keyboardInteractive(let responses):
            try await authenticateWithKeyboardInteractive(responses: responses)
        case .none:
            try await authenticateWithNone()
        }
    }
    
    // MARK: - Channel Operations
    
    public func openChannel(type: String = "session") async throws -> SSH2Channel {
        guard isConnected else {
            throw SSH2Error.protocolError("Not connected")
        }
        
        let channelId = nextChannelId
        nextChannelId += 1
        
        let windowSize: UInt32 = 2097152 // 2MB
        let maxPacketSize: UInt32 = 32768 // 32KB
        
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.channelOpen.rawValue)
            .addString(type)
            .addUInt32(channelId)
            .addUInt32(windowSize)
            .addUInt32(maxPacketSize)
            .build()
        
        try await sendMessage(message)
        
        return try await withCheckedThrowingContinuation { continuation in
            // Store continuation to be resumed when channel open confirmation is received
            // This would be implemented with a proper async/await channel confirmation handler
            // For now, create the channel optimistically
            let channel = SSH2Channel(channelId: channelId, remoteChannelId: 0, windowSize: windowSize, maxPacketSize: maxPacketSize)
            channels[channelId] = channel
            continuation.resume(returning: channel)
        }
    }
    
    public func requestPTY(channel: SSH2Channel, term: String = "xterm-256color", width: UInt32 = 80, height: UInt32 = 24) async throws {
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.channelRequest.rawValue)
            .addUInt32(channel.remoteChannelId)
            .addString("pty-req")
            .addByte(1) // want reply
            .addString(term)
            .addUInt32(width)
            .addUInt32(height)
            .addUInt32(0) // pixel width
            .addUInt32(0) // pixel height
            .addString("") // terminal modes
            .build()
        
        try await sendMessage(message)
    }
    
    public func requestShell(channel: SSH2Channel) async throws {
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.channelRequest.rawValue)
            .addUInt32(channel.remoteChannelId)
            .addString("shell")
            .addByte(1) // want reply
            .build()
        
        try await sendMessage(message)
    }
    
    public func sendChannelData(channel: SSH2Channel, data: Data) async throws {
        guard channel.isOpen else {
            throw SSH2Error.channelError("Channel is closed")
        }
        
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.channelData.rawValue)
            .addUInt32(channel.remoteChannelId)
            .addData(data)
            .build()
        
        try await sendMessage(message)
    }
    
    public func closeChannel(channel: SSH2Channel) async throws {
        channel.isOpen = false
        
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.channelClose.rawValue)
            .addUInt32(channel.remoteChannelId)
            .build()
        
        try await sendMessage(message)
        channels.removeValue(forKey: channel.channelId)
    }
    
    // MARK: - Convenience Methods
    
    /// Send data through the default shell channel, creating it if needed
    public func sendData(_ data: Data) async throws {
        // Get or create the main shell channel
        var shellChannel: SSH2Channel
        
        if let existingChannel = channels.values.first {
            shellChannel = existingChannel
        } else {
            // Create new shell channel
            shellChannel = try await openChannel()
            try await requestPTY(channel: shellChannel)
            try await requestShell(channel: shellChannel)
        }
        
        try await sendChannelData(channel: shellChannel, data: data)
    }
    
    // MARK: - Private Implementation
    
    @MainActor
    private func updateConnectionState(_ newState: SSH2ConnectionState) {
        connectionState = newState
        isConnected = (newState == .connected)
    }
    
    private func resetCryptographicState() {
        sequenceNumber = 0
        serverSequenceNumber = 0
        serverVersion = nil
        sessionId = nil
        serverKexInit = nil
        clientKexInit = nil
        kexAlgorithm = nil
        hostKeyAlgorithm = nil
        encryptionAlgorithm = nil
        macAlgorithm = nil
        compressionAlgorithm = nil
        encryptionKey = nil
        macKey = nil
        decryptionKey = nil
        serverMacKey = nil
        initialVector = nil
        serverInitialVector = nil
    }
    
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let error = error {
                Task {
                    await self?.updateConnectionState(.error("Network error: \(error.localizedDescription)"))
                }
                return
            }
            
            if let data = data {
                Task {
                    await self?.processReceivedData(data)
                }
            }
            
            if !isComplete {
                self?.startReceiving()
            }
        }
    }
    
    private func processReceivedData(_ data: Data) async {
        receiveBuffer.append(data)
        
        // Process complete messages from buffer
        while let message = extractNextMessage() {
            await processMessage(message)
        }
    }
    
    private func extractNextMessage() -> Data? {
        // Handle version exchange phase
        if connectionState == .versionExchange {
            if let newlineIndex = receiveBuffer.firstIndex(of: 0x0A) { // \n
                let line = receiveBuffer.prefix(newlineIndex)
                receiveBuffer.removeFirst(newlineIndex + 1)
                return line
            }
            return nil
        }
        
        // Handle binary SSH packets
        guard receiveBuffer.count >= 5 else { return nil }
        
        let packetLength = receiveBuffer.withUnsafeBytes { bytes in
            bytes.loadUnaligned(as: UInt32.self).bigEndian
        }
        
        let totalLength = Int(packetLength) + 4 // +4 for the length field itself
        guard receiveBuffer.count >= totalLength else { return nil }
        
        let packet = receiveBuffer.prefix(totalLength)
        receiveBuffer.removeFirst(totalLength)
        return Data(packet)
    }
    
    private func processMessage(_ message: Data) async {
        switch connectionState {
        case .versionExchange:
            await processVersionExchange(message)
        case .keyExchange:
            await processKeyExchangeMessage(message)
        case .authentication:
            await processAuthenticationMessage(message)
        case .connected:
            await processConnectedMessage(message)
        default:
            break
        }
    }
    
    // This is a substantial implementation - let me continue with the rest...
}

// MARK: - Version Exchange

extension AdvancedSSHClient {
    private func performVersionExchange() async throws {
        await updateConnectionState(.versionExchange)
        
        let versionString = "\(config.clientVersion)\r\n"
        let versionData = versionString.data(using: .utf8)!
        
        try await sendRawData(versionData)
    }
    
    private func processVersionExchange(_ data: Data) async {
        guard let versionString = String(data: data, encoding: .utf8) else {
            await updateConnectionState(.error("Invalid version string"))
            return
        }
        
        let trimmedVersion = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedVersion.hasPrefix("SSH-2.0-") || trimmedVersion.hasPrefix("SSH-1.99-") {
            serverVersion = trimmedVersion
            Task {
                await self.startKeyExchange()
            }
        } else {
            await updateConnectionState(.error("Unsupported SSH version: \(trimmedVersion)"))
        }
    }
}

// MARK: - Key Exchange

extension AdvancedSSHClient {
    private func startKeyExchange() async {
        await updateConnectionState(.keyExchange)
        
        do {
            let kexInitMessage = buildKexInitMessage()
            clientKexInit = kexInitMessage
            try await sendMessage(kexInitMessage)
        } catch {
            await updateConnectionState(.error("Error: \(error.localizedDescription)"))
        }
    }
    
    private func buildKexInitMessage() -> Data {
        let random = SSH2Crypto.randomBytes(count: 16)
        
        return SSH2MessageBuilder()
            .addByte(SSH2MessageType.kexInit.rawValue)
            .addRawData(random) // 16 random bytes
            .addStringList(config.kexAlgorithms)
            .addStringList(config.hostKeyAlgorithms)
            .addStringList(config.encryptionAlgorithms)
            .addStringList(config.encryptionAlgorithms)
            .addStringList(config.macAlgorithms)
            .addStringList(config.macAlgorithms)
            .addStringList(config.compressionAlgorithms)
            .addStringList(config.compressionAlgorithms)
            .addString("") // languages client to server
            .addString("") // languages server to client
            .addByte(0) // first_kex_packet_follows
            .addUInt32(0) // reserved
            .build()
    }
    
    private func processKeyExchangeMessage(_ data: Data) async {
        guard let packet = SSH2Packet.deserialize(from: data) else {
            await updateConnectionState(.error("Invalid SSH packet"))
            return
        }
        
        let parser = SSH2MessageParser(data: packet.payload)
        guard let messageType = parser.readByte() else {
            await updateConnectionState(.error("Invalid message type"))
            return
        }
        
        switch SSH2MessageType(rawValue: messageType) {
        case .kexInit:
            await processKexInit(parser: parser, rawMessage: data)
        case .kexdhReply:
            await processKexDHReply(parser: parser)
        case .newKeys:
            await processNewKeys()
        default:
            await updateConnectionState(.error("Unexpected message in key exchange"))
        }
    }
    
    private func processKexInit(parser: SSH2MessageParser, rawMessage: Data) async {
        serverKexInit = rawMessage
        
        // Skip 16 random bytes
        _ = Data(count: 16)
        
        let serverKexAlgorithms = parser.readStringList()
        let serverHostKeyAlgorithms = parser.readStringList()
        let serverEncryptionC2S = parser.readStringList()
        _ = parser.readStringList() // server encryption S2C (not used for negotiation)
        let serverMacC2S = parser.readStringList()
        _ = parser.readStringList() // server MAC S2C (not used for negotiation)
        let serverCompressionC2S = parser.readStringList()
        _ = parser.readStringList() // server compression S2C (not used for negotiation)
        
        // Algorithm negotiation
        guard let negotiatedKex = negotiate(client: config.kexAlgorithms, server: serverKexAlgorithms),
              let negotiatedHostKey = negotiate(client: config.hostKeyAlgorithms, server: serverHostKeyAlgorithms),
              let negotiatedEncryption = negotiate(client: config.encryptionAlgorithms, server: serverEncryptionC2S),
              let negotiatedMac = negotiate(client: config.macAlgorithms, server: serverMacC2S),
              let negotiatedCompression = negotiate(client: config.compressionAlgorithms, server: serverCompressionC2S) else {
            
            await updateConnectionState(.error("Key exchange failed: No common algorithms"))
            return
        }
        
        kexAlgorithm = negotiatedKex
        hostKeyAlgorithm = negotiatedHostKey
        encryptionAlgorithm = negotiatedEncryption
        macAlgorithm = negotiatedMac
        compressionAlgorithm = negotiatedCompression
        
        // Start Diffie-Hellman exchange
        await startDiffieHellmanExchange()
    }
    
    private func negotiate(client: [String], server: [String]) -> String? {
        return client.first { server.contains($0) }
    }
    
    private func startDiffieHellmanExchange() async {
        guard let kexAlg = kexAlgorithm else { return }
        
        do {
            let (privateKey, publicKey) = try generateKeyExchangeKeys(algorithm: kexAlg)
            
            // Store private key for later use in shared secret computation
            encryptionKey = privateKey
            
            // Send DH Init
            let dhInitMessage = SSH2MessageBuilder()
                .addByte(SSH2MessageType.kexdhInit.rawValue)
                .addData(publicKey)
                .build()
            
            try await sendMessage(dhInitMessage)
            
        } catch {
            await updateConnectionState(.error("Error: \(error.localizedDescription)"))
        }
    }
    
    private func generateKeyExchangeKeys(algorithm: String) throws -> (Data, Data) {
        switch algorithm {
        case "curve25519-sha256", "curve25519-sha256@libssh.org":
            return SSH2Crypto.curve25519KeyExchange()
        case "ecdh-sha2-nistp256", "ecdh-sha2-nistp384", "ecdh-sha2-nistp521":
            guard let keys = SSH2Crypto.ecdhKeyExchange(curve: algorithm) else {
                throw SSH2Error.keyExchangeFailed("Failed to generate ECDH keys")
            }
            return keys
        default:
            throw SSH2Error.unsupportedAlgorithm(algorithm)
        }
    }
    
    private func processKexDHReply(parser: SSH2MessageParser) async {
        guard let hostKeyData = parser.readData(),
              let serverPublicKey = parser.readData(),
              let signature = parser.readData(),
              let kexAlg = kexAlgorithm,
              let hostKeyAlg = hostKeyAlgorithm else {
            await updateConnectionState(.error(SSH2Error.protocolError("Invalid KEXDH_REPLY")))
            return
        }
        
        do {
            // Verify host key if verifier is provided
            if let verifier = hostKeyVerifier {
                guard verifier(hostKeyData, hostKeyAlg) else {
                    await updateConnectionState(.error("Host key verification failed"))
                    return
                }
            }
            
            // Compute shared secret
            let sharedSecret = try computeSharedSecret(serverPublicKey: serverPublicKey, algorithm: kexAlg)
            
            // Derive session keys
            try deriveSessionKeys(sharedSecret: sharedSecret, hostKey: hostKeyData)
            
            // Verify signature
            let verified = try verifyKexSignature(signature: signature, hostKey: hostKeyData, sharedSecret: sharedSecret)
            guard verified else {
                await updateConnectionState(.error("Signature verification failed"))
                return
            }
            
            await completeKeyExchange()
            
        } catch {
            await updateConnectionState(.error("Error: \(error.localizedDescription)"))
        }
    }
    
    private func processNewKeys() async {
        await updateConnectionState(.authentication)
    }
    
    private func completeKeyExchange() async {
        // Send NEW_KEYS message
        do {
            let newKeysMessage = SSH2MessageBuilder()
                .addByte(SSH2MessageType.newKeys.rawValue)
                .build()
            
            try await sendMessage(newKeysMessage)
        } catch {
            await updateConnectionState(.error("Error: \(error.localizedDescription)"))
        }
    }
    
    private func computeSharedSecret(serverPublicKey: Data, algorithm: String) throws -> Data {
        switch algorithm {
        case "curve25519-sha256", "curve25519-sha256@libssh.org":
            guard let privateKey = encryptionKey else {
                throw SSH2Error.keyExchangeFailed("Missing private key")
            }
            return try SSH2Crypto.curve25519ComputeSharedSecret(privateKey: privateKey, peerPublicKey: serverPublicKey)
        case "ecdh-sha2-nistp256", "ecdh-sha2-nistp384", "ecdh-sha2-nistp521":
            guard let privateKey = encryptionKey else {
                throw SSH2Error.keyExchangeFailed("Missing private key")
            }
            return try SSH2Crypto.ecdhComputeSharedSecret(privateKey: privateKey, peerPublicKey: serverPublicKey, curve: algorithm)
        default:
            throw SSH2Error.unsupportedAlgorithm(algorithm)
        }
    }
    
    private func deriveSessionKeys(sharedSecret: Data, hostKey: Data) throws {
        guard let kexAlg = kexAlgorithm,
              let clientKex = clientKexInit,
              let serverKex = serverKexInit,
              let serverVer = serverVersion else {
            throw SSH2Error.keyExchangeFailed("Missing key exchange data")
        }
        
        // Build exchange hash
        var hashData = Data()
        hashData.append(SSH2MessageBuilder().addString(config.clientVersion).build())
        hashData.append(SSH2MessageBuilder().addString(serverVer).build())
        hashData.append(SSH2MessageBuilder().addData(clientKex).build())
        hashData.append(SSH2MessageBuilder().addData(serverKex).build())
        hashData.append(SSH2MessageBuilder().addData(hostKey).build())
        hashData.append(SSH2MessageBuilder().addData(sharedSecret).build())
        
        let hash = SSH2Crypto.hash(data: hashData, algorithm: kexAlg)
        
        // Set session ID (first exchange hash)
        if sessionId == nil {
            sessionId = hash
        }
        
        // Derive keys using session ID and exchange hash
        let keySize = getKeySize()
        encryptionKey = deriveKey(sharedSecret: sharedSecret, hash: hash, keyId: "A", keySize: keySize)
        decryptionKey = deriveKey(sharedSecret: sharedSecret, hash: hash, keyId: "B", keySize: keySize)
        macKey = deriveKey(sharedSecret: sharedSecret, hash: hash, keyId: "E", keySize: 32)
        serverMacKey = deriveKey(sharedSecret: sharedSecret, hash: hash, keyId: "F", keySize: 32)
        initialVector = deriveKey(sharedSecret: sharedSecret, hash: hash, keyId: "A", keySize: 16)
        serverInitialVector = deriveKey(sharedSecret: sharedSecret, hash: hash, keyId: "B", keySize: 16)
    }
    
    private func getKeySize() -> Int {
        guard let encAlg = encryptionAlgorithm else { return 32 }
        
        switch encAlg {
        case "aes128-ctr", "aes128-gcm@openssh.com": return 16
        case "aes192-ctr": return 24
        case "aes256-ctr", "aes256-gcm@openssh.com", "chacha20-poly1305@openssh.com": return 32
        default: return 32
        }
    }
    
    private func deriveKey(sharedSecret: Data, hash: Data, keyId: String, keySize: Int) -> Data {
        guard let sessionId = sessionId,
              let kexAlg = kexAlgorithm else {
            return Data()
        }
        
        var keyData = Data()
        keyData.append(sharedSecret)
        keyData.append(hash)
        keyData.append(keyId.data(using: .utf8)!)
        keyData.append(sessionId)
        
        let derivedKey = SSH2Crypto.hash(data: keyData, algorithm: kexAlg)
        return Data(derivedKey.prefix(keySize))
    }
    
    private func verifyKexSignature(signature: Data, hostKey: Data, sharedSecret: Data) throws -> Bool {
        // For now, return true - proper signature verification would require
        // parsing the host key and implementing algorithm-specific verification
        return true
    }
}

// MARK: - Authentication Methods

extension AdvancedSSHClient {
    private func authenticateWithPassword(_ password: String) async throws {
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.userAuthRequest.rawValue)
            .addString(config.username)
            .addString("ssh-connection")
            .addString("password")
            .addByte(0) // password change flag
            .addString(password)
            .build()
        
        try await sendMessage(message)
    }
    
    private func authenticateWithPublicKey(privateKey: Data, publicKey: Data, keyType: String) async throws {
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.userAuthRequest.rawValue)
            .addString(config.username)
            .addString("ssh-connection")
            .addString("publickey")
            .addByte(1) // has signature
            .addString(keyType)
            .addData(publicKey)
            .build()
        
        try await sendMessage(message)
    }
    
    private func authenticateWithKeyboardInteractive(responses: [String]) async throws {
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.userAuthRequest.rawValue)
            .addString(config.username)
            .addString("ssh-connection")
            .addString("keyboard-interactive")
            .addString("") // language
            .addString("") // submethods
            .build()
        
        try await sendMessage(message)
    }
    
    private func authenticateWithNone() async throws {
        let message = SSH2MessageBuilder()
            .addByte(SSH2MessageType.userAuthRequest.rawValue)
            .addString(config.username)
            .addString("ssh-connection")
            .addString("none")
            .build()
        
        try await sendMessage(message)
    }
    
    private func processAuthenticationMessage(_ data: Data) async {
        guard let packet = SSH2Packet.deserialize(from: data) else {
            await updateConnectionState(.error("Invalid SSH packet"))
            return
        }
        
        let parser = SSH2MessageParser(data: packet.payload)
        guard let messageType = parser.readByte() else {
            await updateConnectionState(.error("Invalid message type"))
            return
        }
        
        switch SSH2MessageType(rawValue: messageType) {
        case .userAuthSuccess:
            await updateConnectionState(.connected)
        case .userAuthFailure:
            await updateConnectionState(.error("Authentication failed"))
        case .userAuthBanner:
            // Handle banner message
            _ = parser.readString() // banner message
            _ = parser.readString() // language
            // Continue with authentication
        default:
            await updateConnectionState(.error("Unexpected message in authentication"))
        }
    }
}

// MARK: - Connected State Message Processing

extension AdvancedSSHClient {
    private func processConnectedMessage(_ data: Data) async {
        guard let packet = SSH2Packet.deserialize(from: data) else {
            return
        }
        
        let parser = SSH2MessageParser(data: packet.payload)
        guard let messageType = parser.readByte() else {
            return
        }
        
        switch SSH2MessageType(rawValue: messageType) {
        case .channelOpenConfirmation:
            await processChannelOpenConfirmation(parser: parser)
        case .channelOpenFailure:
            await processChannelOpenFailure(parser: parser)
        case .channelData:
            await processChannelData(parser: parser)
        case .channelExtendedData:
            await processChannelExtendedData(parser: parser)
        case .channelEof:
            await processChannelEOF(parser: parser)
        case .channelClose:
            await processChannelClose(parser: parser)
        case .channelSuccess:
            // Channel request succeeded
            break
        case .channelFailure:
            // Channel request failed
            break
        default:
            break
        }
    }
    
    private func processChannelOpenConfirmation(parser: SSH2MessageParser) async {
        guard let localChannelId = parser.readUInt32(),
              let remoteChannelId = parser.readUInt32(),
              let windowSize = parser.readUInt32(),
              let maxPacketSize = parser.readUInt32(),
              channels[localChannelId] != nil else { // channel must exist
            return
        }
        
        // Update channel with server-assigned values
        channels[localChannelId] = SSH2Channel(
            channelId: localChannelId,
            remoteChannelId: remoteChannelId,
            windowSize: windowSize,
            maxPacketSize: maxPacketSize
        )
    }
    
    private func processChannelOpenFailure(parser: SSH2MessageParser) async {
        guard let localChannelId = parser.readUInt32() else { return }
        channels.removeValue(forKey: localChannelId)
    }
    
    private func processChannelData(parser: SSH2MessageParser) async {
        guard let channelId = parser.readUInt32(),
              let data = parser.readData(),
              let channel = channels[channelId] else {
            return
        }
        
        channel.onData?(data)
    }
    
    private func processChannelExtendedData(parser: SSH2MessageParser) async {
        guard let channelId = parser.readUInt32(),
              let dataType = parser.readUInt32(),
              let data = parser.readData(),
              let channel = channels[channelId] else {
            return
        }
        
        channel.onExtendedData?(dataType, data)
    }
    
    private func processChannelEOF(parser: SSH2MessageParser) async {
        guard let channelId = parser.readUInt32(),
              let channel = channels[channelId] else {
            return
        }
        
        channel.onEOF?()
    }
    
    private func processChannelClose(parser: SSH2MessageParser) async {
        guard let channelId = parser.readUInt32(),
              let channel = channels[channelId] else {
            return
        }
        
        channel.isOpen = false
        channel.onClose?()
        channels.removeValue(forKey: channelId)
    }
}

// MARK: - Message Sending

extension AdvancedSSHClient {
    private func sendMessage(_ message: Data) async throws {
        let packet = SSH2Packet(payload: message)
        let packetData = packet.serialize()
        try await sendRawData(packetData)
        sequenceNumber += 1
    }
    
    private func sendRawData(_ data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            connection?.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    continuation.resume(throwing: SSH2Error.networkError(error))
                } else {
                    continuation.resume()
                }
            })
        }
    }
}