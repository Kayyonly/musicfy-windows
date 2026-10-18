import SwiftUI

struct MoodCard: View {
    let title: String
    let artwork: Int
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title).font(MusicfyTypography.cardTitle).lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    AlbumArtworkView(artwork: artwork).frame(width: 46, height: 54)
                        .rotationEffect(.degrees(-12))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(MusicfyTheme.artworkColors(artwork)[0].opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint("Shows a local demonstration selection")
    }
}
