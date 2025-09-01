import SwiftUI
// import CLibVTerm // Not available in standalone project

public struct TerminalView: View {
    @ObservedObject var session: TerminalSession
    @State private var fontSize: CGFloat = 14
    
    public init(session: TerminalSession) {
        self.session = session
    }
    
    public var body: some View {
        #if os(macOS)
        NativeTerminalView(session: session)
            .contextMenu {
                Button("Copy") {
                    // Implement copy functionality
                }
                
                Button("Paste") {
                    // Implement paste functionality
                }
                
                Button("Clear") {
                    session.executeCommand("clear")
                }
                
                Divider()
                
                // GPU acceleration toggle (when available)
                if SettingsManager.shared.canUseGPUAcceleration {
                    Button("GPU Acceleration: \(SettingsManager.shared.gpuAcceleration ? "On" : "Off")") {
                        SettingsManager.shared.gpuAcceleration.toggle()
                    }
                } else {
                    Button("GPU Acceleration: Not Available") {
                        // No action - just informational
                    }
                    .disabled(true)
                }
                
                Button("Settings") {
                    // Open settings window
                }
            }
        #else
        TerminalInputHandler(session: session)
            .contextMenu {
                Button("Copy") {
                    // Implement copy functionality
                }
                
                Button("Paste") {
                    // Implement paste functionality
                }
                
                Button("Clear") {
                    session.executeCommand("clear")
                }
            }
        #endif
    }
}