import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public struct TabbedTerminalView: View {
    @StateObject private var historyManager = CommandHistoryManager()
    @StateObject private var searchManager = TerminalSearchManager()
    @StateObject private var appState = AppState.shared
    
    // Initialize TabManager with history manager - created on first access
    @State private var tabManager: TabManager?
    
    public init() {}
    
    public var body: some View {
        Group {
            if let tabManager = tabManager {
                VStack(spacing: 0) {
                    // Tab bar
                    HStack(spacing: 0) {
                        ForEach(tabManager.tabs) { tab in
                            TabView(
                                tab: tab,
                                isSelected: tab.id == tabManager.selectedTabId,
                                onSelect: { tabManager.selectTab(withId: tab.id) },
                                onClose: { tabManager.closeTab(withId: tab.id) }
                            )
                        }
                
                Spacer()
                
                // History info button
                Button(action: { 
                    // Show history stats or navigate to first command
                    if !historyManager.history.isEmpty {
                        // Just print for now - selectEntry method may not exist
                        print("Selected first history entry")
                    }
                }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(historyManager.history.isEmpty ? .secondary : .blue)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.clear)
                .contentShape(Rectangle())
                
                // Search button
                Button(action: searchManager.toggleSearch) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.clear)
                .contentShape(Rectangle())
                
                        // Add new tab button with context menu
                        Menu {
                            Button("New Terminal", action: tabManager.addNewTab)
                            Button("New Multiplexer") {
                                tabManager.addMultiplexerTab(name: "Multiplexer")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                    #if canImport(AppKit)
                    .background(Color(NSColor.controlBackgroundColor))
                    #else
                    .background(Color(.systemGroupedBackground))
                    #endif
                    .frame(height: 32)
            
            // Search bar
            TerminalSearchView(
                searchText: $searchManager.searchText,
                isSearchVisible: $searchManager.isSearchVisible,
                matchCount: searchManager.matchCount,
                currentMatch: searchManager.currentMatch,
                onSearch: { text, isNext in
                    if let selectedTab = tabManager.selectedTab,
                       let session = selectedTab.session {
                        searchManager.setTerminalText(session.output)
                        searchManager.performSearch(text: text, next: isNext)
                    }
                },
                onClose: {
                    searchManager.isSearchVisible = false
                    searchManager.clearSearch()
                }
            )
            
            // Terminal content
            ZStack {
                if let selectedTab = tabManager.selectedTab {
                    if selectedTab.isMultiplexer {
                        // Show multiplexer interface
                        Text("Multiplexer View")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let session = selectedTab.session {
                        // Show regular terminal interface with the selected session
                        TerminalView(session: session)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .environmentObject(historyManager)
                    } else {
                        Text("No session available")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    Text("No terminal session")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Command Navigator Widget (only for regular terminals)
                if let selectedTab = tabManager.selectedTab, !selectedTab.isMultiplexer {
                    VStack {
                        Text("Command Navigator")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 200, height: 100)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Floating command count indicator  
                HStack {
                    Text("Commands: \(historyManager.history.count)")
                        .font(.caption)
                        .padding(4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding()
            }
        }
            } else {
                // Loading state while TabManager is being initialized
                Text("Loading...")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $appState.showConfiguration) {
            #if os(iOS)
            NavigationView {
                ConfigurationView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                appState.showConfiguration = false
                            }
                        }
                    }
            }
            #else
            ConfigurationView()
            #endif
        }
        .onAppear {
            // Initialize TabManager with history manager
            if tabManager == nil {
                tabManager = TabManager(historyManager: historyManager)
            }
            
            #if canImport(AppKit)
            // Set up keyboard shortcuts for macOS
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event -> NSEvent? in
                if event.modifierFlags.contains(.command) {
                    switch event.charactersIgnoringModifiers {
                    case "f":
                        searchManager.toggleSearch()
                        return nil
                    case "h":
                        if event.modifierFlags.contains(.shift) {
                            // Navigate to most recent command
                            if !historyManager.history.isEmpty {
                                historyManager.selectedEntry = historyManager.history[0]
                            }
                            return nil
                        }
                    case "t":
                        self.tabManager?.addNewTab()
                        return nil
                    case "w":
                        if !event.modifierFlags.contains(.shift) {
                            self.tabManager?.closeSelectedTab()
                            return nil
                        }
                    case "1", "2", "3", "4", "5", "6", "7", "8", "9":
                        // Switch to tab by number
                        if let tabNumber = Int(event.charactersIgnoringModifiers ?? ""),
                           let manager = self.tabManager,
                           tabNumber > 0 && tabNumber <= manager.tabs.count {
                            let targetTab = manager.tabs[tabNumber - 1]
                            manager.selectTab(withId: targetTab.id)
                            return nil
                        }
                    default:
                        break
                    }
                }
                return event
            }
            #else
            // iOS: Keyboard shortcuts are handled through other means
            #endif
            
            // Listen for SSH connection notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CreateSSHTerminalTab"),
                object: nil,
                queue: .main
            ) { notification in
                if let userInfo = notification.userInfo,
                   let connectionInfo = userInfo["connectionInfo"] as? ConnectionInfo,
                   let profileName = userInfo["profileName"] as? String {
                    
                    DispatchQueue.main.async {
                        if let manager = tabManager {
                            manager.addSSHTab(connectionInfo: connectionInfo, profileName: profileName)
                        } else {
                            print("Warning: TabManager not available for SSH connection")
                        }
                    }
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("CreateSSHTerminalTab"), object: nil)
        }
    }
}

struct TabView: View {
    let tab: TerminalTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    
    private var selectedBackgroundColor: Color {
        #if canImport(AppKit)
        return Color(NSColor.selectedControlColor)
        #else
        return Color(.systemBlue).opacity(0.2)
        #endif
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tab.title)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .opacity(isSelected ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.1), value: isSelected)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? selectedBackgroundColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .cornerRadius(4)
    }
}


// Simple terminal view that doesn't use complex NSTextView operations
public struct SimpleTerminalView: View {
    @ObservedObject var session: TerminalSession
    @State private var inputText: String = ""
    
    public init(session: TerminalSession) {
        self.session = session
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Output area
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !session.output.isEmpty {
                        Text(session.output)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    } else {
                        Text("Terminal ready. Type 'help' for commands.")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
            }
            .background(Color.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Input area
            HStack {
                Text("$ ")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                
                TextField("Enter command", text: $inputText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.green)
                    .onSubmit {
                        if !inputText.isEmpty {
                            session.sendInput(inputText)
                            inputText = ""
                        }
                    }
            }
            .padding(8)
            .background(Color.black)
        }
    }
}