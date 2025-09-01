import Foundation
import SwiftUI

// MARK: - Command History Types (for compilation)

public struct CommandHistoryEntry: Identifiable, Codable {
    public let id: UUID
    public let command: String
    public let timestamp: Date
    public let workingDirectory: String
    public let sessionId: String
    public let exitCode: Int?
    public let duration: TimeInterval?
    
    public init(command: String, workingDirectory: String = "", sessionId: String = "", exitCode: Int? = nil, duration: TimeInterval? = nil) {
        self.id = UUID()
        self.command = command
        self.timestamp = Date()
        self.workingDirectory = workingDirectory
        self.sessionId = sessionId
        self.exitCode = exitCode
        self.duration = duration
    }
    
    public var displayText: String {
        return command.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    public var statusIcon: String {
        if let exitCode = exitCode {
            return exitCode == 0 ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        return "clock.circle"
    }
    
    public var statusColor: Color {
        if let exitCode = exitCode {
            return exitCode == 0 ? .green : .red
        }
        return .orange
    }
}

public class CommandHistoryManager: ObservableObject {
    @Published public private(set) var history: [CommandHistoryEntry] = []
    @Published public var isVisible: Bool = false
    @Published public var selectedEntry: CommandHistoryEntry?
    
    private let maxHistorySize: Int
    private let historyFilePath: String
    
    public init(maxHistorySize: Int = 1000) {
        self.maxHistorySize = maxHistorySize
        
        // Set up history file path
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory if documents directory not available
            let tempPath = NSTemporaryDirectory()
            self.historyFilePath = (tempPath as NSString).appendingPathComponent("terminal_history.json")
            return
        }
        self.historyFilePath = documentsPath.appendingPathComponent("terminal_history.json").path
        
        loadHistory()
    }
    
    public func addCommand(_ command: String, workingDirectory: String = "", sessionId: String = "") {
        let entry = CommandHistoryEntry(command: command, workingDirectory: workingDirectory, sessionId: sessionId)
        DispatchQueue.main.async {
            self.history.insert(entry, at: 0)
            if self.history.count > self.maxHistorySize {
                self.history = Array(self.history.prefix(self.maxHistorySize))
            }
            self.saveHistory()
        }
    }
    
    public func clearHistory() {
        DispatchQueue.main.async {
            self.history.removeAll()
            self.saveHistory()
        }
    }
    
    public func searchHistory(query: String) -> [CommandHistoryEntry] {
        if query.isEmpty {
            return history
        }
        
        return history.filter { entry in
            entry.command.localizedCaseInsensitiveContains(query) ||
            entry.workingDirectory.localizedCaseInsensitiveContains(query)
        }
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFilePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: historyFilePath)),
              let loadedHistory = try? JSONDecoder().decode([CommandHistoryEntry].self, from: data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.history = loadedHistory
        }
    }
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: URL(fileURLWithPath: historyFilePath))
        } catch {
            print("Failed to save command history: \(error)")
        }
    }
}

// MARK: - Original TabManager Code

public struct TerminalTab: Identifiable, Equatable {
    public let id = UUID()
    public var title: String  // Make title mutable for dynamic updates
    public let session: TerminalSession?
    public let isMultiplexer: Bool
    
    public init(title: String) {
        self.title = title
        let newSession = TerminalSession()
        self.session = newSession
        self.isMultiplexer = false
    }
    
    public init(title: String, connectionInfo: ConnectionInfo) {
        self.title = title
        let newSession = TerminalSession(connectionInfo: connectionInfo)
        self.session = newSession
        self.isMultiplexer = false
    }
    
    public init(title: String, isMultiplexer: Bool) {
        self.title = title
        self.session = isMultiplexer ? nil : TerminalSession()
        self.isMultiplexer = isMultiplexer
    }
    
    public static func == (lhs: TerminalTab, rhs: TerminalTab) -> Bool {
        lhs.id == rhs.id
    }
}

public class TabManager: ObservableObject {
    @Published public var tabs: [TerminalTab] = []
    @Published public var selectedTabId: UUID?
    public var historyManager: CommandHistoryManager?
    
    public init(historyManager: CommandHistoryManager? = nil) {
        self.historyManager = historyManager
        // Create initial tab
        addNewTab()
    }
    
    public var selectedTab: TerminalTab? {
        guard let selectedId = selectedTabId else { return nil }
        return tabs.first { $0.id == selectedId }
    }
    
    public var selectedSession: TerminalSession? {
        return selectedTab?.session
    }
    
    public func addNewTab() {
        let tabNumber = tabs.count + 1
        let newTab = TerminalTab(title: "Terminal \(tabNumber)")
        
        // Set the history manager on the terminal session
        newTab.session?.historyManager = historyManager
        
        tabs.append(newTab)
        
        // Select the new tab
        selectedTabId = newTab.id
    }
    
    public func addSSHTab(connectionInfo: ConnectionInfo, profileName: String) {
        let displayName = "\(connectionInfo.username)@\(connectionInfo.host)"
        let tabTitle = profileName.isEmpty ? displayName : "\(profileName) (\(displayName))"
        let newTab = TerminalTab(title: tabTitle, connectionInfo: connectionInfo)
        
        // Set the history manager on the terminal session
        newTab.session?.historyManager = historyManager
        
        tabs.append(newTab)
        
        // Select the new SSH tab
        selectedTabId = newTab.id
    }
    
    public func addMultiplexerTab(name: String = "Multiplexer") {
        let newTab = TerminalTab(title: name, isMultiplexer: true)
        
        tabs.append(newTab)
        
        // Select the new multiplexer tab
        selectedTabId = newTab.id
    }
    
    public func closeTab(withId id: UUID) {
        // Don't close the last tab
        guard tabs.count > 1 else { return }
        
        // If we're closing the selected tab, select another one
        if selectedTabId == id {
            if let currentIndex = tabs.firstIndex(where: { $0.id == id }) {
                let nextIndex = currentIndex > 0 ? currentIndex - 1 : currentIndex + 1
                if nextIndex < tabs.count {
                    selectedTabId = tabs[nextIndex].id
                }
            }
        }
        
        // Remove the tab
        tabs.removeAll { $0.id == id }
        
        // If no tab is selected, select the first one
        if selectedTabId == nil || !tabs.contains(where: { $0.id == selectedTabId }) {
            selectedTabId = tabs.first?.id
        }
    }
    
    public func closeSelectedTab() {
        guard let selectedId = selectedTabId else { return }
        closeTab(withId: selectedId)
    }
    
    public func selectTab(withId id: UUID) {
        if tabs.contains(where: { $0.id == id }) {
            selectedTabId = id
        }
    }
    
    public func updateTabTitle(_ title: String, for id: UUID) {
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            tabs[index].title = title
        }
    }
}