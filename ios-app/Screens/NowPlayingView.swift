import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var path: [PlayerDestination]

    init() {
        var initialPath: [PlayerDestination] = []
#if DEBUG
        // Queue/Lyrics are reached normally from the player. This path is seeded only
        // when CI explicitly requests a screenshot of one of those destinations.
        let arguments = ProcessInfo.processInfo.arguments
        if let markerIndex = arguments.firstIndex(of: "-musicfy-screenshot"),
           markerIndex + 1 < arguments.count {
            switch arguments[markerIndex + 1] {
            case "queue": initialPath = [.queue]
            case "lyrics": initialPath = [.lyrics]
            default: break
            }
        }
#endif
        _path = State(initialValue: initialPath)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                playerBackdrop

                ScrollView {
                    VStack(spacing: MusicfySpacing.section) {
                        artwork
                        trackInformation
                        progressControl
                        transportControls
                        utilityControls
                    }
                    .padding(.horizontal, MusicfySpacing.page)
                    .padding(.top, MusicfySpacing.home)
                    .padding(.bottom, MusicfySpacing.page)
                }
                .scrollIndicators(.hidden)
            }
            .background(MusicfyTheme.background.ignoresSafeArea())
            #if DEBUG
            .accessibilityIdentifier("destination.now-playing")
            .onAppear { state.reportScreenshotReady("now-playing") }
            #endif
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close player")
                }
            }
            .navigationDestination(for: PlayerDestination.self) { destination in
                switch destination {
                case .queue: QueueView()
                case .lyrics: LyricsView()
                }
            }
        }
    }

    @ViewBuilder
    private var playerBackdrop: some View {
        if let track = state.selectedTrack {
            ZStack {
                LinearGradient(
                    colors: MusicfyTheme.artworkColors(track.artwork),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(reduceTransparency ? 0.12 : 0.28)

                if !reduceTransparency {
                    AlbumArtworkView(artwork: track.artwork)
                        .blur(radius: 52)
                        .opacity(0.22)
                        .scaleEffect(1.18)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var artwork: some View {
        Group {
            if let liveTrack = state.selectedLiveTrack {
                AsyncImage(url: liveTrack.thumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    AlbumArtworkView(artwork: 0)
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous)
                        .stroke(MusicfyTheme.primary.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
                .accessibilityLabel("Artwork for \(liveTrack.title)")
            } else if let track = state.selectedTrack {
                AlbumArtworkView(artwork: track.artwork)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous)
                            .stroke(MusicfyTheme.primary.opacity(0.12), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 24, y: 12)
                    .accessibilityLabel("Artwork for \(track.title)")
            } else {
                unavailableCard
            }
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    private var trackInformation: some View {
        HStack(alignment: .center, spacing: MusicfySpacing.cardGap) {
            VStack(alignment: .leading, spacing: 6) {
                Text(state.selectedLiveTrack?.title ?? state.selectedTrack?.title ?? "Nothing selected")
                    .font(MusicfyTypography.pageTitle)
                    .foregroundStyle(MusicfyTheme.primary)
                    .lineLimit(2)
                Text(
                    state.selectedLiveTrack.map { liveTrack in
                        liveTrack.albumTitle.map { "\(liveTrack.artist) · \($0)" } ?? liveTrack.artist
                    }
                    ?? state.selectedTrack.map { "\($0.artist) · \($0.albumTitle)" }
                    ?? "Choose a track to begin"
                )
                .font(MusicfyTypography.subtitle)
                .foregroundStyle(MusicfyTheme.secondary)
                .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button { state.toggleFavorite() } label: {
                Image(systemName: state.isFavorite ? "heart.fill" : "heart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(state.isFavorite ? MusicfyTheme.primary : MusicfyTheme.secondary)
                    .frame(width: 44, height: 44)
                    .background(MusicfyTheme.field, in: Circle())
            }
            .disabled(state.selectedID == nil)
            .accessibilityLabel(state.isFavorite ? "Remove from favorites" : "Add to favorites")
        }
    }

    private var progressControl: some View {
        VStack(spacing: 8) {
            Slider(value: progressBinding, in: 0...1)
                .tint(MusicfyTheme.primary)
                .disabled(state.selectedTrack == nil || state.selectedLiveTrack != nil)
                .accessibilityLabel("Playback progress preview")

            HStack {
                Text(timestamp(for: state.progress))
                Spacer()
                Text(state.selectedLiveTrack?.durationText ?? state.selectedTrack?.durationLabel ?? "0:00")
            }
            .font(MusicfyTypography.subtitle)
            .foregroundStyle(MusicfyTheme.secondary)
            .monospacedDigit()
        }
    }

    private var transportControls: some View {
        HStack(spacing: 18) {
            controlButton(symbol: "backward.fill", label: "Previous track", size: 46) { state.step(-1) }
                .disabled(state.selectedLiveTrack != nil)
            controlButton(symbol: state.isDemoPlaying ? "pause.fill" : "play.fill", label: state.selectedLiveTrack != nil ? "Playback source not connected" : (state.isDemoPlaying ? "Pause silent demo" : "Play silent demo"), size: 68) {
                state.toggleDemoPlayback()
            }
            .disabled(state.selectedLiveTrack != nil)
            controlButton(symbol: "forward.fill", label: "Next track", size: 46) { state.step(1) }
                .disabled(state.selectedLiveTrack != nil)
        }
        .frame(maxWidth: .infinity)
    }

    private var utilityControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { state.isShuffle.toggle() } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .font(MusicfyTypography.subtitle.weight(.semibold))
                        .foregroundStyle(state.isShuffle ? MusicfyTheme.primary : MusicfyTheme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .modifier(MusicfyGlass(radius: 14))
                }
                .accessibilityAddTraits(state.isShuffle ? .isSelected : [])
                .accessibilityValue(state.isShuffle ? "On" : "Off")
                Button { state.isRepeat.toggle() } label: {
                    Label("Repeat", systemImage: "repeat")
                        .font(MusicfyTypography.subtitle.weight(.semibold))
                        .foregroundStyle(state.isRepeat ? MusicfyTheme.primary : MusicfyTheme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .modifier(MusicfyGlass(radius: 14))
                }
                .accessibilityAddTraits(state.isRepeat ? .isSelected : [])
                .accessibilityValue(state.isRepeat ? "On" : "Off")
            }

            HStack(spacing: 12) {
                navigationLink(.queue, title: "Queue", symbol: "list.bullet")
                navigationLink(.lyrics, title: "Lyrics", symbol: "quote.bubble")
            }

            Text(state.selectedLiveTrack == nil ? "UI demo · no audio" : "Native audio playback not connected yet")
                .font(MusicfyTypography.subtitle)
                .foregroundStyle(MusicfyTheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .accessibilityLabel(state.selectedLiveTrack == nil ? "UI demo, no audio" : "Native audio playback is not connected yet")
        }
    }

    private func navigationLink(_ destination: PlayerDestination, title: String, symbol: String) -> some View {
        NavigationLink(value: destination) {
            Label(title, systemImage: symbol)
                .font(MusicfyTypography.subtitle.weight(.semibold))
                .foregroundStyle(MusicfyTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .modifier(MusicfyGlass(radius: 14))
        }
    }

    private func controlButton(symbol: String, label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size == 68 ? 25 : 18, weight: .semibold))
                .foregroundStyle(MusicfyTheme.primary)
                .frame(width: size, height: size)
                .background(size == 68 ? MusicfyTheme.primary.opacity(0.12) : MusicfyTheme.field, in: Circle())
        }
        .accessibilityLabel(label)
    }

    private var unavailableCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.largeTitle)
            Text("No track selected")
                .font(MusicfyTypography.cardTitle)
        }
        .foregroundStyle(MusicfyTheme.secondary)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(MusicfyTheme.surface, in: RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous))
    }

    private var progressBinding: Binding<Double> {
        Binding(get: { state.progress }, set: { state.progress = min(max($0, 0), 1) })
    }

    private func timestamp(for progress: Double) -> String {
        let seconds = Int((state.selectedTrack?.duration ?? 0) * min(max(progress, 0), 1))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
