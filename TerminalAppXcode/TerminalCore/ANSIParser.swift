import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Theme Stubs (for compilation)

public struct ThemeColor: Codable, Equatable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let alpha: CGFloat
    
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    #if canImport(AppKit)
    public var nsColor: NSColor {
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
}

// Extension to add ANSI color properties to existing TerminalTheme
extension TerminalTheme {
    // ANSI colors
    public var ansiBlack: ThemeColor { ThemeColor(red: 0, green: 0, blue: 0) }
    public var ansiRed: ThemeColor { ThemeColor(red: 1, green: 0, blue: 0) }
    public var ansiGreen: ThemeColor { ThemeColor(red: 0, green: 1, blue: 0) }
    public var ansiYellow: ThemeColor { ThemeColor(red: 1, green: 1, blue: 0) }
    public var ansiBlue: ThemeColor { ThemeColor(red: 0, green: 0, blue: 1) }
    public var ansiMagenta: ThemeColor { ThemeColor(red: 1, green: 0, blue: 1) }
    public var ansiCyan: ThemeColor { ThemeColor(red: 0, green: 1, blue: 1) }
    public var ansiWhite: ThemeColor { ThemeColor(red: 1, green: 1, blue: 1) }
    
    // Bright ANSI colors
    public var ansiBrightBlack: ThemeColor { ThemeColor(red: 0.5, green: 0.5, blue: 0.5) }
    public var ansiBrightRed: ThemeColor { ThemeColor(red: 1, green: 0.5, blue: 0.5) }
    public var ansiBrightGreen: ThemeColor { ThemeColor(red: 0.5, green: 1, blue: 0.5) }
    public var ansiBrightYellow: ThemeColor { ThemeColor(red: 1, green: 1, blue: 0.5) }
    public var ansiBrightBlue: ThemeColor { ThemeColor(red: 0.5, green: 0.5, blue: 1) }
    public var ansiBrightMagenta: ThemeColor { ThemeColor(red: 1, green: 0.5, blue: 1) }
    public var ansiBrightCyan: ThemeColor { ThemeColor(red: 0.5, green: 1, blue: 1) }
    public var ansiBrightWhite: ThemeColor { ThemeColor(red: 1, green: 1, blue: 1) }
    
    // Background and foreground
    public var background: ThemeColor { ThemeColor(red: 0, green: 0, blue: 0) }
    public var foreground: ThemeColor { ThemeColor(red: 1, green: 1, blue: 1) }
}

public class TerminalThemeManager: ObservableObject {
    public static let shared = TerminalThemeManager()
    public var currentTheme: TerminalTheme { TerminalTheme.shared }
    private init() {}
}

extension Notification.Name {
    static let terminalThemeChanged = Notification.Name("terminalThemeChanged")
}

public struct ANSIColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat
    
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    #if canImport(AppKit)
    public var nsColor: NSColor {
        return NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
    
    #if canImport(UIKit)
    public var uiColor: UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif
}

public struct TextAttributes {
    var foregroundColor: ANSIColor?
    var backgroundColor: ANSIColor?
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderlined: Bool = false
    var isStrikethrough: Bool = false
    var isDim: Bool = false
    var isReversed: Bool = false
    
    public init() {}
    
    #if canImport(AppKit)
    public func nsAttributes(defaultForeground: NSColor, defaultBackground: NSColor, font: NSFont) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        // Font handling
        var finalFont = font
        if isBold || isDim {
            let weight: NSFont.Weight = isBold ? .bold : (isDim ? .light : .regular)
            finalFont = NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: weight)
        }
        attributes[.font] = finalFont
        
        // Color handling
        let fgColor = isReversed ? (backgroundColor?.nsColor ?? defaultBackground) : (foregroundColor?.nsColor ?? defaultForeground)
        let bgColor = isReversed ? (foregroundColor?.nsColor ?? defaultForeground) : (backgroundColor?.nsColor ?? defaultBackground)
        
        attributes[.foregroundColor] = fgColor
        attributes[.backgroundColor] = bgColor
        
        // Text decorations
        if isUnderlined {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if isStrikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        
        return attributes
    }
    #endif
    
    #if canImport(UIKit)
    public func uiAttributes(defaultForeground: UIColor, defaultBackground: UIColor, font: UIFont) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        // Font handling
        var finalFont = font
        if isBold || isDim {
            let weight: UIFont.Weight = isBold ? .bold : (isDim ? .light : .regular)
            finalFont = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: weight)
        }
        attributes[.font] = finalFont
        
        // Color handling
        let fgColor = isReversed ? (backgroundColor?.uiColor ?? defaultBackground) : (foregroundColor?.uiColor ?? defaultForeground)
        let bgColor = isReversed ? (foregroundColor?.uiColor ?? defaultForeground) : (backgroundColor?.uiColor ?? defaultBackground)
        
        attributes[.foregroundColor] = fgColor
        attributes[.backgroundColor] = bgColor
        
        // Text decorations
        if isUnderlined {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if isStrikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        
        return attributes
    }
    #endif
}

