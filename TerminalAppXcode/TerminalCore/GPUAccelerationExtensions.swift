#if os(macOS)
import SwiftUI
import Metal
import MetalKit

// MARK: - GPU Acceleration Feature Flag

extension SettingsManager {
    public var isGPUAccelerationAvailable: Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
    
    public var shouldUseGPURendering: Bool {
        return gpuAcceleration && isGPUAccelerationAvailable
    }
    
    public var gpuDeviceInfo: String {
        guard let device = MTLCreateSystemDefaultDevice() else {
            return "Metal Not Available"
        }
        return device.name
    }
}

// MARK: - Enhanced Terminal View with GPU Support

public struct EnhancedTerminalView: View {
    @ObservedObject var session: TerminalSession
    @StateObject private var settings = SettingsManager.shared
    
    public init(session: TerminalSession) {
        self.session = session
    }
    
    public var body: some View {
        Group {
            // For now, always use NativeTerminalView until Metal integration is complete
            NativeTerminalView(session: session)
        }
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
            if settings.isGPUAccelerationAvailable {
                Button("GPU Acceleration: \\(settings.gpuAcceleration ? "On" : "Off")") {
                    settings.gpuAcceleration.toggle()
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
        .overlay(
            // Performance indicator overlay
            VStack {
                if settings.gpuAcceleration && settings.isGPUAccelerationAvailable {
                    HStack {
                        Spacer()
                        Text("🚀 GPU")
                            .font(.caption2)
                            .padding(2)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(4)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
            }
            .padding(4),
            alignment: .topTrailing
        )
    }
}

// MARK: - GPU Performance Settings Panel

public struct GPUPerformancePanel: View {
    @StateObject private var settings = SettingsManager.shared
    
    public var body: some View {
        GroupBox("GPU Acceleration") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("Enable GPU Acceleration", isOn: $settings.gpuAcceleration)
                    Spacer()
                }
                .disabled(!settings.isGPUAccelerationAvailable)
                
                if settings.isGPUAccelerationAvailable {
                    Text("GPU Device: \\(settings.gpuDeviceInfo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Status: \\(settings.shouldUseGPURendering ? "Active" : "Inactive")")
                        .font(.caption)
                        .foregroundColor(settings.shouldUseGPURendering ? .green : .orange)
                } else {
                    Text("Metal framework not available on this system")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if settings.shouldUseGPURendering {
                    HStack {
                        Text("Target FPS:")
                        Picker("FPS", selection: $settings.preferredFrameRate) {
                            Text("30").tag(30)
                            Text("60").tag(60)
                            Text("120").tag(120)
                        }
                        .pickerStyle(.segmented)
                    }
                    .font(.caption)
                }
            }
        }
    }
}

#else

// MARK: - iOS Fallback (No GPU Acceleration)

public struct EnhancedTerminalView: View {
    @ObservedObject var session: TerminalSession
    
    public init(session: TerminalSession) {
        self.session = session
    }
    
    public var body: some View {
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
    }
}

public struct GPUPerformancePanel: View {
    public var body: some View {
        Text("GPU acceleration not available on iOS")
            .foregroundColor(.secondary)
            .font(.caption)
    }
}

#endif