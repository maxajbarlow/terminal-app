import Foundation
// import CLibVTerm // Not available in standalone project

// Stub VTerm types and constants for standalone project
public typealias VTermKey = Int32
public typealias VTermModifier = Int32
public let VTERM_MOD_NONE: VTermModifier = 0
public let VTERM_MOD_SHIFT: VTermModifier = 1
public let VTERM_MOD_ALT: VTermModifier = 2
public let VTERM_MOD_CTRL: VTermModifier = 4

// Stub VTerm key constants for standalone project
public let VTERM_KEY_BACKSPACE: VTermKey = 8
public let VTERM_KEY_TAB: VTermKey = 9
public let VTERM_KEY_ENTER: VTermKey = 13
public let VTERM_KEY_ESCAPE: VTermKey = 27
public let VTERM_KEY_UP: VTermKey = 1001
public let VTERM_KEY_DOWN: VTermKey = 1002
public let VTERM_KEY_LEFT: VTermKey = 1003
public let VTERM_KEY_RIGHT: VTermKey = 1004

// Stub VTerm function implementations for standalone project
private func vterm_new(_ rows: Int32, _ cols: Int32) -> OpaquePointer? {
    return OpaquePointer(bitPattern: 1)
}

private func vterm_free(_ vt: OpaquePointer) {
    // Stub implementation
}

private func vterm_obtain_screen(_ vt: OpaquePointer) -> OpaquePointer? {
    return OpaquePointer(bitPattern: 2)
}

private func vterm_set_size(_ vt: OpaquePointer, _ rows: Int32, _ cols: Int32) {
    // Stub implementation
}

private func vterm_input_write(_ vt: OpaquePointer, _ bytes: UnsafePointer<Int8>, _ len: Int) -> Int {
    return len // Return bytes written
}

private func vterm_output_read(_ vt: OpaquePointer, _ buffer: UnsafeMutablePointer<Int8>, _ len: Int) -> Int {
    return 0 // No output in stub
}

private func vterm_keyboard_key(_ vt: OpaquePointer, _ key: VTermKey, _ mod: VTermModifier) {
    // Stub implementation
}

private func vterm_keyboard_unichar(_ vt: OpaquePointer, _ c: UInt32, _ mod: VTermModifier) {
    // Stub implementation
}

// Stub VTerm implementation for standalone project
public class VTermWrapper {
    private var vterm: OpaquePointer?
    private var screen: OpaquePointer?
    private let rows: Int
    private let cols: Int
    
    public var onOutput: ((String) -> Void)?
    
    public init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        
        vterm = vterm_new(Int32(rows), Int32(cols))
        if let vterm = vterm {
            screen = vterm_obtain_screen(vterm)
        }
    }
    
    deinit {
        cleanup()
    }
    
    public func cleanup() {
        if let vterm = vterm {
            vterm_free(vterm)
        }
        vterm = nil
        screen = nil
    }
    
    public func resize(rows: Int, cols: Int) {
        guard let vterm = vterm else { return }
        vterm_set_size(vterm, Int32(rows), Int32(cols))
    }
    
    public func sendInput(_ input: String) {
        guard let vterm = vterm else { return }
        
        _ = input.withCString { cString in
            vterm_input_write(vterm, cString, strlen(cString))
        }
        
        processOutput()
    }
    
    public func processData(_ data: Data) {
        guard let vterm = vterm else { return }
        
        data.withUnsafeBytes { bytes in
            if let baseAddress = bytes.baseAddress {
                _ = vterm_input_write(vterm, baseAddress.assumingMemoryBound(to: Int8.self), bytes.count)
            }
        }
        
        processOutput()
    }
    
    private func processOutput() {
        guard let vterm = vterm else { return }
        
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        let bytesRead = vterm_output_read(vterm, buffer, bufferSize)
        if bytesRead > 0 {
            let output = String(cString: buffer, encoding: .utf8) ?? ""
            onOutput?(output)
        }
    }
    
    public func sendKey(_ key: VTermKey, modifiers: VTermModifier = VTERM_MOD_NONE) {
        guard let vterm = vterm else { return }
        vterm_keyboard_key(vterm, key, modifiers)
        processOutput()
    }
    
    public func sendUnichar(_ char: Character, modifiers: VTermModifier = VTERM_MOD_NONE) {
        guard let vterm = vterm,
              let scalar = char.unicodeScalars.first else { return }
        
        vterm_keyboard_unichar(vterm, scalar.value, modifiers)
        processOutput()
    }
}