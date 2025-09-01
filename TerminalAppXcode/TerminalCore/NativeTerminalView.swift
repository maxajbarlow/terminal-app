#if os(macOS)
import AppKit
import SwiftUI

public class NativeTerminalTextView: NSView {
    var onInput: ((String) -> Void)?
    var session: TerminalSession?
    private let settings = SettingsManager.shared
    
    private var scrollView: NSScrollView!
    var terminalTextView: NSTextView!
    private var currentInput: String = ""
    private var promptText: String = ""
    private var commandHistory: [String] = []
    private var historyIndex: Int = 0
    private var isCommandRunning: Bool = false
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Create terminal scroll view and text view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = NSColor.black
        
        terminalTextView = NSTextView()
        terminalTextView.isEditable = true
        terminalTextView.isSelectable = true
        terminalTextView.isRichText = false
        terminalTextView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
        updateTerminalColors()
        
        // Observe settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: NSNotification.Name("SettingsChanged"),
            object: nil
        )
        
        // Observe theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeChanged),
            name: .terminalThemeChanged,
            object: nil
        )
        terminalTextView.isAutomaticQuoteSubstitutionEnabled = false
        terminalTextView.isVerticallyResizable = true
        terminalTextView.isHorizontallyResizable = false
        terminalTextView.delegate = self
        
        // Configure text container properly
        if let textContainer = terminalTextView.textContainer {
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textContainer.widthTracksTextView = true
            textContainer.heightTracksTextView = false
        }
        
        // Set initial frame for the text view
        terminalTextView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        terminalTextView.minSize = NSSize(width: 0, height: 0)
        terminalTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        
        scrollView.documentView = terminalTextView
        
        // Add subviews
        addSubview(scrollView)
        
        // Set background colors
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Setup constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        
        // Add initial prompt
        showNewPrompt()
        
        // Force layout
        self.needsLayout = true
        self.layoutSubtreeIfNeeded()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func settingsChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateTerminalColors()
            self?.updateTerminalFont()
        }
    }
    
    @objc private func themeChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateTerminalColors()
            // Refresh the current text to apply new theme colors
            self?.terminalTextView.needsDisplay = true
        }
    }
    
    private func updateTerminalColors() {
        #if canImport(AppKit)
        let currentTheme = TerminalTheme.shared
        let colorScheme = currentTheme.colorScheme
        
        terminalTextView.textColor = colorScheme.foreground.nsColor
        terminalTextView.backgroundColor = colorScheme.background.nsColor
        scrollView.backgroundColor = colorScheme.background.nsColor
        terminalTextView.insertionPointColor = colorScheme.cursor.nsColor
        terminalTextView.selectedTextAttributes = [
            .backgroundColor: colorScheme.selection.nsColor
        ]
        #endif
    }
    
    private func updateTerminalFont() {
        terminalTextView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
    }
    
    private func showNewPrompt() {
        guard let session = session else { return }
        
        let username = NSUserName()
        let hostname = ProcessInfo.processInfo.hostName
        let homeDir = NSHomeDirectory()
        let currentPath = session.currentPath.isEmpty ? FileManager.default.currentDirectoryPath : session.currentPath
        let displayPath = currentPath.hasPrefix(homeDir) ? currentPath.replacingOccurrences(of: homeDir, with: "~") : currentPath
        let directoryName = URL(fileURLWithPath: displayPath).lastPathComponent == "~" ? "~" : URL(fileURLWithPath: displayPath).lastPathComponent
        
        promptText = "\(username)@\(hostname) \(directoryName) % "
        currentInput = ""
        
        let currentText = terminalTextView.string
        let newText = currentText + promptText
        
        // Create attributed string with ANSI parsing
        let attributedText = ANSIParser.attributedStringFromANSI(
            newText,
            defaultForeground: NSColor(settings.textColor),
            defaultBackground: NSColor(settings.backgroundColor),
            font: NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
        )
        
        terminalTextView.textStorage?.setAttributedString(attributedText)
        
        // Move cursor to end
        let range = NSRange(location: terminalTextView.string.count, length: 0)
        terminalTextView.selectedRange = range
        
        // Scroll to bottom
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        if let textStorage = terminalTextView.textStorage {
            let range = NSRange(location: textStorage.length, length: 0)
            terminalTextView.scrollRangeToVisible(range)
        }
    }
    
    private func executeCommand(_ command: String) {
        // Add the command to the terminal display
        let fullCommand = promptText + command
        let currentText = terminalTextView.string
        let textWithoutPrompt = String(currentText.dropLast(promptText.count + currentInput.count))
        let newText = textWithoutPrompt + fullCommand + "\n"
        
        // Create attributed string with ANSI parsing
        let attributedText = ANSIParser.attributedStringFromANSI(
            newText,
            defaultForeground: NSColor(settings.textColor),
            defaultBackground: NSColor(settings.backgroundColor),
            font: NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
        )
        
        terminalTextView.textStorage?.setAttributedString(attributedText)
        
        // Add command to history if it's not empty and not the same as the last command
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        if !trimmedCommand.isEmpty && (commandHistory.isEmpty || commandHistory.last != trimmedCommand) {
            commandHistory.append(trimmedCommand)
        }
        
        // Reset history index
        historyIndex = commandHistory.count
        
        // Handle clear command locally
        if trimmedCommand == "clear" {
            terminalTextView.textStorage?.setAttributedString(NSAttributedString())
            showNewPrompt()
            return
        }
        
        // Mark command as running
        isCommandRunning = true
        
        // Send command for execution
        onInput?(command)
    }
    
    func updateOutput(_ text: String) {
        // Parse ANSI escape sequences and apply formatting
        let attributedText = ANSIParser.attributedStringFromANSI(
            text,
            defaultForeground: NSColor(settings.textColor),
            defaultBackground: NSColor(settings.backgroundColor),
            font: NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
        )
        
        terminalTextView.textStorage?.setAttributedString(attributedText)
        if !isCommandRunning {
            showNewPrompt()
        }
    }
    
    func commandCompleted() {
        // Mark command as completed and show new prompt
        isCommandRunning = false
        
        // Ensure we add a newline if the output doesn't end with one
        let currentText = terminalTextView.string
        if !currentText.isEmpty && !currentText.hasSuffix("\n") {
            terminalTextView.string = currentText + "\n"
        }
        
        showNewPrompt()
    }
    
    func appendOutput(_ text: String) {
        // Parse ANSI escape sequences for the new text
        let newAttributedText = ANSIParser.attributedStringFromANSI(
            text,
            defaultForeground: NSColor(settings.textColor),
            defaultBackground: NSColor(settings.backgroundColor),
            font: NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
        )
        
        // During command execution, just append output without worrying about prompts
        if isCommandRunning {
            terminalTextView.textStorage?.append(newAttributedText)
            scrollToBottom()
        } else {
            // Check if we currently have a prompt displayed
            let currentText = terminalTextView.string
            if currentText.hasSuffix(promptText + currentInput) {
                // Remove the current prompt and input temporarily
                let textWithoutPrompt = String(currentText.dropLast(promptText.count + currentInput.count))
                
                // Create attributed string for text without prompt
                let textWithoutPromptAttributed = ANSIParser.attributedStringFromANSI(
                    textWithoutPrompt,
                    defaultForeground: NSColor(settings.textColor),
                    defaultBackground: NSColor(settings.backgroundColor),
                    font: NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
                )
                
                // Combine and set
                let combinedText = NSMutableAttributedString(attributedString: textWithoutPromptAttributed)
                combinedText.append(newAttributedText)
                terminalTextView.textStorage?.setAttributedString(combinedText)
            } else {
                // No active prompt, just append the output
                terminalTextView.textStorage?.append(newAttributedText)
            }
            
            scrollToBottom()
        }
    }
    
    
    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Focus the terminal text view when view appears
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(self?.terminalTextView)
        }
    }
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func becomeFirstResponder() -> Bool {
        window?.makeFirstResponder(terminalTextView)
        return true
    }
}

