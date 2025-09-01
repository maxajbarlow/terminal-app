import Foundation
import SwiftUI

// MARK: - Command History Entry

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

// MARK: - Command History Manager

public class CommandHistoryManager: ObservableObject {
    @Published public private(set) var history: [CommandHistoryEntry] = []
    @Published public var isVisible: Bool = false
    @Published public var selectedEntry: CommandHistoryEntry?
    
    private let maxHistorySize: Int
    private let historyFilePath: String
    // Note: CommandCompleter integration removed to avoid circular dependencies
    private let commandRegistry = BuiltInCommandRegistry.shared
    
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
    
    // MARK: - History Management
    
    public func addCommand(_ command: String, workingDirectory: String = "", sessionId: String = "") {
        let entry = CommandHistoryEntry(
            command: command,
            workingDirectory: workingDirectory,
            sessionId: sessionId
        )
        
        DispatchQueue.main.async {
            // Remove duplicate recent commands
            if let lastEntry = self.history.first, lastEntry.command == command {
                return
            }
            
            // Add to beginning of history
            self.history.insert(entry, at: 0)
            
            // Trim history if it exceeds max size
            if self.history.count > self.maxHistorySize {
                self.history = Array(self.history.prefix(self.maxHistorySize))
            }
            
            self.saveHistory()
        }
    }
    
    public func updateCommandResult(_ commandId: UUID, exitCode: Int, duration: TimeInterval) {
        DispatchQueue.main.async {
            if let index = self.history.firstIndex(where: { $0.id == commandId }) {
                let entry = self.history[index]
                // Create updated entry with same ID and timestamp but new result data
                self.history[index] = CommandHistoryEntry(
                    command: entry.command,
                    workingDirectory: entry.workingDirectory,
                    sessionId: entry.sessionId,
                    exitCode: exitCode,
                    duration: duration
                )
                self.saveHistory()
            }
        }
    }
    
    public func clearHistory() {
        DispatchQueue.main.async {
            self.history.removeAll()
            self.selectedEntry = nil
            self.saveHistory()
        }
    }
    
    public func removeCommand(_ entry: CommandHistoryEntry) {
        DispatchQueue.main.async {
            self.history.removeAll { $0.id == entry.id }
            if self.selectedEntry?.id == entry.id {
                self.selectedEntry = nil
            }
            self.saveHistory()
        }
    }
    
    // MARK: - Search and Filter
    
    public func searchHistory(_ searchText: String) -> [CommandHistoryEntry] {
        if searchText.isEmpty {
            return history
        }
        
        return history.filter { entry in
            entry.command.localizedCaseInsensitiveContains(searchText) ||
            entry.workingDirectory.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public func getHistoryForSession(_ sessionId: String) -> [CommandHistoryEntry] {
        return history.filter { $0.sessionId == sessionId }
    }
    
    public func getRecentCommands(limit: Int = 50) -> [CommandHistoryEntry] {
        return Array(history.prefix(limit))
    }
    
    public func getUniqueCommands() -> [String] {
        var seen = Set<String>()
        return history.compactMap { entry in
            let trimmed = entry.command.trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.contains(trimmed) {
                return nil
            }
            seen.insert(trimmed)
            return trimmed
        }
    }
    
    // MARK: - Navigation
    
    public func selectEntry(_ entry: CommandHistoryEntry) {
        DispatchQueue.main.async {
            self.selectedEntry = entry
        }
    }
    
    public func selectNext() {
        guard let current = selectedEntry,
              let currentIndex = history.firstIndex(where: { $0.id == current.id }),
              currentIndex < history.count - 1 else {
            return
        }
        
        DispatchQueue.main.async {
            self.selectedEntry = self.history[currentIndex + 1]
        }
    }
    
    public func selectPrevious() {
        guard let current = selectedEntry,
              let currentIndex = history.firstIndex(where: { $0.id == current.id }),
              currentIndex > 0 else {
            return
        }
        
        DispatchQueue.main.async {
            self.selectedEntry = self.history[currentIndex - 1]
        }
    }
    
    public func toggle() {
        DispatchQueue.main.async {
            self.isVisible.toggle()
        }
    }
    
    // MARK: - Persistence
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: URL(fileURLWithPath: historyFilePath))
        } catch {
            print("Failed to save command history: \(error)")
        }
    }
    
    private func loadHistory() {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: historyFilePath))
            let loadedHistory = try JSONDecoder().decode([CommandHistoryEntry].self, from: data)
            
            DispatchQueue.main.async {
                self.history = loadedHistory
            }
        } catch {
            print("Failed to load command history: \(error)")
        }
    }
    
    // MARK: - Statistics
    
    public var totalCommands: Int {
        return history.count
    }
    
    public var successfulCommands: Int {
        return history.filter { $0.exitCode == 0 }.count
    }
    
    public var failedCommands: Int {
        return history.filter { ($0.exitCode ?? 0) != 0 }.count
    }
    
    public var mostUsedCommands: [(command: String, count: Int)] {
        let commands = history.map { $0.command.components(separatedBy: " ").first ?? "" }
        let commandCounts = Dictionary(grouping: commands, by: { $0 }).mapValues { $0.count }
        return commandCounts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }.prefix(10).map { $0 }
    }
    
    // MARK: - Command Completion & Help
    
    public func completeCommand(_ partial: String) -> [String] {
        // Get built-in command completions
        let builtInCommands = commandRegistry.getAllCommandNames()
            .filter { $0.lowercased().hasPrefix(partial.lowercased()) }
        
        // Add unique commands from history
        let historicalCommands = history
            .map { $0.command.components(separatedBy: " ").first ?? "" }
            .filter { !$0.isEmpty && $0.lowercased().hasPrefix(partial.lowercased()) }
        
        let uniqueHistorical = Set(historicalCommands)
        var completions = builtInCommands
        completions.append(contentsOf: uniqueHistorical)
        
        // Remove duplicates and sort
        return Array(Set(completions)).sorted()
    }
    
    public func getCommandHelp(_ commandName: String) -> String? {
        return commandRegistry.generateHelp(for: commandName)
    }
    
    public func getQuickReference() -> String {
        return commandRegistry.generateQuickReference()
    }
    
    public func isBuiltInCommand(_ command: String) -> Bool {
        let commandName = command.components(separatedBy: " ").first ?? ""
        return commandRegistry.getCommand(named: commandName) != nil
    }
    
    public func suggestNextArguments(for command: String, currentArgs: [String]) -> [String] {
        let commandName = command.components(separatedBy: " ").first ?? ""
        
        // Basic argument suggestions based on command type
        switch commandName.lowercased() {
        case "ls":
            return ["-l", "-a", "-la", "-lh", "-R"]
        case "git":
            return ["init", "clone", "add", "commit", "push", "pull", "status", "log", "branch"]
        case "ssh":
            // Get recent SSH hosts from history
            return getSSHHostsFromHistory()
        case "cd":
            return ["~", "..", "/", "Documents", "Desktop"]
        default:
            return []
        }
    }
    
    private func getSSHHostsFromHistory() -> [String] {
        return history
            .compactMap { entry -> String? in
                let cmd = entry.command.trimmingCharacters(in: .whitespaces)
                if cmd.hasPrefix("ssh ") {
                    let parts = cmd.components(separatedBy: " ")
                    return parts.count > 1 ? parts[1] : nil
                }
                return nil
            }
            .reversed()
            .prefix(3)
            .map { String($0) }
    }
}