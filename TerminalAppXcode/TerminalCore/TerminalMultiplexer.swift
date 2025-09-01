import Foundation
import SwiftUI
import Combine

// MARK: - Terminal Multiplexer Core

/// Terminal multiplexer similar to tmux - manages sessions, windows, and panes
public class TerminalMultiplexer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var sessions: [TerminalMultiplexSession] = []
    @Published public var activeSessionId: String?
    @Published public var isAttached: Bool = false
    
    // MARK: - Private Properties
    
    private var sessionCounter: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultSession()
    }
    
    // MARK: - Session Management
    
    /// Create a new multiplexer session
    @discardableResult
    public func createSession(name: String? = nil, 
                            workingDirectory: String? = nil,
                            command: String? = nil) -> TerminalMultiplexSession {
        sessionCounter += 1
        let sessionName = name ?? "session-\(sessionCounter)"
        
        let session = TerminalMultiplexSession(
            id: UUID().uuidString,
            name: sessionName,
            workingDirectory: workingDirectory
        )
        
        // Create initial window with initial pane
        let initialWindow = session.createWindow(name: "main")
        if let command = command {
            initialWindow.activePane?.executeCommand(command)
        }
        
        sessions.append(session)
        
        // Auto-attach if no active session
        if activeSessionId == nil {
            attachToSession(session.id)
        }
        
        return session
    }
    
    /// Attach to a specific session
    public func attachToSession(_ sessionId: String) {
        guard sessions.contains(where: { $0.id == sessionId }) else { return }
        
        activeSessionId = sessionId
        isAttached = true
        
        // Subscribe to session changes
        if let session = getSession(sessionId) {
            session.objectWillChange
                .sink { [weak self] in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }
    
    /// Detach from current session
    public func detachFromSession() {
        activeSessionId = nil
        isAttached = false
        cancellables.removeAll()
    }
    
    /// Kill a session
    public func killSession(_ sessionId: String) {
        sessions.removeAll { $0.id == sessionId }
        
        if activeSessionId == sessionId {
            // Switch to next available session or create new one
            if let nextSession = sessions.first {
                attachToSession(nextSession.id)
            } else {
                setupDefaultSession()
            }
        }
    }
    
    /// Get session by ID
    public func getSession(_ sessionId: String) -> TerminalMultiplexSession? {
        return sessions.first { $0.id == sessionId }
    }
    
    /// Get currently active session
    public var activeSession: TerminalMultiplexSession? {
        guard let sessionId = activeSessionId else { return nil }
        return getSession(sessionId)
    }
    
    // MARK: - Window Management
    
    /// Create new window in active session
    @discardableResult
    public func createWindow(name: String? = nil) -> TerminalMultiplexWindow? {
        return activeSession?.createWindow(name: name)
    }
    
    /// Switch to next window in active session
    public func nextWindow() {
        activeSession?.nextWindow()
    }
    
    /// Switch to previous window in active session
    public func previousWindow() {
        activeSession?.previousWindow()
    }
    
    /// Kill current window in active session
    public func killWindow() {
        activeSession?.killCurrentWindow()
    }
    
    // MARK: - Pane Management
    
    /// Split current pane horizontally
    public func splitHorizontal() {
        activeSession?.activeWindow?.splitCurrentPaneHorizontally()
    }
    
    /// Split current pane vertically
    public func splitVertical() {
        activeSession?.activeWindow?.splitCurrentPaneVertically()
    }
    
    /// Move to next pane
    public func nextPane() {
        activeSession?.activeWindow?.nextPane()
    }
    
    /// Move to previous pane
    public func previousPane() {
        activeSession?.activeWindow?.previousPane()
    }
    
    /// Kill current pane
    public func killPane() {
        activeSession?.activeWindow?.killCurrentPane()
    }
    
    // MARK: - Commands
    
    /// Send command to current pane
    public func sendCommand(_ command: String) {
        activeSession?.activeWindow?.activePane?.executeCommand(command)
    }
    
    /// Send keys to current pane
    public func sendKeys(_ keys: String) {
        activeSession?.activeWindow?.activePane?.sendKeys(keys)
    }
    
    // MARK: - Status Information
    
    public var statusLine: String {
        guard let session = activeSession else { return "No session" }
        let windowInfo = session.windows.enumerated().map { index, window in
            let prefix = index == session.activeWindowIndex ? "*" : ""
            return "\(prefix)\(window.name)"
        }.joined(separator: " ")
        
        return "[\(session.name)] \(windowInfo)"
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultSession() {
        let defaultSession = createSession(name: "main")
        attachToSession(defaultSession.id)
    }
}

// MARK: - Terminal Multiplexer Session

public class TerminalMultiplexSession: ObservableObject, Identifiable {
    
    // MARK: - Properties
    
    public let id: String
    public let name: String
    public let workingDirectory: String?
    public let createdAt: Date
    
    @Published public var windows: [TerminalMultiplexWindow] = []
    @Published public var activeWindowIndex: Int = 0
    
    private var windowCounter: Int = 0
    
    // MARK: - Initialization
    
    init(id: String, name: String, workingDirectory: String? = nil) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.createdAt = Date()
    }
    
    // MARK: - Window Management
    
    @discardableResult
    func createWindow(name: String? = nil) -> TerminalMultiplexWindow {
        windowCounter += 1
        let windowName = name ?? "window-\(windowCounter)"
        
        let window = TerminalMultiplexWindow(
            id: UUID().uuidString,
            name: windowName,
            workingDirectory: workingDirectory
        )
        
        windows.append(window)
        activeWindowIndex = windows.count - 1
        
        return window
    }
    
    func nextWindow() {
        guard !windows.isEmpty else { return }
        activeWindowIndex = (activeWindowIndex + 1) % windows.count
    }
    
    func previousWindow() {
        guard !windows.isEmpty else { return }
        activeWindowIndex = activeWindowIndex > 0 ? activeWindowIndex - 1 : windows.count - 1
    }
    
    func killCurrentWindow() {
        guard activeWindowIndex < windows.count else { return }
        
        windows.remove(at: activeWindowIndex)
        
        if windows.isEmpty {
            // Create a new default window
            createWindow(name: "main")
        } else {
            // Adjust active window index
            activeWindowIndex = min(activeWindowIndex, windows.count - 1)
        }
    }
    
    var activeWindow: TerminalMultiplexWindow? {
        guard activeWindowIndex < windows.count else { return nil }
        return windows[activeWindowIndex]
    }
}

// MARK: - Terminal Multiplexer Window

public class TerminalMultiplexWindow: ObservableObject, Identifiable {
    
    // MARK: - Properties
    
    public let id: String
    public let name: String
    public let workingDirectory: String?
    public let createdAt: Date
    
    @Published public var panes: [TerminalMultiplexPane] = []
    @Published public var activePaneId: String?
    @Published public var layout: PaneLayout = .single
    
    // MARK: - Initialization
    
    init(id: String, name: String, workingDirectory: String? = nil) {
        self.id = id
        self.name = name
        self.workingDirectory = workingDirectory
        self.createdAt = Date()
        
        // Create initial pane
        createInitialPane()
    }
    
    // MARK: - Pane Management
    
    private func createInitialPane() {
        let initialPane = TerminalMultiplexPane(
            id: UUID().uuidString,
            workingDirectory: workingDirectory
        )
        
        panes.append(initialPane)
        activePaneId = initialPane.id
        layout = .single
    }
    
    func splitCurrentPaneHorizontally() {
        guard let currentPane = activePane else { return }
        
        let newPane = TerminalMultiplexPane(
            id: UUID().uuidString,
            workingDirectory: currentPane.session.currentPath
        )
        
        panes.append(newPane)
        activePaneId = newPane.id
        
        // Update layout
        updateLayoutForSplit()
    }
    
    func splitCurrentPaneVertically() {
        guard let currentPane = activePane else { return }
        
        let newPane = TerminalMultiplexPane(
            id: UUID().uuidString,
            workingDirectory: currentPane.session.currentPath
        )
        
        panes.append(newPane)
        activePaneId = newPane.id
        
        // Update layout
        updateLayoutForSplit()
    }
    
    func nextPane() {
        guard panes.count > 1,
              let currentIndex = panes.firstIndex(where: { $0.id == activePaneId }) else { return }
        
        let nextIndex = (currentIndex + 1) % panes.count
        activePaneId = panes[nextIndex].id
    }
    
    func previousPane() {
        guard panes.count > 1,
              let currentIndex = panes.firstIndex(where: { $0.id == activePaneId }) else { return }
        
        let previousIndex = currentIndex > 0 ? currentIndex - 1 : panes.count - 1
        activePaneId = panes[previousIndex].id
    }
    
    func killCurrentPane() {
        guard let paneId = activePaneId,
              let paneIndex = panes.firstIndex(where: { $0.id == paneId }),
              panes.count > 1 else { return }
        
        panes.remove(at: paneIndex)
        
        // Switch to next pane
        if paneIndex < panes.count {
            activePaneId = panes[paneIndex].id
        } else if paneIndex > 0 {
            activePaneId = panes[paneIndex - 1].id
        }
        
        // Update layout
        updateLayoutAfterKill()
    }
    
    var activePane: TerminalMultiplexPane? {
        guard let paneId = activePaneId else { return nil }
        return panes.first { $0.id == paneId }
    }
    
    // MARK: - Layout Management
    
    private func updateLayoutForSplit() {
        switch panes.count {
        case 1:
            layout = .single
        case 2:
            layout = .horizontal
        case 3...4:
            layout = .grid
        default:
            layout = .complex
        }
    }
    
    private func updateLayoutAfterKill() {
        updateLayoutForSplit()
    }
}

// MARK: - Terminal Multiplexer Pane

public class TerminalMultiplexPane: ObservableObject, Identifiable {
    
    // MARK: - Properties
    
    public let id: String
    public let createdAt: Date
    
    @Published public var session: TerminalSession
    @Published public var isActive: Bool = false
    
    // MARK: - Initialization
    
    init(id: String, workingDirectory: String? = nil, connectionInfo: ConnectionInfo? = nil) {
        self.id = id
        self.createdAt = Date()
        
        if let connectionInfo = connectionInfo {
            self.session = TerminalSession(connectionInfo: connectionInfo)
        } else {
            self.session = TerminalSession()
        }
        
        // Set working directory if provided
        if let workingDir = workingDirectory {
            session.currentPath = workingDir
        }
    }
    
    // MARK: - Terminal Operations
    
    func executeCommand(_ command: String) {
        session.executeCommand(command)
    }
    
    func sendKeys(_ keys: String) {
        session.sendInput(keys)
    }
    
    func interruptCommand() {
        session.interruptCurrentCommand()
    }
}

// MARK: - Supporting Types

public enum PaneLayout {
    case single
    case horizontal
    case vertical
    case grid
    case complex
}

// MARK: - Multiplexer Commands

/// Command processor for multiplexer-specific commands (similar to tmux commands)
public class MultiplexerCommandProcessor {
    
    private weak var multiplexer: TerminalMultiplexer?
    
    init(multiplexer: TerminalMultiplexer) {
        self.multiplexer = multiplexer
    }
    
    /// Process multiplexer command (e.g., "tmux new-session", "tmux split-window")
    func processCommand(_ command: String) -> Bool {
        let components = command.components(separatedBy: .whitespaces)
        guard let firstComponent = components.first else { return false }
        
        // Handle tmux-style commands
        if firstComponent == "tmux" || firstComponent == "mux" {
            return processTmuxCommand(Array(components.dropFirst()))
        }
        
        return false
    }
    
    private func processTmuxCommand(_ args: [String]) -> Bool {
        guard let command = args.first else { return false }
        
        switch command {
        case "new-session", "new":
            let name = extractOption(args, option: "-s") ?? extractOption(args, option: "--session-name")
            multiplexer?.createSession(name: name)
            return true
            
        case "new-window", "neww":
            let name = extractOption(args, option: "-n") ?? extractOption(args, option: "--window-name")
            multiplexer?.createWindow(name: name)
            return true
            
        case "split-window", "splitw":
            if args.contains("-h") || args.contains("--horizontal") {
                multiplexer?.splitHorizontal()
            } else {
                multiplexer?.splitVertical()
            }
            return true
            
        case "next-window", "next":
            multiplexer?.nextWindow()
            return true
            
        case "previous-window", "prev":
            multiplexer?.previousWindow()
            return true
            
        case "select-pane", "selectp":
            if args.contains("-t") || args.contains("--target") {
                // TODO: Implement pane selection by target
            } else if args.contains("-L") {
                // TODO: Move left
            } else if args.contains("-R") {
                // TODO: Move right  
            } else if args.contains("-U") {
                // TODO: Move up
            } else if args.contains("-D") {
                // TODO: Move down
            }
            return true
            
        case "kill-pane":
            multiplexer?.killPane()
            return true
            
        case "kill-window":
            multiplexer?.killWindow()
            return true
            
        case "detach", "detach-client":
            multiplexer?.detachFromSession()
            return true
            
        case "list-sessions", "ls":
            // TODO: Print session list
            return true
            
        default:
            return false
        }
    }
    
    private func extractOption(_ args: [String], option: String) -> String? {
        guard let index = args.firstIndex(of: option),
              index + 1 < args.count else { return nil }
        return args[index + 1]
    }
}