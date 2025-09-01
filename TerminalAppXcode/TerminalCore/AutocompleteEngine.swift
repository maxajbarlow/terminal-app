import Foundation
import SwiftUI

// MARK: - Autocomplete Engine

public class AutocompleteEngine: ObservableObject {
    @Published public var currentSuggestion: String = ""
    @Published public var isShowingSuggestion: Bool = false
    
    private let commandRegistry = BuiltInCommandRegistry.shared
    private var historyManager: CommandHistoryManager?
    
    // All available commands
    private lazy var allCommands: Set<String> = {
        var commands = Set<String>()
        
        // Built-in Unix commands
        commands.formUnion(commandRegistry.getAllCommandNames())
        
        // App commands (direct access)
        let appCommands = [
            "split", "close", "next", "prev", "pane",
            "config", "settings", "theme", "about", "version"
        ]
        commands.formUnion(appCommands)
        
        // SSH command
        commands.insert("ssh")
        
        // Basic shell commands that work on both platforms
        let basicCommands = [
            "help", "clear", "echo", "history",
            "ls", "pwd", "cd", "cat", "mkdir", "touch", "rm"
        ]
        commands.formUnion(basicCommands)
        
        return commands
    }()
    
    public init(historyManager: CommandHistoryManager? = nil) {
        self.historyManager = historyManager
    }
    
    // MARK: - Main Autocomplete Logic
    
    public func updateSuggestion(for input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        
        // Don't show suggestions for empty input or if user is typing arguments
        guard !trimmed.isEmpty else {
            hideSuggestion()
            return
        }
        
        // Parse the input to get the command being typed
        let parts = trimmed.components(separatedBy: " ")
        guard let firstPart = parts.first, !firstPart.isEmpty else {
            hideSuggestion()
            return
        }
        
        // Handle different command prefixes
        let (commandToMatch, prefix) = parseCommand(firstPart)
        
        // If user is typing arguments (space already present), show argument suggestions
        if parts.count > 1 {
            showArgumentSuggestion(for: commandToMatch, currentArgs: Array(parts.dropFirst()), input: input)
            return
        }
        
        // Show command completion
        showCommandSuggestion(for: commandToMatch, prefix: prefix, input: input)
    }
    
    private func parseCommand(_ input: String) -> (command: String, prefix: String) {
        if input.hasPrefix("..") {
            return (String(input.dropFirst(2)), "..")
        } else if input.hasPrefix(":") {
            return (String(input.dropFirst(1)), ":")
        } else {
            return (input, "")
        }
    }
    
    private func showCommandSuggestion(for partial: String, prefix: String, input: String) {
        // Find best matching command
        let bestMatch = findBestCommandMatch(for: partial)
        
        guard let match = bestMatch, match != partial.lowercased() else {
            hideSuggestion()
            return
        }
        
        // Create full suggestion with prefix
        let fullSuggestion = prefix + match
        
        // Only show the part that hasn't been typed yet
        let suggestionSuffix = String(fullSuggestion.dropFirst(input.count))
        
        showSuggestion(suggestionSuffix)
    }
    
    private func showArgumentSuggestion(for command: String, currentArgs: [String], input: String) {
        let suggestions = getArgumentSuggestions(for: command, currentArgs: currentArgs)
        
        guard let suggestion = suggestions.first else {
            hideSuggestion()
            return
        }
        
        // For argument suggestions, show the suggestion after a space
        let fullSuggestion = input.hasSuffix(" ") ? suggestion : " " + suggestion
        showSuggestion(fullSuggestion)
    }
    
    private func findBestCommandMatch(for partial: String) -> String? {
        let lowercasePartial = partial.lowercased()
        
        // First, try exact prefix matches
        let prefixMatches = allCommands.filter { $0.lowercased().hasPrefix(lowercasePartial) }
        
        if let exactMatch = prefixMatches.first(where: { $0.lowercased() == lowercasePartial }) {
            return nil // Don't suggest if it's already complete
        }
        
        // Return the shortest prefix match (most likely intended)
        return prefixMatches.sorted { $0.count < $1.count }.first
    }
    
    private func getArgumentSuggestions(for command: String, currentArgs: [String]) -> [String] {
        let cmd = command.lowercased()
        
        switch cmd {
        case "split":
            if currentArgs.isEmpty {
                return ["h", "v", "horizontal", "vertical", "toggle"]
            }
        case "theme":
            if currentArgs.isEmpty {
                return ["list", "set", "font", "opacity", "reset", "current"]
            } else if currentArgs.count == 1 && currentArgs[0].lowercased() == "set" {
                return TerminalColorScheme.allSchemes.map { "\"\($0.name)\"" }
            } else if currentArgs.count == 1 && currentArgs[0].lowercased() == "font" {
                return TerminalTheme.availableFonts.map { "\"\($0.family)\"" }
            }
        case "pane":
            return ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
        case "ssh":
            // Could suggest known hosts from history
            return getSSHSuggestions()
        case "help":
            return Array(allCommands).sorted()
        case "cd":
            return ["~", "..", "/", "Documents", "Desktop"]
        case "ls":
            return ["-l", "-a", "-la", "-lh", "-R"]
        case "git":
            return ["init", "clone", "add", "commit", "push", "pull", "status", "log", "branch"]
        case "vim", "nano":
            return ["README.md", "config.txt", ".bashrc"]
        default:
            break
        }
        
        return []
    }
    
