import Foundation
import SwiftUI

// Shared application state that can be accessed from anywhere
public class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var showConfiguration = false
    
    private init() {}
    
    public func openConfiguration() {
        DispatchQueue.main.async { [weak self] in
            self?.showConfiguration = true
        }
    }
    
    public func closeConfiguration() {
        DispatchQueue.main.async { [weak self] in
            self?.showConfiguration = false
        }
    }
}