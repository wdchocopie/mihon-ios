import SwiftUI
import MihonUI

// The iOS app entry point. Lives in App/ (NOT Sources/) so it is part of the
// generated Xcode app target only — SPM and `swift test` on Windows never touch
// it, which is why the local core loop stays Mac-free. Compiles on Apple
// platforms only.
@main
struct MihonApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
