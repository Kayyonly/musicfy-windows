import SwiftUI

struct MusicfyGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    var radius: CGFloat
    var interactive = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(MusicfyTheme.chrome, in: shape)
                .clipShape(shape)
                .overlay { outline }
        } else {
#if compiler(>=6.2)
            // Xcode 16.4 cannot resolve Glass. Exclude new SDK names from its
            // compilation, in addition to checking runtime availability.
            if #available(iOS 26.0, *) {
                content.glassEffect(.regular.tint(MusicfyTheme.chrome.opacity(0.35)).interactive(interactive), in: shape)
                    .overlay {
                        if contrast == .increased {
                            outline
                        }
                    }
            } else {
                fallback(content)
            }
#else
            fallback(content)
#endif
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    private var outline: some View {
        shape.strokeBorder(
            MusicfyTheme.primary.opacity(contrast == .increased ? 0.55 : 0.14), lineWidth: 1)
            .allowsHitTesting(false)
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background {
                shape.fill(.ultraThinMaterial)
                shape.fill(MusicfyTheme.chrome.opacity(0.56))
            }
            .clipShape(shape)
            .overlay { outline }
            .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
    }
}

/// Groups native glass surfaces without merging the player and tab bar at rest.
/// The fallback retains the same layout on the supported iOS 17 baseline.
struct MusicfyGlassGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    @ViewBuilder var body: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            GlassEffectContainer(spacing: 4) { content }
        } else {
            content
        }
#else
        content
#endif
    }
}
