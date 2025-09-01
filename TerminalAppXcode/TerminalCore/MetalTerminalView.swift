#if os(macOS)
import Metal
import MetalKit
import AppKit
import SwiftUI

// MARK: - Metal Terminal Renderer

public class MetalTerminalRenderer: NSObject, ObservableObject {
    private var device: MTLDevice
    private var commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var textTexture: MTLTexture?
    private var vertexBuffer: MTLBuffer?
    
    // Terminal grid properties
    public var gridWidth: Int = 80
    public var gridHeight: Int = 24
    public var cellWidth: Float = 12.0
    public var cellHeight: Float = 18.0
    
    // Text rendering
    private var characterMap: [Character: MTLTexture] = [:]
    private var font: NSFont
    private var foregroundColor: simd_float4 = simd_float4(0.9, 0.9, 0.9, 1.0)
    private var backgroundColor: simd_float4 = simd_float4(0.0, 0.0, 0.0, 1.0)
    
    // Terminal buffer
    private var terminalBuffer: [[TerminalCell]] = []
    private var cursorX: Int = 0
    private var cursorY: Int = 0
    private var cursorVisible: Bool = true
    private var lastCursorBlink: CFAbsoluteTime = 0
    
    public override init() {
        // Initialize Metal
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue")
        }
        self.commandQueue = commandQueue
        
        // Initialize font
        self.font = NSFont.monospacedSystemFont(ofSize: 14.0, weight: .regular)
        
        super.init()
        
