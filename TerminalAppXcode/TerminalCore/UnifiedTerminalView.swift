#if os(macOS)
import SwiftUI
import Metal

// MARK: - Unified Terminal View

public struct UnifiedTerminalView: View {
    @ObservedObject var session: TerminalSession
    @StateObject private var settings = SettingsManager.shared
    @State private var metalSupported: Bool = false
    
    public init(session: TerminalSession) {
        self.session = session
    }
    
    public var body: some View {
        Group {
            if shouldUseMetalRenderer {
                MetalTerminalSwiftUIView(session: session)
                    .onAppear {
                        checkMetalSupport()
                    }
            } else {
                NativeTerminalView(session: session)
            }
        }
        .onChange(of: settings.gpuAcceleration) { _ in
            checkMetalSupport()
        }
    }
    
    private var shouldUseMetalRenderer: Bool {
        return settings.gpuAcceleration && metalSupported
    }
    
    private func checkMetalSupport() {
        metalSupported = MTLCreateSystemDefaultDevice() != nil
        
        if settings.gpuAcceleration && !metalSupported {
            // Show warning that GPU acceleration is not available
            print("Warning: GPU acceleration requested but Metal is not supported on this device. Falling back to CPU rendering.")
        }
    }
}

// MARK: - Performance Settings View

public struct PerformanceSettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var metalSupported: Bool = false
    
    public var body: some View {
        Form {
            Section("Rendering Performance") {
                Toggle("GPU Acceleration (Metal)", isOn: $settings.gpuAcceleration)
                    .disabled(!metalSupported)
                    .help(metalSupported ? 
                          "Use GPU acceleration for faster terminal rendering" : 
                          "Metal is not supported on this device")
                
                if !metalSupported {
                    Text("GPU acceleration is not available on this device")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                
                if settings.gpuAcceleration && metalSupported {
                    Picker("Target Frame Rate", selection: $settings.preferredFrameRate) {
                        Text("30 FPS").tag(30)
                        Text("60 FPS").tag(60)
                        Text("120 FPS").tag(120)
                    }
                    .pickerStyle(.segmented)
                    .help("Higher frame rates provide smoother animation but use more power")
                }
            }
            
            Section("Performance Info") {
                if metalSupported {
                    if let device = MTLCreateSystemDefaultDevice() {
                        Text("GPU: \\(device.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Max Buffer Length: \\(formatBytes(device.maxBufferLength))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            
                        Text("Supports Non-Uniform Threadgroups: \\(device.supportsFeatureSet(.macOS_GPUFamily2_v1) ? "Yes" : "No")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Metal not supported - using CPU rendering")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            checkMetalSupport()
        }
    }
    
    private func checkMetalSupport() {
        metalSupported = MTLCreateSystemDefaultDevice() != nil
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Settings Integration

extension SettingsManager {
    public var renderingInfo: String {
        if gpuAcceleration {
            if let device = MTLCreateSystemDefaultDevice() {
                return "GPU Accelerated (\\(device.name))"
            } else {
                return "GPU Acceleration Requested (Metal Not Available)"
            }
        } else {
            return "CPU Rendering"
        }
    }
    
    public var canUseGPUAcceleration: Bool {
        return MTLCreateSystemDefaultDevice() != nil
    }
}

#endif