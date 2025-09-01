import Foundation
import SwiftUI

// MARK: - Terminal Color Theme System

/// Comprehensive terminal color theme system supporting popular themes
public class TerminalThemeManager: ObservableObject {
    
    @Published public var currentTheme: TerminalTheme
    @Published public var availableThemes: [TerminalTheme]
    
    public static let shared = TerminalThemeManager()
    
    private init() {
        // Initialize with all available themes
        self.availableThemes = TerminalTheme.allThemes
        self.currentTheme = TerminalTheme.draculaTheme
        
        // Load saved theme preference
        loadSavedTheme()
    }
    
    public func setTheme(_ theme: TerminalTheme) {
        currentTheme = theme
        saveTheme()
        
        // Notify system of theme change
        NotificationCenter.default.post(name: .terminalThemeChanged, object: theme)
    }
    
    public func getTheme(by name: String) -> TerminalTheme? {
        return availableThemes.first { $0.name == name }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(currentTheme.name, forKey: "TerminalTheme")
    }
    
    private func loadSavedTheme() {
        if let savedThemeName = UserDefaults.standard.string(forKey: "TerminalTheme"),
           let savedTheme = getTheme(by: savedThemeName) {
            currentTheme = savedTheme
        }
    }
}

// MARK: - Terminal Theme Structure

public struct TerminalTheme: Identifiable, Equatable, Codable {
    public let id = UUID()
    public let name: String
    public let displayName: String
    public let author: String
    public let description: String
    
    // Basic colors
    public let background: ThemeColor
    public let foreground: ThemeColor
    public let cursor: ThemeColor
    public let selection: ThemeColor
    
    // ANSI Colors (16 colors)
    public let ansiBlack: ThemeColor
    public let ansiRed: ThemeColor
    public let ansiGreen: ThemeColor
    public let ansiYellow: ThemeColor
    public let ansiBlue: ThemeColor
    public let ansiMagenta: ThemeColor
    public let ansiCyan: ThemeColor
    public let ansiWhite: ThemeColor
    public let ansiBrightBlack: ThemeColor
    public let ansiBrightRed: ThemeColor
    public let ansiBrightGreen: ThemeColor
    public let ansiBrightYellow: ThemeColor
    public let ansiBrightBlue: ThemeColor
    public let ansiBrightMagenta: ThemeColor
    public let ansiBrightCyan: ThemeColor
    public let ansiBrightWhite: ThemeColor
    
    public static func == (lhs: TerminalTheme, rhs: TerminalTheme) -> Bool {
        lhs.name == rhs.name
    }
}

// MARK: - Theme Color

public struct ThemeColor: Codable, Equatable {
    public let hex: String
    public let alpha: Double
    
    public init(hex: String, alpha: Double = 1.0) {
        self.hex = hex
        self.alpha = alpha
    }
    
    public var color: Color {
        return Color(hex: hex).opacity(alpha)
    }
    
    public var nsColor: NSColor {
        return NSColor(color)
    }
}

// MARK: - Popular Terminal Themes

extension TerminalTheme {
    