        setupMetalPipeline()
        initializeTerminalBuffer()
    }
    
    private func setupMetalPipeline() {
        // Create Metal shaders
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;
        
        struct VertexIn {
            float2 position [[attribute(0)]];
            float2 texCoord [[attribute(1)]];
            float4 color [[attribute(2)]];
        };
        
        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
            float4 color;
        };
        
        vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
            VertexOut out;
            out.position = float4(in.position, 0.0, 1.0);
            out.texCoord = in.texCoord;
            out.color = in.color;
            return out;
        }
        
        fragment float4 fragment_main(VertexOut in [[stage_in]],
                                      texture2d<float> texture [[texture(0)]],
                                      sampler textureSampler [[sampler(0)]]) {
            float4 texColor = texture.sample(textureSampler, in.texCoord);
            return texColor * in.color;
        }
        """
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            let vertexFunction = library.makeFunction(name: "vertex_main")
            let fragmentFunction = library.makeFunction(name: "fragment_main")
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            // Vertex descriptor
            let vertexDescriptor = MTLVertexDescriptor()
            vertexDescriptor.attributes[0].format = .float2
            vertexDescriptor.attributes[0].offset = 0
            vertexDescriptor.attributes[0].bufferIndex = 0
            
            vertexDescriptor.attributes[1].format = .float2
            vertexDescriptor.attributes[1].offset = 8
            vertexDescriptor.attributes[1].bufferIndex = 0
            
            vertexDescriptor.attributes[2].format = .float4
            vertexDescriptor.attributes[2].offset = 16
            vertexDescriptor.attributes[2].bufferIndex = 0
            
            vertexDescriptor.layouts[0].stride = 32
            vertexDescriptor.layouts[0].stepRate = 1
            vertexDescriptor.layouts[0].stepFunction = .perVertex
            
            pipelineDescriptor.vertexDescriptor = vertexDescriptor
            
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error creating Metal pipeline: \\(error)")
        }
    }
    
    private func initializeTerminalBuffer() {
        terminalBuffer = Array(repeating: Array(repeating: TerminalCell(), count: gridWidth), count: gridHeight)
    }
    
    public func updateGridSize(width: Int, height: Int) {
        gridWidth = width
        gridHeight = height
        initializeTerminalBuffer()
    }
    
    public func writeText(_ text: String, at x: Int, y: Int, color: simd_float4 = simd_float4(0.9, 0.9, 0.9, 1.0)) {
        guard y >= 0 && y < gridHeight else { return }
        
        var currentX = x
        for char in text {
            guard currentX >= 0 && currentX < gridWidth else { break }
            
            terminalBuffer[y][currentX] = TerminalCell(
                character: char,
                foregroundColor: color,
                backgroundColor: backgroundColor
            )
            currentX += 1
        }
    }
    
    public func clearLine(_ line: Int) {
        guard line >= 0 && line < gridHeight else { return }
        for x in 0..<gridWidth {
            terminalBuffer[line][x] = TerminalCell()
        }
    }
    
    public func clearScreen() {
        for y in 0..<gridHeight {
            clearLine(y)
        }
        cursorX = 0
        cursorY = 0
    }
    
    public func setCursor(x: Int, y: Int) {
        cursorX = max(0, min(x, gridWidth - 1))
        cursorY = max(0, min(y, gridHeight - 1))
    }
    
    private func createTextureForCharacter(_ character: Character) -> MTLTexture? {
        let size = CGSize(width: Int(cellWidth), height: Int(cellHeight))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        // Clear background
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
        context.fill(CGRect(origin: .zero, size: size))
        
        // Draw character
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        
        let string = String(character)
        let attributedString = NSAttributedString(string: string, attributes: attributes)
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let bounds = CTLineGetBoundsWithOptions(line, [])
        
        // Center the character
        let x = (size.width - bounds.width) / 2
        let y = (size.height - bounds.height) / 2
        
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
        
        // Create Metal texture from bitmap
        guard let cgImage = context.makeImage() else { return nil }
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead]
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else { return nil }
        
        let bytesPerRow = Int(size.width) * 4
        let data = context.data!
        
        texture.replace(
            region: MTLRegionMake2D(0, 0, Int(size.width), Int(size.height)),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )
        
        return texture
    }
    
    private func getTextureForCharacter(_ character: Character) -> MTLTexture? {
        if let texture = characterMap[character] {
            return texture
        }
        
        let texture = createTextureForCharacter(character)
        characterMap[character] = texture
        return texture
    }
    
    public func render(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pipelineState = pipelineState else { return }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(backgroundColor.x),
            green: Double(backgroundColor.y),
            blue: Double(backgroundColor.z),
            alpha: Double(backgroundColor.w)
        )
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Create vertices for all visible characters
        var vertices: [TerminalVertex] = []
        
        let viewWidth = Float(view.bounds.width)
        let viewHeight = Float(view.bounds.height)
        
        for y in 0..<gridHeight {
            for x in 0..<gridWidth {
                let cell = terminalBuffer[y][x]
                guard cell.character != " " && cell.character != Character("\\0") else { continue }
                
                // Calculate screen positions
                let screenX = Float(x) * cellWidth
                let screenY = Float(y) * cellHeight
                
                // Convert to normalized device coordinates
                let left = (screenX / viewWidth) * 2.0 - 1.0
                let right = ((screenX + cellWidth) / viewWidth) * 2.0 - 1.0
                let top = 1.0 - (screenY / viewHeight) * 2.0
                let bottom = 1.0 - ((screenY + cellHeight) / viewHeight) * 2.0
                
                // Create quad vertices
                let quad = [
                    TerminalVertex(position: simd_float2(left, top), texCoord: simd_float2(0, 0), color: cell.foregroundColor),
                    TerminalVertex(position: simd_float2(right, top), texCoord: simd_float2(1, 0), color: cell.foregroundColor),
                    TerminalVertex(position: simd_float2(left, bottom), texCoord: simd_float2(0, 1), color: cell.foregroundColor),
                    TerminalVertex(position: simd_float2(right, top), texCoord: simd_float2(1, 0), color: cell.foregroundColor),
                    TerminalVertex(position: simd_float2(right, bottom), texCoord: simd_float2(1, 1), color: cell.foregroundColor),
                    TerminalVertex(position: simd_float2(left, bottom), texCoord: simd_float2(0, 1), color: cell.foregroundColor)
                ]
                vertices.append(contentsOf: quad)
            }
        }
        
        // Draw cursor if visible
        if cursorVisible {
            let currentTime = CFAbsoluteTimeGetCurrent()
            if currentTime - lastCursorBlink > 0.5 {
                cursorVisible = !cursorVisible
                lastCursorBlink = currentTime
            }
            
            if cursorVisible {
                let screenX = Float(cursorX) * cellWidth
                let screenY = Float(cursorY) * cellHeight
                
                let left = (screenX / viewWidth) * 2.0 - 1.0
                let right = ((screenX + cellWidth) / viewWidth) * 2.0 - 1.0
                let top = 1.0 - (screenY / viewHeight) * 2.0
                let bottom = 1.0 - ((screenY + cellHeight) / viewHeight) * 2.0
                
                let cursorColor = simd_float4(1.0, 1.0, 1.0, 0.8)
                let cursorQuad = [
                    TerminalVertex(position: simd_float2(left, top), texCoord: simd_float2(0, 0), color: cursorColor),
                    TerminalVertex(position: simd_float2(right, top), texCoord: simd_float2(1, 0), color: cursorColor),
                    TerminalVertex(position: simd_float2(left, bottom), texCoord: simd_float2(0, 1), color: cursorColor),
                    TerminalVertex(position: simd_float2(right, top), texCoord: simd_float2(1, 0), color: cursorColor),
                    TerminalVertex(position: simd_float2(right, bottom), texCoord: simd_float2(1, 1), color: cursorColor),
                    TerminalVertex(position: simd_float2(left, bottom), texCoord: simd_float2(0, 1), color: cursorColor)
                ]
                vertices.append(contentsOf: cursorQuad)
            }
        }
        
        guard !vertices.isEmpty else {
            renderEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }
        
        // Create vertex buffer
        let vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<TerminalVertex>.stride,
            options: []
        )
        
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // For now, draw without textures (will implement character textures next)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Terminal Data Structures

struct TerminalVertex {
    let position: simd_float2
    let texCoord: simd_float2
    let color: simd_float4
}

struct TerminalCell {
    var character: Character = " "
    var foregroundColor: simd_float4 = simd_float4(0.9, 0.9, 0.9, 1.0)
    var backgroundColor: simd_float4 = simd_float4(0.0, 0.0, 0.0, 1.0)
    var attributes: TerminalAttributes = TerminalAttributes()
}

struct TerminalAttributes {
    var bold: Bool = false
    var italic: Bool = false
    var underline: Bool = false
    var reverse: Bool = false
}

// MARK: - Metal Terminal View

public class MetalTerminalView: MTKView {
    private var renderer: MetalTerminalRenderer?
    var session: TerminalSession?
    var onInput: ((String) -> Void)?
    
    private var currentInput: String = ""
    private var promptText: String = ""
    private var isCommandRunning: Bool = false
    
    public override init(frame frameRect: NSRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        setupView()
    }
    
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        guard let device = device else {
            print("Metal device not available")
            return
        }
        
        self.renderer = MetalTerminalRenderer()
        self.delegate = self
        self.preferredFramesPerSecond = 60
        self.enableSetNeedsDisplay = true
        self.autoResizeDrawable = true
        self.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        // Enable keyboard input
        self.acceptsTouchEvents = false
        self.wantsLayer = true
    }
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func becomeFirstResponder() -> Bool {
        return true
    }
    
    public override func keyDown(with event: NSEvent) {
        guard let characters = event.characters else { return }
        
        for char in characters {
            switch char {
            case "\\r", "\\n": // Enter key
                handleEnterKey()
            case "\\u{8}", "\\u{7f}": // Backspace
                handleBackspace()
            case "\\u{9}": // Tab
                handleTab()
            case "\\u{3}": // Ctrl+C
                handleInterrupt()
            default:
                if char.isPrintable {
                    currentInput += String(char)
                    updatePromptLine()
                }
            }
        }
    }
    
    private func handleEnterKey() {
        let command = currentInput.trimmingCharacters(in: .whitespaces)
        
        // Add command to terminal display
        renderer?.writeText(promptText + command, at: 0, y: getCurrentLine())
        moveCursorToNewLine()
        
        // Execute command
        if !command.isEmpty {
            isCommandRunning = true
            onInput?(command)
        }
        
        currentInput = ""
        if !isCommandRunning {
            showNewPrompt()
        }
    }
    
    private func handleBackspace() {
        if !currentInput.isEmpty {
            currentInput.removeLast()
            updatePromptLine()
        }
    }
    
    private func handleTab() {
        // TODO: Implement tab completion
    }
    
    private func handleInterrupt() {
        if isCommandRunning {
            session?.interruptCurrentCommand()
            renderer?.writeText("^C", at: promptText.count + currentInput.count, y: getCurrentLine())
            moveCursorToNewLine()
            isCommandRunning = false
            showNewPrompt()
        } else {
            renderer?.writeText("^C", at: promptText.count + currentInput.count, y: getCurrentLine())
            moveCursorToNewLine()
            showNewPrompt()
        }
    }
    
    private func getCurrentLine() -> Int {
        // TODO: Implement proper line tracking
        return 0
    }
    
    private func moveCursorToNewLine() {
        // TODO: Implement proper cursor management
    }
    
    private func showNewPrompt() {
        guard let session = session else { return }
        
        let username = NSUserName()
        let hostname = ProcessInfo.processInfo.hostName
        let homeDir = NSHomeDirectory()
        let currentPath = session.currentPath.isEmpty ? FileManager.default.currentDirectoryPath : session.currentPath
        let displayPath = currentPath.hasPrefix(homeDir) ? currentPath.replacingOccurrences(of: homeDir, with: "~") : currentPath
        let directoryName = URL(fileURLWithPath: displayPath).lastPathComponent
        
        promptText = "\\(username)@\\(hostname) \\(directoryName) % "
        currentInput = ""
        updatePromptLine()
    }
    
    private func updatePromptLine() {
        let fullLine = promptText + currentInput
        renderer?.writeText(fullLine, at: 0, y: getCurrentLine())
        renderer?.setCursor(x: fullLine.count, y: getCurrentLine())
    }
    
    public func updateOutput(_ output: String) {
        // TODO: Parse output and update terminal buffer
        isCommandRunning = false
        showNewPrompt()
        setNeedsDisplay()
    }
    
    public func commandCompleted() {
        isCommandRunning = false
        showNewPrompt()
        setNeedsDisplay()
    }
}

// MARK: - MTKViewDelegate

extension MetalTerminalView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Update grid size based on new view size
        let newWidth = Int(size.width / CGFloat(renderer?.cellWidth ?? 12.0))
        let newHeight = Int(size.height / CGFloat(renderer?.cellHeight ?? 18.0))
        renderer?.updateGridSize(width: newWidth, height: newHeight)
    }
    
    public func draw(in view: MTKView) {
        renderer?.render(in: view)
    }
}

// MARK: - SwiftUI Integration

public struct MetalTerminalSwiftUIView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession
    
    public func makeNSView(context: Context) -> MetalTerminalView {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported")
        }
        
        let view = MetalTerminalView(frame: .zero, device: device)
        view.session = session
        view.onInput = { command in
            session.sendInput(command)
        }
        
        // Set up command completion callback
        session.onCommandCompleted = { [weak view] in
            DispatchQueue.main.async {
                view?.commandCompleted()
            }
        }
        
        // Set initial output
        view.updateOutput(session.output)
        
        return view
    }
    
    public func updateNSView(_ nsView: MetalTerminalView, context: Context) {
        nsView.updateOutput(session.output)
    }
}

// MARK: - Character Extensions

extension Character {
    var isPrintable: Bool {
        return !isWhitespace && !isNewline && !isControl
    }
    
    var isControl: Bool {
        return unicodeScalars.allSatisfy { $0.properties.generalCategory == .control }
    }
}

#endif