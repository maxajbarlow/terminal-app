#!/bin/bash

# iOS App Signing Script
# Prerequisites:
# 1. Apple Developer Account
# 2. Valid certificates in Keychain
# 3. Provisioning profile for the app

set -e

echo "🔐 iOS App Signing Script"
echo "========================="

# Configuration
APP_NAME="TerminalApp"
BUNDLE_ID="com.yourname.terminalapp"  # Change this to your bundle ID
DEVELOPMENT_TEAM="YOUR_TEAM_ID"       # Change this to your team ID

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Package.swift not found. Please run this script from the project root."
    exit 1
fi

echo "📱 Building for iOS..."

# Build for iOS device
xcodebuild -scheme "$APP_NAME" \
    -destination "generic/platform=iOS" \
    -configuration Release \
    -archivePath "$APP_NAME.xcarchive" \
    archive \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"

echo "✅ Archive created successfully!"

# Export IPA
echo "📦 Exporting IPA..."

# Create ExportOptions.plist
cat > ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>$DEVELOPMENT_TEAM</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
EOF

# Export the archive
xcodebuild -exportArchive \
    -archivePath "$APP_NAME.xcarchive" \
    -exportPath "./export" \
    -exportOptionsPlist ExportOptions.plist

echo "✅ App exported to ./export/$APP_NAME.ipa"
echo "📱 Ready for installation via Xcode or TestFlight!"

# Cleanup
rm -f ExportOptions.plist

echo ""
echo "🎉 App signing completed successfully!"
echo ""
echo "Next steps:"
echo "1. Install via Xcode: Product → Destination → Choose Device"
echo "2. Or drag the .ipa to iTunes/Finder to install"
echo "3. For distribution: Upload to App Store Connect"