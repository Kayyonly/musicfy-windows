import SwiftUI

struct AlbumArtworkView: View {
    let artwork: Int
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: MusicfyTheme.artworkColors(artwork), startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: proxy.size.width * 0.08)
                    .frame(width: proxy.size.width * 0.72, height: proxy.size.width * 0.72)
                    .offset(x: proxy.size.width * 0.18, y: proxy.size.height * 0.18)
                Image(systemName: "waveform.path")
                    .font(.system(size: max(16, proxy.size.width * 0.28), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityHidden(true)
    }
}
