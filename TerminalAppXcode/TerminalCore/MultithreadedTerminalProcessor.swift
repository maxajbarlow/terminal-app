import Foundation
import Combine

/// Multithreaded terminal output processing system
/// Processes ANSI sequences, terminal output, and command results on background threads
public class MultithreadedTerminalProcessor: ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties (Main Thread Only)
    @Published public var processedOutput: String = ""
    @Published public var isProcessing: Bool = false
    @Published public var processingStats: ProcessingStats = ProcessingStats()
    
    // MARK: - Configuration
    private let bufferSize: Int = 8192 // 8KB buffer chunks
    private let maxOutputHistory: Int = 50_000 // Maximum lines to keep in memory
    private let maxConcurrentOperations: Int = 4
    
    // MARK: - Threading Infrastructure  
    private let outputProcessingQueue = DispatchQueue(
        label: "terminal.output.processing",
        qos: .userInitiated,
        attributes: .concurrent
    )
    
    private let ansiProcessingQueue = DispatchQueue(
        label: "terminal.ansi.processing", 
        qos: .userInitiated
    )
    
    private let bufferQueue = DispatchQueue(
        label: "terminal.buffer.management",
        qos: .utility
    )
    
    private let mainThreadUpdateQueue = DispatchQueue.main
    
    // MARK: - Thread-Safe Data Structures
    private let outputBuffer = ThreadSafeBuffer<String>()
    private let processingOperations = ThreadSafeCounter()
    private var isShuttingDown = false
    private let shutdownLock = NSLock()
    
    // MARK: - Processing Statistics
    public struct ProcessingStats {
        var totalBytesProcessed: Int64 = 0
        var totalLinesProcessed: Int = 0
        var averageProcessingTimeMs: Double = 0
        var backgroundThreadsActive: Int = 0
        var maxConcurrentOperations: Int = 0
        
        public var throughputMBps: Double {
            let seconds = averageProcessingTimeMs / 1000.0
            return seconds > 0 ? Double(totalBytesProcessed) / (1024 * 1024) / seconds : 0
        }
    }
    
    // MARK: - Initialization
    public init() {
        setupProcessingPipeline()
    }
    
    // MARK: - Public Interface
    
    /// Process raw terminal output with multithreading
    public func processOutput(_ rawOutput: String) {
        guard !rawOutput.isEmpty else { return }
        
        processingOperations.increment()
        updateProcessingState(true)
        
        // Process output on background thread
        outputProcessingQueue.async { [weak self] in
            self?.performBackgroundProcessing(rawOutput)
        }
    }
    
    /// Process large output chunks efficiently  
    public func processLargeOutput(_ rawOutput: String) {
        guard !rawOutput.isEmpty else { return }
        
        let chunks = rawOutput.chunked(into: bufferSize)
        let totalChunks = chunks.count
        
        updateProcessingState(true)
        
        // Process chunks concurrently with limited concurrency
        let semaphore = DispatchSemaphore(value: maxConcurrentOperations)
        let group = DispatchGroup()
        
        for (index, chunk) in chunks.enumerated() {
            outputProcessingQueue.async(group: group) { [weak self] in
                semaphore.wait()
                defer { 
                    semaphore.signal()
                    self?.processingOperations.decrement()
                }
                
                self?.processingOperations.increment()
                self?.processChunk(chunk, index: index, total: totalChunks)
            }
        }
        
        // Update UI when all chunks are processed
        group.notify(queue: mainThreadUpdateQueue) { [weak self] in
            self?.finalizeOutput()
            self?.updateProcessingState(false)
        }
    }
    
    /// Clear output and reset state
    public func clearOutput() {
        bufferQueue.async { [weak self] in
            self?.outputBuffer.clear()
            
            DispatchQueue.main.async {
                self?.processedOutput = ""
                self?.processingStats = ProcessingStats()
            }
        }
    }
    
    // MARK: - Background Processing
    
    private func performBackgroundProcessing(_ rawOutput: String) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Phase 1: ANSI sequence processing on dedicated thread
        ansiProcessingQueue.async { [weak self] in
            guard let self = self, !self.isShuttingDown else {
                self?.processingOperations.decrement()
                return
            }
            
            let processedAnsi = self.processAnsiSequences(rawOutput)
            
            // Phase 2: Buffer management and deduplication
            self.bufferQueue.async {
                guard !self.isShuttingDown else {
                    self.processingOperations.decrement()
                    return
                }
                
                self.outputBuffer.append(processedAnsi)
                let finalOutput = self.outputBuffer.getBufferedOutput()
                
                // Phase 3: UI update on main thread
                let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms
                
                self.mainThreadUpdateQueue.async {
                    self.processedOutput = finalOutput
                    self.updateStats(
                        bytesProcessed: Int64(rawOutput.utf8.count),
                        linesProcessed: rawOutput.components(separatedBy: .newlines).count,
                        processingTime: processingTime
                    )
                    self.processingOperations.decrement()
                    
                    if self.processingOperations.value == 0 {
                        self.updateProcessingState(false)
                    }
                }
            }
        }
    }
    
    private func processChunk(_ chunk: String, index: Int, total: Int) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Process ANSI sequences
        let processedChunk = processAnsiSequences(chunk)
        
        // Add to buffer with ordering
        bufferQueue.async { [weak self] in
            guard let self = self, !self.isShuttingDown else { return }
            
            self.outputBuffer.appendWithOrder(processedChunk, order: index)
            
            // Update stats
            let processingTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            
            self.mainThreadUpdateQueue.async {
                self.updateStats(
                    bytesProcessed: Int64(chunk.utf8.count),
                    linesProcessed: chunk.components(separatedBy: .newlines).count,
                    processingTime: processingTime
                )
            }
        }
    }
    
    // MARK: - ANSI Sequence Processing
    
    private func processAnsiSequences(_ input: String) -> String {
        // Strip ANSI color codes and control sequences for cleaner output
        var result = input
        
        // Remove ANSI escape sequences
        let ansiPattern = #/\x1B\[[0-9;]*[mK]/#
        result = result.replacing(ansiPattern, with: "")
        
        // Remove carriage returns that would overwrite content
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        
        // Handle backspace sequences
        result = processBackspaces(result)
        
        return result
    }
    
    private func processBackspaces(_ input: String) -> String {
        var result = ""
        var currentLine = ""
        
        for char in input {
            switch char {
            case "\u{08}": // Backspace
                if !currentLine.isEmpty {
                    currentLine.removeLast()
                }
            case "\n":
                result += currentLine + "\n"
                currentLine = ""
            default:
                currentLine.append(char)
            }
        }
        
        if !currentLine.isEmpty {
            result += currentLine
        }
        
        return result
    }
    
    // MARK: - Buffer Management
    
    private func finalizeOutput() {
        let finalOutput = outputBuffer.getBufferedOutput()
        
        mainThreadUpdateQueue.async { [weak self] in
            self?.processedOutput = finalOutput
        }
    }
    
    // MARK: - Statistics and State Management
    
    private func updateProcessingState(_ processing: Bool) {
        mainThreadUpdateQueue.async { [weak self] in
            self?.isProcessing = processing
        }
    }
    
    private func updateStats(bytesProcessed: Int64, linesProcessed: Int, processingTime: Double) {
        var newStats = processingStats
        
        newStats.totalBytesProcessed += bytesProcessed
        newStats.totalLinesProcessed += linesProcessed
        
        // Rolling average for processing time
        let alpha = 0.1 // Smoothing factor
        newStats.averageProcessingTimeMs = (1 - alpha) * newStats.averageProcessingTimeMs + alpha * processingTime
        
        newStats.backgroundThreadsActive = processingOperations.value
        newStats.maxConcurrentOperations = max(newStats.maxConcurrentOperations, processingOperations.value)
        
        processingStats = newStats
    }
    
    private func setupProcessingPipeline() {
        // Configure queue priorities and QoS
        outputProcessingQueue.setTarget(queue: DispatchQueue.global(qos: .userInitiated))
        ansiProcessingQueue.setTarget(queue: DispatchQueue.global(qos: .userInitiated))
        bufferQueue.setTarget(queue: DispatchQueue.global(qos: .utility))
    }
    
    // MARK: - Cleanup
    
    deinit {
        shutdownLock.lock()
        isShuttingDown = true
        shutdownLock.unlock()
        
        // Cancel any pending operations
        outputProcessingQueue.suspend()
        ansiProcessingQueue.suspend()
        bufferQueue.suspend()
    }
}

