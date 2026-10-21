import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        if let track = state.selectedTrack {
            HStack(spacing: 4) {
                Button { state.showsPlayer = true } label: {
                    HStack(spacing: 10) {
                        AlbumArtworkView(artwork: track.artwork).frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title).font(MusicfyTypography.cardTitle)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            Text(track.artist).font(MusicfyTypography.subtitle)
                                .foregroundStyle(MusicfyTheme.secondary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Open Now Playing: \(track.title), \(track.artist)")
                .accessibilityIdentifier("player.open")
                Button { state.toggleDemoPlayback() } label: {
                    Image(systemName: state.isDemoPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).frame(width: 44, height: 48)
                }
                .accessibilityLabel(state.isDemoPlaying ? "Pause silent demo" : "Play silent demo")
                if !dynamicTypeSize.isAccessibilitySize {
                    Button { state.step(1) } label: {
                        Image(systemName: "forward.end.fill").frame(width: 44, height: 48)
                    }.accessibilityLabel("Next demo track")
                }
            }
            .buttonStyle(.plain)
            .padding(MusicfySpacing.chromePadding)
            .frame(minHeight: MusicfySpacing.miniPlayerHeight)
            .modifier(MusicfyGlass(radius: 28))
        }
    }
}