    private func getSSHSuggestions() -> [String] {
        // Get recent SSH commands from history
        guard let history = historyManager?.history else { return [] }
        
        let sshCommands = history
            .compactMap { entry -> String? in
                let cmd = entry.command.trimmingCharacters(in: .whitespaces)
                if cmd.hasPrefix("ssh ") {
                    let parts = cmd.components(separatedBy: " ")
                    return parts.count > 1 ? parts[1] : nil
                }
                return nil
            }
            .reversed() // Most recent first
        
        return Array(Set(sshCommands)).prefix(3).map { String($0) }
    }
    
    private func showSuggestion(_ suggestion: String) {
        DispatchQueue.main.async {
            self.currentSuggestion = suggestion
            self.isShowingSuggestion = true
        }
    }
    
    private func hideSuggestion() {
        DispatchQueue.main.async {
            self.currentSuggestion = ""
            self.isShowingSuggestion = false
        }
    }
    
    // MARK: - Public Interface
    
    public func acceptSuggestion() -> String {
        let suggestion = currentSuggestion
        hideSuggestion()
        return suggestion
    }
    
    public func clearSuggestion() {
        hideSuggestion()
    }
    
    public func getSuggestionText() -> String {
        return isShowingSuggestion ? currentSuggestion : ""
    }
}

// MARK: - Autocomplete TextField

public struct AutocompleteTextField: View {
    @Binding private var text: String
    @StateObject private var autocomplete: AutocompleteEngine
    @State private var textFieldText: String = ""
    @FocusState private var isFocused: Bool
    
    private let placeholder: String
    private let onSubmit: (String) -> Void
    private let onTextChange: ((String) -> Void)?
    
    public init(
        text: Binding<String>,
        placeholder: String = "Enter command...",
        onSubmit: @escaping (String) -> Void,
        onTextChange: ((String) -> Void)? = nil,
        historyManager: CommandHistoryManager? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onTextChange = onTextChange
        self._autocomplete = StateObject(wrappedValue: AutocompleteEngine(historyManager: historyManager))
    }
    
    public var body: some View {
        ZStack(alignment: .leading) {
            // Background text field
            TextField(placeholder, text: $textFieldText)
                .focused($isFocused)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 14, family: .monospace))
                .onChange(of: textFieldText) { newValue in
                    text = newValue
                    onTextChange?(newValue)
                    autocomplete.updateSuggestion(for: newValue)
                }
                .onSubmit {
                    onSubmit(textFieldText)
                    textFieldText = ""
                    autocomplete.clearSuggestion()
                }
                .onKeyPress(.space) { keyPress in
                    if autocomplete.isShowingSuggestion {
                        // Accept suggestion on space
                        let suggestion = autocomplete.acceptSuggestion()
                        textFieldText += suggestion
                        text = textFieldText
                        onTextChange?(textFieldText)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.tab) { keyPress in
                    if autocomplete.isShowingSuggestion {
                        // Accept suggestion on tab
                        let suggestion = autocomplete.acceptSuggestion()
                        textFieldText += suggestion
                        text = textFieldText
                        onTextChange?(textFieldText)
                        return .handled
                    }
                    return .ignored
                }
                .onKeyPress(.escape) { keyPress in
                    // Clear suggestion on escape
                    autocomplete.clearSuggestion()
                    return .handled
                }
            
            // Suggestion overlay
            if autocomplete.isShowingSuggestion && isFocused {
                HStack {
                    // Typed text (invisible to align suggestion)
                    Text(textFieldText)
                        .font(.system(size: 14, family: .monospace))
                        .opacity(0)
                    
                    // Suggestion text
                    Text(autocomplete.currentSuggestion)
                        .font(.system(size: 14, family: .monospace))
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .allowsHitTesting(false) // Let touches pass through to text field
            }
        }
    }
}

// MARK: - Enhanced Terminal Input Handler with Autocomplete

public struct AutocompleteTerminalInput: View {
    @ObservedObject var session: TerminalSession
    @State private var inputText = ""
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = 0
    @FocusState private var isInputFocused: Bool
    
    public init(session: TerminalSession) {
        self.session = session
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Prompt indicator
            Text("$")
                .font(.system(size: 14, family: .monospace, weight: .bold))
                .foregroundColor(.green)
            
            // Autocomplete text field
            AutocompleteTextField(
                text: $inputText,
                placeholder: "Type command... (space/tab to autocomplete)",
                onSubmit: { command in
                    executeCommand(command)
                },
                onTextChange: { newText in
                    // Handle text changes if needed
                }
            )
            .focused($isInputFocused)
            
            // Send button
            Button("Send") {
                executeCommand(inputText)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .onAppear {
            isInputFocused = true
        }
        .onKeyPress(.upArrow) { keyPress in
            navigateHistory(direction: .up)
            return .handled
        }
        .onKeyPress(.downArrow) { keyPress in
            navigateHistory(direction: .down)
            return .handled
        }
    }
    
    private func executeCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // Add to history
        commandHistory.append(trimmed)
        historyIndex = commandHistory.count
        
        // Execute command
        session.sendInput(trimmed)
        
        // Clear input
        inputText = ""
        
        // Maintain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInputFocused = true
        }
    }
    
    private enum HistoryDirection {
        case up, down
    }
    
    private func navigateHistory(direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }
        
        switch direction {
        case .up:
            if historyIndex > 0 {
                historyIndex -= 1
                inputText = commandHistory[historyIndex]
            }
        case .down:
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
                inputText = commandHistory[historyIndex]
            } else if historyIndex == commandHistory.count - 1 {
                historyIndex = commandHistory.count
                inputText = ""
            }
        }
    }
}