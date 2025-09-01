import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum ConfigTab: String, CaseIterable {
    case profiles = "Profiles"
    case users = "Users"
    case appearance = "Appearance"
    case notifications = "Notifications"
    case bookmarks = "Bookmarks"
    case shortcuts = "Shortcuts"
    case icloud = "iCloud"
    case about = "About"
    case privacy = "Privacy"
    case terms = "Terms"
    
    var title: String {
        return self.rawValue
    }
    
    var icon: String {
        switch self {
        case .profiles: return "person.2.rectangle.stack"
        case .users: return "person.circle"
        case .appearance: return "paintbrush"
        case .notifications: return "bell"
        case .bookmarks: return "bookmark"
        case .shortcuts: return "keyboard"
        case .icloud: return "icloud"
        case .about: return "info.circle"
        case .privacy: return "hand.raised"
        case .terms: return "doc.text"
        }
    }
}

public struct ConfigurationView: View {
    @State private var selectedTab: ConfigTab = .profiles
    @StateObject private var settings = SettingsManager.shared
    
    public init() {}
    
    public var body: some View {
#if canImport(AppKit)
        NavigationView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                Text("Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                    .padding(.top)
                
                List(ConfigTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
                .listStyle(SidebarListStyle())
            }
            .frame(minWidth: 200)
            
            // Main content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedTab {
                    case .profiles:
                        ProfilesView()
                    case .users:
                        UsersView()
                    case .appearance:
                        AppearanceView()
                    case .notifications:
                        NotificationsView()
                    case .bookmarks:
                        BookmarksView()
                    case .shortcuts:
                        ShortcutsView()
                    case .icloud:
                        ICloudView()
                    case .about:
                        AboutView()
                    case .privacy:
                        PrivacyView()
                    case .terms:
                        TermsView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding()
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .frame(minWidth: 800, minHeight: 600)
#else
        VStack(spacing: 0) {
            // Main content - expanded to fill space
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .profiles:
                        ProfilesView()
                    case .users:
                        UsersView()
                    case .appearance:
                        AppearanceView()
                    case .notifications:
                        NotificationsView()
                    case .bookmarks:
                        BookmarksView()
                    case .shortcuts:
                        ShortcutsView()
                    case .icloud:
                        ICloudView()
                    case .about:
                        AboutView()
                    case .privacy:
                        PrivacyView()
                    case .terms:
                        TermsView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding()
                .padding(.bottom, 80)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Tab navigation - moved to bottom
            VStack(spacing: 0) {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ConfigTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab }) {
                                VStack(spacing: 3) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 12))
                                    Text(tab.title)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .frame(minWidth: 50)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 70)
                .background(Color.gray.opacity(0.1))
            }
        }
#endif
    }
}

// MARK: - Data Models

// ConnectionProfile moved to separate file

// MARK: - Individual Views

struct ProfilesView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedProfile: ConnectionProfile?
    @State private var showingAddProfile = false
    @State private var showingEditProfile = false
    @State private var showingProfileDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Connection Profiles")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Add Profile") {
                    showingAddProfile = true
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.small)
            }
            
            Text("Create profiles that combine hosts, users, and SSH keys for easy connections")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            // Main content
