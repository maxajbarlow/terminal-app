import SwiftUI

// MARK: - Mosh Status View

/// Displays Mosh connection status and quality indicators
public struct MoshStatusView: View {
    @ObservedObject var moshClient: MoshClient
    @State private var showDetails = false
    
    public init(moshClient: MoshClient) {
        self.moshClient = moshClient
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Connection quality indicator
            connectionQualityIndicator
            
            // Status text
            Text(moshClient.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            // Latency and packet loss
            if moshClient.isConnected {
                connectionMetrics
            }
            
            // Details button
            Button(action: { showDetails.toggle() }) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
        .sheet(isPresented: $showDetails) {
            MoshConnectionDetailsView(moshClient: moshClient)
        }
    }
    
    private var connectionQualityIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: moshClient.connectionQuality.icon)
                .font(.caption)
                .foregroundColor(moshClient.connectionQuality.color)
            
            // Signal strength bars
            ForEach(0..<4) { level in
                Rectangle()
                    .fill(signalBarColor(for: level))
                    .frame(width: 3, height: CGFloat(4 + level * 2))
            }
        }
    }
    
    private func signalBarColor(for level: Int) -> Color {
        switch moshClient.connectionQuality {
        case .excellent:
            return .green
        case .good:
            return level < 3 ? .blue : .gray.opacity(0.3)
        case .fair:
            return level < 2 ? .orange : .gray.opacity(0.3)
        case .poor:
            return level < 1 ? .red : .gray.opacity(0.3)
        }
    }
    
    private var connectionMetrics: some View {
        HStack(spacing: 8) {
            // Latency
            Label {
                Text("\(Int(moshClient.latency * 1000))ms")
                    .font(.caption2)
                    .monospacedDigit()
            } icon: {
                Image(systemName: "timer")
                    .font(.caption2)
            }
            
            // Packet loss
            if moshClient.packetLoss > 0.001 {
                Label {
                    Text("\(Int(moshClient.packetLoss * 100))%")
                        .font(.caption2)
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
    }
}

// MARK: - Mosh Connection Details View

struct MoshConnectionDetailsView: View {
    @ObservedObject var moshClient: MoshClient
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Connection info
                GroupBox("Connection") {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(label: "Status", value: moshClient.statusMessage)
                        InfoRow(label: "Quality", value: qualityDescription)
                        InfoRow(label: "Latency", value: "\(Int(moshClient.latency * 1000))ms")
                        InfoRow(label: "Packet Loss", value: String(format: "%.2f%%", moshClient.packetLoss * 100))
                    }
                    .padding(.vertical, 4)
                }
                
                // Mosh features
                GroupBox("Mosh Features") {
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "arrow.triangle.2.circlepath", 
                                  title: "State Synchronization", 
                                  description: "Maintains terminal state across reconnections")
                        
                        FeatureRow(icon: "bolt.fill", 
                                  title: "Local Echo", 
                                  description: "Instant feedback with prediction engine")
                        
                        FeatureRow(icon: "wifi.exclamationmark", 
                                  title: "Resilient Connection", 
                                  description: "Survives network changes and interruptions")
                        
                        FeatureRow(icon: "lock.shield", 
                                  title: "Encrypted Transport", 
                                  description: "AES-256 encryption for all communications")
                    }
                    .padding(.vertical, 4)
                }
                
                // Connection actions
                if moshClient.isConnected {
                    HStack {
                        Button("Disconnect") {
                            moshClient.disconnect()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Spacer()
                        
                        Button("Force Reconnect") {
                            Task {
                                try? await moshClient.reconnect()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Mosh Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var qualityDescription: String {
        switch moshClient.connectionQuality {
        case .excellent: return "Excellent (Low latency, no loss)"
        case .good: return "Good (Acceptable latency)"
        case .fair: return "Fair (Some delays expected)"
        case .poor: return "Poor (High latency or packet loss)"
        }
    }
}

// MARK: - Helper Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Mosh Connection Button

public struct MoshConnectionButton: View {
    let host: String
    let username: String
    let port: Int
    @State private var isConnecting = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    public init(host: String, username: String, port: Int = MoshProtocol.defaultPort) {
        self.host = host
        self.username = username
        self.port = port
    }
    
    public var body: some View {
        Button(action: connectMosh) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text("Connect with Mosh")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isConnecting)
        .overlay {
            if isConnecting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            }
        }
        .alert("Connection Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func connectMosh() {
        isConnecting = true
        
        // Create connection info
        let connectionInfo = ConnectionInfo(
            type: .mosh,
            host: host,
            port: port,
            username: username,
            password: nil
        )
        
        // Post notification to create Mosh tab
        NotificationCenter.default.post(
            name: NSNotification.Name("CreateMoshTerminalTab"),
            object: nil,
            userInfo: [
                "connectionInfo": connectionInfo,
                "profileName": "Mosh: \(username)@\(host)"
            ]
        )
        
        isConnecting = false
    }
}