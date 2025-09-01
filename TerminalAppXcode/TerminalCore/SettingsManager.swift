import SwiftUI
import Combine
#if os(macOS)
import Metal
#endif

// MARK: - SSH2 Stubs (for compilation)

public enum SSH2HostKeyPolicy {
    case strict
    case ask  
    case accept
    case acceptNew
}

public class SSH2HostKeyManager {
    public init() {}
}

public class SSH2HostKeyValidator {
    public init(hostKeyManager: SSH2HostKeyManager, policy: SSH2HostKeyPolicy) {}
    public func validateHostKey(hostname: String, port: Int, keyType: String, publicKey: Data) async -> Bool {
        return true
    }
}


// MARK: - Connection Profile (for compilation)

public struct ConnectionProfile: Identifiable, Hashable, Codable {
    public let id = UUID()
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var sshKeyPath: String?
    public var description: String
    public var color: Color
    
    public init(name: String, host: String, port: Int, username: String, sshKeyPath: String? = nil, description: String, color: Color) {
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.sshKeyPath = sshKeyPath
        self.description = description
        self.color = color
    }
    
    public static let examples: [ConnectionProfile] = [
        ConnectionProfile(
            name: "Development Server",
            host: "dev.example.com",
            port: 22,
            username: "developer",
            description: "Main development server",
            color: .blue
        ),
        ConnectionProfile(
            name: "Production Server",
            host: "prod.example.com",
            port: 22,
            username: "admin",
            description: "Production server",
            color: .red
        ),
        ConnectionProfile(
            name: "Local VM",
            host: "192.168.1.100",
            port: 2222,
            username: "user",
            description: "Local virtual machine",
            color: .green
        )
    ]
}

// MARK: - ConnectionProfile Codable Implementation

extension ConnectionProfile {
    enum CodingKeys: String, CodingKey {
        case id, name, host, port, username, sshKeyPath, description
        case colorRed, colorGreen, colorBlue, colorAlpha
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _ = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let host = try container.decode(String.self, forKey: .host)
        let port = try container.decode(Int.self, forKey: .port)
        let username = try container.decode(String.self, forKey: .username)
        let sshKeyPath = try container.decodeIfPresent(String.self, forKey: .sshKeyPath)
        let description = try container.decode(String.self, forKey: .description)
        
        let red = try container.decode(Double.self, forKey: .colorRed)
        let green = try container.decode(Double.self, forKey: .colorGreen)
        let blue = try container.decode(Double.self, forKey: .colorBlue)
        let alpha = try container.decode(Double.self, forKey: .colorAlpha)
        let color = Color(red: red, green: green, blue: blue, opacity: alpha)
        
        self.init(name: name, host: host, port: port, username: username, 
                  sshKeyPath: sshKeyPath, description: description, color: color)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(username, forKey: .username)
        try container.encodeIfPresent(sshKeyPath, forKey: .sshKeyPath)
        try container.encode(description, forKey: .description)
        
        // Encode color components
        #if canImport(AppKit)
        if let components = NSColor(color).cgColor.components {
            try container.encode(Double(components[0]), forKey: .colorRed)
            try container.encode(Double(components[1]), forKey: .colorGreen)
            try container.encode(Double(components[2]), forKey: .colorBlue)
            try container.encode(Double(components[3]), forKey: .colorAlpha)
        }
        #else
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        try container.encode(Double(red), forKey: .colorRed)
        try container.encode(Double(green), forKey: .colorGreen)
        try container.encode(Double(blue), forKey: .colorBlue)
        try container.encode(Double(alpha), forKey: .colorAlpha)
        #endif
    }
}

