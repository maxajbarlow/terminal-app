import SwiftUI
// import CLibVTerm // Not available in standalone project
#if os(iOS)
import UIKit

public struct iOSKeyboardHandler: UIViewRepresentable {
    @Binding var inputText: String
    let onKeyPress: (String) -> Void
    let onSpecialKey: (VTermKey, VTermModifier) -> Void
    
    public func makeUIView(context: Context) -> KeyboardInputView {
        let view = KeyboardInputView()
        view.onTextInput = { text in
            onKeyPress(text)
        }
        view.onSpecialKey = onSpecialKey
        return view
    }
    
    public func updateUIView(_ uiView: KeyboardInputView, context: Context) {
        uiView.inputText = inputText
    }
}

public class KeyboardInputView: UIView, UITextInputTraits {
    var inputText: String = ""
    var onTextInput: ((String) -> Void)?
    var onSpecialKey: ((VTermKey, VTermModifier) -> Void)?
    
    private var textStorage = ""
    
    public override var canBecomeFirstResponder: Bool { return true }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        becomeFirstResponder()
    }
    
    // MARK: - UIKeyInput
    
    public var hasText: Bool {
        return !textStorage.isEmpty
    }
    
    public func insertText(_ text: String) {
        textStorage += text
        onTextInput?(text)
    }
    
    public func deleteBackward() {
        if !textStorage.isEmpty {
            textStorage.removeLast()
            onSpecialKey?(VTERM_KEY_BACKSPACE, VTERM_MOD_NONE)
        }
    }
    
    // MARK: - UITextInputTraits
    
    public var keyboardType: UIKeyboardType = .default
    public var returnKeyType: UIReturnKeyType = .default
    public var autocorrectionType: UITextAutocorrectionType = .no
    public var autocapitalizationType: UITextAutocapitalizationType = .none
    public var spellCheckingType: UITextSpellCheckingType = .no
    
    // MARK: - Hardware Keyboard Support
    
    public override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(upArrowPressed)),
            UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(downArrowPressed)),
            UIKeyCommand(input: UIKeyCommand.inputLeftArrow, modifierFlags: [], action: #selector(leftArrowPressed)),
            UIKeyCommand(input: UIKeyCommand.inputRightArrow, modifierFlags: [], action: #selector(rightArrowPressed)),
            UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(tabPressed)),
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(enterPressed)),
            UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escapePressed)),
            
            // Ctrl combinations
            UIKeyCommand(input: "c", modifierFlags: .control, action: #selector(ctrlCPressed)),
            UIKeyCommand(input: "d", modifierFlags: .control, action: #selector(ctrlDPressed)),
            UIKeyCommand(input: "l", modifierFlags: .control, action: #selector(ctrlLPressed)),
            UIKeyCommand(input: "z", modifierFlags: .control, action: #selector(ctrlZPressed)),
        ]
    }
    
    @objc private func upArrowPressed() {
        onSpecialKey?(VTERM_KEY_UP, VTERM_MOD_NONE)
    }
    
    @objc private func downArrowPressed() {
        onSpecialKey?(VTERM_KEY_DOWN, VTERM_MOD_NONE)
    }
    
    @objc private func leftArrowPressed() {
        onSpecialKey?(VTERM_KEY_LEFT, VTERM_MOD_NONE)
    }
    
    @objc private func rightArrowPressed() {
        onSpecialKey?(VTERM_KEY_RIGHT, VTERM_MOD_NONE)
    }
    
    @objc private func tabPressed() {
        onSpecialKey?(VTERM_KEY_TAB, VTERM_MOD_NONE)
    }
    
    @objc private func enterPressed() {
        onSpecialKey?(VTERM_KEY_ENTER, VTERM_MOD_NONE)
    }
    
    @objc private func escapePressed() {
        onSpecialKey?(VTERM_KEY_ESCAPE, VTERM_MOD_NONE)
    }
    
    @objc private func ctrlCPressed() {
        onTextInput?("\u{03}") // Ctrl+C
    }
    
    @objc private func ctrlDPressed() {
        onTextInput?("\u{04}") // Ctrl+D
    }
    
    @objc private func ctrlLPressed() {
        onTextInput?("\u{0C}") // Ctrl+L
    }
    
    @objc private func ctrlZPressed() {
        onTextInput?("\u{1A}") // Ctrl+Z
    }
}

// MARK: - Touch Gestures

public struct TouchGestureHandler: View {
    let onTap: (CGPoint) -> Void
    let onLongPress: (CGPoint) -> Void
    let onPinch: (CGFloat) -> Void
    
    @State private var scale: CGFloat = 1.0
    
    public var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { location in
                onTap(location)
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                // Long press handled in perform block
            } onPressingChanged: { isPressing in
                // Handle press state changes if needed
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = value
                    }
                    .onEnded { value in
                        onPinch(value)
                        scale = 1.0
                    }
            )
    }
}

#endif