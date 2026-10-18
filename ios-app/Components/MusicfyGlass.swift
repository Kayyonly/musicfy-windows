import SwiftUI

struct MusicfyGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: radius).fill(MusicfyTheme.chrome)
                } else {
                    RoundedRectangle(cornerRadius: radius).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: radius).fill(MusicfyTheme.chrome.opacity(0.65))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.1), lineWidth: 1) }
    }
}
