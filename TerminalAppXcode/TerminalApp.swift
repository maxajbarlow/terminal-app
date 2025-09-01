import SwiftUI

@main
struct TerminalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif
    }
}

struct ContentView: View {
    var body: some View {
        TabbedTerminalView()
            #if os(macOS)
            .frame(minWidth: 800, minHeight: 600)
            #endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