public struct ANSIStyledText {
    let text: String
    let attributes: TextAttributes
    
    public init(text: String, attributes: TextAttributes) {
        self.text = text
        self.attributes = attributes
    }
}

public class ANSIParser {
    // Theme-based colors - these are populated from the current theme
    private static var currentTheme: TerminalTheme = TerminalThemeManager.shared.currentTheme
    
    // Listen for theme changes
    private static var themeObserver: NSObjectProtocol? = {
        NotificationCenter.default.addObserver(
            forName: .terminalThemeChanged,
            object: nil,
            queue: .main
        ) { notification in
            if let theme = notification.object as? TerminalTheme {
                currentTheme = theme
            }
        }
    }()
    
    private static var standardColors: [ANSIColor] {
        return [
            themeColorToANSI(currentTheme.ansiBlack),     // Black
            themeColorToANSI(currentTheme.ansiRed),       // Red
            themeColorToANSI(currentTheme.ansiGreen),     // Green
            themeColorToANSI(currentTheme.ansiYellow),    // Yellow
            themeColorToANSI(currentTheme.ansiBlue),      // Blue
            themeColorToANSI(currentTheme.ansiMagenta),   // Magenta
            themeColorToANSI(currentTheme.ansiCyan),      // Cyan
            themeColorToANSI(currentTheme.ansiWhite)      // White
        ]
    }
    
    private static var brightColors: [ANSIColor] {
        return [
            themeColorToANSI(currentTheme.ansiBrightBlack),    // Bright Black
            themeColorToANSI(currentTheme.ansiBrightRed),      // Bright Red
            themeColorToANSI(currentTheme.ansiBrightGreen),    // Bright Green
            themeColorToANSI(currentTheme.ansiBrightYellow),   // Bright Yellow
            themeColorToANSI(currentTheme.ansiBrightBlue),     // Bright Blue
            themeColorToANSI(currentTheme.ansiBrightMagenta),  // Bright Magenta
            themeColorToANSI(currentTheme.ansiBrightCyan),     // Bright Cyan
            themeColorToANSI(currentTheme.ansiBrightWhite)     // Bright White
        ]
    }
    
    // Convert ThemeColor to ANSIColor
    private static func themeColorToANSI(_ themeColor: ThemeColor) -> ANSIColor {
        return ANSIColor(
            red: themeColor.red,
            green: themeColor.green, 
            blue: themeColor.blue,
            alpha: themeColor.alpha
        )
    }
    
    public static func parseANSIString(_ input: String) -> [ANSIStyledText] {
        var results: [ANSIStyledText] = []
        var currentAttributes = TextAttributes()
        var currentText = ""
        var i = input.startIndex
        
        while i < input.endIndex {
            if input[i] == "\u{1B}" && i < input.index(before: input.endIndex) && input[input.index(after: i)] == "[" {
                // Found ANSI escape sequence
                
                // Add any accumulated text with current attributes
                if !currentText.isEmpty {
                    results.append(ANSIStyledText(text: currentText, attributes: currentAttributes))
                    currentText = ""
                }
                
                // Parse the escape sequence
                let escapeStart = i
                i = input.index(i, offsetBy: 2) // Skip "\u{1B}["
                
                // Find the end of the escape sequence
                var sequenceEnd = i
                while sequenceEnd < input.endIndex {
                    let char = input[sequenceEnd]
                    if char.isLetter || char == "~" {
                        break
                    }
                    sequenceEnd = input.index(after: sequenceEnd)
                }
                
                if sequenceEnd < input.endIndex {
                    let sequence = String(input[i..<sequenceEnd])
                    let command = input[sequenceEnd]
                    
                    // Process the escape sequence
                    currentAttributes = processEscapeSequence(sequence, command: command, currentAttributes: currentAttributes)
                    
                    i = input.index(after: sequenceEnd)
                } else {
                    // Malformed escape sequence, treat as regular text
                    currentText.append(input[escapeStart])
                    i = input.index(after: escapeStart)
                }
            } else {
                // Regular character
                currentText.append(input[i])
                i = input.index(after: i)
            }
        }
        
        // Add any remaining text
        if !currentText.isEmpty {
            results.append(ANSIStyledText(text: currentText, attributes: currentAttributes))
        }
        
        return results
    }
    
