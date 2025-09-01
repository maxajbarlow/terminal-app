import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Scrollback Buffer Management

public class ScrollbackBuffer: ObservableObject {
    @Published var displayText: String = ""
    
    private var lines: [String] = []
    public let maxLines: Int
    public let maxLineLength: Int
    
    public init(maxLines: Int = 1000, maxLineLength: Int = 2000) {
        self.maxLines = maxLines
        self.maxLineLength = maxLineLength
    }
    
    public func append(_ text: String) {
        // Split incoming text into lines
        let newLines = text.components(separatedBy: .newlines)
        
        for (index, line) in newLines.enumerated() {
            if index == 0 && !lines.isEmpty {
                // Append to the last existing line
                let lastIndex = lines.count - 1
                let truncatedLine = String((lines[lastIndex] + line).prefix(maxLineLength))
                lines[lastIndex] = truncatedLine
            } else {
                // Add as new line
                let truncatedLine = String(line.prefix(maxLineLength))
                lines.append(truncatedLine)
            }
        }
        
        // Trim buffer if it exceeds max lines
        if lines.count > maxLines {
            let excess = lines.count - maxLines
            lines.removeFirst(excess)
        }
        
        // Update display text
        updateDisplayText()
    }
    
    public func clear() {
        lines.removeAll()
        updateDisplayText()
    }
    
    public func setInitialContent(_ content: String) {
        clear()
        append(content)
    }
    
    private func updateDisplayText() {
        displayText = lines.joined(separator: "\n")
    }
    
    public var lineCount: Int {
        return lines.count
    }
    
    public var totalCharacters: Int {
        return displayText.count
    }
    
    // Get the last N lines
    public func getLastLines(_ count: Int) -> String {
        let startIndex = max(0, lines.count - count)
        return lines[startIndex...].joined(separator: "\n")
    }
    
    // Search functionality
    public func searchLines(containing searchTerm: String, caseSensitive: Bool = false) -> [Int] {
        let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        return lines.enumerated().compactMap { index, line in
            return line.range(of: searchTerm, options: options) != nil ? index : nil
        }
    }
    
    // Memory management and performance metrics
    public var memoryFootprint: Int {
        return lines.reduce(0) { $0 + $1.utf8.count } + displayText.utf8.count
    }
    
    public var bufferUtilization: Double {
        return Double(lines.count) / Double(maxLines)
    }
    
    // Optimize for large outputs by batching updates
    private var pendingText: String = ""
    private var lastUpdateTime = Date()
    private let batchUpdateInterval: TimeInterval = 0.1 // 100ms
    
    public func appendOptimized(_ text: String) {
        pendingText += text
        
        let now = Date()
        if now.timeIntervalSince(lastUpdateTime) >= batchUpdateInterval || pendingText.count > 1000 {
            flushPendingText()
        }
    }
    
    public func flushPendingText() {
        if !pendingText.isEmpty {
            append(pendingText)
            pendingText = ""
            lastUpdateTime = Date()
        }
    }
    
    // Export functionality for debugging or saving
    public func exportToString() -> String {
        return displayText
    }
    
    public func exportLines(from startIndex: Int = 0, to endIndex: Int? = nil) -> [String] {
        let end = endIndex ?? lines.count
        let validStart = max(0, min(startIndex, lines.count))
        let validEnd = max(validStart, min(end, lines.count))
        
        return Array(lines[validStart..<validEnd])
    }
}

// View to render text with ANSI color codes
struct ANSITextView: View {
    let text: String
    @ObservedObject private var theme = TerminalTheme.shared
    
    var body: some View {
        let styledTexts = ANSIParser.parseANSIString(text)
        
        if styledTexts.isEmpty || styledTexts.count == 1 {
            // Simple text without ANSI codes or single segment
            Text(text)
                .foregroundColor(theme.colorScheme.foreground)
        } else {
            // Render ANSI styled text with theme colors
            renderStyledText(styledTexts)
        }
    }
    