    // MARK: - Dracula Theme
    public static let draculaTheme = TerminalTheme(
        name: "dracula",
        displayName: "Dracula",
        author: "Dracula Team",
        description: "A dark theme for many editors, shells, and more",
        background: ThemeColor(hex: "#282a36"),
        foreground: ThemeColor(hex: "#f8f8f2"),
        cursor: ThemeColor(hex: "#f8f8f2"),
        selection: ThemeColor(hex: "#44475a", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#21222c"),
        ansiRed: ThemeColor(hex: "#ff5555"),
        ansiGreen: ThemeColor(hex: "#50fa7b"),
        ansiYellow: ThemeColor(hex: "#f1fa8c"),
        ansiBlue: ThemeColor(hex: "#bd93f9"),
        ansiMagenta: ThemeColor(hex: "#ff79c6"),
        ansiCyan: ThemeColor(hex: "#8be9fd"),
        ansiWhite: ThemeColor(hex: "#f8f8f2"),
        ansiBrightBlack: ThemeColor(hex: "#6272a4"),
        ansiBrightRed: ThemeColor(hex: "#ff6e6e"),
        ansiBrightGreen: ThemeColor(hex: "#69ff94"),
        ansiBrightYellow: ThemeColor(hex: "#ffffa5"),
        ansiBrightBlue: ThemeColor(hex: "#d6acff"),
        ansiBrightMagenta: ThemeColor(hex: "#ff92df"),
        ansiBrightCyan: ThemeColor(hex: "#a4ffff"),
        ansiBrightWhite: ThemeColor(hex: "#ffffff")
    )
    
    // MARK: - Solarized Dark Theme
    public static let solarizedDarkTheme = TerminalTheme(
        name: "solarized-dark",
        displayName: "Solarized Dark",
        author: "Ethan Schoonover",
        description: "Precision colors for machines and people",
        background: ThemeColor(hex: "#002b36"),
        foreground: ThemeColor(hex: "#839496"),
        cursor: ThemeColor(hex: "#93a1a1"),
        selection: ThemeColor(hex: "#073642", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#073642"),
        ansiRed: ThemeColor(hex: "#dc322f"),
        ansiGreen: ThemeColor(hex: "#859900"),
        ansiYellow: ThemeColor(hex: "#b58900"),
        ansiBlue: ThemeColor(hex: "#268bd2"),
        ansiMagenta: ThemeColor(hex: "#d33682"),
        ansiCyan: ThemeColor(hex: "#2aa198"),
        ansiWhite: ThemeColor(hex: "#eee8d5"),
        ansiBrightBlack: ThemeColor(hex: "#586e75"),
        ansiBrightRed: ThemeColor(hex: "#cb4b16"),
        ansiBrightGreen: ThemeColor(hex: "#586e75"),
        ansiBrightYellow: ThemeColor(hex: "#657b83"),
        ansiBrightBlue: ThemeColor(hex: "#839496"),
        ansiBrightMagenta: ThemeColor(hex: "#6c71c4"),
        ansiBrightCyan: ThemeColor(hex: "#93a1a1"),
        ansiBrightWhite: ThemeColor(hex: "#fdf6e3")
    )
    
    // MARK: - Solarized Light Theme
    public static let solarizedLightTheme = TerminalTheme(
        name: "solarized-light",
        displayName: "Solarized Light",
        author: "Ethan Schoonover",
        description: "Light variant of the precision color scheme",
        background: ThemeColor(hex: "#fdf6e3"),
        foreground: ThemeColor(hex: "#657b83"),
        cursor: ThemeColor(hex: "#586e75"),
        selection: ThemeColor(hex: "#eee8d5", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#073642"),
        ansiRed: ThemeColor(hex: "#dc322f"),
        ansiGreen: ThemeColor(hex: "#859900"),
        ansiYellow: ThemeColor(hex: "#b58900"),
        ansiBlue: ThemeColor(hex: "#268bd2"),
        ansiMagenta: ThemeColor(hex: "#d33682"),
        ansiCyan: ThemeColor(hex: "#2aa198"),
        ansiWhite: ThemeColor(hex: "#eee8d5"),
        ansiBrightBlack: ThemeColor(hex: "#002b36"),
        ansiBrightRed: ThemeColor(hex: "#cb4b16"),
        ansiBrightGreen: ThemeColor(hex: "#586e75"),
        ansiBrightYellow: ThemeColor(hex: "#657b83"),
        ansiBrightBlue: ThemeColor(hex: "#839496"),
        ansiBrightMagenta: ThemeColor(hex: "#6c71c4"),
        ansiBrightCyan: ThemeColor(hex: "#93a1a1"),
        ansiBrightWhite: ThemeColor(hex: "#fdf6e3")
    )
    
    // MARK: - Monokai Theme
    public static let monokaiTheme = TerminalTheme(
        name: "monokai",
        displayName: "Monokai",
        author: "Wimer Hazenberg",
        description: "Inspired by the Monokai color scheme for TextMate",
        background: ThemeColor(hex: "#272822"),
        foreground: ThemeColor(hex: "#f8f8f2"),
        cursor: ThemeColor(hex: "#f8f8f0"),
        selection: ThemeColor(hex: "#49483e", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#272822"),
        ansiRed: ThemeColor(hex: "#f92672"),
        ansiGreen: ThemeColor(hex: "#a6e22e"),
        ansiYellow: ThemeColor(hex: "#f4bf75"),
        ansiBlue: ThemeColor(hex: "#66d9ef"),
        ansiMagenta: ThemeColor(hex: "#ae81ff"),
        ansiCyan: ThemeColor(hex: "#a1efe4"),
        ansiWhite: ThemeColor(hex: "#f8f8f2"),
        ansiBrightBlack: ThemeColor(hex: "#75715e"),
        ansiBrightRed: ThemeColor(hex: "#f92672"),
        ansiBrightGreen: ThemeColor(hex: "#a6e22e"),
        ansiBrightYellow: ThemeColor(hex: "#f4bf75"),
        ansiBrightBlue: ThemeColor(hex: "#66d9ef"),
        ansiBrightMagenta: ThemeColor(hex: "#ae81ff"),
        ansiBrightCyan: ThemeColor(hex: "#a1efe4"),
        ansiBrightWhite: ThemeColor(hex: "#f9f8f5")
    )
    
    // MARK: - One Dark Theme
    public static let oneDarkTheme = TerminalTheme(
        name: "one-dark",
        displayName: "One Dark",
        author: "Atom Team",
        description: "Based on Atom's One Dark syntax theme",
        background: ThemeColor(hex: "#282c34"),
        foreground: ThemeColor(hex: "#abb2bf"),
        cursor: ThemeColor(hex: "#528bff"),
        selection: ThemeColor(hex: "#3e4451", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#1e2127"),
        ansiRed: ThemeColor(hex: "#e06c75"),
        ansiGreen: ThemeColor(hex: "#98c379"),
        ansiYellow: ThemeColor(hex: "#d19a66"),
        ansiBlue: ThemeColor(hex: "#61afef"),
        ansiMagenta: ThemeColor(hex: "#c678dd"),
        ansiCyan: ThemeColor(hex: "#56b6c2"),
        ansiWhite: ThemeColor(hex: "#abb2bf"),
        ansiBrightBlack: ThemeColor(hex: "#5c6370"),
        ansiBrightRed: ThemeColor(hex: "#e06c75"),
        ansiBrightGreen: ThemeColor(hex: "#98c379"),
        ansiBrightYellow: ThemeColor(hex: "#d19a66"),
        ansiBrightBlue: ThemeColor(hex: "#61afef"),
        ansiBrightMagenta: ThemeColor(hex: "#c678dd"),
        ansiBrightCyan: ThemeColor(hex: "#56b6c2"),
        ansiBrightWhite: ThemeColor(hex: "#ffffff")
    )
    
    // MARK: - Gruvbox Dark Theme
    public static let gruvboxDarkTheme = TerminalTheme(
        name: "gruvbox-dark",
        displayName: "Gruvbox Dark",
        author: "Pavel Pertsev",
        description: "Retro groove color scheme",
        background: ThemeColor(hex: "#282828"),
        foreground: ThemeColor(hex: "#ebdbb2"),
        cursor: ThemeColor(hex: "#ebdbb2"),
        selection: ThemeColor(hex: "#3c3836", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#282828"),
        ansiRed: ThemeColor(hex: "#cc241d"),
        ansiGreen: ThemeColor(hex: "#98971a"),
        ansiYellow: ThemeColor(hex: "#d79921"),
        ansiBlue: ThemeColor(hex: "#458588"),
        ansiMagenta: ThemeColor(hex: "#b16286"),
        ansiCyan: ThemeColor(hex: "#689d6a"),
        ansiWhite: ThemeColor(hex: "#a89984"),
        ansiBrightBlack: ThemeColor(hex: "#928374"),
        ansiBrightRed: ThemeColor(hex: "#fb4934"),
        ansiBrightGreen: ThemeColor(hex: "#b8bb26"),
        ansiBrightYellow: ThemeColor(hex: "#fabd2f"),
        ansiBrightBlue: ThemeColor(hex: "#83a598"),
        ansiBrightMagenta: ThemeColor(hex: "#d3869b"),
        ansiBrightCyan: ThemeColor(hex: "#8ec07c"),
        ansiBrightWhite: ThemeColor(hex: "#ebdbb2")
    )
    
    // MARK: - Nord Theme
    public static let nordTheme = TerminalTheme(
        name: "nord",
        displayName: "Nord",
        author: "Arctic Ice Studio",
        description: "An arctic, north-bluish color palette",
        background: ThemeColor(hex: "#2e3440"),
        foreground: ThemeColor(hex: "#d8dee9"),
        cursor: ThemeColor(hex: "#d8dee9"),
        selection: ThemeColor(hex: "#434c5e", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#3b4252"),
        ansiRed: ThemeColor(hex: "#bf616a"),
        ansiGreen: ThemeColor(hex: "#a3be8c"),
        ansiYellow: ThemeColor(hex: "#ebcb8b"),
        ansiBlue: ThemeColor(hex: "#81a1c1"),
        ansiMagenta: ThemeColor(hex: "#b48ead"),
        ansiCyan: ThemeColor(hex: "#88c0d0"),
        ansiWhite: ThemeColor(hex: "#e5e9f0"),
        ansiBrightBlack: ThemeColor(hex: "#4c566a"),
        ansiBrightRed: ThemeColor(hex: "#bf616a"),
        ansiBrightGreen: ThemeColor(hex: "#a3be8c"),
        ansiBrightYellow: ThemeColor(hex: "#ebcb8b"),
        ansiBrightBlue: ThemeColor(hex: "#81a1c1"),
        ansiBrightMagenta: ThemeColor(hex: "#b48ead"),
        ansiBrightCyan: ThemeColor(hex: "#8fbcbb"),
        ansiBrightWhite: ThemeColor(hex: "#eceff4")
    )
    
    // MARK: - Tomorrow Night Theme
    public static let tomorrowNightTheme = TerminalTheme(
        name: "tomorrow-night",
        displayName: "Tomorrow Night",
        author: "Chris Kempson",
        description: "The precursor to the Base16 Theme",
        background: ThemeColor(hex: "#1d1f21"),
        foreground: ThemeColor(hex: "#c5c8c6"),
        cursor: ThemeColor(hex: "#c5c8c6"),
        selection: ThemeColor(hex: "#373b41", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#1d1f21"),
        ansiRed: ThemeColor(hex: "#cc6666"),
        ansiGreen: ThemeColor(hex: "#b5bd68"),
        ansiYellow: ThemeColor(hex: "#f0c674"),
        ansiBlue: ThemeColor(hex: "#81a2be"),
        ansiMagenta: ThemeColor(hex: "#b294bb"),
        ansiCyan: ThemeColor(hex: "#8abeb7"),
        ansiWhite: ThemeColor(hex: "#c5c8c6"),
        ansiBrightBlack: ThemeColor(hex: "#969896"),
        ansiBrightRed: ThemeColor(hex: "#cc6666"),
        ansiBrightGreen: ThemeColor(hex: "#b5bd68"),
        ansiBrightYellow: ThemeColor(hex: "#f0c674"),
        ansiBrightBlue: ThemeColor(hex: "#81a2be"),
        ansiBrightMagenta: ThemeColor(hex: "#b294bb"),
        ansiBrightCyan: ThemeColor(hex: "#8abeb7"),
        ansiBrightWhite: ThemeColor(hex: "#ffffff")
    )
    
    // MARK: - Material Theme
    public static let materialTheme = TerminalTheme(
        name: "material",
        displayName: "Material",
        author: "Mattia Astorino",
        description: "Material Design inspired terminal theme",
        background: ThemeColor(hex: "#263238"),
        foreground: ThemeColor(hex: "#eeffff"),
        cursor: ThemeColor(hex: "#ffcc00"),
        selection: ThemeColor(hex: "#314549", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#263238"),
        ansiRed: ThemeColor(hex: "#f07178"),
        ansiGreen: ThemeColor(hex: "#c3e88d"),
        ansiYellow: ThemeColor(hex: "#ffcb6b"),
        ansiBlue: ThemeColor(hex: "#82aaff"),
        ansiMagenta: ThemeColor(hex: "#c792ea"),
        ansiCyan: ThemeColor(hex: "#89ddff"),
        ansiWhite: ThemeColor(hex: "#eeffff"),
        ansiBrightBlack: ThemeColor(hex: "#546e7a"),
        ansiBrightRed: ThemeColor(hex: "#f07178"),
        ansiBrightGreen: ThemeColor(hex: "#c3e88d"),
        ansiBrightYellow: ThemeColor(hex: "#ffcb6b"),
        ansiBrightBlue: ThemeColor(hex: "#82aaff"),
        ansiBrightMagenta: ThemeColor(hex: "#c792ea"),
        ansiBrightCyan: ThemeColor(hex: "#89ddff"),
        ansiBrightWhite: ThemeColor(hex: "#ffffff")
    )
    
    // MARK: - Oceanic Next Theme
    public static let oceanicNextTheme = TerminalTheme(
        name: "oceanic-next",
        displayName: "Oceanic Next",
        author: "Dmitri Voronianski",
        description: "Oceanic Next color scheme",
        background: ThemeColor(hex: "#1b2b34"),
        foreground: ThemeColor(hex: "#d8dee9"),
        cursor: ThemeColor(hex: "#d8dee9"),
        selection: ThemeColor(hex: "#4f5b66", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#343d46"),
        ansiRed: ThemeColor(hex: "#ec5f67"),
        ansiGreen: ThemeColor(hex: "#99c794"),
        ansiYellow: ThemeColor(hex: "#fac863"),
        ansiBlue: ThemeColor(hex: "#6699cc"),
        ansiMagenta: ThemeColor(hex: "#c594c5"),
        ansiCyan: ThemeColor(hex: "#5fb3b3"),
        ansiWhite: ThemeColor(hex: "#d8dee9"),
        ansiBrightBlack: ThemeColor(hex: "#65737e"),
        ansiBrightRed: ThemeColor(hex: "#ec5f67"),
        ansiBrightGreen: ThemeColor(hex: "#99c794"),
        ansiBrightYellow: ThemeColor(hex: "#fac863"),
        ansiBrightBlue: ThemeColor(hex: "#6699cc"),
        ansiBrightMagenta: ThemeColor(hex: "#c594c5"),
        ansiBrightCyan: ThemeColor(hex: "#5fb3b3"),
        ansiBrightWhite: ThemeColor(hex: "#ffffff")
    )
    
    // MARK: - Ayu Dark Theme
    public static let ayuDarkTheme = TerminalTheme(
        name: "ayu-dark",
        displayName: "Ayu Dark",
        author: "Ayu Team",
        description: "Modern and minimalistic theme",
        background: ThemeColor(hex: "#0f1419"),
        foreground: ThemeColor(hex: "#e6e1cf"),
        cursor: ThemeColor(hex: "#f29718"),
        selection: ThemeColor(hex: "#253340", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#000000"),
        ansiRed: ThemeColor(hex: "#f34c2b"),
        ansiGreen: ThemeColor(hex: "#8fb573"),
        ansiYellow: ThemeColor(hex: "#e7c547"),
        ansiBlue: ThemeColor(hex: "#36a3d9"),
        ansiMagenta: ThemeColor(hex: "#b367ce"),
        ansiCyan: ThemeColor(hex: "#7fb4ca"),
        ansiWhite: ThemeColor(hex: "#e6e1cf"),
        ansiBrightBlack: ThemeColor(hex: "#323232"),
        ansiBrightRed: ThemeColor(hex: "#ff6565"),
        ansiBrightGreen: ThemeColor(hex: "#9acd68"),
        ansiBrightYellow: ThemeColor(hex: "#f29718"),
        ansiBrightBlue: ThemeColor(hex: "#68d5ff"),
        ansiBrightMagenta: ThemeColor(hex: "#df9cf3"),
        ansiBrightCyan: ThemeColor(hex: "#95e6cb"),
        ansiBrightWhite: ThemeColor(hex: "#ffffff")
    )
    
    // MARK: - Catppuccin Mocha Theme
    public static let catppuccinMochaTheme = TerminalTheme(
        name: "catppuccin-mocha",
        displayName: "Catppuccin Mocha",
        author: "Catppuccin Team",
        description: "Soothing pastel theme for the high-spirited!",
        background: ThemeColor(hex: "#1e1e2e"),
        foreground: ThemeColor(hex: "#cdd6f4"),
        cursor: ThemeColor(hex: "#f5e0dc"),
        selection: ThemeColor(hex: "#313244", alpha: 0.7),
        ansiBlack: ThemeColor(hex: "#45475a"),
        ansiRed: ThemeColor(hex: "#f38ba8"),
        ansiGreen: ThemeColor(hex: "#a6e3a1"),
        ansiYellow: ThemeColor(hex: "#f9e2af"),
        ansiBlue: ThemeColor(hex: "#89b4fa"),
        ansiMagenta: ThemeColor(hex: "#f5c2e7"),
        ansiCyan: ThemeColor(hex: "#94e2d5"),
        ansiWhite: ThemeColor(hex: "#bac2de"),
        ansiBrightBlack: ThemeColor(hex: "#585b70"),
        ansiBrightRed: ThemeColor(hex: "#f38ba8"),
        ansiBrightGreen: ThemeColor(hex: "#a6e3a1"),
        ansiBrightYellow: ThemeColor(hex: "#f9e2af"),
        ansiBrightBlue: ThemeColor(hex: "#89b4fa"),
        ansiBrightMagenta: ThemeColor(hex: "#f5c2e7"),
        ansiBrightCyan: ThemeColor(hex: "#94e2d5"),
        ansiBrightWhite: ThemeColor(hex: "#a6adc8")
    )
    
    // MARK: - All Themes Collection
    public static let allThemes: [TerminalTheme] = [
        draculaTheme,
        solarizedDarkTheme,
        solarizedLightTheme,
        monokaiTheme,
        oneDarkTheme,
        gruvboxDarkTheme,
        nordTheme,
        tomorrowNightTheme,
        materialTheme,
        oceanicNextTheme,
        ayuDarkTheme,
        catppuccinMochaTheme
    ]
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - NSColor Extension

extension NSColor {
    convenience init(_ color: Color) {
        let nsColor = NSColor(color)
        self.init(red: nsColor.redComponent,
                 green: nsColor.greenComponent,
                 blue: nsColor.blueComponent,
                 alpha: nsColor.alphaComponent)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let terminalThemeChanged = Notification.Name("terminalThemeChanged")
}