import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    var body: some View {
        ZStack {
            MusicfyTheme.background.ignoresSafeArea()
            // Keep each tab mounted so local search/scroll presentation state survives switches.
            HomeView().opacity(state.tab == .home ? 1 : 0)
                .allowsHitTesting(state.tab == .home).accessibilityHidden(state.tab != .home)
            SearchView().opacity(state.tab == .search ? 1 : 0)
                .allowsHitTesting(state.tab == .search).accessibilityHidden(state.tab != .search)
            LibraryView().opacity(state.tab == .library ? 1 : 0)
                .allowsHitTesting(state.tab == .library).accessibilityHidden(state.tab != .library)
            ProfileView().opacity(state.tab == .profile ? 1 : 0)
                .allowsHitTesting(state.tab == .profile).accessibilityHidden(state.tab != .profile)
        }
        .foregroundStyle(MusicfyTheme.primary)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                MiniPlayerView()
                MusicfyBottomNavigation()
            }
            .padding(.horizontal, MusicfySpacing.page)
            .padding(.top, 8).padding(.bottom, 8)
            .background {
                LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .sheet(isPresented: $state.showsPlayer) {
            NowPlayingView().environmentObject(state)
                .preferredColorScheme(.dark)
                .presentationDragIndicator(.visible)
        }
    }
}
