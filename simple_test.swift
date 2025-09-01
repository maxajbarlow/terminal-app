#!/usr/bin/env swift

import SwiftUI
import AppKit

@main
struct SimpleTest: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Hello World!")
                    .padding()
                Button("Test Shell") {
                    let task = Process()
                    let pipe = Pipe()
                    
                    task.standardOutput = pipe
                    task.executableURL = URL(fileURLWithPath: "/bin/sh")
                    task.arguments = ["-c", "echo 'Shell works!'"]
                    
                    try? task.run()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        print("Shell output: \(output)")
                    }
                    
                    task.waitUntilExit()
                }
            }
        }
    }
}