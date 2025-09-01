import SwiftUI
#if os(macOS)
import AppKit

struct MacOSTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onEnter: () -> Void
    var onFocusChange: (Bool) -> Void
    
    init(text: Binding<String>, placeholder: String, onEnter: @escaping () -> Void, onFocusChange: @escaping (Bool) -> Void = { _ in }) {
        self._text = text
        self.placeholder = placeholder
        self.onEnter = onEnter
        self.onFocusChange = onFocusChange
    }
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        
        // Enable editing and focus
        textField.isEditable = true
        textField.isSelectable = true
        textField.refusesFirstResponder = false
        
        // Force focus on creation and ensure window is key
        DispatchQueue.main.async {
            textField.window?.makeKey()
            textField.window?.makeFirstResponder(textField)
            textField.becomeFirstResponder()
        }
        
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            // Preserve cursor position when updating text
            let selectedRange = nsView.currentEditor()?.selectedRange ?? NSRange(location: 0, length: 0)
            nsView.stringValue = text
            
            // Restore cursor position if it's valid
            if selectedRange.location <= text.count {
                DispatchQueue.main.async {
                    if let textEditor = nsView.currentEditor() {
                        let newRange = NSRange(location: min(selectedRange.location, text.count), length: 0)
                        textEditor.selectedRange = newRange
                    }
                }
            }
        }
        
        // Maintain focus if needed
        if nsView.window?.firstResponder != nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacOSTextField
        
        init(_ parent: MacOSTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            if obj.object is NSTextField {
                parent.onEnter()
            }
            parent.onFocusChange(false)
        }
        
        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocusChange(true)
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onEnter()
                return true
            }
            return false
        }
    }
}
#endif