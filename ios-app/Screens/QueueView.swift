import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var state: MusicfyDemoState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MusicfySpacing.section) {
                nowPlayingSection
                continuePlayingSection
            }
            .padding(.horizontal, MusicfySpacing.page)
            .padding(.top, MusicfySpacing.home)
            .padding(.bottom, MusicfySpacing.page)
        }
        .scrollIndicators(.hidden)
        .background(MusicfyTheme.background.ignoresSafeArea())
        #if DEBUG
        .accessibilityIdentifier("destination.queue")
        .onAppear { state.reportScreenshotReady("queue") }
        #endif
        .navigationTitle("Queue")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var nowPlayingSection: some View {
        if let track = state.selectedTrack {
            VStack(alignment: .leading, spacing: MusicfySpacing.cardGap) {
                SectionHeader(title: "Now Playing", subtitle: "Selected for this demo")
                queueRow(track, selected: true)
            }
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private var continuePlayingSection: some View {
        let remaining = state.queue.filter { $0.id != state.selectedID }
        VStack(alignment: .leading, spacing: MusicfySpacing.cardGap) {
            SectionHeader(title: "Continue Playing", subtitle: remaining.isEmpty ? nil : "Choose a track to preview")
            if remaining.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(remaining.enumerated()), id: \.element.id) { index, track in
                        queueRow(track, selected: false, rank: index + 1)
                    }
                }
            }
        }
    }

    private func queueRow(_ track: MockTrack, selected: Bool, rank: Int? = nil) -> some View {
        HStack(spacing: 10) {
            TrackRow(track: track, rank: rank, isSelected: selected) {
                state.select(track)
            }
            .frame(minHeight: 60)

            if selected {
                Image(systemName: state.isDemoPlaying ? "waveform" : "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MusicfyTheme.primary)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(state.isDemoPlaying ? "Silent demo active" : "Selected")
            }
        }
        .padding(.trailing, selected ? 4 : 0)
        .background(selected ? MusicfyTheme.field : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityValue(selected ? "Selected" : "")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.badge.minus")
                .font(.title2)
                .foregroundStyle(MusicfyTheme.secondary)
            Text("Your queue is empty")
                .font(MusicfyTypography.cardTitle)
                .foregroundStyle(MusicfyTheme.primary)
            Text("Select a demo track from Home or Search.")
                .font(MusicfyTypography.subtitle)
                .foregroundStyle(MusicfyTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MusicfySpacing.home)
        .padding(.horizontal, MusicfySpacing.cardGap)
        .background(MusicfyTheme.surface, in: RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous))
    }
}
