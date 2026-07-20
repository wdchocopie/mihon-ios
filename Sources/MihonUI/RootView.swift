import Foundation
import MihonCore

// SwiftUI screens. SwiftUI is Apple-only, so the module body is guarded and
// compiles to empty on Windows/Linux. All interactive UI work (previews,
// simulator, iteration) happens on a Mac or via CI→TestFlight→iPad; nothing
// here is developable in the local Windows loop, by design.
#if canImport(SwiftUI)
import SwiftUI

/// App root. Placeholder five-tab shell matching Mihon's information
/// architecture (Library, Updates, History, Browse, More). The real per-tab
/// NavigationStacks + typed router come in Wave 3 (Lane 4).
public struct RootView: View {
    public init() {}

    public var body: some View {
        TabView {
            Text("Library").tabItem { Label("Library", systemImage: "books.vertical") }
            Text("Updates").tabItem { Label("Updates", systemImage: "arrow.clockwise") }
            Text("History").tabItem { Label("History", systemImage: "clock") }
            Text("Browse").tabItem { Label("Browse", systemImage: "globe") }
            Text("More").tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}

#endif