    @ViewBuilder
    private func renderStyledText(_ styledTexts: [ANSIStyledText]) -> some View {
        // For now, render as plain text with theme foreground color
        // TODO: Implement proper ANSI color rendering with theme integration
        Text(styledTexts.map { $0.text }.joined())
            .foregroundColor(theme.colorScheme.foreground)
    }
}

public struct InlineTerminalView: View {
    @ObservedObject var session: TerminalSession
    @StateObject private var scrollbackBuffer = ScrollbackBuffer(maxLines: UserDefaults.standard.integer(forKey: "scrollbackLines") > 0 ? UserDefaults.standard.integer(forKey: "scrollbackLines") : 1000)
    @ObservedObject private var theme = TerminalTheme.shared
    @State private var currentCommand: String = ""
    @State private var cursorPosition: Int = 0
    @State private var commandHistory: [String] = []
    @State private var historyIndex: Int = 0
    @State private var savedCommand: String = ""
    @State private var isCommandRunning: Bool = false
    @State private var cursorVisible: Bool = true
    @FocusState private var isTextFieldFocused: Bool
    
    @State private var cursorTimer: Timer?
    
    public init(session: TerminalSession) {
        self.session = session
    }
    
    private var currentPrompt: String {
        #if canImport(AppKit)
        // macOS: Full terminal-style prompt
        let username = NSUserName()
        let hostname = ProcessInfo.processInfo.hostName.replacingOccurrences(of: ".local", with: "")
        let homeDir = NSHomeDirectory()
        let currentPath = session.currentPath.isEmpty ? FileManager.default.currentDirectoryPath : session.currentPath
        let displayPath = currentPath.hasPrefix(homeDir) ? currentPath.replacingOccurrences(of: homeDir, with: "~") : currentPath
        let directoryName = URL(fileURLWithPath: displayPath).lastPathComponent == "~" ? "~" : URL(fileURLWithPath: displayPath).lastPathComponent
        
        return "\(username)@\(hostname) \(directoryName) % "
        #else
        // iOS: Simple app-style prompt
        return "$ "
        #endif
    }
    
    private var displayText: String {
        if isCommandRunning {
            return scrollbackBuffer.displayText
        } else {
            // Insert cursor at cursor position
            var commandWithCursor = currentCommand
            let validCursorPos = min(cursorPosition, currentCommand.count)
            
            // Show cursor when visible (blinking)
            if cursorVisible {
                if validCursorPos < commandWithCursor.count {
                    let index = commandWithCursor.index(commandWithCursor.startIndex, offsetBy: validCursorPos)
                    commandWithCursor.insert("▊", at: index)
                } else {
                    // Cursor at end of command
                    commandWithCursor += "▊"
                }
            }
            
            return scrollbackBuffer.displayText + currentPrompt + commandWithCursor
        }
    }
    
