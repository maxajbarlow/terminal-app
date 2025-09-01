import Foundation
import SwiftUI

// MARK: - Connection Profile Data Model

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

// MARK: - Codable Implementation

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