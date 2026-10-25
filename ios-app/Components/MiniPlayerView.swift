import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var displayedTitle: String? {
        state.selectedLiveTrack?.title ?? state.selectedTrack?.title
    }

    private var displayedArtist: String? {
        state.selectedLiveTrack?.artist ?? state.selectedTrack?.artist
    }

    @ViewBuilder
    private var displayedArtwork: some View {
        if let url = state.selectedLiveTrack?.thumbnailURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                AlbumArtworkView(artwork: 0)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            AlbumArtworkView(artwork: state.selectedTrack?.artwork ?? 0)
                .frame(width: 48, height: 48)
        }
    }

    var body: some View {
        if let title = displayedTitle, let artist = displayedArtist {
            HStack(spacing: 4) {
                Button { state.showsPlayer = true } label: {
                    HStack(spacing: 10) {
                        displayedArtwork
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(MusicfyTypography.cardTitle)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            Text(artist).font(MusicfyTypography.subtitle)
                                .foregroundStyle(MusicfyTheme.secondary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Open Now Playing: \(title), \(artist)")
                .accessibilityIdentifier("player.open")
                Button { state.togglePlayback() } label: {
                    Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3).frame(width: 44, height: 48)
                }
                .disabled(!state.isLiveAudioAvailable && !state.hasDemoSelection)
                .accessibilityLabel(miniPlayerPlayLabel)
                if !dynamicTypeSize.isAccessibilitySize {
                    Button { state.step(1) } label: {
                        Image(systemName: "forward.end.fill").frame(width: 44, height: 48)
                    }
                    .disabled(state.isLiveTrackSelected)
                    .accessibilityLabel("Next demo track")
                }
            }
            .buttonStyle(.plain)
            .padding(MusicfySpacing.chromePadding)
            .frame(minHeight: MusicfySpacing.miniPlayerHeight)
            .modifier(MusicfyGlass(radius: 28))
        }
    }

    private var miniPlayerPlayLabel: String {
        if state.isLiveAudioAvailable {
            return state.player.isPlaying ? "Pause" : "Play"
        }
        if state.isLiveTrackSelected {
            return "Audio source unavailable"
        }
        return state.isPlaying ? "Pause silent demo" : "Play silent demo"
    }
}
