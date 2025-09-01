import Foundation
import Network
import CryptoKit
import Combine

// MARK: - Mosh Protocol Implementation

/// Mosh State Synchronization Protocol (SSP) Implementation
public class MoshProtocol {
    
    // MARK: - Protocol Constants
    
    public static let protocolVersion: UInt8 = 2
    public static let defaultPort: Int = 60001
    public static let heartbeatInterval: TimeInterval = 3.0
    public static let reconnectTimeout: TimeInterval = 10.0
    
    // MARK: - Message Types
    
    public enum MessageType: UInt8 {
        case stateUpdate = 0x01
        case acknowledgment = 0x02
        case heartbeat = 0x03
        case keyExchange = 0x04
        case terminalResize = 0x05
        case prediction = 0x06
        case retransmitRequest = 0x07
    }
    
    // MARK: - SSP Packet Structure
    
    public struct SSPPacket {
        let sequenceNumber: UInt64
        let acknowledgmentNumber: UInt64
        let timestamp: UInt64
        let messageType: MessageType
        let payload: Data
        let checksum: Data
        
        init(sequenceNumber: UInt64, acknowledgmentNumber: UInt64, messageType: MessageType, payload: Data) {
            self.sequenceNumber = sequenceNumber
            self.acknowledgmentNumber = acknowledgmentNumber
            self.timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
            self.messageType = messageType
            self.payload = payload
            self.checksum = Self.calculateChecksum(sequenceNumber: sequenceNumber, 
                                                  acknowledgmentNumber: acknowledgmentNumber,
                                                  timestamp: timestamp,
                                                  messageType: messageType,
                                                  payload: payload)
        }
        
        static func calculateChecksum(sequenceNumber: UInt64, acknowledgmentNumber: UInt64, 
                                     timestamp: UInt64, messageType: MessageType, payload: Data) -> Data {
            var data = Data()
            data.append(contentsOf: withUnsafeBytes(of: sequenceNumber.bigEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: acknowledgmentNumber.bigEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: timestamp.bigEndian) { Data($0) })
            data.append(messageType.rawValue)
            data.append(payload)
            
            let hash = SHA256.hash(data: data)
            return Data(hash.prefix(8)) // Use first 8 bytes as checksum
        }
        
        func serialize() -> Data {
            var data = Data()
            data.append(contentsOf: withUnsafeBytes(of: sequenceNumber.bigEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: acknowledgmentNumber.bigEndian) { Data($0) })
            data.append(contentsOf: withUnsafeBytes(of: timestamp.bigEndian) { Data($0) })
            data.append(messageType.rawValue)
            data.append(contentsOf: withUnsafeBytes(of: UInt32(payload.count).bigEndian) { Data($0) })
            data.append(payload)
            data.append(checksum)
            return data
        }
        
        static func deserialize(from data: Data) -> SSPPacket? {
            guard data.count >= 37 else { return nil } // Minimum packet size
            
            var offset = 0
            
            // Read sequence number
            let sequenceNumber = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt64.self).bigEndian
            }
            offset += 8
            
