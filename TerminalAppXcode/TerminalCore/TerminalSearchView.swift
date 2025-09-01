import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

public struct TerminalSearchView: View {
    @Binding var searchText: String
    @Binding var isSearchVisible: Bool
    let matchCount: Int
    let currentMatch: Int
    let onSearch: (String, Bool) -> Void // text, isNext
    let onClose: () -> Void
    
    public init(
        searchText: Binding<String>,
        isSearchVisible: Binding<Bool>,
        matchCount: Int,
        currentMatch: Int,
        onSearch: @escaping (String, Bool) -> Void,
        onClose: @escaping () -> Void
    ) {
        self._searchText = searchText
        self._isSearchVisible = isSearchVisible
        self.matchCount = matchCount
        self.currentMatch = currentMatch
        self.onSearch = onSearch
        self.onClose = onClose
    }
    
    public var body: some View {
        if isSearchVisible {
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    
                    TextField("Search", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 12))
                        .onSubmit {
                            performSearch(next: true)
                        }
                        .onChange(of: searchText) { newValue in
                            if !newValue.isEmpty {
                                performSearch(next: true)
                            }
                        }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                #if canImport(AppKit)
                .background(Color(NSColor.textBackgroundColor))
                #else
                .background(Color(.systemBackground))
                #endif
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        #if canImport(AppKit)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        #else
                        .stroke(Color(.separator), lineWidth: 1)
                        #endif
                )
                
                if !searchText.isEmpty && matchCount > 0 {
                    Text("\(currentMatch)/\(matchCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                
                Button(action: { performSearch(next: false) }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(searchText.isEmpty || matchCount == 0)
                
                Button(action: { performSearch(next: true) }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(searchText.isEmpty || matchCount == 0)
                
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            #if canImport(AppKit)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(.systemGroupedBackground))
            #endif
        }
    }
    
    private func performSearch(next: Bool) {
        guard !searchText.isEmpty else { return }
        onSearch(searchText, next)
    }
}

public class TerminalSearchManager: ObservableObject {
    @Published var searchText: String = ""
    @Published var isSearchVisible: Bool = false
    @Published var highlightedText: String = ""
    @Published var matchCount: Int = 0
    @Published var currentMatch: Int = 0
    
    private var matches: [Range<String.Index>] = []
    private var currentMatchIndex: Int = 0
    private var originalText: String = ""
    
    public init() {}
    
    public func setTerminalText(_ text: String) {
        originalText = text
        if !searchText.isEmpty {
            updateHighlights()
        }
    }
    
    // Enhanced search with scrollback buffer integration
    public func setScrollbackBuffer(_ buffer: ScrollbackBuffer) {
        originalText = buffer.displayText
        if !searchText.isEmpty {
            updateHighlights()
        }
    }
    
    public func toggleSearch() {
        isSearchVisible.toggle()
        if isSearchVisible {
            // Focus will be handled by SwiftUI
        } else {
            clearSearch()
        }
    }
    
    public func performSearch(text: String, next: Bool) {
        searchText = text
        
        if text.isEmpty {
            clearSearch()
            return
        }
        
        // Find all matches
        matches = findAllMatches(in: originalText, searchText: text)
        
        if !matches.isEmpty {
            if next {
                currentMatchIndex = (currentMatchIndex + 1) % matches.count
            } else {
                currentMatchIndex = currentMatchIndex > 0 ? currentMatchIndex - 1 : matches.count - 1
            }
        } else {
            currentMatchIndex = 0
        }
        
        updateHighlights()
    }
    
    public func clearSearch() {
        searchText = ""
        matches = []
        currentMatchIndex = 0
        highlightedText = originalText
        matchCount = 0
        currentMatch = 0
    }
    
    private func updateHighlights() {
        if searchText.isEmpty {
            highlightedText = originalText
            matchCount = 0
            currentMatch = 0
            return
        }
        
        matchCount = matches.count
        currentMatch = matches.isEmpty ? 0 : currentMatchIndex + 1
        
        // For now, just return the original text since SwiftUI Text highlighting is complex
        // We'll implement a simple search counter instead of visual highlighting
        highlightedText = originalText
    }
    
    private func findAllMatches(in text: String, searchText: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = text.startIndex
        
        while searchStartIndex < text.endIndex {
            if let range = text.range(of: searchText, options: .caseInsensitive, range: searchStartIndex..<text.endIndex) {
                ranges.append(range)
                searchStartIndex = range.upperBound
            } else {
                break
            }
        }
        
        return ranges
    }
    
    public var currentMatchInfo: (current: Int, total: Int) {
        return (currentMatchIndex + 1, matches.count)
    }
}