// MARK: - Thread-Safe Data Structures

private class ThreadSafeBuffer<T> {
    private var buffer: [T] = []
    private var orderedBuffer: [Int: T] = [:]
    private var nextExpectedOrder = 0
    private let lock = NSLock()
    
    func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(item)
    }
    
    func appendWithOrder(_ item: T, order: Int) {
        lock.lock()
        defer { lock.unlock() }
        orderedBuffer[order] = item
        processOrderedBuffer()
    }
    
    private func processOrderedBuffer() {
        while let item = orderedBuffer[nextExpectedOrder] {
            buffer.append(item)
            orderedBuffer.removeValue(forKey: nextExpectedOrder)
            nextExpectedOrder += 1
        }
    }
    
    func getBufferedOutput() -> String where T == String {
        lock.lock()
        defer { lock.unlock() }
        return buffer.joined()
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
        orderedBuffer.removeAll()
        nextExpectedOrder = 0
    }
}

private class ThreadSafeCounter {
    private var _value: Int = 0
    private let lock = NSLock()
    
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    
    func increment() {
        lock.lock()
        defer { lock.unlock() }
        _value += 1
    }
    
    func decrement() {
        lock.lock()
        defer { lock.unlock() }
        _value = max(0, _value - 1)
    }
}

// MARK: - Utility Extensions

private extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map { i in
            let startIndex = index(startIndex, offsetBy: i)
            let endIndex = index(startIndex, offsetBy: min(size, count - i))
            return String(self[startIndex..<endIndex])
        }
    }
}