// MARK: - Settings Manager
public class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()
    
    // MARK: - Appearance Settings
    @AppStorage("terminal.textColor") private var textColorData: Data = Data()
    @AppStorage("terminal.backgroundColor") private var backgroundColorData: Data = Data()
    @AppStorage("terminal.fontSize") public var fontSize: Double = 13 {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        }
    }
    @AppStorage("terminal.fontFamily") public var fontFamily: String = "SF Mono"
    @AppStorage("terminal.cursorStyle") public var cursorStyle: String = "block"
    @AppStorage("terminal.cursorBlink") public var cursorBlink: Bool = true
    
    // MARK: - Performance Settings
    @AppStorage("terminal.gpuAcceleration") public var gpuAcceleration: Bool = true {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        }
    }
    @AppStorage("terminal.preferredFrameRate") public var preferredFrameRate: Int = 60
    
    @Published public var textColor: Color = .green {
        didSet { 
            saveColor(textColor, to: &textColorData)
            NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        }
    }
    
    @Published public var backgroundColor: Color = .black {
        didSet { 
            saveColor(backgroundColor, to: &backgroundColorData)
            NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
        }
    }
    
    // MARK: - Notification Settings
    @AppStorage("notifications.enabled") public var notificationsEnabled: Bool = true
    @AppStorage("notifications.sound") public var notificationSound: Bool = true
    @AppStorage("notifications.badge") public var notificationBadge: Bool = false
    @AppStorage("notifications.onCommandComplete") public var notifyOnCommandComplete: Bool = false
    @AppStorage("notifications.onConnectionLost") public var notifyOnConnectionLost: Bool = true
    
    // MARK: - iCloud Settings
    @AppStorage("icloud.enabled") public var iCloudEnabled: Bool = false
    @AppStorage("icloud.syncProfiles") public var syncProfiles: Bool = true
    @AppStorage("icloud.syncKeys") public var syncSSHKeys: Bool = false
    @AppStorage("icloud.syncSettings") public var syncSettings: Bool = true
    
    // MARK: - Connection Profiles
    @AppStorage("profiles.data") private var profilesData: Data = Data()
    @Published public var profiles: [ConnectionProfile] = [] {
        didSet { saveProfiles() }
    }
    
    // MARK: - Bookmarks
    @AppStorage("bookmarks.data") private var bookmarksData: Data = Data()
    @Published public var bookmarks: [CommandBookmark] = [] {
        didSet { saveBookmarks() }
    }
    
    // MARK: - Keyboard Shortcuts
    @AppStorage("shortcuts.data") private var shortcutsData: Data = Data()
    @Published public var shortcuts: [KeyboardShortcut] = [] {
        didSet { saveShortcuts() }
    }
    
    // MARK: - Terminal Behavior
    @AppStorage("terminal.scrollback") public var scrollbackLines: Int = 1000
    @AppStorage("terminal.bellSound") public var bellSound: Bool = true
    @AppStorage("terminal.autoComplete") public var autoComplete: Bool = true
    @AppStorage("terminal.confirmClose") public var confirmCloseTab: Bool = true
    
    private init() {
        loadSettings()
        setupDefaultShortcuts()
    }
    
    // MARK: - Load/Save Methods
    
    private func loadSettings() {
        // Load colors
        if !textColorData.isEmpty {
            textColor = loadColor(from: textColorData) ?? .green
        }
        if !backgroundColorData.isEmpty {
            backgroundColor = loadColor(from: backgroundColorData) ?? .black
        }
        
        // Load profiles
        if !profilesData.isEmpty {
            if let decoded = try? JSONDecoder().decode([ConnectionProfile].self, from: profilesData) {
                profiles = decoded
            }
        } else {
            // Load example profiles for first launch
            profiles = ConnectionProfile.examples
        }
        
        // Load bookmarks
        if !bookmarksData.isEmpty {
            if let decoded = try? JSONDecoder().decode([CommandBookmark].self, from: bookmarksData) {
                bookmarks = decoded
            }
        }
        
        // Load shortcuts
        if !shortcutsData.isEmpty {
            if let decoded = try? JSONDecoder().decode([KeyboardShortcut].self, from: shortcutsData) {
                shortcuts = decoded
            }
        }
    }
    
    private func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            profilesData = encoded
        }
    }
    
    private func saveBookmarks() {
        if let encoded = try? JSONEncoder().encode(bookmarks) {
            bookmarksData = encoded
        }
    }
    
    private func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            shortcutsData = encoded
        }
    }
    
    private func setupDefaultShortcuts() {
        if shortcuts.isEmpty {
            shortcuts = [
                KeyboardShortcut(id: UUID(), key: "k", modifiers: [.command], action: "clear", description: "Clear Terminal"),
                KeyboardShortcut(id: UUID(), key: "l", modifiers: [.command], action: "ls -la", description: "List Files"),
                KeyboardShortcut(id: UUID(), key: "d", modifiers: [.command], action: "exit", description: "Exit Session")
            ]
        }
    }
    
    // MARK: - Color Persistence
    
    private func saveColor(_ color: Color, to data: inout Data) {
        #if canImport(AppKit)
        if let nsColor = NSColor(color).cgColor.components {
            let colorData = ColorData(
                red: Double(nsColor[0]),
                green: Double(nsColor[1]),
                blue: Double(nsColor[2]),
                alpha: Double(nsColor[3])
            )
            if let encoded = try? JSONEncoder().encode(colorData) {
                data = encoded
            }
        }
        #else
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let colorData = ColorData(
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            alpha: Double(alpha)
        )
        if let encoded = try? JSONEncoder().encode(colorData) {
            data = encoded
        }
        #endif
    }
    
    private func loadColor(from data: Data) -> Color? {
        guard let colorData = try? JSONDecoder().decode(ColorData.self, from: data) else {
            return nil
        }
        return Color(
            red: colorData.red,
            green: colorData.green,
            blue: colorData.blue,
            opacity: colorData.alpha
        )
    }
    
    // MARK: - Profile Management
    
    public func addProfile(_ profile: ConnectionProfile) {
        profiles.append(profile)
    }
    
    public func updateProfile(_ profile: ConnectionProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        }
    }
    
    public func deleteProfile(_ profile: ConnectionProfile) {
        profiles.removeAll { $0.id == profile.id }
    }
    
    public func connectToProfile(_ profile: ConnectionProfile) async {
        do {
            let config = SSH2ClientConfig(
                host: profile.host,
                port: profile.port,
                username: profile.username
            )
            
            let sshClient = AdvancedSSHClient(config: config)
            
            // Set up host key verification
            let hostKeyManager = SSH2HostKeyManager()
            sshClient.hostKeyVerifier = { publicKey, keyType in
                let validator = SSH2HostKeyValidator(hostKeyManager: hostKeyManager, policy: .acceptNew)
                return await validator.validateHostKey(
                    hostname: profile.host,
                    port: profile.port,
                    keyType: keyType,
                    publicKey: publicKey
                )
            }
            
            // Connect to SSH server
            try await sshClient.connect()
            
            // Authenticate
            let credential: SSH2AuthCredential
            if let keyPath = profile.sshKeyPath, !keyPath.isEmpty {
                // Use key-based authentication
                let keyInfo = try SSH2KeyManager.loadPublicKey(from: keyPath + ".pub")
                let privateKeyData = try SSH2KeyManager.loadPrivateKey(from: keyPath, keyType: keyInfo.keyType)
                credential = .publicKey(privateKey: privateKeyData, publicKey: keyInfo.publicKey, keyType: keyInfo.keyType.rawValue)
            } else {
                // Use password authentication (would need to prompt user)
                credential = .password("") // Empty password for demo
            }
            
            try await sshClient.authenticate(with: credential)
            
            // Create terminal session
            let channel = try await sshClient.openChannel()
            try await sshClient.requestPTY(channel: channel)
            try await sshClient.requestShell(channel: channel)
            
            // Post notification with SSH client
            NotificationCenter.default.post(
                name: NSNotification.Name("CreateAdvancedSSHTerminalTab"),
                object: nil,
                userInfo: [
                    "sshClient": sshClient,
                    "channel": channel,
                    "profileName": profile.name
                ]
            )
            
        } catch {
            print("SSH connection failed: \(error)")
            
            // Fallback to simple SSH for backward compatibility
            let connectionInfo = ConnectionInfo(
                type: .ssh,
                host: profile.host,
                port: profile.port,
                username: profile.username,
                password: profile.sshKeyPath ?? ""
            )
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CreateSSHTerminalTab"),
                object: nil,
                userInfo: [
                    "connectionInfo": connectionInfo,
                    "profileName": profile.name
                ]
            )
        }
    }
    
    // MARK: - Bookmark Management
    
    public func addBookmark(_ bookmark: CommandBookmark) {
        bookmarks.append(bookmark)
    }
    
    public func deleteBookmark(_ bookmark: CommandBookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
    }
    
    // MARK: - Shortcut Management
    
    public func addShortcut(_ shortcut: KeyboardShortcut) {
        shortcuts.append(shortcut)
    }
    
    public func updateShortcut(_ shortcut: KeyboardShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
        }
    }
    
    public func deleteShortcut(_ shortcut: KeyboardShortcut) {
        shortcuts.removeAll { $0.id == shortcut.id }
    }
    
    public func executeShortcut(key: String, modifiers: Set<ModifierKey>) -> String? {
        for shortcut in shortcuts {
            if shortcut.key.lowercased() == key.lowercased() && shortcut.modifiers == modifiers {
                return shortcut.action
            }
        }
        return nil
    }
    
    // MARK: - Apply Settings
    
    public func applyTerminalTheme() {
        // This would be called to apply theme settings to terminal sessions
        // Implementation handled through NotificationCenter for loose coupling
        NotificationCenter.default.post(name: NSNotification.Name("SettingsChanged"), object: nil)
    }
    
    // MARK: - Notifications
    
    public func sendNotification(title: String, body: String) {
        guard notificationsEnabled else { return }
        
        #if canImport(AppKit)
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        if notificationSound {
            notification.soundName = NSUserNotificationDefaultSoundName
        }
        NSUserNotificationCenter.default.deliver(notification)
        #else
        // iOS notification handling would go here
        #endif
    }
    
    // MARK: - GPU Acceleration Support
    #if os(macOS)
    public var renderingInfo: String {
        if gpuAcceleration {
            if let device = MTLCreateSystemDefaultDevice() {
                return "GPU Accelerated (\\(device.name))"
            } else {
                return "GPU Acceleration Requested (Metal Not Available)"
            }
        } else {
            return "CPU Rendering"
        }
    }
    
    public var canUseGPUAcceleration: Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
    
    public var shouldUseGPURendering: Bool {
        return gpuAcceleration && canUseGPUAcceleration
    }
    
    public var gpuDeviceInfo: String {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return "Metal Not Available"
        }
        return device.name
    }
    #else
    public var renderingInfo: String {
        return "CPU Rendering (iOS)"
    }
    
    public var canUseGPUAcceleration: Bool {
        return false
    }
    
    public var shouldUseGPURendering: Bool {
        return false
    }
    
    public var gpuDeviceInfo: String {
        return "Not Available on iOS"
    }
    #endif
}

// MARK: - Data Models

struct ColorData: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

public struct CommandBookmark: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var command: String
    public var description: String
    public var category: String
    
    public init(id: UUID = UUID(), name: String, command: String, description: String = "", category: String = "General") {
        self.id = id
        self.name = name
        self.command = command
        self.description = description
        self.category = category
    }
}

public struct KeyboardShortcut: Identifiable, Codable, Hashable {
    public let id: UUID
    public var key: String
    public var modifiers: Set<ModifierKey>
    public var action: String
    public var description: String
    
    public init(id: UUID = UUID(), key: String, modifiers: Set<ModifierKey>, action: String, description: String) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.action = action
        self.description = description
    }
}

public enum ModifierKey: String, Codable {
    case command = "cmd"
    case shift = "shift"
    case option = "opt"
    case control = "ctrl"
}

