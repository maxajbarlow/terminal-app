#if os(macOS)
import AppKit
import SwiftUI

public class TerminalWindow: NSWindow {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        makeKeyAndOrderFront(nil)
    }
    
    public override func makeKey() {
        super.makeKey()
        // Ensure text field gets focus
        DispatchQueue.main.async { [weak self] in
            if let textField = self?.findTextField(in: self?.contentView) {
                self?.makeFirstResponder(textField)
            }
        }
    }
    
    private func findTextField(in view: NSView?) -> NSTextField? {
        guard let view = view else { return nil }
        
        if let textField = view as? NSTextField {
            return textField
        }
        
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        
        return nil
    }
}

public struct TerminalWindowAccessor: NSViewRepresentable {
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Replace window with our custom window
                let terminalWindow = TerminalWindow(
                    contentRect: window.frame,
                    styleMask: window.styleMask,
                    backing: .buffered,
                    defer: false
                )
                terminalWindow.contentView = window.contentView
                terminalWindow.title = window.title
                terminalWindow.makeKeyAndOrderFront(nil)
                
                // Activate the app
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif