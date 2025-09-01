import SwiftUI

// MARK: - Command Navigator Widget

public struct CommandNavigatorWidget: View {
    @ObservedObject var historyManager: CommandHistoryManager
    @State private var isPressed = false
    @State private var dragOffset: CGFloat = 0
    @State private var showPreview = false
    @State private var previewText = ""
    @State private var hapticTimer: Timer?
    
    public var onCommandSelected: ((String) -> Void)?
    
    private let widgetWidth: CGFloat = 8
    private let activeWidth: CGFloat = 24
    
    public init(historyManager: CommandHistoryManager, onCommandSelected: ((String) -> Void)? = nil) {
        self.historyManager = historyManager
        self.onCommandSelected = onCommandSelected
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Command Navigator Switch
            HStack {
                Spacer()
                
                ZStack {
                    // Background track
                    RoundedRectangle(cornerRadius: activeWidth / 2)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: isPressed || showPreview ? activeWidth : widgetWidth, height: 120)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed || showPreview)
                    
                    // Navigation controls
                    VStack(spacing: 8) {
                        // Up button (previous command)
                        NavigationButton(
                            icon: "chevron.up",
                            isActive: isPressed && dragOffset < -10,
                            action: navigateToPrevious
                        )
                        
                        // Center indicator
                        Circle()
                            .fill(currentCommandColor)
                            .frame(width: 6, height: 6)
                            .scaleEffect(isPressed ? 1.2 : 1.0)
                            .opacity(historyManager.history.isEmpty ? 0.3 : 0.8)
                        
                        // Down button (next command)
                        NavigationButton(
                            icon: "chevron.down",
                            isActive: isPressed && dragOffset > 10,
                            action: navigateToNext
                        )
                    }
                    .opacity(isPressed || showPreview ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 0.2), value: isPressed || showPreview)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isPressed {
                                isPressed = true
                                showCommandPreview()
                                generateHapticFeedback(.selectionChanged)
                            }
                            
                            dragOffset = value.translation.height
                            
                            // Trigger navigation with haptic feedback
                            if abs(dragOffset) > 30 {
                                if dragOffset < -30 && canNavigateUp {
                                    navigateToPrevious()
                                    generateHapticFeedback(.impactLight)
                                    dragOffset = 0
                                } else if dragOffset > 30 && canNavigateDown {
                                    navigateToNext()
                                    generateHapticFeedback(.impactLight)
                                    dragOffset = 0
                                }
                            }
                        }
                        .onEnded { _ in
                            isPressed = false
                            dragOffset = 0
                            
                            // Hide preview after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                if !isPressed {
                                    showPreview = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    executeCurrentCommand()
                    generateHapticFeedback(.impactMedium)
                }
                .onHover { hovering in
                    if hovering && !historyManager.history.isEmpty {
                        showCommandPreview()
                    } else if !isPressed {
                        showPreview = false
                    }
                }
            }
            
            Spacer()
        }
        .overlay(
            // Command preview
            commandPreviewOverlay,
            alignment: .trailing
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showPreview)
    }
    
    private var commandPreviewOverlay: some View {
        HStack {
            if showPreview && !previewText.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(previewText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.trailing)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.8))
                        )
                        .transition(.scale.combined(with: .opacity))
                    
                    if let selectedEntry = historyManager.selectedEntry {
                        Text(selectedEntry.timeAgo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.trailing, activeWidth + 8)
            }
        }
    }
    
    private var currentCommandColor: Color {
        guard let selectedEntry = historyManager.selectedEntry else {
            return .gray
        }
        return selectedEntry.statusColor
    }
    
    private var canNavigateUp: Bool {
        guard let current = historyManager.selectedEntry,
              let currentIndex = historyManager.history.firstIndex(where: { $0.id == current.id }) else {
            return !historyManager.history.isEmpty
        }
        return currentIndex > 0
    }
    
    private var canNavigateDown: Bool {
        guard let current = historyManager.selectedEntry,
              let currentIndex = historyManager.history.firstIndex(where: { $0.id == current.id }) else {
            return false
        }
        return currentIndex < historyManager.history.count - 1
    }
    
    private func navigateToPrevious() {
        if historyManager.selectedEntry == nil && !historyManager.history.isEmpty {
            // First navigation - select the most recent command
            historyManager.selectEntry(historyManager.history[0])
        } else {
            historyManager.selectPrevious()
        }
        updatePreview()
    }
    
    private func navigateToNext() {
        historyManager.selectNext()
        updatePreview()
    }
    
    private func executeCurrentCommand() {
        guard let selectedEntry = historyManager.selectedEntry else { return }
        onCommandSelected?(selectedEntry.command)
    }
    
    private func showCommandPreview() {
        showPreview = true
        updatePreview()
    }
    
    private func updatePreview() {
        if let selectedEntry = historyManager.selectedEntry {
            previewText = selectedEntry.displayText
        } else if !historyManager.history.isEmpty {
            previewText = "Recent: \(historyManager.history[0].displayText)"
        } else {
            previewText = "No commands"
        }
    }
    
    private func generateHapticFeedback(_ feedbackType: HapticFeedbackType) {
        #if canImport(AppKit)
        // macOS haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #else
        // iOS haptic feedback
        switch feedbackType {
        case .impactLight:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .impactMedium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .impactHeavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .selectionChanged:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
        #endif
    }
}

// MARK: - Navigation Button

private struct NavigationButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive ? .white : .gray)
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(isActive ? Color.blue.opacity(0.8) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Haptic Feedback Types

private enum HapticFeedbackType {
    case impactLight
    case impactMedium
    case impactHeavy
    case selectionChanged
}

// MARK: - Floating Command Indicator

public struct FloatingCommandIndicator: View {
    @ObservedObject var historyManager: CommandHistoryManager
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.8
    
    public init(historyManager: CommandHistoryManager) {
        self.historyManager = historyManager
    }
    
    public var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                if historyManager.totalCommands > 0 {
                    VStack(spacing: 2) {
                        Circle()
                            .fill(Color.blue.opacity(0.8))
                            .frame(width: 4, height: 4)
                        
                        Text("\(historyManager.totalCommands)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.6))
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            opacity = 0.8
                            scale = 1.0
                        }
                    }
                    .onChange(of: historyManager.totalCommands) { oldValue, newValue in
                        // Pulse animation when count changes
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scale = 1.2
                        }
                        withAnimation(.easeInOut(duration: 0.3).delay(0.2)) {
                            scale = 1.0
                        }
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 120) // Position above the navigator widget
        }
    }
}