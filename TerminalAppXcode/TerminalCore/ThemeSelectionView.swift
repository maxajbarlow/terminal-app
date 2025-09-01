import SwiftUI

// MARK: - Theme Selection View

public struct ThemeSelectionView: View {
    
    @ObservedObject private var themeManager = TerminalThemeManager.shared
    @State private var selectedTheme: TerminalTheme
    @State private var searchText = ""
    
    public init() {
        self.selectedTheme = TerminalThemeManager.shared.currentTheme
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search themes...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor))
                
                // Theme grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredThemes) { theme in
                            ThemePreviewCard(
                                theme: theme,
                                isSelected: theme.name == selectedTheme.name,
                                onSelect: {
                                    selectedTheme = theme
                                    themeManager.setTheme(theme)
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Terminal Themes")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var filteredThemes: [TerminalTheme] {
        if searchText.isEmpty {
            return themeManager.availableThemes
        } else {
            return themeManager.availableThemes.filter { theme in
                theme.displayName.localizedCaseInsensitiveContains(searchText) ||
                theme.author.localizedCaseInsensitiveContains(searchText) ||
                theme.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    
    let theme: TerminalTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Theme preview
            ThemePreview(theme: theme)
            
            // Theme info
            VStack(spacing: 4) {
                Text(theme.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(theme.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(theme.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            onSelect()
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Theme Preview

struct ThemePreview: View {
    
    let theme: TerminalTheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal window header
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Spacer()
                
                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.windowBackgroundColor))
            
            // Terminal content preview
            VStack(alignment: .leading, spacing: 2) {
                // Sample command line
                HStack(spacing: 0) {
                    Text("❯ ")
                        .foregroundColor(theme.cursor.color)
                    Text("ls -la")
                        .foregroundColor(theme.foreground.color)
                    Spacer()
                }
                
                // Sample output with colors
                HStack(spacing: 0) {
                    Text("drwxr-xr-x")
                        .foregroundColor(theme.ansiBlue.color)
                    Text("  5 user staff")
                        .foregroundColor(theme.foreground.color)
                    Spacer()
                }
                
                HStack(spacing: 0) {
                    Text("-rw-r--r--")
                        .foregroundColor(theme.ansiWhite.color)
                    Text("  1 user staff")
                        .foregroundColor(theme.foreground.color)
                    Text(" README.md")
                        .foregroundColor(theme.ansiGreen.color)
                    Spacer()
                }
                
                HStack(spacing: 0) {
                    Text("-rwxr-xr-x")
                        .foregroundColor(theme.ansiRed.color)
                    Text("  1 user staff")
                        .foregroundColor(theme.foreground.color)
                    Text(" script.sh")
                        .foregroundColor(theme.ansiYellow.color)
                    Spacer()
                }
                
                // Cursor
                HStack(spacing: 0) {
                    Text("❯ ")
                        .foregroundColor(theme.cursor.color)
                    Rectangle()
                        .fill(theme.cursor.color)
                        .frame(width: 8, height: 12)
                    Spacer()
                }
            }
            .padding(8)
            .font(.caption.monospaced())
            .frame(height: 80)
            .background(theme.background.color)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(height: 110)
    }
}

// MARK: - Color Palette Preview

struct ColorPalettePreview: View {
    
    let theme: TerminalTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color Palette")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Basic colors
            VStack(alignment: .leading, spacing: 4) {
                Text("Basic Colors")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    ColorSwatch(color: theme.background.color, name: "Background")
                    ColorSwatch(color: theme.foreground.color, name: "Foreground")
                    ColorSwatch(color: theme.cursor.color, name: "Cursor")
                    ColorSwatch(color: theme.selection.color, name: "Selection")
                }
            }
            
            // ANSI colors
            VStack(alignment: .leading, spacing: 4) {
                Text("ANSI Colors")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ColorSwatch(color: theme.ansiBlack.color, name: "Black")
                    ColorSwatch(color: theme.ansiRed.color, name: "Red")
                    ColorSwatch(color: theme.ansiGreen.color, name: "Green")
                    ColorSwatch(color: theme.ansiYellow.color, name: "Yellow")
                    ColorSwatch(color: theme.ansiBlue.color, name: "Blue")
                    ColorSwatch(color: theme.ansiMagenta.color, name: "Magenta")
                    ColorSwatch(color: theme.ansiCyan.color, name: "Cyan")
                    ColorSwatch(color: theme.ansiWhite.color, name: "White")
                }
            }
            
            // Bright ANSI colors
            VStack(alignment: .leading, spacing: 4) {
                Text("Bright ANSI Colors")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                    ColorSwatch(color: theme.ansiBrightBlack.color, name: "Bright Black")
                    ColorSwatch(color: theme.ansiBrightRed.color, name: "Bright Red")
                    ColorSwatch(color: theme.ansiBrightGreen.color, name: "Bright Green")
                    ColorSwatch(color: theme.ansiBrightYellow.color, name: "Bright Yellow")
                    ColorSwatch(color: theme.ansiBrightBlue.color, name: "Bright Blue")
                    ColorSwatch(color: theme.ansiBrightMagenta.color, name: "Bright Magenta")
                    ColorSwatch(color: theme.ansiBrightCyan.color, name: "Bright Cyan")
                    ColorSwatch(color: theme.ansiBrightWhite.color, name: "Bright White")
                }
            }
        }
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 0.5)
                )
            
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

// MARK: - Theme Detail View

struct ThemeDetailView: View {
    
    let theme: TerminalTheme
    @ObservedObject private var themeManager = TerminalThemeManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Theme header
                VStack(alignment: .leading, spacing: 8) {
                    Text(theme.displayName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("by \(theme.author)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(theme.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Apply theme button
                Button(action: {
                    themeManager.setTheme(theme)
                }) {
                    Label(
                        themeManager.currentTheme.name == theme.name ? "Applied" : "Apply Theme",
                        systemImage: themeManager.currentTheme.name == theme.name ? "checkmark" : "paintbrush"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .disabled(themeManager.currentTheme.name == theme.name)
                
                // Large preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.headline)
                    
                    ThemePreview(theme: theme)
                        .frame(height: 200)
                }
                
                // Color palette
                ColorPalettePreview(theme: theme)
            }
            .padding()
        }
        .navigationTitle(theme.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Quick Theme Selector

public struct QuickThemeSelector: View {
    
    @ObservedObject private var themeManager = TerminalThemeManager.shared
    @State private var showingThemeSelection = false
    
    public init() {}
    
    public var body: some View {
        Menu {
            ForEach(themeManager.availableThemes) { theme in
                Button(theme.displayName) {
                    themeManager.setTheme(theme)
                }
            }
            
            Divider()
            
            Button("More Themes...") {
                showingThemeSelection = true
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(themeManager.currentTheme.background.color)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
                    )
                
                Text(themeManager.currentTheme.displayName)
                    .font(.caption)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingThemeSelection) {
            ThemeSelectionView()
        }
    }
}