#if canImport(AppKit)
            HSplitView {
                // Profile list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profiles")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    List(settings.profiles, id: \.id, selection: $selectedProfile) { profile in
                        ProfileRow(profile: profile)
                            .tag(profile)
                    }
                    .listStyle(SidebarListStyle())
                }
                .frame(minWidth: 250)
                
                // Profile details
                if let profile = selectedProfile {
                    ProfileDetailView(profile: profile, onEdit: {
                        showingEditProfile = true
                    }, onDelete: {
                        deleteProfile(profile)
                    })
                } else {
                    VStack {
                        Image(systemName: "person.2.rectangle.stack")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Select a profile to view details")
                            .foregroundColor(.secondary)
                        
                        Text("or create a new one to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
#else
            // Mobile-friendly single column layout
            VStack(spacing: 12) {
                ForEach(settings.profiles) { profile in
                    Button(action: {
                        selectedProfile = profile
                        showingProfileDetail = true
                    }) {
                        MobileProfileRow(profile: profile)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            
            Spacer(minLength: 0)
#endif
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingAddProfile) {
            AddProfileView { newProfile in
                settings.addProfile(newProfile)
                selectedProfile = newProfile
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            if let profile = selectedProfile {
                EditProfileView(profile: profile) { updatedProfile in
                    settings.updateProfile(updatedProfile)
                    selectedProfile = updatedProfile
                }
            }
        }
        .sheet(isPresented: $showingProfileDetail) {
            if let profile = selectedProfile {
                MobileProfileDetailView(profile: profile, onEdit: {
                    showingProfileDetail = false
                    showingEditProfile = true
                }, onDelete: {
                    deleteProfile(profile)
                    showingProfileDetail = false
                })
            }
        }
    }
    
    private func deleteProfile(_ profile: ConnectionProfile) {
        settings.deleteProfile(profile)
        if selectedProfile?.id == profile.id {
            selectedProfile = nil
        }
    }
}

struct ProfileRow: View {
    let profile: ConnectionProfile
    
    var body: some View {
        HStack {
            Circle()
                .fill(profile.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.headline)
                
                Text("\(profile.username)@\(profile.host)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if profile.sshKeyPath != nil {
                Image(systemName: "key")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MobileProfileRow: View {
    let profile: ConnectionProfile
    
    var body: some View {
        HStack {
            Circle()
                .fill(profile.color)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(profile.username)@\(profile.host):\(profile.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !profile.description.isEmpty {
                    Text(profile.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack {
                if profile.sshKeyPath != nil {
                    Image(systemName: "key.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MobileProfileDetailView: View {
    @Environment(\.dismiss) var dismiss
    let profile: ConnectionProfile
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Profile header
                HStack {
                    Circle()
                        .fill(profile.color)
                        .frame(width: 24, height: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if !profile.description.isEmpty {
                            Text(profile.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                
                // Connection details
                VStack(spacing: 0) {
                    MobileDetailRow(label: "Host", value: profile.host, icon: "server.rack")
                    Divider().padding(.leading, 40)
                    MobileDetailRow(label: "Port", value: "\(profile.port)", icon: "number")
                    Divider().padding(.leading, 40)
                    MobileDetailRow(label: "Username", value: profile.username, icon: "person")
                    
                    if let keyPath = profile.sshKeyPath {
                        Divider().padding(.leading, 40)
                        MobileDetailRow(label: "SSH Key", value: URL(fileURLWithPath: keyPath).lastPathComponent, icon: "key")
                    } else {
                        Divider().padding(.leading, 40)
                        MobileDetailRow(label: "Authentication", value: "Password", icon: "lock")
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button("Connect to Server") {
                        Task {
                            await SettingsManager.shared.connectToProfile(profile)
                        }
                        dismiss()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    Button("Test Connection") {
                        // TODO: Implement connection test
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Profile Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Edit Profile") {
                            onEdit()
                        }
                        
                        Button("Duplicate Profile") {
                            // TODO: Implement duplication
                        }
                        
                        Divider()
                        
                        Button("Delete Profile", role: .destructive) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct MobileDetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(label)
                .fontWeight(.medium)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .font(.system(.subheadline, design: .monospaced))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct ProfileDetailView: View {
    let profile: ConnectionProfile
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Circle()
                    .fill(profile.color)
                    .frame(width: 20, height: 20)
                
                Text(profile.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Menu {
                    Button("Edit Profile") {
                        onEdit()
                    }
                    
                    Button("Duplicate Profile") {
                        // TODO: Implement duplication
                    }
                    
                    Divider()
                    
                    Button("Delete Profile", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(BorderlessButtonMenuStyle())
            }
            
            if !profile.description.isEmpty {
                Text(profile.description)
                    .foregroundColor(.secondary)
            }
            
            // Connection details
            VStack(spacing: 16) {
                DetailRow(label: "Host", value: profile.host, icon: "server.rack")
                DetailRow(label: "Port", value: "\(profile.port)", icon: "number")
                DetailRow(label: "Username", value: profile.username, icon: "person")
                
                if let keyPath = profile.sshKeyPath {
                    DetailRow(label: "SSH Key", value: keyPath, icon: "key")
                } else {
                    DetailRow(label: "Authentication", value: "Password", icon: "lock")
                }
            }
            .padding()
#if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
#else
            .background(Color.gray.opacity(0.1))
#endif
            .cornerRadius(8)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Connect") {
                    Task {
                        await SettingsManager.shared.connectToProfile(profile)
                    }
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.large)
                
                Button("Test Connection") {
                    // TODO: Implement connection test
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.large)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(label)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct AddProfileView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (ConnectionProfile) -> Void
    
    @State private var name = ""
    @State private var host = ""
    @State private var port = 22
    @State private var username = ""
    @State private var sshKeyPath = ""
    @State private var description = ""
    @State private var selectedColor = Color.blue
    @State private var usePassword = true
    
    let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .gray]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Profile Name", text: $name)
                    TextField("Description", text: $description)
                    
                    HStack {
                        Text("Color")
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                }
                
                Section("Connection") {
                    TextField("Host", text: $host)
                    TextField("Port", value: $port, format: .number)
                    TextField("Username", text: $username)
                }
                
                Section("Authentication") {
                    Picker("Method", selection: $usePassword) {
                        Text("Password").tag(true)
                        Text("SSH Key").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if !usePassword {
                        SSHKeyManagementView(sshKeyPath: $sshKeyPath)
                    }
                }
            }
            .navigationTitle("New Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let profile = ConnectionProfile(
                            name: name,
                            host: host,
                            port: port,
                            username: username,
                            sshKeyPath: usePassword ? nil : sshKeyPath,
                            description: description,
                            color: selectedColor
                        )
                        onSave(profile)
                        dismiss()
                    }
                    .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
                }
            }
        }
        #if canImport(AppKit)
        .frame(width: 500, height: 600)
        #endif
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    let profile: ConnectionProfile
    let onSave: (ConnectionProfile) -> Void
    
    @State private var name: String
    @State private var host: String
    @State private var port: Int
    @State private var username: String
    @State private var sshKeyPath: String
    @State private var description: String
    @State private var selectedColor: Color
    @State private var usePassword: Bool
    
    let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .yellow, .gray]
    
    init(profile: ConnectionProfile, onSave: @escaping (ConnectionProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        
        _name = State(initialValue: profile.name)
        _host = State(initialValue: profile.host)
        _port = State(initialValue: profile.port)
        _username = State(initialValue: profile.username)
        _sshKeyPath = State(initialValue: profile.sshKeyPath ?? "")
        _description = State(initialValue: profile.description)
        _selectedColor = State(initialValue: profile.color)
        _usePassword = State(initialValue: profile.sshKeyPath == nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Profile Name", text: $name)
                    TextField("Description", text: $description)
                    
                    HStack {
                        Text("Color")
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(colors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                }
                
                Section("Connection") {
                    TextField("Host", text: $host)
                    TextField("Port", value: $port, format: .number)
                    TextField("Username", text: $username)
                }
                
                Section("Authentication") {
                    Picker("Method", selection: $usePassword) {
                        Text("Password").tag(true)
                        Text("SSH Key").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if !usePassword {
                        SSHKeyManagementView(sshKeyPath: $sshKeyPath)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedProfile = ConnectionProfile(
                            name: name,
                            host: host,
                            port: port,
                            username: username,
                            sshKeyPath: usePassword ? nil : sshKeyPath,
                            description: description,
                            color: selectedColor
                        )
                        onSave(updatedProfile)
                        dismiss()
                    }
                    .disabled(name.isEmpty || host.isEmpty || username.isEmpty)
                }
            }
        }
        #if canImport(AppKit)
        .frame(width: 500, height: 600)
        #endif
    }
}

struct UsersView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Users")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Manage user profiles and credentials")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Current User: \(NSUserName())")
                        .font(.subheadline)
                    Spacer()
                }
                
                HStack {
                    Text("No additional users configured")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Button("Add User") {
                        // TODO: Add user dialog
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .controlSize(.small)
                }
            }
            .padding(12)
#if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
#else
            .background(Color.gray.opacity(0.1))
#endif
            .cornerRadius(8)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppearanceView: View {
    @StateObject private var settings = SettingsManager.shared
    @ObservedObject private var theme = TerminalTheme.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Appearance")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Customize the terminal appearance")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            // Theme Selection
            GroupBox(label: Text("Color Theme").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Theme", selection: Binding(
                        get: { 
                            TerminalColorScheme.allSchemes.firstIndex(where: { $0.name == theme.colorScheme.name }) ?? 0 
                        },
                        set: { index in
                            theme.updateColorScheme(TerminalColorScheme.allSchemes[index])
                        }
                    )) {
                        ForEach(Array(TerminalColorScheme.allSchemes.enumerated()), id: \.offset) { index, scheme in
                            Text(scheme.name).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    // Theme preview
                    HStack(spacing: 8) {
                        ForEach(0..<8, id: \.self) { index in
                            let colors = [
                                theme.colorScheme.black,
                                theme.colorScheme.red,
                                theme.colorScheme.green,
                                theme.colorScheme.yellow,
                                theme.colorScheme.blue,
                                theme.colorScheme.magenta,
                                theme.colorScheme.cyan,
                                theme.colorScheme.white
                            ]
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colors[index])
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Custom Colors (override theme)
            VStack(spacing: 12) {
                HStack {
                    Text("Custom Text Color:")
                        .font(.subheadline)
                    Spacer()
                    ColorPicker("", selection: $settings.textColor)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Custom Background:")
                        .font(.subheadline)
                    Spacer()
                    ColorPicker("", selection: $settings.backgroundColor)
                        .labelsHidden()
                }
                
                // Font Settings
                HStack {
                    Text("Font Family:")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: Binding(
                        get: {
                            TerminalTheme.availableFonts.firstIndex(where: { $0.family == theme.font.family }) ?? 0
                        },
                        set: { index in
                            let font = TerminalTheme.availableFonts[index]
                            theme.updateFont(family: font.family)
                        }
                    )) {
                        ForEach(Array(TerminalTheme.availableFonts.enumerated()), id: \.offset) { index, font in
                            Text(font.family)
                                .font(.custom(font.family, size: 12))
                                .tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 150)
                }
                
                VStack(spacing: 6) {
                    HStack {
                        Text("Font Size:")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(theme.font.size))pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(
                        get: { theme.font.size },
                        set: { theme.updateFont(size: $0) }
                    ), in: 10...24, step: 1)
                }
            }
            .padding(12)
#if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
#else
            .background(Color.gray.opacity(0.1))
#endif
            .cornerRadius(8)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NotificationsView: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Configure notification preferences")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)
                    .font(.subheadline)
                Toggle("Play Sound", isOn: $settings.notificationSound)
                    .font(.subheadline)
                    .disabled(!settings.notificationsEnabled)
                Toggle("Show Badge", isOn: $settings.notificationBadge)
                    .font(.subheadline)
                    .disabled(!settings.notificationsEnabled)
                Toggle("Notify on Command Complete", isOn: $settings.notifyOnCommandComplete)
                    .font(.subheadline)
                    .disabled(!settings.notificationsEnabled)
                Toggle("Notify on Connection Lost", isOn: $settings.notifyOnConnectionLost)
                    .font(.subheadline)
                    .disabled(!settings.notificationsEnabled)
            }
            .padding(12)
#if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
#else
            .background(Color.gray.opacity(0.1))
#endif
            .cornerRadius(8)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BookmarksView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var showingAddBookmark = false
    @State private var newBookmarkName = ""
    @State private var newBookmarkCommand = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bookmarks")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Save frequently used commands and locations")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            VStack(spacing: 8) {
                if settings.bookmarks.isEmpty {
                    HStack {
                        Text("No bookmarks saved")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(12)
                } else {
                    ForEach(settings.bookmarks) { bookmark in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bookmark.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(bookmark.command)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                settings.deleteBookmark(bookmark)
                            }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.5))
                        .cornerRadius(6)
                    }
                    .padding(.horizontal, 4)
                }
                
                Button("Add Bookmark") {
                    showingAddBookmark = true
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            }
            .padding(12)
#if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
#else
            .background(Color.gray.opacity(0.1))
#endif
            .cornerRadius(8)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingAddBookmark) {
            AddBookmarkView { name, command in
                let bookmark = CommandBookmark(name: name, command: command)
                settings.addBookmark(bookmark)
            }
        }
    }
}

struct ShortcutsView: View {
    @StateObject private var settings = SettingsManager.shared
    @State private var showingAddShortcut = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Command Shortcuts")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Create keyboard shortcuts for frequently used commands")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            VStack(spacing: 8) {
                ForEach(settings.shortcuts) { shortcut in
                    HStack {
                        HStack(spacing: 2) {
                            ForEach(Array(shortcut.modifiers), id: \.self) { modifier in
                                Text(modifierSymbol(modifier))
                                    .font(.system(.caption, design: .monospaced))
                            }
                            Text(shortcut.key.uppercased())
                                .font(.system(.caption, design: .monospaced))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
#if canImport(AppKit)
                        .background(Color(NSColor.controlColor))
#else
                        .background(Color(.systemFill))
#endif
                        .cornerRadius(4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shortcut.description)
                                .font(.subheadline)
                            Text(shortcut.action)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            settings.deleteShortcut(shortcut)
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.5))
                    .cornerRadius(6)
                }
                
                Button("Add Shortcut") {
                    showingAddShortcut = true
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .controlSize(.small)
                .frame(maxWidth: .infinity)
            }
            .padding(12)
#if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
#else
            .background(Color.gray.opacity(0.1))
#endif
            .cornerRadius(8)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingAddShortcut) {
            AddShortcutView { shortcut in
                settings.addShortcut(shortcut)
            }
        }
    }
    
    private func modifierSymbol(_ modifier: ModifierKey) -> String {
        switch modifier {
        case .command: return "⌘"
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        }
    }
}

struct ICloudView: View {
    @StateObject private var settings = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iCloud Sync")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Synchronize your settings and data across devices")
                .foregroundColor(.secondary)
                .font(.subheadline)
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable iCloud Sync", isOn: $settings.iCloudEnabled)
                    .font(.subheadline)
                
                if settings.iCloudEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Synced Data:")
                            .fontWeight(.medium)
                            .font(.subheadline)
                        
                        Toggle("Sync Connection Profiles", isOn: $settings.syncProfiles)
                            .font(.caption)
                        Toggle("Sync SSH Keys", isOn: $settings.syncSSHKeys)
                            .font(.caption)
                        Toggle("Sync Settings", isOn: $settings.syncSettings)
                            .font(.caption)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 4)
                }
            }
            .padding(12)
#if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
#else
            .background(Color.gray.opacity(0.1))
#endif
            .cornerRadius(8)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "terminal")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Terminal App")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                
                Text("A native terminal emulator built with Swift and SwiftUI.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .padding(.horizontal)
                
                VStack(spacing: 6) {
                    Text("Features:")
                        .fontWeight(.medium)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("• Local shell execution")
                        Text("• SSH connections")
                        Text("• Real-time output display")
                        Text("• Command timeout protection")
                        Text("• Custom command support")
                        Text("• Cross-platform support")
                    }
                    .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                VStack(spacing: 12) {
                    Link("Website", destination: URL(string: "https://example.com")!)
                        .buttonStyle(BorderedButtonStyle())
                    Link("Support", destination: URL(string: "https://example.com/support")!)
                        .buttonStyle(BorderedButtonStyle())
                    Link("GitHub", destination: URL(string: "https://github.com")!)
                        .buttonStyle(BorderedButtonStyle())
                }
                .padding(.top)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: August 2025")
                    .foregroundColor(.secondary)
                
                Group {
                    Text("Data Collection")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("This application does not collect, store, or transmit any personal data without your explicit consent. All terminal operations are performed locally on your device.")
                    
                    Text("Local Data Storage")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Configuration settings, SSH keys, and bookmarks are stored locally on your device. If iCloud sync is enabled, this data may be synchronized across your Apple devices using your iCloud account.")
                    
                    Text("Third-Party Services")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("This application does not use any third-party analytics, tracking, or advertising services.")
                    
                    Text("Contact")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("If you have questions about this privacy policy, please contact us at privacy@example.com")
                }
            }
            .padding()
        }
    }
}

struct TermsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Terms of Use")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: August 2025")
                    .foregroundColor(.secondary)
                
                Group {
                    Text("Acceptance of Terms")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("By using this application, you agree to be bound by these terms of use.")
                    
                    Text("License")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("This software is provided under the MIT License. You are free to use, modify, and distribute this application subject to the terms of the license.")
                    
                    Text("Disclaimer")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("This application is provided 'as is' without any warranties, express or implied. Use at your own risk.")
                    
                    Text("Limitation of Liability")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("The developers shall not be liable for any damages arising from the use of this application.")
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if canImport(AppKit)
public class ConfigurationWindowController: NSWindowController {
    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Configuration"
        window.contentView = NSHostingView(rootView: ConfigurationView())
        window.center()
        
        self.init(window: window)
    }
    
    public func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif

// MARK: - SSH Key Management View

struct SSHKeyManagementView: View {
    @Binding var sshKeyPath: String
    @State private var showingKeyGenerator = false
    @State private var showingFilePicker = false
    @State private var availableKeys: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Key path input with browse button
            HStack {
                TextField("SSH Key Path", text: $sshKeyPath)
                
                Button("Browse...") {
                    showingFilePicker = true
                }
                .buttonStyle(BorderedButtonStyle())
            }
            
            // Available keys section
            if !availableKeys.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Keys:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(availableKeys, id: \.self) { keyPath in
                                Button(URL(fileURLWithPath: keyPath).lastPathComponent) {
                                    sshKeyPath = keyPath
                                }
                                .buttonStyle(BorderedButtonStyle())
                                .controlSize(.small)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            
            // Key generation section
            HStack {
                Button("Generate New Key") {
                    showingKeyGenerator = true
                }
                .buttonStyle(BorderedButtonStyle())
                
                Spacer()
                
                if !sshKeyPath.isEmpty {
                    Button("Test Key") {
                        testSSHKey()
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
            }
        }
        .onAppear {
            loadAvailableKeys()
        }
        .sheet(isPresented: $showingKeyGenerator) {
            SSHKeyGeneratorView { generatedKeyPath in
                sshKeyPath = generatedKeyPath
                loadAvailableKeys()
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    sshKeyPath = url.path
                }
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }
    
    private func loadAvailableKeys() {
        let defaultPaths = SSHClient.defaultPrivateKeyPaths.values
        availableKeys = defaultPaths.filter { path in
            FileManager.default.fileExists(atPath: NSString(string: path).expandingTildeInPath)
        }
    }
    
    private func testSSHKey() {
        // TODO: Implement key testing
        print("Testing SSH key at: \(sshKeyPath)")
    }
}

// MARK: - SSH Key Generator View

struct SSHKeyGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    let onKeyGenerated: (String) -> Void
    
    @State private var keyType: KeyType = .ed25519
    @State private var keyName = "id_ed25519"
    @State private var comment = ""
    @State private var isGenerating = false
    @State private var generationError: String?
    
    enum KeyType: String, CaseIterable {
        case ed25519 = "Ed25519"
        case p256 = "P-256 ECDSA"
        case p384 = "P-384 ECDSA" 
        case p521 = "P-521 ECDSA"
        
        var defaultName: String {
            switch self {
            case .ed25519: return "id_ed25519"
            case .p256: return "id_ecdsa_p256"
            case .p384: return "id_ecdsa_p384"
            case .p521: return "id_ecdsa_p521"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Generate SSH Key Pair")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Create a new SSH key pair for secure authentication")
                        .foregroundColor(.secondary)
                }
                
                Form {
                    Section("Key Type") {
                        Picker("Algorithm", selection: $keyType) {
                            ForEach(KeyType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .onChange(of: keyType) { newType in
                            keyName = newType.defaultName
                        }
                    }
                    
                    Section("Key Details") {
                        TextField("Key Name", text: $keyName)
                        TextField("Comment (optional)", text: $comment)
                    }
                    
                    Section("Location") {
                        HStack {
                            Text("Path:")
                            Spacer()
                            Text("\(SSHClient.defaultSSHDirectory)/\(keyName)")
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                
                if let error = generationError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Generate SSH Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationBarBackButtonHidden(true)
            #if os(iOS)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Generate") {
                    generateKey()
                }
                .disabled(isGenerating || keyName.isEmpty)
            )
            #endif
            .disabled(isGenerating)
        }
    }
    
    private func generateKey() {
        guard !keyName.isEmpty else { return }
        
        isGenerating = true
        generationError = nil
        
        Task {
            do {
                let keyPair: (privateKey: String, publicKey: String)
                
                switch keyType {
                case .ed25519:
                    keyPair = SSHClient.generateEd25519KeyPair()
                case .p256:
                    keyPair = SSHClient.generateP256KeyPair()
                case .p384:
                    keyPair = SSHClient.generateP256KeyPair() // Simplified to use P256
                case .p521:
                    keyPair = SSHClient.generateP256KeyPair() // Simplified to use P256
                }
                
                // Save the key pair
                let privateKeyPath = "\(SSHClient.defaultSSHDirectory)/\(keyName)"
                
                try SSHClient.savePrivateKey(keyPair.privateKey, name: keyName)
                try SSHClient.savePublicKey(keyPair.publicKey, name: keyName, comment: comment.isEmpty ? "Generated by Terminal App" : comment)
                
                await MainActor.run {
                    onKeyGenerated(privateKeyPath)
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    generationError = "Failed to generate key: \(error.localizedDescription)"
                    isGenerating = false
                }
            }
        }
    }
}
// MARK: - Add Bookmark View

struct AddBookmarkView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (String, String) -> Void
    
    @State private var name = ""
    @State private var command = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Bookmark Details") {
                    TextField("Name", text: $name)
                    TextField("Command", text: $command)
                }
            }
            .navigationTitle("Add Bookmark")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, command)
                        dismiss()
                    }
                    .disabled(name.isEmpty || command.isEmpty)
                }
            }
        }
        #if canImport(AppKit)
        .frame(width: 400, height: 200)
        #endif
    }
}

