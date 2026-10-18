import SwiftUI

struct AlbumCard: View {
    let album: MockAlbum
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 137
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                AlbumArtworkView(artwork: album.artwork).frame(width: width, height: width)
                Text(album.title).font(MusicfyTypography.cardTitle).lineLimit(2)
                Text(album.artist).font(MusicfyTypography.subtitle)
                    .foregroundStyle(MusicfyTheme.secondary).lineLimit(2)
            }
            .frame(width: width, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(album.title), \(album.artist)")
        .accessibilityHint("Selects this track for the silent UI demo")
    }
}
