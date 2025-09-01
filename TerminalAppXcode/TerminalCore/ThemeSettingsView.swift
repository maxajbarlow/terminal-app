import SwiftUI

public struct ThemeSettingsView: View {
    @ObservedObject var theme: TerminalTheme
    @State private var selectedFontIndex: Int = 0
    @State private var selectedSizeIndex: Int = 4 // 12pt
    @State private var selectedSchemeIndex: Int = 0
    @State private var showPreview: Bool = true
    
    public init(theme: TerminalTheme = TerminalTheme.shared) {
        self.theme = theme
        // Initialize selection indices based on current theme
        _selectedFontIndex = State(initialValue: TerminalTheme.availableFonts.firstIndex(where: { $0.family == theme.font.family }) ?? 0)
        _selectedSizeIndex = State(initialValue: TerminalTheme.fontSizes.firstIndex(of: theme.font.size) ?? 4)
        _selectedSchemeIndex = State(initialValue: TerminalColorScheme.allSchemes.firstIndex(where: { $0.name == theme.colorScheme.name }) ?? 0)
    }
    
    public var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Font Settings
                GroupBox(label: Text("Font Settings").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Font Family
                        HStack {
                            Text("Font Family:")
                                .frame(width: 120, alignment: .leading)
                            
                            Picker("Font Family", selection: $selectedFontIndex) {
                                ForEach(Array(TerminalTheme.availableFonts.enumerated()), id: \.offset) { index, font in
                                    Text(font.family).tag(index)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedFontIndex) { newValue in
                                let selectedFont = TerminalTheme.availableFonts[newValue]
                                theme.updateFont(family: selectedFont.family)
                            }
                        }
                        
                        // Font Size
                        HStack {
                            Text("Font Size:")
                                .frame(width: 120, alignment: .leading)
                            
                            Picker("Font Size", selection: $selectedSizeIndex) {
                                ForEach(Array(TerminalTheme.fontSizes.enumerated()), id: \.offset) { index, size in
                                    Text("\(Int(size))pt").tag(index)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedSizeIndex) { newValue in
                                let selectedSize = TerminalTheme.fontSizes[newValue]
                                theme.updateFont(size: selectedSize)
                            }
                        }
                        
                        // Line Spacing
                        HStack {
                            Text("Line Spacing:")
                                .frame(width: 120, alignment: .leading)
                            
                            Slider(value: Binding(
                                get: { Double(theme.lineSpacing) },
                                set: { theme.updateLineSpacing(CGFloat($0)) }
                            ), in: 1.0...2.0, step: 0.1) {
                                Text("Line Spacing")
                            } minimumValueLabel: {
                                Text("1.0")
                            } maximumValueLabel: {
                                Text("2.0")
                            }
                            
                            Text(String(format: "%.1f", theme.lineSpacing))
                                .frame(width: 30)
                        }
                    }
                    .padding()
                }
                
                // Color Scheme Settings
                GroupBox(label: Text("Color Scheme").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Color Scheme Picker
                        HStack {
                            Text("Theme:")
                                .frame(width: 120, alignment: .leading)
                            
                            Picker("Color Scheme", selection: $selectedSchemeIndex) {
                                ForEach(Array(TerminalColorScheme.allSchemes.enumerated()), id: \.offset) { index, scheme in
                                    Text(scheme.name).tag(index)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: selectedSchemeIndex) { newValue in
                                let selectedScheme = TerminalColorScheme.allSchemes[newValue]
                                theme.updateColorScheme(selectedScheme)
                            }
                        }
                        
                        // Color Scheme Preview
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            colorSchemePreview
                                .frame(height: 80)
                                .background(theme.colorScheme.background)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding()
                }
                
                // Display Settings
                GroupBox(label: Text("Display Settings").font(.headline)) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Opacity
                        HStack {
                            Text("Opacity:")
                                .frame(width: 120, alignment: .leading)
                            
                            Slider(value: Binding(
                                get: { theme.opacity },
                                set: { theme.updateOpacity($0) }
                            ), in: 0.5...1.0, step: 0.05) {
                                Text("Opacity")
                            } minimumValueLabel: {
                                Text("50%")
                            } maximumValueLabel: {
                                Text("100%")
                            }
                            
                            Text("\(Int(theme.opacity * 100))%")
                                .frame(width: 40)
                        }
                        
                        // Blur Effect
                        HStack {
                            Text("Blur Effect:")
                                .frame(width: 120, alignment: .leading)
                            
                            Toggle("Enable blur effect behind terminal", isOn: Binding(
                                get: { theme.blurEffect },
                                set: { theme.updateBlurEffect($0) }
                            ))
                        }
                        
                        // Cursor Blink Rate
                        HStack {
                            Text("Cursor Blink:")
                                .frame(width: 120, alignment: .leading)
                            
                            Slider(value: Binding(
                                get: { theme.cursorBlinkRate },
                                set: { theme.updateCursorBlinkRate($0) }
                            ), in: 0.1...2.0, step: 0.1) {
                                Text("Cursor Blink Rate")
                            } minimumValueLabel: {
                                Text("Slow")
                            } maximumValueLabel: {
                                Text("Fast")
                            }
                            
                            Text(String(format: "%.1fs", theme.cursorBlinkRate))
                                .frame(width: 40)
                        }
                    }
                    .padding()
                }
                
