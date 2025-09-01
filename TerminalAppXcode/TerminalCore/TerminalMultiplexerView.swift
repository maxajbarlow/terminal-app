import SwiftUI

// MARK: - Terminal Multiplexer View

public struct TerminalMultiplexerView: View {
    
    @StateObject private var multiplexer = TerminalMultiplexer()
    @State private var showSessionManager = false
    @State private var commandProcessor: MultiplexerCommandProcessor?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            if multiplexer.isAttached, let session = multiplexer.activeSession {
                // Status bar
                MultiplexerStatusBar(
                    multiplexer: multiplexer,
                    onSessionManager: { showSessionManager = true }
                )
                
                // Active window content
                if let window = session.activeWindow {
                    WindowView(window: window, multiplexer: multiplexer)
                } else {
                    EmptyWindowView()
                }
            } else {
                // Session selection screen
                SessionManagerView(multiplexer: multiplexer)
            }
        }
        .onAppear {
            commandProcessor = MultiplexerCommandProcessor(multiplexer: multiplexer)
        }
        .sheet(isPresented: $showSessionManager) {
            SessionManagerView(multiplexer: multiplexer)
        }
        .keyboardShortcuts(multiplexer: multiplexer)
    }
}

// MARK: - Multiplexer Status Bar

struct MultiplexerStatusBar: View {
    
