import SwiftUI

struct LyricsView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var activeLine = 0

    private let lyrics = MockLyrics.demo

    var body: some View {
        ZStack {
            backdrop

            ScrollView {
                VStack(alignment: .leading, spacing: MusicfySpacing.section) {
                    header
                    lyricsCard
                }
                .padding(.horizontal, MusicfySpacing.page)
                .padding(.top, MusicfySpacing.home)
                .padding(.bottom, MusicfySpacing.page)
            }
            .scrollIndicators(.hidden)
        }
        .background(MusicfyTheme.background.ignoresSafeArea())
        .navigationTitle("Lyrics")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var backdrop: some View {
        if let track = state.selectedTrack {
            ZStack {
                LinearGradient(
                    colors: MusicfyTheme.artworkColors(track.artwork),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(reduceTransparency ? 0.10 : 0.20)
                if !reduceTransparency {
                    AlbumArtworkView(artwork: track.artwork)
                        .blur(radius: 58)
                        .opacity(0.15)
                        .scaleEffect(1.2)
                }
            }
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.selectedTrack?.title ?? "Lyrics")
                .font(MusicfyTypography.pageTitle)
                .foregroundStyle(MusicfyTheme.primary)
                .lineLimit(2)
            Text("Original demo · unsynced")
                .font(MusicfyTypography.subtitle.weight(.semibold))
                .foregroundStyle(MusicfyTheme.secondary)
            Text("Tap a line to highlight it. These lines are original demonstration text and are not synced to audio.")
                .font(MusicfyTypography.subtitle)
                .foregroundStyle(MusicfyTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lyricsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lyrics.lines.enumerated()), id: \.offset) { index, line in
                Button {
                    activeLine = index
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index == activeLine ? MusicfyTheme.primary : Color.clear)
                            .frame(width: 4)
                        Text(line)
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(MusicfyTheme.primary)
                            .opacity(index == activeLine ? 1 : 0.70)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 60)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Lyric line \(index + 1): \(line)")
                .accessibilityAddTraits(index == activeLine ? .isSelected : [])
            }
        }
        .padding(.horizontal, MusicfySpacing.cardGap)
        .padding(.vertical, 12)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: MusicfySpacing.radius).fill(MusicfyTheme.surface)
            } else {
                RoundedRectangle(cornerRadius: MusicfySpacing.radius).fill(.ultraThinMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous)
                .stroke(MusicfyTheme.divider.opacity(0.55), lineWidth: 1)
        }
    }
}
