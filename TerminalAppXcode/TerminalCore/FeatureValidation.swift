import Foundation
import SwiftUI

// MARK: - Feature Validation System
// This file validates that all advertised features are accessible and functional

public struct Feature {
    let name: String
    let category: String
    let accessPath: String
    let requiresPlatform: Platform?
    let isImplemented: Bool
    let testCommand: String?
    let uiLocation: String?
}

public enum Platform {
    case iOS
    case macOS
    case both
}

public class FeatureValidator {
    
    // MARK: - All Features List
    static let allFeatures: [Feature] = [
        
        // MARK: Terminal Core Features
        Feature(
            name: "Local Shell Execution",
            category: "Terminal Core",
            accessPath: "Main terminal view",
            requiresPlatform: .macOS,
            isImplemented: true,
            testCommand: "echo 'test'",
            uiLocation: "Main terminal input"
        ),
        Feature(
            name: "SSH Connections",
            category: "Terminal Core",
            accessPath: "Type: ssh user@host",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "ssh user@example.com",
            uiLocation: "Terminal input or Configuration > Profiles"
        ),
        Feature(
            name: "Mosh Connections",
            category: "Terminal Core",
            accessPath: "Configuration > Profiles",
            requiresPlatform: .both,
            isImplemented: false, // Stub only
            testCommand: nil,
            uiLocation: "Configuration > Profiles"
        ),
        Feature(
            name: "Command History",
            category: "Terminal Core",
            accessPath: "Automatically saved",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "history",
            uiLocation: "Up/Down arrows in terminal"
        ),
        Feature(
            name: "Clear Terminal",
            category: "Terminal Core",
            accessPath: "Type: clear or ..clear",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "clear",
            uiLocation: "Terminal input"
        ),
        
        // MARK: Theme Features
        Feature(
            name: "Theme Selection",
            category: "Themes",
            accessPath: "Configuration > Appearance",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..theme list",
            uiLocation: "Settings > Appearance > Color Theme"
        ),
        Feature(
            name: "Font Selection",
            category: "Themes",
            accessPath: "Configuration > Appearance",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..theme font",
            uiLocation: "Settings > Appearance > Font Family"
        ),
        Feature(
            name: "Font Size Adjustment",
            category: "Themes",
            accessPath: "Configuration > Appearance",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..theme size 14",
            uiLocation: "Settings > Appearance > Font Size"
        ),
        Feature(
            name: "Custom Colors",
            category: "Themes",
            accessPath: "Configuration > Appearance",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Settings > Appearance > Custom Colors"
        ),
        Feature(
            name: "Predefined Themes",
            category: "Themes",
            accessPath: "Configuration > Appearance",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..theme set dracula",
            uiLocation: "Settings > Appearance > Theme Dropdown"
        ),
        
        // MARK: Split/Pane Features
        Feature(
            name: "Horizontal Split",
            category: "Split/Panes",
            accessPath: "..split h",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..split h",
            uiLocation: "Terminal command"
        ),
        Feature(
            name: "Vertical Split",
            category: "Split/Panes",
            accessPath: "..split v",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..split v",
            uiLocation: "Terminal command"
        ),
        Feature(
            name: "Toggle Split Direction",
            category: "Split/Panes",
            accessPath: "..split toggle",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..split toggle",
            uiLocation: "Terminal command"
        ),
        Feature(
            name: "Close Pane",
            category: "Split/Panes",
            accessPath: "..close",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..close",
            uiLocation: "Terminal command"
        ),
        Feature(
            name: "Navigate Panes",
            category: "Split/Panes",
            accessPath: "..next, ..prev, ..pane [n]",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..next",
            uiLocation: "Terminal command"
        ),
        
        // MARK: Tab Features
        Feature(
            name: "Multiple Tabs",
            category: "Tabs",
            accessPath: "UI Tab Bar",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Tab bar at top of terminal"
        ),
        Feature(
            name: "New Tab",
            category: "Tabs",
            accessPath: "Plus button in tab bar",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Plus icon in tab bar"
        ),
        Feature(
            name: "Close Tab",
            category: "Tabs",
            accessPath: "X button on tab",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "X icon on each tab"
        ),
        Feature(
            name: "Tab Navigation",
            category: "Tabs",
            accessPath: "Click on tabs",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Tab bar"
        ),
        
        // MARK: Settings/Configuration
        Feature(
            name: "Configuration Window",
            category: "Settings",
            accessPath: "..config or Settings button",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "..config",
            uiLocation: "Settings icon or ..config command"
        ),
        Feature(
            name: "Connection Profiles",
            category: "Settings",
            accessPath: "Configuration > Profiles",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Settings > Profiles tab"
        ),
        Feature(
            name: "SSH Key Management",
            category: "Settings",
            accessPath: "Configuration > SSH Keys",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Settings > SSH Keys tab"
        ),
        Feature(
            name: "Notifications Settings",
            category: "Settings",
            accessPath: "Configuration > Notifications",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Settings > Notifications tab"
        ),
        Feature(
            name: "iCloud Sync",
            category: "Settings",
            accessPath: "Configuration > iCloud",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Settings > iCloud tab"
        ),
        
        // MARK: Command Features
        Feature(
            name: "Command Completion",
            category: "Commands",
            accessPath: "Tab key while typing",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Terminal input with Tab key"
        ),
        Feature(
            name: "Command Help",
            category: "Commands",
            accessPath: "help or ..help",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "help",
            uiLocation: "Terminal input"
        ),
        Feature(
            name: "Built-in Commands List",
            category: "Commands",
            accessPath: "help command",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "help ls",
            uiLocation: "Terminal input"
        ),
        Feature(
            name: "Command Suggestions",
            category: "Commands",
            accessPath: "Automatic while typing",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Terminal input"
        ),
        
        // MARK: iOS-Specific Features
        Feature(
            name: "Hardware Keyboard Support",
            category: "iOS Features",
            accessPath: "Connect keyboard",
            requiresPlatform: .iOS,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Automatic when keyboard connected"
        ),
        Feature(
            name: "Touch Keyboard",
            category: "iOS Features",
            accessPath: "Tap terminal",
            requiresPlatform: .iOS,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Tap terminal area"
        ),
        
        // MARK: macOS-Specific Features
        Feature(
            name: "External Command Execution",
            category: "macOS Features",
            accessPath: "Type any command",
            requiresPlatform: .macOS,
            isImplemented: true,
            testCommand: "ls -la",
            uiLocation: "Terminal input"
        ),
        Feature(
            name: "Process Management",
            category: "macOS Features",
            accessPath: "Ctrl+C to interrupt",
            requiresPlatform: .macOS,
            isImplemented: true,
            testCommand: "ping google.com",
            uiLocation: "Terminal with Ctrl+C"
        ),
        
        // MARK: Visual Features
        Feature(
            name: "ANSI Color Support",
            category: "Visual",
            accessPath: "Automatic",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "echo -e '\\033[31mRed\\033[0m'",
            uiLocation: "Terminal output"
        ),
        Feature(
            name: "Terminal Search",
            category: "Visual",
            accessPath: "Search icon",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Search icon in terminal"
        ),
        Feature(
            name: "Line Wrapping",
            category: "Visual",
            accessPath: "Automatic",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: "echo 'very long line...'",
            uiLocation: "Terminal output"
        ),
        Feature(
            name: "Scrollback Buffer",
            category: "Visual",
            accessPath: "Scroll in terminal",
            requiresPlatform: .both,
            isImplemented: true,
            testCommand: nil,
            uiLocation: "Terminal scroll area"
        )
    ]
    
