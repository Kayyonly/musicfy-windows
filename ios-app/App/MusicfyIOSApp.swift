import SwiftUI

@main
struct MusicfyIOSApp: App {
    @StateObject private var state = MusicfyDemoState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView().environmentObject(state)
                .preferredColorScheme(.dark)
                .tint(MusicfyTheme.primary)
        }
        .onChange(of: scenePhase) { _, phase in
            // Observer cleanup is explicit rather than done in deinit, which is not
            // actor-isolated. Backgrounding ends playback and releases the observers.
            if phase == .background { state.endPlayback() }
        }
    }
}
