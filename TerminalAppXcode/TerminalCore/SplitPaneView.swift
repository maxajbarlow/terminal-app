import SwiftUI
import Foundation

public enum SplitDirection {
    case horizontal
    case vertical
}

public struct SplitPaneView: View {
    @StateObject private var splitManager = SplitPaneManager()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Split status bar (only show when multiple panes)
            if splitManager.panes.count > 1 {
                HStack {
                    Text("\(splitManager.panes.count) panes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(splitManager.splitDirection == .horizontal ? "Horizontal" : "Vertical")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("⌘D: Split • ⌘]: Next • ⌘[: Previous • ⌘W: Close")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.05))
            }
            
            // Main content
            ZStack {
                Color.black
                
                if splitManager.panes.count == 1 {
                    // Single pane
                    InlineTerminalView(session: splitManager.panes[0].session)
                        .id(splitManager.panes[0].id)
                } else if splitManager.panes.count > 1 {
                    // Multiple panes
                    splitContainer
                }
            }
        }
        .onAppear {
            if splitManager.panes.isEmpty {
                splitManager.addPane()
            }
        }
        #if canImport(AppKit)
        .background(KeyboardShortcutHandler(splitManager: splitManager))
        #endif
    }
    
    @ViewBuilder
    private var splitContainer: some View {
        if splitManager.splitDirection == .horizontal {
            HStack(spacing: 1) {
                ForEach(splitManager.panes) { pane in
                    paneView(for: pane)
                        .frame(maxWidth: .infinity)
                }
            }
        } else {
            VStack(spacing: 1) {
                ForEach(splitManager.panes) { pane in
                    paneView(for: pane)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }
    
    @ViewBuilder
    private func paneView(for pane: TerminalPane) -> some View {
        VStack(spacing: 0) {
            // Pane header with controls
            HStack(spacing: 8) {
                // Pane indicator
                Circle()
                    .fill(pane.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text("Terminal \(pane.id)")
                    .font(.caption)
                    .foregroundColor(pane.isActive ? .primary : .secondary)
                    .fontWeight(pane.isActive ? .semibold : .regular)
                
                Spacer()
                
                // Split controls (only show for active pane)
                if pane.isActive {
                    Group {
                        // Split horizontally
                        Button(action: {
                            splitManager.splitHorizontally()
                        }) {
                            Image(systemName: "rectangle.split.2x1")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Split Horizontally (⌘D)")
                        
                        // Split vertically
                        Button(action: {
                            splitManager.splitVertically()
                        }) {
                            Image(systemName: "rectangle.split.1x2")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Split Vertically (⌘⇧D)")
                        
                        // Toggle split direction
                        if splitManager.panes.count > 1 {
                            Button(action: {
                                splitManager.toggleSplitDirection()
                            }) {
                                Image(systemName: splitManager.splitDirection == .horizontal ? "rectangle.split.1x2" : "rectangle.split.2x1")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Toggle Split Direction (⌘R)")
                        }
                    }
                }
                
                // Close button (only if more than one pane)
                if splitManager.panes.count > 1 {
                    Button(action: {
                        splitManager.closePane(pane.id)
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Close Pane (⌘W)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(pane.isActive ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            
            // Terminal content
            InlineTerminalView(session: pane.session)
                .id(pane.id)
                .border(pane.isActive ? Color.blue : Color.gray.opacity(0.3), width: pane.isActive ? 2 : 1)
                .onTapGesture {
                    splitManager.setActivePane(pane.id)
                }
                .onAppear {
                    // Connect the app command handler when pane appears
                    setupAppCommandHandler(for: pane)
                }
        }
    }
    
    // Connect app command handler to terminal session
    private func setupAppCommandHandler(for pane: TerminalPane) {
        pane.session.setAppCommandHandler { [weak splitManager] command, args in
            guard let splitManager = splitManager else { return false }
            
            // Set this pane as active when command is executed
            splitManager.setActivePane(pane.id)
            
            return splitManager.handleAppCommand(command, args)
        }
    }
}

// MARK: - Data Models

public class TerminalPane: ObservableObject, Identifiable {
    public let id: Int
    public let session: TerminalSession
    @Published public var isActive: Bool = false
    
    public init(id: Int) {
        self.id = id
        self.session = TerminalSession()
    }
}

public class SplitPaneManager: ObservableObject {
    @Published public var panes: [TerminalPane] = []
    @Published public var splitDirection: SplitDirection = .horizontal
    @Published public var activePaneId: Int? = nil
    
    private var nextId: Int = 1
    
    public init() {}
    
    public func addPane() {
        let pane = TerminalPane(id: nextId)
        nextId += 1
        
        panes.append(pane)
        setActivePane(pane.id)
    }
    
    public func closePane(_ paneId: Int) {
        guard panes.count > 1 else { return } // Don't close the last pane
        
        if let index = panes.firstIndex(where: { $0.id == paneId }) {
            panes.remove(at: index)
            
            // If we closed the active pane, set another one as active
            if activePaneId == paneId {
                if !panes.isEmpty {
                    let newActiveIndex = min(index, panes.count - 1)
                    setActivePane(panes[newActiveIndex].id)
                }
            }
        }
    }
    
    public func setActivePane(_ paneId: Int) {
        // Deactivate all panes
        for pane in panes {
            pane.isActive = false
        }
        
        // Activate the selected pane
        if let pane = panes.first(where: { $0.id == paneId }) {
            pane.isActive = true
            activePaneId = paneId
        }
    }
    
    public func splitHorizontally() {
        splitDirection = .horizontal
        addPane()
    }
    
    public func splitVertically() {
        splitDirection = .vertical
        addPane()
    }
    
    public func toggleSplitDirection() {
        splitDirection = splitDirection == .horizontal ? .vertical : .horizontal
    }
    
    public func switchToNextPane() {
        guard let currentActiveId = activePaneId,
              let currentIndex = panes.firstIndex(where: { $0.id == currentActiveId }) else {
            if !panes.isEmpty {
                setActivePane(panes[0].id)
            }
            return
        }
        
        let nextIndex = (currentIndex + 1) % panes.count
        setActivePane(panes[nextIndex].id)
    }
    
    public func switchToPreviousPane() {
        guard let currentActiveId = activePaneId,
              let currentIndex = panes.firstIndex(where: { $0.id == currentActiveId }) else {
            if let lastPane = panes.last {
                setActivePane(lastPane.id)
            }
            return
        }
        
        let previousIndex = (currentIndex - 1 + panes.count) % panes.count
        setActivePane(panes[previousIndex].id)
    }
    
    // Handle app commands from .. command mode
    public func handleAppCommand(_ command: String, _ args: [String]) -> Bool {
        switch command {
        case "split":
            if let direction = args.first {
                switch direction.lowercased() {
                case "h", "horizontal":
                    splitHorizontally()
                    return true
                case "v", "vertical":
                    splitVertically()
                    return true
                case "toggle":
                    toggleSplitDirection()
                    return true
                default:
                    return false
                }
            } else {
                // Default to horizontal split
                splitHorizontally()
                return true
            }
        case "close":
            if let activePaneId = activePaneId {
                closePane(activePaneId)
                return true
            }
            return false
        case "next":
            switchToNextPane()
            return true
        case "prev", "previous":
            switchToPreviousPane()
            return true
        case "pane":
            if let paneNumberStr = args.first,
               let paneNumber = Int(paneNumberStr),
               paneNumber > 0 && paneNumber <= panes.count {
                let paneId = panes[paneNumber - 1].id
                setActivePane(paneId)
                return true
            }
            return false
        default:
            return false
        }
    }
}

#if canImport(AppKit)
// MARK: - Keyboard Shortcuts (macOS only)

struct KeyboardShortcutHandler: NSViewRepresentable {
    let splitManager: SplitPaneManager
    
    func makeNSView(context: Context) -> NSView {
        let view = ShortcutHandlingView()
        view.splitManager = splitManager
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class ShortcutHandlingView: NSView {
    var splitManager: SplitPaneManager?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Don't become first responder - let the terminal handle input
    }
    
    override func keyDown(with event: NSEvent) {
        guard let splitManager = splitManager else {
            super.keyDown(with: event)
            return
        }
        
        // Handle split pane shortcuts
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "d": // Cmd+D - Split horizontally
                if event.modifierFlags.contains(.shift) {
                    // Cmd+Shift+D - Split vertically
                    splitManager.splitVertically()
                } else {
                    // Cmd+D - Split horizontally
                    splitManager.splitHorizontally()
                }
                return
            case "w": // Cmd+W - Close current pane
                if let activePaneId = splitManager.activePaneId {
                    splitManager.closePane(activePaneId)
                }
                return
            case "r": // Cmd+R - Toggle split direction
                splitManager.toggleSplitDirection()
                return
            case "]": // Cmd+] - Switch to next pane
                splitManager.switchToNextPane()
                return
            case "[": // Cmd+[ - Switch to previous pane
                splitManager.switchToPreviousPane()
                return
            case "1", "2", "3", "4", "5", "6", "7", "8", "9": // Cmd+1-9 - Switch to specific pane
                if let paneNumber = Int(event.charactersIgnoringModifiers ?? ""),
                   paneNumber > 0 && paneNumber <= splitManager.panes.count {
                    let paneId = splitManager.panes[paneNumber - 1].id
                    splitManager.setActivePane(paneId)
                }
                return
            default:
                break
            }
        }
        
        super.keyDown(with: event)
    }
}
#endif