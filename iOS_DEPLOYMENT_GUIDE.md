# iOS Deployment Guide

## 📱 Deploy TerminalApp to iPhone/iPad

### Prerequisites

1. **Apple Developer Account** ($99/year)
   - Sign up at [developer.apple.com](https://developer.apple.com)
   - Or use a free account for development (7-day limit)

2. **Xcode** (Latest version from Mac App Store)

3. **Connected iOS Device** or use iOS Simulator

### Step 1: Open in Xcode

```bash
cd /Users/maxbarlow/Claude-Bashy/TerminalApp
open Package.swift
```

### Step 2: Configure App Signing

1. **Select Target:**
   - Click on "TerminalApp" in project navigator
   - Select the "TerminalApp" target (not TerminalCore)

2. **Signing & Capabilities:**
   - Click "Signing & Capabilities" tab
   - Check ✅ "Automatically manage signing"
   - Select your **Team** from dropdown
   - Update **Bundle Identifier**: `com.yourname.terminalapp`

3. **Bundle ID Setup:**
   ```
   Bundle Identifier: com.yourname.terminalapp
   Display Name: Terminal App
   Version: 1.0.0
   Build: 1
   ```

### Step 3: iOS-Specific Configuration

Add this to your main app target if needed:

```swift
// Minimum iOS version
iOS Deployment Target: 16.0

// Required capabilities
- UIFileSharingEnabled: YES (for file access)
- UISupportsDocumentBrowser: YES (optional)
```

### Step 4: Build & Deploy

#### For iOS Device:
1. Connect your iPhone/iPad via USB
2. Select your device in Xcode toolbar
3. Press **Cmd+R** to build and run
4. **Trust Developer**: Settings → General → VPN & Device Management

#### For iOS Simulator:
1. Select "iPhone 15 Pro" (or preferred simulator)
2. Press **Cmd+R** to build and run

### Step 5: Distribution Options

#### Option A: TestFlight (Recommended)
1. Archive: **Product → Archive**
2. Upload to App Store Connect
3. Invite testers via TestFlight

#### Option B: Ad Hoc Distribution
1. Use the provided `sign_app.sh` script
2. Modify with your Team ID and Bundle ID
3. Run: `./sign_app.sh`

#### Option C: Direct Installation
1. Build for device in Xcode
2. Window → Devices and Simulators
3. Drag .app to device

### Troubleshooting

#### Common Issues:

**"No matching provisioning profile"**
```
Solution: 
1. Go to Apple Developer portal
2. Register your device UDID
3. Create/update provisioning profile
4. Download and install in Xcode
```

**"Code signing error"**
```
Solution:
1. Keychain Access → View certificates
2. Ensure iOS Developer certificate is valid
3. Restart Xcode if needed
```

**"App crashes on launch"**
```
Solution:
1. Check iOS deployment target (16.0+)
2. Verify all iOS conditionals are correct
3. Test in simulator first
```

### iOS-Specific Features

The app includes iOS optimizations:

✅ **Cross-Platform UI**
- Adaptive layouts for iPhone/iPad
- iOS-specific colors and fonts
- Touch-friendly controls

✅ **iOS Terminal Features**
- Built-in commands (no external process spawning)
- File system access within app sandbox
- Swipe gestures and touch input

✅ **iOS Theme Support**
- All 4 color schemes work on iOS
- Font scaling for accessibility
- Dark mode support

### Security & Permissions

The app requires:
```xml
<!-- Info.plist additions if needed -->
<key>NSDocumentsFolderUsageDescription</key>
<string>Terminal app needs file access for commands</string>
```

### Performance Notes

- iOS version uses built-in commands only
- No external process spawning on iOS
- Optimized memory usage for mobile devices
- Battery-efficient with proper backgrounding

---

🎉 **Your terminal app is now ready for iOS deployment!**

For questions about Apple Developer account setup or certificate issues, refer to Apple's official documentation or contact Apple Developer Support.