            // Read acknowledgment number
            let acknowledgmentNumber = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt64.self).bigEndian
            }
            offset += 8
            
            // Read timestamp
            let timestamp = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt64.self).bigEndian
            }
            offset += 8
            
            // Read message type
            guard let messageType = MessageType(rawValue: data[offset]) else { return nil }
            offset += 1
            
            // Read payload length
            let payloadLength = data.withUnsafeBytes { bytes in
                bytes.load(fromByteOffset: offset, as: UInt32.self).bigEndian
            }
            offset += 4
            
            // Read payload
            guard data.count >= offset + Int(payloadLength) + 8 else { return nil }
            let payload = data.subdata(in: offset..<(offset + Int(payloadLength)))
            offset += Int(payloadLength)
            
            // Read checksum
            let checksum = data.subdata(in: offset..<(offset + 8))
            
            // Verify checksum
            let expectedChecksum = calculateChecksum(sequenceNumber: sequenceNumber,
                                                    acknowledgmentNumber: acknowledgmentNumber,
                                                    timestamp: timestamp,
                                                    messageType: messageType,
                                                    payload: payload)
            
            guard checksum == expectedChecksum else { return nil }
            
            return SSPPacket(sequenceNumber: sequenceNumber,
                           acknowledgmentNumber: acknowledgmentNumber,
                           messageType: messageType,
                           payload: payload)
        }
    }
    
    // MARK: - Terminal State
    
    public class TerminalState {
        private var cells: [[Cell]]
        private var cursorRow: Int
        private var cursorColumn: Int
        private var rows: Int
        private var columns: Int
        private var stateVersion: UInt64
        
        struct Cell: Codable {
            var character: Character
            var foregroundColor: UInt32
            var backgroundColor: UInt32
            var attributes: UInt8
        }
        
        init(rows: Int = 24, columns: Int = 80) {
            self.rows = rows
            self.columns = columns
            self.cursorRow = 0
            self.cursorColumn = 0
            self.stateVersion = 0
            self.cells = Array(repeating: Array(repeating: Cell(character: " ", 
                                                               foregroundColor: 0xFFFFFF,
                                                               backgroundColor: 0x000000,
                                                               attributes: 0), 
                                              count: columns), 
                             count: rows)
        }
        
        func updateCell(row: Int, column: Int, character: Character, 
                       foregroundColor: UInt32? = nil, backgroundColor: UInt32? = nil) {
            guard row >= 0 && row < rows && column >= 0 && column < columns else { return }
            
            cells[row][column].character = character
            if let fg = foregroundColor {
                cells[row][column].foregroundColor = fg
            }
            if let bg = backgroundColor {
                cells[row][column].backgroundColor = bg
            }
            stateVersion += 1
        }
        
        func moveCursor(to row: Int, column: Int) {
            cursorRow = max(0, min(row, rows - 1))
            cursorColumn = max(0, min(column, columns - 1))
            stateVersion += 1
        }
        
        func serialize() -> Data {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            
            let stateData: [String: Any] = [
                "version": stateVersion,
                "rows": rows,
                "columns": columns,
                "cursorRow": cursorRow,
                "cursorColumn": cursorColumn,
                "cells": cells.map { row in
                    row.map { cell in
                        [
                            "char": String(cell.character),
                            "fg": cell.foregroundColor,
                            "bg": cell.backgroundColor,
                            "attr": cell.attributes
                        ]
                    }
                }
            ]
            
            return try! JSONSerialization.data(withJSONObject: stateData, options: .sortedKeys)
        }
        
        func applyDelta(_ delta: Data) {
            // Apply incremental state updates
            guard let deltaDict = try? JSONSerialization.jsonObject(with: delta) as? [String: Any] else { return }
            
            if let version = deltaDict["version"] as? UInt64, version > stateVersion {
                stateVersion = version
                
                if let updates = deltaDict["updates"] as? [[String: Any]] {
                    for update in updates {
                        if let row = update["row"] as? Int,
                           let col = update["col"] as? Int,
                           let char = update["char"] as? String,
                           !char.isEmpty {
                            updateCell(row: row, column: col, character: Character(char))
                        }
                    }
                }
                
                if let newCursorRow = deltaDict["cursorRow"] as? Int,
                   let newCursorCol = deltaDict["cursorColumn"] as? Int {
                    moveCursor(to: newCursorRow, column: newCursorCol)
                }
            }
        }
        
        func resize(rows: Int, columns: Int) {
            self.rows = rows
            self.columns = columns
            
            // Resize cell array
            if cells.count < rows {
                // Add rows
                for _ in cells.count..<rows {
                    cells.append(Array(repeating: Cell(character: " ",
                                                      foregroundColor: 0xFFFFFF,
                                                      backgroundColor: 0x000000,
                                                      attributes: 0),
                                     count: columns))
                }
            } else if cells.count > rows {
                // Remove rows
                cells = Array(cells.prefix(rows))
            }
            
            // Adjust columns
            for i in 0..<cells.count {
                if cells[i].count < columns {
                    // Add columns
                    for _ in cells[i].count..<columns {
                        cells[i].append(Cell(character: " ",
                                           foregroundColor: 0xFFFFFF,
                                           backgroundColor: 0x000000,
                                           attributes: 0))
                    }
                } else if cells[i].count > columns {
                    // Remove columns
                    cells[i] = Array(cells[i].prefix(columns))
                }
            }
            
            stateVersion += 1
        }
        
        func render() -> String {
            return cells.map { row in
                row.map { String($0.character) }.joined()
            }.joined(separator: "\n")
        }
    }
    
    // MARK: - Prediction Engine
    
    public class PredictionEngine {
        private var localEcho: Bool = true
        private var pendingInput: String = ""
        private var confirmedPosition: Int = 0
        private var predictedState: TerminalState
        private var confirmedState: TerminalState
        
        init(terminalState: TerminalState) {
            self.predictedState = terminalState
            self.confirmedState = TerminalState(rows: terminalState.rows, columns: terminalState.columns)
        }
        
        func predictInput(_ input: String) -> String {
            guard localEcho else { return "" }
            
            pendingInput.append(input)
            
            // Apply prediction to local state
            for char in input {
                if char == "\n" || char == "\r" {
                    predictedState.moveCursor(to: predictedState.cursorRow + 1, column: 0)
                } else if char == "\u{7F}" { // Backspace
                    if predictedState.cursorColumn > 0 {
                        predictedState.moveCursor(to: predictedState.cursorRow, 
                                                column: predictedState.cursorColumn - 1)
                        predictedState.updateCell(row: predictedState.cursorRow,
                                                column: predictedState.cursorColumn,
                                                character: " ")
                    }
                } else if char.isASCII && !char.isControl {
                    predictedState.updateCell(row: predictedState.cursorRow,
                                            column: predictedState.cursorColumn,
                                            character: char)
                    predictedState.moveCursor(to: predictedState.cursorRow,
                                            column: predictedState.cursorColumn + 1)
                }
            }
            
            return input
        }
        
        func confirmPrediction(upTo position: Int) {
            if position <= pendingInput.count {
                confirmedPosition = position
                
                // Remove confirmed input from pending
                if position > 0 {
                    pendingInput.removeFirst(position)
                }
            }
        }
        
        func rollbackPrediction() {
            // Revert to confirmed state
            predictedState = confirmedState
            pendingInput = ""
            confirmedPosition = 0
        }
        
        func updateConfirmedState(_ state: TerminalState) {
            confirmedState = state
            
            // Reapply pending predictions
            if !pendingInput.isEmpty {
                let temp = pendingInput
                pendingInput = ""
                _ = predictInput(temp)
            }
        }
    }
}

// MARK: - Mosh Connection State

public enum MoshConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case suspended
}

// MARK: - Mosh Errors

public enum MoshProtocolError: Error, LocalizedError {
    case invalidPacket
    case checksumMismatch
    case connectionTimeout
    case authenticationFailed
    case encryptionError
    case stateDesyncError
    
    public var errorDescription: String? {
        switch self {
        case .invalidPacket: return "Invalid Mosh packet received"
        case .checksumMismatch: return "Packet checksum verification failed"
        case .connectionTimeout: return "Connection timed out"
        case .authenticationFailed: return "Authentication failed"
        case .encryptionError: return "Encryption/decryption error"
        case .stateDesyncError: return "Terminal state desynchronization"
        }
    }
}