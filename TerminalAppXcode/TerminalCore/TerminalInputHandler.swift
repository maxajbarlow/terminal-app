import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct TerminalInputHandler: View {
    @ObservedObject var session: TerminalSession
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var historyManager = CommandHistoryManager()
    @State private var inputText = ""
    @FocusState private var isTerminalFocused: Bool
    
    public init(session: TerminalSession) {
        self.session = session
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Terminal output area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Display all output
                        Text(session.output)
                            .font(.system(size: CGFloat(settings.fontSize), design: .monospaced))
                            .foregroundColor(settings.textColor)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("bottom")
                    }
                    .padding()
                }
                .background(settings.backgroundColor)
                .onChange(of: session.output) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            // Test and input controls
            VStack(spacing: 8) {
                // Test button
                HStack {
                    Button("🎲 TEST - Click Me!") {
                        testButtonPressed()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .foregroundColor(.white)
                    
                    Button("Clear Terminal") {
                        clearTerminal()
                    }
                    .buttonStyle(BorderedButtonStyle())
                    
                    Spacer()
                }
                
                // Input field
                #if os(iOS)
                HStack {
                    Text("$")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                    
                    TextField("Type command...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .focused($isTerminalFocused)
                        .onSubmit {
                            handleEnter(command: inputText)
                        }
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    
                    Button("Enter") {
                        handleEnter(command: inputText)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                #else
                // macOS input field with better cursor management
                HStack {
                    Text("$")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                    
                    MacOSTextField(
                        text: $inputText,
                        placeholder: "Type command...",
                        onEnter: {
                            handleEnter(command: inputText)
                        },
                        onFocusChange: { focused in
                            isTerminalFocused = focused
                        }
                    )
                    
                    Button("Enter") {
                        handleEnter(command: inputText)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                #endif
            }
            .padding()
            .background(Color.gray)
        }
        .onAppear {
            #if os(macOS)
            // Force window and text field focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = NSApp.keyWindow ?? NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(window.contentView)
                }
                isTerminalFocused = true
            }
            #else
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTerminalFocused = true
            }
            #endif
        }
        .onTapGesture {
            isTerminalFocused = true
        }
    }
    
    private func handleEnter(command: String? = nil) {
        let cmd = command ?? inputText.trimmingCharacters(in: .whitespaces)
        if !cmd.isEmpty {
            // Add to history
            historyManager.addCommand(cmd, sessionId: session.sessionId)
            
            // Send to session
            session.sendInput(cmd)
        }
        inputText = ""
    }
    
    private func testButtonPressed() {
        let randomMessages = [
            "✅ Button works! App is responsive!",
            "🎉 Success! The interface is working!",
            "👍 Great! Interaction detected!",
            "🚀 Perfect! UI is functional!",
            "✨ Excellent! Button press registered!"
        ]
        
        let message = randomMessages.randomElement() ?? "Button pressed!"
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        // Add message directly to terminal output
        DispatchQueue.main.async {
            self.session.output += "\n[\(timestamp)] \(message)\n"
        }
    }
    
    private func clearTerminal() {
        session.executeCommand("clear")
    }
}