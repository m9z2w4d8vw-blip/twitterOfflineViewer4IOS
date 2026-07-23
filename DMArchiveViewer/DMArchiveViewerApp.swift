import SwiftUI

@main
struct DMArchiveViewerApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.dark.rawValue

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .preferredColorScheme(appearanceMode == AppearanceMode.light.rawValue ? .light : .dark)
        }
    }
}