// MARK: - NSTextViewDelegate

extension NativeTerminalTextView: NSTextViewDelegate {
    public func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // Enter key pressed
            let command = currentInput.trimmingCharacters(in: .whitespaces)
            executeCommand(command)
            return true
        } else if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
            // Simple backspace handling
            if !currentInput.isEmpty {
                currentInput.removeLast()
                updateCurrentLine()
            }
            return true
        } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
            // Tab key pressed - handle completion
            handleTabCompletion()
            return true
        } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            // Ctrl+C pressed - interrupt current command
            handleInterrupt()
            return true
        } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
            // Up arrow - previous command in history
            navigateHistory(direction: .previous)
            return true
        } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
            // Down arrow - next command in history
            navigateHistory(direction: .next)
            return true
        }
        
        // Handle regular character input
        return false // Let NSTextView handle normal character insertion
    }
    
    public func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // Only allow typing at the end of the text, after the prompt
        let text = textView.string
        let promptLocation = text.range(of: promptText, options: .backwards)?.upperBound
        
        // Convert String.Index to Int for NSRange comparison
        let promptEnd = promptLocation.map { text.distance(from: text.startIndex, to: $0) } ?? 0
        
        // Only allow changes after the prompt
        if affectedCharRange.location >= promptEnd {
            // Update our current input tracking
            if let replacement = replacementString {
                if affectedCharRange.length == 0 {
                    // Character insertion
                    let insertIndex = affectedCharRange.location - promptEnd
                    if insertIndex <= currentInput.count {
                        let stringIndex = currentInput.index(currentInput.startIndex, offsetBy: insertIndex)
                        currentInput.insert(contentsOf: replacement, at: stringIndex)
                    }
                } else {
                    // Character deletion or replacement
                    let deleteStart = affectedCharRange.location - promptEnd
                    let deleteLength = affectedCharRange.length
                    if deleteStart >= 0 && deleteStart + deleteLength <= currentInput.count {
                        let startIndex = currentInput.index(currentInput.startIndex, offsetBy: deleteStart)
                        let endIndex = currentInput.index(startIndex, offsetBy: deleteLength)
                        currentInput.replaceSubrange(startIndex..<endIndex, with: replacement)
                    }
                }
            }
            return true
        }
        
        // Prevent changes before the prompt
        return false
    }
    
    public func textDidChange(_ notification: Notification) {
        // Disable textDidChange to prevent complex state manipulation that causes crashes
        // All text changes are now handled explicitly through doCommandBy
    }
    
    private func updateCurrentLine() {
        // Simple and safe approach - find the last prompt and replace everything after it
        let currentText = terminalTextView.string
        let newLineText: String
        
        if let promptRange = currentText.range(of: promptText, options: .backwards) {
            let beforePrompt = String(currentText[..<promptRange.lowerBound])
            newLineText = beforePrompt + promptText + currentInput
        } else {
            // Fallback - just append prompt and input
            newLineText = currentText + promptText + currentInput
        }
        
        // Create attributed string with ANSI parsing
        let attributedText = ANSIParser.attributedStringFromANSI(
            newLineText,
            defaultForeground: NSColor.green,
            defaultBackground: NSColor.black,
            font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        )
        
        terminalTextView.textStorage?.setAttributedString(attributedText)
        
        // Move cursor to end safely
        let newLength = terminalTextView.string.count
        terminalTextView.selectedRange = NSRange(location: newLength, length: 0)
    }
    
    private func handleTabCompletion() {
        guard let session = session else { return }
        
        // Parse the current input to find what needs completion
        let words = currentInput.components(separatedBy: " ")
        guard !words.isEmpty else { return }
        
        let lastWord = words.last ?? ""
        let isFirstWord = words.count == 1
        
        // Get current working directory
        let workingDir = session.currentPath.isEmpty ? FileManager.default.currentDirectoryPath : session.currentPath
        
        // Determine the directory to search in
        var searchDir = workingDir
        var searchPrefix = lastWord
        
        // Handle paths with directory components
        if lastWord.contains("/") {
            let lastWordURL = URL(fileURLWithPath: lastWord)
            let directory = lastWordURL.deletingLastPathComponent().path
            searchPrefix = lastWordURL.lastPathComponent
            
            if lastWord.hasPrefix("/") {
                // Absolute path
                searchDir = directory
            } else if lastWord.hasPrefix("~/") {
                // Home-relative path
                searchDir = NSHomeDirectory() + String(directory.dropFirst(1))
            } else {
                // Relative path
                searchDir = (workingDir as NSString).appendingPathComponent(directory)
            }
        } else if lastWord.hasPrefix("~/") {
            searchDir = NSHomeDirectory()
            searchPrefix = String(lastWord.dropFirst(2))
        }
        
        // Get completions
        let completions = findCompletions(in: searchDir, prefix: searchPrefix, commandContext: isFirstWord)
        
        if completions.isEmpty {
            // No completions - maybe add a subtle beep or flash
            NSSound.beep()
        } else if completions.count == 1 {
            // Single completion - complete it
            let completion = completions[0]
            completeCurrentWord(with: completion, lastWord: lastWord)
        } else {
            // Multiple completions - show them
            showCompletions(completions, originalWord: lastWord)
        }
    }
    
    private func findCompletions(in directory: String, prefix: String, commandContext: Bool) -> [String] {
        var completions: [String] = []
        
        // For first word (command), also include built-in commands
        if commandContext {
            let builtinCommands = ["help", "config", "connect", "about", "version", "clear"]
            completions += builtinCommands.filter { $0.hasPrefix(prefix) }
        }
        
        // Find file/directory completions
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: directory)
            for item in contents {
                if item.hasPrefix(prefix) && !item.hasPrefix(".") || prefix.hasPrefix(".") && item.hasPrefix(prefix) {
                    var completion = item
                    
                    // Check if it's a directory and add trailing slash
                    let fullPath = (directory as NSString).appendingPathComponent(item)
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                        completion += "/"
                    }
                    
                    completions.append(completion)
                }
            }
        } catch {
            // Directory not accessible
        }
        
        return completions.sorted()
    }
    
    private func completeCurrentWord(with completion: String, lastWord: String) {
        // Replace the last word with the completion
        var words = currentInput.components(separatedBy: " ")
        if !words.isEmpty {
            // Handle path completion
            if lastWord.contains("/") {
                let lastWordURL = URL(fileURLWithPath: lastWord)
                let directory = lastWordURL.deletingLastPathComponent().path
                if directory == "/" {
                    words[words.count - 1] = "/" + completion
                } else if directory.isEmpty {
                    words[words.count - 1] = completion
                } else {
                    words[words.count - 1] = directory + "/" + completion
                }
            } else if lastWord.hasPrefix("~/") {
                words[words.count - 1] = "~/" + completion
            } else {
                words[words.count - 1] = completion
            }
            
            currentInput = words.joined(separator: " ")
            updateCurrentLine()
        }
    }
    
    private func showCompletions(_ completions: [String], originalWord: String) {
        // Add newline and show completions
        let completionText = completions.joined(separator: "  ")
        let currentText = terminalTextView.string
        let textWithoutPrompt = String(currentText.dropLast(promptText.count + currentInput.count))
        
        // Show completions and redisplay prompt
        let newText = textWithoutPrompt + promptText + currentInput + "\n" + completionText + "\n"
        
        // Create attributed string with ANSI parsing
        let attributedText = ANSIParser.attributedStringFromANSI(
            newText,
            defaultForeground: NSColor(settings.textColor),
            defaultBackground: NSColor(settings.backgroundColor),
            font: NSFont.monospacedSystemFont(ofSize: CGFloat(settings.fontSize), weight: .regular)
        )
        
        terminalTextView.textStorage?.setAttributedString(attributedText)
        showNewPrompt()
        
        // Current input is already set, just update the display
        updateCurrentLine()
    }
    
    private func handleInterrupt() {
        if isCommandRunning {
            // Add ^C to the current output
            let currentText = terminalTextView.string
            let newText = currentText + "^C\n"
            
            // Create attributed string with ANSI parsing
            let attributedText = ANSIParser.attributedStringFromANSI(
                newText,
                defaultForeground: NSColor.green,
                defaultBackground: NSColor.black,
                font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            )
            
            terminalTextView.textStorage?.setAttributedString(attributedText)
            
            // Send interrupt signal to the shell
            session?.interruptCurrentCommand()
            
            // Mark command as completed and show new prompt
            isCommandRunning = false
            showNewPrompt()
        } else {
            // Clear current input and show ^C
            let currentText = terminalTextView.string
            let textWithoutCurrentLine = String(currentText.dropLast(promptText.count + currentInput.count))
            
            // Show ^C and start new prompt
            let newText = textWithoutCurrentLine + promptText + currentInput + "^C\n"
            
            // Create attributed string with ANSI parsing
            let attributedText = ANSIParser.attributedStringFromANSI(
                newText,
                defaultForeground: NSColor.green,
                defaultBackground: NSColor.black,
                font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            )
            
            terminalTextView.textStorage?.setAttributedString(attributedText)
            showNewPrompt()
        }
    }
    
    private enum HistoryDirection {
        case previous, next
    }
    
    private func navigateHistory(direction: HistoryDirection) {
        guard !commandHistory.isEmpty else { return }
        
        switch direction {
        case .previous:
            if historyIndex > 0 {
                historyIndex -= 1
                currentInput = commandHistory[historyIndex]
            }
        case .next:
            if historyIndex < commandHistory.count - 1 {
                historyIndex += 1
                currentInput = commandHistory[historyIndex]
            } else if historyIndex == commandHistory.count - 1 {
                historyIndex = commandHistory.count
                currentInput = ""
            }
        }
        
        updateCurrentLine()
    }
}

public struct NativeTerminalView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession
    
    public func makeNSView(context: Context) -> NativeTerminalTextView {
        let view = NativeTerminalTextView()
        view.session = session
        view.onInput = { command in
            session.sendInput(command)
        }
        
        // Disable live output streaming temporarily to fix crashes
        // session.onLiveOutput = { [weak view] liveOutput in
        //     DispatchQueue.main.async {
        //         view?.appendOutput(liveOutput)
        //     }
        // }
        
        // Set up command completion callback
        session.onCommandCompleted = { [weak view] in
            DispatchQueue.main.async {
                view?.commandCompleted()
            }
        }
        
        // Set initial output
        view.updateOutput(session.output)
        
        // Ensure window is key and focused
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = view.window {
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(view.terminalTextView)
            }
        }
        
        return view
    }
    
    public func updateNSView(_ nsView: NativeTerminalTextView, context: Context) {
        // Safe update only when output changes significantly
        let currentContent = nsView.terminalTextView.string
        let newContent = session.output
        
        // Only update if there's a substantial change to avoid frequent updates
        if newContent.count > currentContent.count + 50 || 
           newContent.count < currentContent.count - 10 {
            nsView.updateOutput(session.output)
        }
    }
}
#endif