    public var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Display terminal text with inline command
                    ANSITextView(text: displayText)
                        .font(theme.font.swiftUIFont())
                        .foregroundColor(theme.colorScheme.foreground)
                        .lineSpacing(theme.lineSpacing - 1.0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .textSelection(.enabled)
                    
                }
                .id("bottom")
            }
            .background(theme.colorScheme.background.opacity(theme.opacity))
            .onChange(of: displayText) { _ in
                withAnimation {
                    scrollProxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .background(theme.colorScheme.background.opacity(theme.opacity))
        .contentShape(Rectangle()) // Make entire area clickable
        #if canImport(AppKit)
        .background(KeyEventHandler(action: handleKeyPress))
        #else
        // iOS input handling with overlay TextField
        .overlay(
            TextField("", text: $currentCommand)
                .opacity(0)
                .focused($isTextFieldFocused)
                .onSubmit {
                    executeCommand()
                }
        )
        #endif
        .onTapGesture {
            isTextFieldFocused = true
            cursorVisible = true
            #if canImport(AppKit)
            // Force the key handler view to become first responder (macOS only)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                if let window = NSApp.keyWindow,
                   let keyHandlerView = findKeyHandlerView(in: window.contentView) {
                    window.makeFirstResponder(keyHandlerView)
                }
            }
            #endif
        }
        .onAppear {
            setupSession()
            initializeTerminal()
            isTextFieldFocused = true
            cursorVisible = true
            setupCursorTimer()
        }
        .onChange(of: theme.cursorBlinkRate) { _ in
            setupCursorTimer()
        }
        .onChange(of: currentCommand) { _ in
            // Keep cursor position stable when text changes
            // Only adjust if cursor is beyond the text length
            if cursorPosition > currentCommand.count {
                cursorPosition = currentCommand.count
            }
        }
    }
    
    private func setupCursorTimer() {
        cursorTimer?.invalidate()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: theme.cursorBlinkRate, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
    
    private func initializeTerminal() {
        scrollbackBuffer.setInitialContent("""
Terminal App v1.0.0 - Ready

Type 'help' for available commands or use any standard shell command.

""")
    }
    
    private func setupSession() {
        session.onLiveOutput = { [weak scrollbackBuffer] output in
            DispatchQueue.main.async {
                scrollbackBuffer?.append(output)
            }
        }
        
        session.onCommandCompleted = { [weak scrollbackBuffer] in
            DispatchQueue.main.async {
                if !(scrollbackBuffer?.displayText.hasSuffix("\n") ?? true) {
                    scrollbackBuffer?.append("\n")
                }
                isCommandRunning = false
            }
        }
    }
    
    #if canImport(AppKit)
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        // Reset cursor visibility on any key press
        cursorVisible = true
        
        // Handle Cmd+C for copy (when text is selected)
        if press.modifiers.contains(.command) && press.characters == "c" {
            // Let the system handle copy when text is selected
            return .ignored
        }
        
        // Handle Cmd+V for paste
        if press.modifiers.contains(.command) && press.characters == "v" {
            if let pasteboard = NSPasteboard.general.string(forType: .string) {
                let index = currentCommand.index(currentCommand.startIndex, offsetBy: min(cursorPosition, currentCommand.count))
                currentCommand.insert(contentsOf: pasteboard, at: index)
                cursorPosition += pasteboard.count
            }
            return .handled
        }
        
        // Handle arrow keys for command history
        if press.keyCode == 126 { // Up arrow
            navigateHistory(direction: .previous)
            return .handled
        } else if press.keyCode == 125 { // Down arrow
            navigateHistory(direction: .next)
            return .handled
        } else if press.keyCode == 123 { // Left arrow
            if cursorPosition > 0 {
                cursorPosition -= 1
                // Force view update by triggering a state change
                cursorVisible = true
            }
            return .handled
        } else if press.keyCode == 124 { // Right arrow
            if cursorPosition < currentCommand.count {
                cursorPosition += 1
                // Force view update by triggering a state change
                cursorVisible = true
            }
            return .handled
        }
        
        // Handle Home key (move to beginning of line)
        if press.keyCode == 115 {
            cursorPosition = 0
            cursorVisible = true
            return .handled
        }
        
        // Handle End key (move to end of line)
        if press.keyCode == 119 {
            cursorPosition = currentCommand.count
            cursorVisible = true
            return .handled
        }
        
        // Handle Tab for completion
        if press.keyCode == 48 { // Tab
            performTabCompletion()
            return .handled
        }
        
        // Handle Enter key
        if press.keyCode == 36 { // Return/Enter
            executeCommand()
            return .handled
        }
        
        // Handle Delete/Backspace
        if press.keyCode == 51 { // Delete/Backspace
            if cursorPosition > 0 && !currentCommand.isEmpty {
                let index = currentCommand.index(currentCommand.startIndex, offsetBy: cursorPosition - 1)
                currentCommand.remove(at: index)
                cursorPosition -= 1
                cursorVisible = true
            }
            return .handled
        }
        
        // Handle Ctrl+C to interrupt
        if press.modifiers.contains(.control) && press.characters == "c" {
            if isCommandRunning {
                session.interruptCurrentCommand()
                scrollbackBuffer.append("^C\n")
                isCommandRunning = false
            } else {
                // Clear current command
                currentCommand = ""
                cursorPosition = 0
            }
            return .handled
        }
        
        // Handle Ctrl+L to show buffer stats (debug)
        if press.modifiers.contains(.control) && press.characters == "l" {
            let stats = """
            
            === Scrollback Buffer Stats ===
            Lines: \(scrollbackBuffer.lineCount)/\(scrollbackBuffer.maxLines)
            Characters: \(scrollbackBuffer.totalCharacters)
            Memory: \(scrollbackBuffer.memoryFootprint) bytes
            Utilization: \(String(format: "%.1f", scrollbackBuffer.bufferUtilization * 100))%
            ===============================
            
            """
            scrollbackBuffer.append(stats)
            return .handled
        }
        
        // Handle regular character input
        if !press.characters.isEmpty && !press.modifiers.contains(.command) && !press.modifiers.contains(.control) {
            // Insert character at cursor position
            let character = press.characters
            if cursorPosition <= currentCommand.count {
                let index = currentCommand.index(currentCommand.startIndex, offsetBy: cursorPosition)
                currentCommand.insert(contentsOf: character, at: index)
                cursorPosition += character.count
            }
            return .handled
        }
        
        return .ignored
    }
    #endif
    
    private func navigateHistory(direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }
        
        // Save current command if we're at the bottom
        if historyIndex == commandHistory.count {
            savedCommand = currentCommand
        }
        
        switch direction {
        case .previous:
            if historyIndex > 0 {
                historyIndex -= 1
                currentCommand = commandHistory[historyIndex]
                cursorPosition = currentCommand.count
            }
        case .next:
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
                currentCommand = commandHistory[historyIndex]
                cursorPosition = currentCommand.count
            } else if historyIndex == commandHistory.count - 1 {
                historyIndex = commandHistory.count
                currentCommand = savedCommand
                cursorPosition = currentCommand.count
            }
        }
    }
    
    private func performTabCompletion() {
        let components = currentCommand.split(separator: " ")
        guard let lastComponent = components.last else { return }
        
        let partialPath = String(lastComponent)
        let expandedPath = NSString(string: partialPath).expandingTildeInPath
        
        let parentDir: String
        let searchTerm: String
        
        if expandedPath.contains("/") {
            parentDir = URL(fileURLWithPath: expandedPath).deletingLastPathComponent().path
            searchTerm = URL(fileURLWithPath: expandedPath).lastPathComponent
        } else {
            parentDir = session.currentPath.isEmpty ? FileManager.default.currentDirectoryPath : session.currentPath
            searchTerm = expandedPath
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: parentDir)
            let matches = contents.filter { $0.lowercased().hasPrefix(searchTerm.lowercased()) }
            
            if matches.count == 1, let match = matches.first {
                // Replace the partial path with the full match
                let beforeLastComponent = components.dropLast().joined(separator: " ")
                if !beforeLastComponent.isEmpty {
                    currentCommand = beforeLastComponent + " " + match
                } else {
                    currentCommand = match
                }
                
                // Add trailing slash for directories
                let fullPath = parentDir + "/" + match
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    currentCommand += "/"
                }
            } else if matches.count > 1 {
                // Find common prefix
                let commonPrefix = findCommonPrefix(matches)
                if commonPrefix.count > searchTerm.count {
                    let beforeLastComponent = components.dropLast().joined(separator: " ")
                    if !beforeLastComponent.isEmpty {
                        currentCommand = beforeLastComponent + " " + commonPrefix
                    } else {
                        currentCommand = commonPrefix
                    }
                } else {
                    // Show available options
                    scrollbackBuffer.append(currentPrompt + currentCommand + "\n")
                    scrollbackBuffer.append(matches.joined(separator: "  ") + "\n")
                }
            }
        } catch {
            // Silently fail tab completion
        }
    }
    
    private func findCommonPrefix(_ strings: [String]) -> String {
        guard !strings.isEmpty else { return "" }
        guard strings.count > 1 else { return strings[0] }
        
        let sorted = strings.sorted()
        let first = sorted.first!
        let last = sorted.last!
        
        var commonPrefix = ""
        for (char1, char2) in zip(first, last) {
            if char1 == char2 {
                commonPrefix.append(char1)
            } else {
                break
            }
        }
        
        return commonPrefix
    }
    
    private func executeCommand() {
        guard !currentCommand.isEmpty else { return }
        
        // Add to history
        if commandHistory.isEmpty || commandHistory.last != currentCommand {
            commandHistory.append(currentCommand)
        }
        historyIndex = commandHistory.count
        savedCommand = ""
        
        // Add command to output
        scrollbackBuffer.append(currentPrompt + currentCommand + "\n")
        
        // Handle clear command locally
        if currentCommand == "clear" {
            scrollbackBuffer.clear()
            currentCommand = ""
            cursorPosition = 0
            return
        }
        
        // Send to session
        isCommandRunning = true
        session.sendInput(currentCommand)
        currentCommand = ""
        cursorPosition = 0
    }
    
    private enum HistoryDirection {
        case previous, next
    }
    
    #if canImport(AppKit)
    // Helper function to find the key handler view in the view hierarchy
    private func findKeyHandlerView(in view: NSView?) -> KeyHandlingView? {
        guard let view = view else { return nil }
        
        if let keyHandlerView = view as? KeyHandlingView {
            return keyHandlerView
        }
        
        for subview in view.subviews {
            if let found = findKeyHandlerView(in: subview) {
                return found
            }
        }
        
        return nil
    }
    #endif
}