                // Performance Settings (macOS only)
                #if os(macOS)
                GroupBox(label: Text("GPU Acceleration").font(.headline)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Toggle("Enable GPU Acceleration", isOn: Binding(
                                get: { SettingsManager.shared.gpuAcceleration },
                                set: { SettingsManager.shared.gpuAcceleration = $0 }
                            ))
                            Spacer()
                        }
                        .disabled(!SettingsManager.shared.canUseGPUAcceleration)
                        
                        if SettingsManager.shared.canUseGPUAcceleration {
                            Text("GPU Device: \(SettingsManager.shared.gpuDeviceInfo)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Status: \(SettingsManager.shared.shouldUseGPURendering ? "Active" : "Inactive")")
                                .font(.caption)
                                .foregroundColor(SettingsManager.shared.shouldUseGPURendering ? .green : .orange)
                        } else {
                            Text("Metal framework not available on this system")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        if SettingsManager.shared.shouldUseGPURendering {
                            HStack {
                                Text("Target FPS:")
                                Picker("FPS", selection: Binding(
                                    get: { SettingsManager.shared.preferredFrameRate },
                                    set: { SettingsManager.shared.preferredFrameRate = $0 }
                                )) {
                                    Text("30").tag(30)
                                    Text("60").tag(60)
                                    Text("120").tag(120)
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                }
                #endif
                
                Spacer()
                
                // Terminal Preview
                if showPreview {
                    GroupBox(label: Text("Live Preview").font(.headline)) {
                        terminalPreview
                            .frame(height: 120)
                    }
                }
            }
            .padding()
            .navigationTitle("Terminal Theme Settings")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset to Default") {
                        resetToDefaults()
                    }
                }
                
                ToolbarItem(placement: .navigation) {
                    Button(showPreview ? "Hide Preview" : "Show Preview") {
                        showPreview.toggle()
                    }
                }
            }
        }
    }
    
    private var colorSchemePreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                colorSwatch(theme.colorScheme.red)
                colorSwatch(theme.colorScheme.green)
                colorSwatch(theme.colorScheme.yellow)
                colorSwatch(theme.colorScheme.blue)
                colorSwatch(theme.colorScheme.magenta)
                colorSwatch(theme.colorScheme.cyan)
                colorSwatch(theme.colorScheme.white)
            }
            
            HStack(spacing: 4) {
                colorSwatch(theme.colorScheme.brightRed)
                colorSwatch(theme.colorScheme.brightGreen)
                colorSwatch(theme.colorScheme.brightYellow)
                colorSwatch(theme.colorScheme.brightBlue)
                colorSwatch(theme.colorScheme.brightMagenta)
                colorSwatch(theme.colorScheme.brightCyan)
                colorSwatch(theme.colorScheme.brightWhite)
            }
            
            Text("Terminal text example")
                .font(theme.font.swiftUIFont())
                .foregroundColor(theme.colorScheme.foreground)
                .padding(.top, 4)
        }
        .padding(8)
    }
    
    private func colorSwatch(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 16, height: 16)
            .cornerRadius(2)
    }
    
    private var terminalPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("user@hostname ~ % ls -la")
                .font(theme.font.swiftUIFont())
                .foregroundColor(theme.colorScheme.foreground)
            
            Text("drwxr-xr-x  8 user  staff   256 Aug 30 10:30 ").foregroundColor(theme.colorScheme.white) +
            Text("Documents").foregroundColor(theme.colorScheme.blue)
            
            Text("-rw-r--r--  1 user  staff  1024 Aug 30 09:15 ").foregroundColor(theme.colorScheme.white) +
            Text("file.txt").foregroundColor(theme.colorScheme.green)
            
            Text("user@hostname ~ % ").foregroundColor(theme.colorScheme.foreground) +
            Text("▊").foregroundColor(theme.colorScheme.cursor)
        }
        .font(theme.font.swiftUIFont())
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colorScheme.background.opacity(theme.opacity))
        .cornerRadius(6)
    }
    
    private func resetToDefaults() {
        theme.updateFont(family: TerminalFont.defaultMonospace.family, size: TerminalFont.defaultMonospace.size, weight: TerminalFont.defaultMonospace.weight)
        theme.updateColorScheme(.defaultDark)
        theme.updateOpacity(0.95)
        theme.updateBlurEffect(true)
        theme.updateCursorBlinkRate(0.5)
        theme.updateLineSpacing(1.2)
        
        // Update UI selections
        selectedFontIndex = 0
        selectedSizeIndex = 4
        selectedSchemeIndex = 0
    }
}

struct ThemeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ThemeSettingsView()
    }
}