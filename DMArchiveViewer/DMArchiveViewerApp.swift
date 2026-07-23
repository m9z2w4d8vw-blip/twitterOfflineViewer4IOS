import SwiftUI

@main
struct DMArchiveViewerApp: App {
    var body: some Scene {
        WindowGroup {
            LibraryView()
                .preferredColorScheme(.dark)
        }
    }
}
