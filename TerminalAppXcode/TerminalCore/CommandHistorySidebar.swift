import SwiftUI

// MARK: - Command History Sidebar

public struct CommandHistorySidebar: View {
    @ObservedObject var historyManager: CommandHistoryManager
    @State private var searchText = ""
    @State private var showingStats = false
    
    public var onCommandSelected: ((String) -> Void)?
    
    public init(historyManager: CommandHistoryManager, onCommandSelected: ((String) -> Void)? = nil) {
        self.historyManager = historyManager
        self.onCommandSelected = onCommandSelected
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Search
            searchView
            
            // History List
            historyListView
            
            Divider()
            
            // Footer with stats
            footerView
        }
        .frame(width: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Command History")
                .font(.headline)
                .fontWeight(.medium)
            
            Spacer()
            
            Button(action: { showingStats.toggle() }) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Show statistics")
            
            Button(action: { historyManager.toggle() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Close history")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var searchView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            
            TextField("Search commands...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(6)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    private var historyListView: some View {
        ScrollViewReader { proxy in
            List(filteredHistory, id: \.id) { entry in
                CommandHistoryRow(
                    entry: entry,
                    isSelected: historyManager.selectedEntry?.id == entry.id,
                    onSelect: {
                        historyManager.selectEntry(entry)
                        onCommandSelected?(entry.command)
                    },
                    onDelete: {
                        historyManager.removeCommand(entry)
                    }
                )
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .listRowSeparator(.hidden)
            }
            .listStyle(PlainListStyle())
            .onChange(of: historyManager.selectedEntry) { entry in
                if let entry = entry {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(entry.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    private var footerView: some View {
        VStack(spacing: 4) {
            if showingStats {
                statsView
                    .transition(.slide)
            }
            
            HStack {
                Text("\(historyManager.totalCommands) commands")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Clear All") {
                    historyManager.clearHistory()
                }
                .font(.caption)
                .foregroundColor(.red)
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    private var statsView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("\(historyManager.successfulCommands) successful")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("\(historyManager.failedCommands) failed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var filteredHistory: [CommandHistoryEntry] {
        return historyManager.searchHistory(searchText)
    }
}

// MARK: - Command History Row

private struct CommandHistoryRow: View {
    let entry: CommandHistoryEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Image(systemName: entry.statusIcon)
                .font(.system(size: 10))
                .foregroundColor(entry.statusColor)
                .frame(width: 12)
            
            // Command content
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayText)
                    .font(.system(size: 11, family: .monospaced))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(isSelected ? .white : .primary)
                
                HStack {
                    Text(entry.timeAgo)
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    Spacer()
                    
                    if let duration = entry.duration {
                        Text(String(format: "%.1fs", duration))
                            .font(.caption2)
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Delete button (shown on hover)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .opacity(0.7)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.gray.opacity(0.1) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Copy Command") {
                NSPasteboard.general.setString(entry.command, forType: .string)
            }
            
            Button("Copy with Working Directory") {
                let fullCommand = "cd \(entry.workingDirectory) && \(entry.command)"
                NSPasteboard.general.setString(fullCommand, forType: .string)
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Command History Stats View

public struct CommandHistoryStatsView: View {
    @ObservedObject var historyManager: CommandHistoryManager
    
    public init(historyManager: CommandHistoryManager) {
        self.historyManager = historyManager
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Command Statistics")
                .font(.headline)
            
            // Overview stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(title: "Total Commands", value: "\(historyManager.totalCommands)", color: .blue)
                StatCard(title: "Success Rate", value: successRate, color: .green)
                StatCard(title: "Failed Commands", value: "\(historyManager.failedCommands)", color: .red)
                StatCard(title: "Avg per Session", value: avgPerSession, color: .orange)
            }
            
            // Most used commands
            if !historyManager.mostUsedCommands.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Used Commands")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(Array(historyManager.mostUsedCommands.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .trailing)
                            
                            Text(item.command)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(item.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private var successRate: String {
        let total = historyManager.totalCommands
        if total == 0 { return "0%" }
        let rate = Double(historyManager.successfulCommands) / Double(total) * 100
        return String(format: "%.1f%%", rate)
    }
    
    private var avgPerSession: String {
        // Simplified calculation - in a real app you'd track unique sessions
        return "~\(historyManager.totalCommands / max(1, historyManager.totalCommands / 20))"
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}