    private static func processEscapeSequence(_ sequence: String, command: Character, currentAttributes: TextAttributes) -> TextAttributes {
        var attributes = currentAttributes
        
        switch command {
        case "m": // SGR (Select Graphic Rendition)
            let codes = sequence.split(separator: ";").compactMap { Int($0) }
            if codes.isEmpty {
                // Reset to default
                attributes = TextAttributes()
            } else {
                for code in codes {
                    attributes = processSGRCode(code, attributes: attributes)
                }
            }
        case "K": // Erase in Line
            // For now, ignore cursor positioning commands
            break
        case "H", "f": // Cursor Position
            // For now, ignore cursor positioning commands
            break
        case "A", "B", "C", "D": // Cursor movement
            // For now, ignore cursor movement commands
            break
        default:
            // Unknown command, ignore
            break
        }
        
        return attributes
    }
    
    private static func processSGRCode(_ code: Int, attributes: TextAttributes) -> TextAttributes {
        var result = attributes
        
        switch code {
        case 0: // Reset
            result = TextAttributes()
        case 1: // Bold
            result.isBold = true
        case 2: // Dim
            result.isDim = true
        case 3: // Italic
            result.isItalic = true
        case 4: // Underline
            result.isUnderlined = true
        case 7: // Reverse
            result.isReversed = true
        case 9: // Strikethrough
            result.isStrikethrough = true
        case 22: // Normal intensity (not bold or dim)
            result.isBold = false
            result.isDim = false
        case 23: // Not italic
            result.isItalic = false
        case 24: // Not underlined
            result.isUnderlined = false
        case 27: // Not reversed
            result.isReversed = false
        case 29: // Not strikethrough
            result.isStrikethrough = false
        case 30...37: // Foreground colors
            result.foregroundColor = standardColors[code - 30]
        case 38: // Extended foreground color (256-color or RGB)
            // TODO: Implement 256-color and RGB support
            break
        case 39: // Default foreground color
            result.foregroundColor = nil
        case 40...47: // Background colors
            result.backgroundColor = standardColors[code - 40]
        case 48: // Extended background color (256-color or RGB)
            // TODO: Implement 256-color and RGB support
            break
        case 49: // Default background color
            result.backgroundColor = nil
        case 90...97: // Bright foreground colors
            result.foregroundColor = brightColors[code - 90]
        case 100...107: // Bright background colors
            result.backgroundColor = brightColors[code - 100]
        default:
            // Unknown code, ignore
            break
        }
        
        return result
    }
    
    #if canImport(AppKit)
    public static func attributedStringFromANSI(_ input: String, defaultForeground: NSColor, defaultBackground: NSColor, font: NSFont) -> NSAttributedString {
        let styledTexts = parseANSIString(input)
        let result = NSMutableAttributedString()
        
        for styledText in styledTexts {
            let attributes = styledText.attributes.nsAttributes(
                defaultForeground: defaultForeground,
                defaultBackground: defaultBackground,
                font: font
            )
            let attributedString = NSAttributedString(string: styledText.text, attributes: attributes)
            result.append(attributedString)
        }
        
        return result
    }
    #endif
    
    #if canImport(UIKit)
    public static func attributedStringFromANSI(_ input: String, defaultForeground: UIColor, defaultBackground: UIColor, font: UIFont) -> NSAttributedString {
        let styledTexts = parseANSIString(input)
        let result = NSMutableAttributedString()
        
        for styledText in styledTexts {
            let attributes = styledText.attributes.uiAttributes(
                defaultForeground: defaultForeground,
                defaultBackground: defaultBackground,
                font: font
            )
            let attributedString = NSAttributedString(string: styledText.text, attributes: attributes)
            result.append(attributedString)
        }
        
        return result
    }
    #endif
}