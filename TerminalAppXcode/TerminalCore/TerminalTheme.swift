import SwiftUI
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Terminal Theme Management

public struct TerminalFont {
    public let family: String
    public let size: CGFloat
    public let weight: Font.Weight
    
    public static let defaultMonospace = TerminalFont(family: "Menlo", size: 12, weight: .regular)
    public static let smallMonospace = TerminalFont(family: "Menlo", size: 10, weight: .regular)
    public static let largeMonospace = TerminalFont(family: "Menlo", size: 14, weight: .regular)
    
    public func swiftUIFont() -> Font {
        return Font.custom(family, size: size).weight(weight)
    }
    
    #if canImport(AppKit)
    public func nsFont() -> NSFont {
        let nsWeight = nsWeight(from: weight)
        return NSFont(name: family, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: nsWeight)
    }
    
    private func nsWeight(from weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
    #endif
    
    #if canImport(UIKit)
    public func uiFont() -> UIFont {
        let uiWeight = uiWeight(from: weight)
        return UIFont(name: family, size: size) ?? UIFont.monospacedSystemFont(ofSize: size, weight: uiWeight)
    }
    
    private func uiWeight(from weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
    #endif
}

public struct TerminalColorScheme {
    public let name: String
    public let background: Color
    public let foreground: Color
    public let cursor: Color
    public let selection: Color
    public let black: Color
    public let red: Color
    public let green: Color
    public let yellow: Color
    public let blue: Color
    public let magenta: Color
    public let cyan: Color
    public let white: Color
    public let brightBlack: Color
    public let brightRed: Color
    public let brightGreen: Color
    public let brightYellow: Color
    public let brightBlue: Color
    public let brightMagenta: Color
    public let brightCyan: Color
    public let brightWhite: Color
    
    // Predefined color schemes
    public static let defaultDark = TerminalColorScheme(
        name: "Default Dark",
        background: Color.black,
        foreground: Color.green,
        cursor: Color.green,
        selection: Color.blue.opacity(0.3),
        black: Color.black,
        red: Color.red,
        green: Color.green,
        yellow: Color.yellow,
        blue: Color.blue,
        magenta: Color.purple,
        cyan: Color.cyan,
        white: Color.white,
        brightBlack: Color.gray,
        brightRed: Color.red.opacity(0.8),
        brightGreen: Color.green.opacity(0.8),
        brightYellow: Color.yellow.opacity(0.8),
        brightBlue: Color.blue.opacity(0.8),
        brightMagenta: Color.purple.opacity(0.8),
        brightCyan: Color.cyan.opacity(0.8),
        brightWhite: Color.white.opacity(0.9)
    )
    
    public static let solarizedDark = TerminalColorScheme(
        name: "Solarized Dark",
        background: Color(red: 0.0, green: 0.168, blue: 0.211),
        foreground: Color(red: 0.514, green: 0.580, blue: 0.588),
        cursor: Color(red: 0.514, green: 0.580, blue: 0.588),
        selection: Color(red: 0.0, green: 0.168, blue: 0.211).opacity(0.5),
        black: Color(red: 0.0, green: 0.168, blue: 0.211),
        red: Color(red: 0.863, green: 0.196, blue: 0.184),
        green: Color(red: 0.522, green: 0.600, blue: 0.0),
        yellow: Color(red: 0.710, green: 0.537, blue: 0.0),
        blue: Color(red: 0.149, green: 0.545, blue: 0.824),
        magenta: Color(red: 0.827, green: 0.211, blue: 0.510),
        cyan: Color(red: 0.164, green: 0.631, blue: 0.596),
        white: Color(red: 0.933, green: 0.910, blue: 0.835),
        brightBlack: Color(red: 0.0, green: 0.168, blue: 0.211),
        brightRed: Color(red: 0.796, green: 0.294, blue: 0.086),
        brightGreen: Color(red: 0.345, green: 0.431, blue: 0.459),
        brightYellow: Color(red: 0.396, green: 0.482, blue: 0.514),
        brightBlue: Color(red: 0.514, green: 0.580, blue: 0.588),
        brightMagenta: Color(red: 0.576, green: 0.631, blue: 0.631),
        brightCyan: Color(red: 0.992, green: 0.965, blue: 0.890),
        brightWhite: Color(red: 0.992, green: 0.965, blue: 0.890)
    )
    
    public static let monokai = TerminalColorScheme(
        name: "Monokai",
        background: Color(red: 0.157, green: 0.157, blue: 0.118),
        foreground: Color(red: 0.973, green: 0.973, blue: 0.949),
        cursor: Color(red: 0.973, green: 0.973, blue: 0.949),
        selection: Color(red: 0.157, green: 0.157, blue: 0.118).opacity(0.5),
        black: Color(red: 0.157, green: 0.157, blue: 0.118),
        red: Color(red: 0.976, green: 0.149, blue: 0.447),
        green: Color(red: 0.651, green: 0.886, blue: 0.180),
        yellow: Color(red: 0.976, green: 0.875, blue: 0.075),
        blue: Color(red: 0.400, green: 0.851, blue: 0.937),
        magenta: Color(red: 0.682, green: 0.506, blue: 1.0),
        cyan: Color(red: 0.400, green: 0.851, blue: 0.937),
        white: Color(red: 0.973, green: 0.973, blue: 0.949),
        brightBlack: Color(red: 0.459, green: 0.459, blue: 0.459),
        brightRed: Color(red: 0.976, green: 0.149, blue: 0.447),
        brightGreen: Color(red: 0.651, green: 0.886, blue: 0.180),
        brightYellow: Color(red: 0.976, green: 0.875, blue: 0.075),
        brightBlue: Color(red: 0.400, green: 0.851, blue: 0.937),
        brightMagenta: Color(red: 0.682, green: 0.506, blue: 1.0),
        brightCyan: Color(red: 0.400, green: 0.851, blue: 0.937),
        brightWhite: Color(red: 0.973, green: 0.973, blue: 0.949)
    )
    
    public static let dracula = TerminalColorScheme(
        name: "Dracula",
        background: Color(red: 0.157, green: 0.165, blue: 0.212),
        foreground: Color(red: 0.945, green: 0.980, blue: 1.0),
        cursor: Color(red: 0.945, green: 0.980, blue: 1.0),
        selection: Color(red: 0.275, green: 0.275, blue: 0.353),
        black: Color(red: 0.0, green: 0.0, blue: 0.0),
        red: Color(red: 1.0, green: 0.333, blue: 0.333),
        green: Color(red: 0.314, green: 0.980, blue: 0.482),
        yellow: Color(red: 0.945, green: 0.980, blue: 0.549),
        blue: Color(red: 0.741, green: 0.576, blue: 0.976),
        magenta: Color(red: 1.0, green: 0.475, blue: 0.776),
        cyan: Color(red: 0.553, green: 0.918, blue: 0.996),
        white: Color(red: 0.945, green: 0.980, blue: 1.0),
        brightBlack: Color(red: 0.275, green: 0.275, blue: 0.353),
        brightRed: Color(red: 1.0, green: 0.333, blue: 0.333),
        brightGreen: Color(red: 0.314, green: 0.980, blue: 0.482),
        brightYellow: Color(red: 0.945, green: 0.980, blue: 0.549),
        brightBlue: Color(red: 0.741, green: 0.576, blue: 0.976),
        brightMagenta: Color(red: 1.0, green: 0.475, blue: 0.776),
        brightCyan: Color(red: 0.553, green: 0.918, blue: 0.996),
        brightWhite: Color(red: 0.945, green: 0.980, blue: 1.0)
    )
    
    public static let allSchemes = [defaultDark, solarizedDark, monokai, dracula]
}

#if canImport(AppKit)
// MARK: - Color Extensions for NSColor conversion
extension Color {
    public var nsColor: NSColor {
        return NSColor(self)
    }
}
#endif

public class TerminalTheme: ObservableObject {
    @Published public var font: TerminalFont = .defaultMonospace
    @Published public var colorScheme: TerminalColorScheme = .defaultDark
    @Published public var opacity: Double = 0.95
    @Published public var blurEffect: Bool = true
    @Published public var cursorBlinkRate: Double = 0.5
    @Published public var lineSpacing: CGFloat = 1.2
    
    public static let shared = TerminalTheme()
    
    private init() {
        loadFromUserDefaults()
    }
    
    // Available fonts
    public static let availableFonts = [
        TerminalFont(family: "Menlo", size: 12, weight: .regular),
        TerminalFont(family: "Monaco", size: 12, weight: .regular),
        TerminalFont(family: "SF Mono", size: 12, weight: .regular),
        TerminalFont(family: "Courier New", size: 12, weight: .regular),
        TerminalFont(family: "JetBrains Mono", size: 12, weight: .regular),
        TerminalFont(family: "Fira Code", size: 12, weight: .regular)
    ]
    
    public static let fontSizes: [CGFloat] = [8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24]
    
    public func updateFont(family: String? = nil, size: CGFloat? = nil, weight: Font.Weight? = nil) {
        font = TerminalFont(
            family: family ?? font.family,
            size: size ?? font.size,
            weight: weight ?? font.weight
        )
        saveToUserDefaults()
    }
    
    public func updateColorScheme(_ scheme: TerminalColorScheme) {
        colorScheme = scheme
        saveToUserDefaults()
    }
    
    public func updateOpacity(_ newOpacity: Double) {
        opacity = newOpacity
        saveToUserDefaults()
    }
    
    public func updateBlurEffect(_ enabled: Bool) {
        blurEffect = enabled
        saveToUserDefaults()
    }
    
    public func updateCursorBlinkRate(_ rate: Double) {
        cursorBlinkRate = rate
        saveToUserDefaults()
    }
    
    public func updateLineSpacing(_ spacing: CGFloat) {
        lineSpacing = spacing
        saveToUserDefaults()
    }
    
    private func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        
        // Load font settings
        if let fontFamily = defaults.object(forKey: "terminal_font_family") as? String {
            let fontSize = defaults.object(forKey: "terminal_font_size") as? CGFloat ?? 12
            let fontWeightRaw = defaults.object(forKey: "terminal_font_weight") as? String ?? "regular"
            let fontWeight = Font.Weight.from(string: fontWeightRaw)
            font = TerminalFont(family: fontFamily, size: fontSize, weight: fontWeight)
        }
        
        // Load color scheme
        if let schemeName = defaults.object(forKey: "terminal_color_scheme") as? String {
            if let scheme = TerminalColorScheme.allSchemes.first(where: { $0.name == schemeName }) {
                colorScheme = scheme
            }
        }
        
        // Load other settings
        opacity = defaults.object(forKey: "terminal_opacity") as? Double ?? 0.95
        blurEffect = defaults.object(forKey: "terminal_blur_effect") as? Bool ?? true
        cursorBlinkRate = defaults.object(forKey: "terminal_cursor_blink_rate") as? Double ?? 0.5
        lineSpacing = defaults.object(forKey: "terminal_line_spacing") as? CGFloat ?? 1.2
    }
    
    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        
        defaults.set(font.family, forKey: "terminal_font_family")
        defaults.set(font.size, forKey: "terminal_font_size")
        defaults.set(font.weight.stringValue, forKey: "terminal_font_weight")
        defaults.set(colorScheme.name, forKey: "terminal_color_scheme")
        defaults.set(opacity, forKey: "terminal_opacity")
        defaults.set(blurEffect, forKey: "terminal_blur_effect")
        defaults.set(cursorBlinkRate, forKey: "terminal_cursor_blink_rate")
        defaults.set(lineSpacing, forKey: "terminal_line_spacing")
    }
}

// MARK: - Extensions for convenience

extension Font.Weight {
    static func from(string: String) -> Font.Weight {
        switch string.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
    
    var stringValue: String {
        switch self {
        case .ultraLight: return "ultralight"
        case .thin: return "thin"
        case .light: return "light"
        case .regular: return "regular"
        case .medium: return "medium"
        case .semibold: return "semibold"
        case .bold: return "bold"
        case .heavy: return "heavy"
        case .black: return "black"
        default: return "regular"
        }
    }
}