    @ObservedObject var multiplexer: TerminalMultiplexer
    let onSessionManager: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Session indicator
            Button(action: onSessionManager) {
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.3.group")
                        .font(.caption)
                    Text(multiplexer.activeSession?.name ?? "No Session")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(4)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Window tabs
            if let session = multiplexer.activeSession {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(session.windows.enumerated()), id: \.element.id) { index, window in
                            WindowTab(
                                window: window,
                                isActive: index == session.activeWindowIndex,
                                onSelect: { 
                                    session.activeWindowIndex = index
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 8) {
                // New window
                Button(action: { multiplexer.createWindow() }) {
                    Image(systemName: "plus.rectangle")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                .help("New Window (⌘T)")
                
                // Split horizontal
                Button(action: { multiplexer.splitHorizontal() }) {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Split Horizontal (⌘D)")
                
                // Split vertical
                Button(action: { multiplexer.splitVertical() }) {
                    Image(systemName: "rectangle.split.1x2")
                        .font(.caption)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Split Vertical (⌘⇧D)")
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.secondary.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Window Tab

struct WindowTab: View {
    
    let window: TerminalMultiplexWindow
    let isActive: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Text(window.name)
                    .font(.caption)
                    .fontWeight(isActive ? .medium : .regular)
                
                // Pane count indicator
                if window.panes.count > 1 {
                    Text("\(window.panes.count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 3)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isActive ? Color.accentColor : Color.clear
            )
            .foregroundColor(
                isActive ? .white : .primary
            )
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Window View

struct WindowView: View {
    
    @ObservedObject var window: TerminalMultiplexWindow
    @ObservedObject var multiplexer: TerminalMultiplexer
    
    var body: some View {
        GeometryReader { geometry in
            switch window.layout {
            case .single:
                SinglePaneView(window: window, multiplexer: multiplexer)
                
            case .horizontal:
                HorizontalSplitView(window: window, multiplexer: multiplexer, geometry: geometry)
                
            case .vertical:
                VerticalSplitView(window: window, multiplexer: multiplexer, geometry: geometry)
                
            case .grid:
                GridPaneView(window: window, multiplexer: multiplexer, geometry: geometry)
                
            case .complex:
                ComplexLayoutView(window: window, multiplexer: multiplexer, geometry: geometry)
            }
        }
    }
}

// MARK: - Single Pane View

struct SinglePaneView: View {
    
    @ObservedObject var window: TerminalMultiplexWindow
    @ObservedObject var multiplexer: TerminalMultiplexer
    
    var body: some View {
        if let pane = window.panes.first {
            PaneView(pane: pane, isActive: true, multiplexer: multiplexer)
        } else {
            EmptyPaneView()
        }
    }
}

// MARK: - Horizontal Split View

struct HorizontalSplitView: View {
    
    @ObservedObject var window: TerminalMultiplexWindow
    @ObservedObject var multiplexer: TerminalMultiplexer
    let geometry: GeometryProxy
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(window.panes.enumerated()), id: \.element.id) { index, pane in
                PaneView(
                    pane: pane,
                    isActive: pane.id == window.activePaneId,
                    multiplexer: multiplexer
                )
                .frame(width: geometry.size.width / CGFloat(window.panes.count))
                
                if index < window.panes.count - 1 {
                    SplitDivider()
                }
            }
        }
    }
}

// MARK: - Vertical Split View

struct VerticalSplitView: View {
    
    @ObservedObject var window: TerminalMultiplexWindow
    @ObservedObject var multiplexer: TerminalMultiplexer
    let geometry: GeometryProxy
    
    var body: some View {
        VStack(spacing: 1) {
            ForEach(Array(window.panes.enumerated()), id: \.element.id) { index, pane in
                PaneView(
                    pane: pane,
                    isActive: pane.id == window.activePaneId,
                    multiplexer: multiplexer
                )
                .frame(height: geometry.size.height / CGFloat(window.panes.count))
                
                if index < window.panes.count - 1 {
                    SplitDivider()
                }
            }
        }
    }
}

// MARK: - Grid Pane View

struct GridPaneView: View {
    
    @ObservedObject var window: TerminalMultiplexWindow
    @ObservedObject var multiplexer: TerminalMultiplexer
    let geometry: GeometryProxy
    
    var body: some View {
        let columns = window.panes.count <= 2 ? 1 : 2
        let rows = Int(ceil(Double(window.panes.count) / Double(columns)))
        
        VStack(spacing: 1) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < window.panes.count {
                            let pane = window.panes[index]
                            PaneView(
                                pane: pane,
                                isActive: pane.id == window.activePaneId,
                                multiplexer: multiplexer
                            )
                        } else {
                            Spacer()
                        }
                    }
                }
                .frame(height: geometry.size.height / CGFloat(rows))
            }
        }
    }
}

// MARK: - Complex Layout View

struct ComplexLayoutView: View {
    
    @ObservedObject var window: TerminalMultiplexWindow
    @ObservedObject var multiplexer: TerminalMultiplexer
    let geometry: GeometryProxy
    
    var body: some View {
        // For now, fallback to grid layout for complex arrangements
        GridPaneView(window: window, multiplexer: multiplexer, geometry: geometry)
    }
}

// MARK: - Pane View

struct PaneView: View {
    
    @ObservedObject var pane: TerminalMultiplexPane
    let isActive: Bool
    @ObservedObject var multiplexer: TerminalMultiplexer
    
    var body: some View {
        ZStack {
            // Terminal content
            NativeTerminalView(session: pane.session)
            
            // Active indicator
            if isActive {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .onTapGesture {
            if let window = multiplexer.activeSession?.activeWindow {
                window.activePaneId = pane.id
            }
        }
    }
}

// MARK: - Split Divider

struct SplitDivider: View {
    
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 1, height: nil)
    }
}

// MARK: - Empty Views

struct EmptyWindowView: View {
    var body: some View {
        VStack {
            Image(systemName: "terminal")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No active window")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

struct EmptyPaneView: View {
    var body: some View {
        VStack {
            Image(systemName: "rectangle.dashed")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("Empty pane")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Session Manager View

struct SessionManagerView: View {
    
    @ObservedObject var multiplexer: TerminalMultiplexer
    @State private var newSessionName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Session list
                List {
                    ForEach(multiplexer.sessions) { session in
                        SessionRow(
                            session: session,
                            isActive: session.id == multiplexer.activeSessionId,
                            onAttach: { 
                                multiplexer.attachToSession(session.id)
                            },
                            onKill: {
                                multiplexer.killSession(session.id)
                            }
                        )
                    }
                }
                
                // New session
                HStack {
                    TextField("New session name", text: $newSessionName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Create") {
                        let name = newSessionName.isEmpty ? nil : newSessionName
                        let session = multiplexer.createSession(name: name)
                        multiplexer.attachToSession(session.id)
                        newSessionName = ""
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                }
                .padding()
            }
            .navigationTitle("Terminal Sessions")
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    
    let session: TerminalMultiplexSession
    let isActive: Bool
    let onAttach: () -> Void
    let onKill: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.name)
                        .font(.headline)
                    
                    if isActive {
                        Text("(active)")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                
                Text("\(session.windows.count) windows")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if !isActive {
                    Button("Attach", action: onAttach)
                        .buttonStyle(BorderedButtonStyle())
                }
                
                Button("Kill", action: onKill)
                    .buttonStyle(BorderedButtonStyle())
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Keyboard Shortcuts

extension View {
    func keyboardShortcuts(multiplexer: TerminalMultiplexer) -> some View {
        self
            .keyboardShortcut("t", modifiers: .command) {
                multiplexer.createWindow()
            }
            .keyboardShortcut("d", modifiers: .command) {
                multiplexer.splitHorizontal()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift]) {
                multiplexer.splitVertical()
            }
            .keyboardShortcut("w", modifiers: .command) {
                multiplexer.killWindow()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift]) {
                multiplexer.killPane()
            }
            .keyboardShortcut("]", modifiers: .command) {
                multiplexer.nextWindow()
            }
            .keyboardShortcut("[", modifiers: .command) {
                multiplexer.previousWindow()
            }
            .keyboardShortcut("o", modifiers: .command) {
                multiplexer.nextPane()
            }
    }
}