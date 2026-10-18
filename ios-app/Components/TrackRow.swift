import SwiftUI

struct TrackRow: View {
    let track: MockTrack
    var rank: Int? = nil
    var isSelected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let rank {
                    Text(rank.formatted()).font(.title3.bold()).frame(minWidth: 22)
                }
                AlbumArtworkView(artwork: track.artwork).frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title).font(MusicfyTypography.cardTitle).lineLimit(2)
                    Text(track.artist).font(MusicfyTypography.subtitle)
                        .foregroundStyle(MusicfyTheme.secondary).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").accessibilityHidden(true)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(track.title), \(track.artist)")
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint("Selects this track for the silent UI demo")
    }
}