#if canImport(AppKit)
// Extension to handle key events (macOS only)
extension View {
    func onTerminalKeyPress(perform action: @escaping (KeyPress) -> KeyPress.Result) -> some View {
        return self.background(KeyEventHandler(action: action))
    }
}

struct KeyEventHandler: NSViewRepresentable {
    let action: (KeyPress) -> KeyPress.Result
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyHandlingView()
        view.onKeyPress = action
        
        // Note: makeNSView is already on main thread, no need for async dispatch
        // The view will become first responder when it's added to the view hierarchy
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // updateNSView is called frequently during SwiftUI updates
        // Since action is a let constant and set in makeNSView, no updates needed
        // This prevents "Modifying state during view update" warnings
    }
}

class KeyHandlingView: NSView {
    var onKeyPress: ((KeyPress) -> KeyPress.Result)?
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Request focus when added to window - but only if window is key and we can accept
        if let window = self.window, 
           window.isKeyWindow,
           self.acceptsFirstResponder,
           window.firstResponder != self {
            window.makeFirstResponder(self)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Ensure we become first responder when clicked - but only if needed
        if let window = self.window, 
           window.firstResponder != self,
           self.acceptsFirstResponder {
            window.makeFirstResponder(self)
        }
        super.mouseDown(with: event)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // awakeFromNib is called during view setup - avoid makeFirstResponder here
        // Focus will be handled by viewDidMoveToWindow and user interactions
    }
    
    override func keyDown(with event: NSEvent) {
        // Convert NSEvent to our KeyPress type
        let keyPress = KeyPress(
            keyCode: event.keyCode,
            characters: event.characters ?? "",
            modifiers: EventModifiers(event)
        )
        
        if let onKeyPress = onKeyPress {
            let result = onKeyPress(keyPress)
            if result == .ignored {
                super.keyDown(with: event)
            }
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return true
    }
}

// Simple KeyPress implementation for older macOS
struct KeyPress {
    enum Result {
        case handled
        case ignored
    }
    
    let keyCode: UInt16
    let characters: String
    let modifiers: EventModifiers
}

extension EventModifiers {
    init(_ event: NSEvent) {
        var modifiers: EventModifiers = []
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        self = modifiers
    }
}
#endif