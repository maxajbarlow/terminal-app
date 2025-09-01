#!/bin/bash

# Build and run the TerminalApp as a proper macOS application

echo "Building TerminalApp..."
swift build -c release

if [ $? -eq 0 ]; then
    echo "Copying to app bundle..."
    cp .build/release/TerminalApp TerminalApp.app/Contents/MacOS/
    
    echo "Launching TerminalApp..."
    open TerminalApp.app
else
    echo "Build failed!"
    exit 1
fi