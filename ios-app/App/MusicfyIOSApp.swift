import SwiftUI

@main
struct MusicfyIOSApp: App {
    @StateObject private var state = MusicfyDemoState()
    var body: some Scene {
        WindowGroup {
            AppRootView().environmentObject(state)
                .preferredColorScheme(.dark)
                .tint(MusicfyTheme.primary)
        }
    }
}