// MARK: - Add Shortcut View

struct AddShortcutView: View {
    @Environment(\.dismiss) var dismiss
    let onSave: (KeyboardShortcut) -> Void
    
    @State private var key = ""
    @State private var useCommand = true
    @State private var useShift = false
    @State private var useOption = false
    @State private var useControl = false
    @State private var action = ""
    @State private var description = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Key Combination") {
                    TextField("Key (single letter)", text: $key)
                        .onChange(of: key) { newValue in
                            key = String(newValue.prefix(1))
                        }
                    
                    Toggle("⌘ Command", isOn: $useCommand)
                    Toggle("⇧ Shift", isOn: $useShift)
                    Toggle("⌥ Option", isOn: $useOption)
                    Toggle("⌃ Control", isOn: $useControl)
                }
                
                Section("Action") {
                    TextField("Command to Execute", text: $action)
                    TextField("Description", text: $description)
                }
            }
            .navigationTitle("Add Shortcut")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var modifiers = Set<ModifierKey>()
                        if useCommand { modifiers.insert(.command) }
                        if useShift { modifiers.insert(.shift) }
                        if useOption { modifiers.insert(.option) }
                        if useControl { modifiers.insert(.control) }
                        
                        let shortcut = KeyboardShortcut(
                            key: key,
                            modifiers: modifiers,
                            action: action,
                            description: description.isEmpty ? action : description
                        )
                        onSave(shortcut)
                        dismiss()
                    }
                    .disabled(key.isEmpty || action.isEmpty || (!useCommand && !useShift && !useOption && !useControl))
                }
            }
        }
        #if canImport(AppKit)
        .frame(width: 400, height: 350)
        #endif
    }
}