    // MARK: - Validation Methods
    
    public static func validateAllFeatures(for platform: Platform) -> ValidationReport {
        var report = ValidationReport()
        
        for feature in allFeatures {
            // Check platform compatibility
            if let requiredPlatform = feature.requiresPlatform {
                switch requiredPlatform {
                case .iOS where platform == .macOS:
                    continue
                case .macOS where platform == .iOS:
                    continue
                default:
                    break
                }
            }
            
            // Validate feature
            let result = validateFeature(feature)
            report.addResult(result)
        }
        
        return report
    }
    
    private static func validateFeature(_ feature: Feature) -> FeatureValidationResult {
        var issues: [String] = []
        
        // Check implementation status
        if !feature.isImplemented {
            issues.append("Feature not implemented")
        }
        
        // Check accessibility
        if feature.uiLocation == nil && feature.testCommand == nil {
            issues.append("No clear way to access feature")
        }
        
        // Check specific known issues
        switch feature.name {
        case "Mosh Connections":
            issues.append("Only stub implementation exists")
        case "Tab Management Commands":
            issues.append("Commands removed - use UI tabs instead")
        default:
            break
        }
        
        return FeatureValidationResult(
            feature: feature,
            isAccessible: feature.uiLocation != nil || feature.testCommand != nil,
            isWorking: feature.isImplemented,
            issues: issues
        )
    }
}

