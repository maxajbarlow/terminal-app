import SwiftUI

#if os(iOS)
import UIKit

// MARK: - iOS Command Row for Terminal

public struct iOSCommandRow: View {
    @Binding var inputText: String
    let onTextInsert: (String) -> Void
    let onSpecialAction: (CommandAction) -> Void
    
    @State private var selectedCategory: CommandCategory = .common
    
    public enum CommandCategory: String, CaseIterable {
        case common = "Common"
        case navigation = "Navigate"
        case symbols = "Symbols"
        case control = "Control"
        
        var icon: String {
            switch self {
            case .common: return "command.circle"
            case .navigation: return "arrow.up.arrow.down"
            case .symbols: return "textformat.123"
            case .control: return "control"
            }
        }
    }
    
    public enum CommandAction {
        case tab
        case escape
        case ctrlC
        case ctrlD
        case clear
        case up
        case down
        case left
        case right
        case home
        case end
    }
    
    public init(inputText: Binding<String>, 
                onTextInsert: @escaping (String) -> Void,
                onSpecialAction: @escaping (CommandAction) -> Void) {
        self._inputText = inputText
        self.onTextInsert = onTextInsert
        self.onSpecialAction = onSpecialAction
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Category selector
            HStack(spacing: 0) {
                ForEach(CommandCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        VStack(spacing: 2) {
                            Image(systemName: category.icon)
                                .font(.system(size: 14, weight: .medium))
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(selectedCategory == category ? .blue : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .background(
                        Rectangle()
                            .fill(selectedCategory == category ? Color.blue.opacity(0.1) : Color.clear)
                    )
                }
            }
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color(.separator)),
                alignment: .bottom
            )
            
            // Command buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(commandsForCategory(selectedCategory), id: \.id) { command in
                        CommandButton(
                            command: command,
                            onTap: {
                                if let text = command.insertText {
                                    onTextInsert(text)
                                } else if let action = command.action {
                                    onSpecialAction(action)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(height: 44)
            .background(Color(.secondarySystemBackground))
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
    
    private func commandsForCategory(_ category: CommandCategory) -> [CommandItem] {
        switch category {
        case .common:
            return [
                CommandItem(id: "ls", title: "ls", insertText: "ls"),
                CommandItem(id: "cd", title: "cd", insertText: "cd "),
                CommandItem(id: "pwd", title: "pwd", insertText: "pwd"),
                CommandItem(id: "clear", title: "clear", action: .clear),
                CommandItem(id: "history", title: "history", insertText: "history"),
                CommandItem(id: "help", title: "help", insertText: "help"),
                CommandItem(id: "ps", title: "ps", insertText: "ps"),
                CommandItem(id: "top", title: "top", insertText: "top"),
                CommandItem(id: "df", title: "df", insertText: "df"),
                CommandItem(id: "whoami", title: "whoami", insertText: "whoami"),
            ]
        case .navigation:
            return [
                CommandItem(id: "up", title: "↑", action: .up),
                CommandItem(id: "down", title: "↓", action: .down),
                CommandItem(id: "left", title: "←", action: .left),
                CommandItem(id: "right", title: "→", action: .right),
                CommandItem(id: "home", title: "Home", action: .home),
                CommandItem(id: "end", title: "End", action: .end),
                CommandItem(id: "tab", title: "Tab", action: .tab),
                CommandItem(id: "esc", title: "Esc", action: .escape),
            ]
        case .symbols:
            return [
                CommandItem(id: "pipe", title: "|", insertText: "|"),
                CommandItem(id: "ampersand", title: "&", insertText: "&"),
                CommandItem(id: "semicolon", title: ";", insertText: ";"),
                CommandItem(id: "dollar", title: "$", insertText: "$"),
                CommandItem(id: "tilde", title: "~", insertText: "~"),
                CommandItem(id: "backtick", title: "`", insertText: "`"),
                CommandItem(id: "hash", title: "#", insertText: "#"),
                CommandItem(id: "at", title: "@", insertText: "@"),
                CommandItem(id: "percent", title: "%", insertText: "%"),
                CommandItem(id: "caret", title: "^", insertText: "^"),
                CommandItem(id: "asterisk", title: "*", insertText: "*"),
                CommandItem(id: "minus", title: "-", insertText: "-"),
                CommandItem(id: "underscore", title: "_", insertText: "_"),
                CommandItem(id: "equals", title: "=", insertText: "="),
                CommandItem(id: "plus", title: "+", insertText: "+"),
                CommandItem(id: "backslash", title: "\\", insertText: "\\"),
                CommandItem(id: "slash", title: "/", insertText: "/"),
                CommandItem(id: "question", title: "?", insertText: "?"),
                CommandItem(id: "less", title: "<", insertText: "<"),
                CommandItem(id: "greater", title: ">", insertText: ">"),
                CommandItem(id: "lbrace", title: "{", insertText: "{"),
                CommandItem(id: "rbrace", title: "}", insertText: "}"),
                CommandItem(id: "lbracket", title: "[", insertText: "["),
                CommandItem(id: "rbracket", title: "]", insertText: "]"),
                CommandItem(id: "lparen", title: "(", insertText: "("),
                CommandItem(id: "rparen", title: ")", insertText: ")"),
            ]
        case .control:
            return [
                CommandItem(id: "ctrl-c", title: "^C", action: .ctrlC),
                CommandItem(id: "ctrl-d", title: "^D", action: .ctrlD),
                CommandItem(id: "space", title: "Space", insertText: " "),
                CommandItem(id: "enter", title: "Enter", insertText: "\n"),
                CommandItem(id: "backspace", title: "⌫", insertText: "\u{08}"),
                CommandItem(id: "sudo", title: "sudo", insertText: "sudo "),
                CommandItem(id: "grep", title: "grep", insertText: "grep "),
                CommandItem(id: "find", title: "find", insertText: "find "),
                CommandItem(id: "chmod", title: "chmod", insertText: "chmod "),
                CommandItem(id: "chown", title: "chown", insertText: "chown "),
            ]
        }
    }
}

// MARK: - Command Item Model

public struct CommandItem {
    let id: String
    let title: String
    let insertText: String?
    let action: iOSCommandRow.CommandAction?
    
    init(id: String, title: String, insertText: String) {
        self.id = id
        self.title = title
        self.insertText = insertText
        self.action = nil
    }
    
    init(id: String, title: String, action: iOSCommandRow.CommandAction) {
        self.id = id
        self.title = title
        self.insertText = nil
        self.action = action
    }
}

// MARK: - Command Button Component

private struct CommandButton: View {
    let command: CommandItem
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            Text(command.title)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isPressed ? Color(.systemGray2) : Color(.systemGray5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(.systemGray3), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }) {
            // Long press completed
        }
    }
}

// MARK: - iOS Enhanced Terminal Input

public struct iOSEnhancedTerminalInput: View {
    @Binding var inputText: String
    let placeholder: String
    let onSubmit: (String) -> Void
    let onTextChange: ((String) -> Void)?
    let historyManager: CommandHistoryManager?
    
    @FocusState private var isInputFocused: Bool
    @State private var showCommandRow = false
    
    public init(
        inputText: Binding<String>,
        placeholder: String = "Type command...",
        onSubmit: @escaping (String) -> Void,
        onTextChange: ((String) -> Void)? = nil,
        historyManager: CommandHistoryManager? = nil
    ) {
        self._inputText = inputText
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onTextChange = onTextChange
        self.historyManager = historyManager
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Command row (iOS only)
            if showCommandRow {
                iOSCommandRow(
                    inputText: $inputText,
                    onTextInsert: { text in
                        inputText += text
                        onTextChange?(inputText)
                    },
                    onSpecialAction: { action in
                        handleSpecialAction(action)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // Main input area
            HStack(spacing: 8) {
                Text("$")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    .fontWeight(.bold)
                
                AutocompleteTextField(
                    text: $inputText,
                    placeholder: placeholder,
                    onSubmit: onSubmit,
                    onTextChange: onTextChange,
                    historyManager: historyManager
                )
                .focused($isInputFocused)
                
                // Command row toggle button (iOS only)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showCommandRow.toggle()
                    }
                }) {
                    Image(systemName: showCommandRow ? "keyboard.chevron.compact.down" : "keyboard.chevron.compact.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
        }
        .onChange(of: isInputFocused) { focused in
            if !focused {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCommandRow = false
                }
            }
        }
    }
    
    private func handleSpecialAction(_ action: iOSCommandRow.CommandAction) {
        switch action {
        case .tab:
            inputText += "\t"
        case .escape:
            inputText = ""
        case .ctrlC:
            inputText += "\u{03}" // Ctrl+C
        case .ctrlD:
            inputText += "\u{04}" // Ctrl+D
        case .clear:
            onSubmit("clear")
            inputText = ""
        case .up:
            // Handle history navigation up
            navigateHistory(.up)
        case .down:
            // Handle history navigation down  
            navigateHistory(.down)
        case .left, .right:
            // These would need cursor position handling
            break
        case .home:
            // Move cursor to beginning
            break
        case .end:
            // Move cursor to end
            break
        }
        
        onTextChange?(inputText)
    }
    
    private func navigateHistory(_ direction: HistoryDirection) {
        guard let historyManager = historyManager else { return }
        
        let history = historyManager.getUniqueCommands()
        guard !history.isEmpty else { return }
        
        // Simple history navigation - in a full implementation this would maintain state
        switch direction {
        case .up:
            if let lastCommand = history.first {
                inputText = lastCommand
            }
        case .down:
            inputText = ""
        }
    }
    
    private enum HistoryDirection {
        case up, down
    }
}

#endif