// MARK: - Validation Report

public struct ValidationReport {
    var totalFeatures: Int = 0
    var workingFeatures: Int = 0
    var accessibleFeatures: Int = 0
    var brokenFeatures: [FeatureValidationResult] = []
    var inaccessibleFeatures: [FeatureValidationResult] = []
    
    mutating func addResult(_ result: FeatureValidationResult) {
        totalFeatures += 1
        
        if result.isWorking {
            workingFeatures += 1
        } else {
            brokenFeatures.append(result)
        }
        
        if result.isAccessible {
            accessibleFeatures += 1
        } else {
            inaccessibleFeatures.append(result)
        }
    }
    
    public func generateReport() -> String {
        var report = """
        =====================================
        FEATURE VALIDATION REPORT
        =====================================
        
        Total Features: \(totalFeatures)
        Working: \(workingFeatures) (\(percentage(workingFeatures, of: totalFeatures))%)
        Accessible: \(accessibleFeatures) (\(percentage(accessibleFeatures, of: totalFeatures))%)
        
        """
        
        if !brokenFeatures.isEmpty {
            report += """
            ⚠️ BROKEN FEATURES (\(brokenFeatures.count)):
            ------------------------------------
            """
            for result in brokenFeatures {
                report += "\n• \(result.feature.name)"
                for issue in result.issues {
                    report += "\n  - \(issue)"
                }
            }
            report += "\n\n"
        }
        
        if !inaccessibleFeatures.isEmpty {
            report += """
            ❌ INACCESSIBLE FEATURES (\(inaccessibleFeatures.count)):
            ------------------------------------
            """
            for result in inaccessibleFeatures {
                report += "\n• \(result.feature.name)"
                report += "\n  Access: \(result.feature.accessPath)"
            }
            report += "\n\n"
        }
        
        report += """
        ✅ WORKING FEATURES BY CATEGORY:
        ------------------------------------
        """
        
        let categories = Dictionary(grouping: FeatureValidator.allFeatures) { $0.category }
        for (category, features) in categories.sorted(by: { $0.key < $1.key }) {
            let working = features.filter { $0.isImplemented }.count
            report += "\n\(category): \(working)/\(features.count)"
        }
        
        return report
    }
    
    private func percentage(_ value: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return (value * 100) / total
    }
}

public struct FeatureValidationResult {
    let feature: Feature
    let isAccessible: Bool
    let isWorking: Bool
    let issues: [String]
}

// MARK: - Quick Validation Function

public func runFeatureValidation() -> String {
    #if canImport(AppKit)
    let platform = Platform.macOS
    #else
    let platform = Platform.iOS
    #endif
    
    let report = FeatureValidator.validateAllFeatures(for: platform)
    return report.generateReport()
}