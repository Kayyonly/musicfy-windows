import SwiftUI

struct MusicfyBottomNavigation: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @GestureState private var dragPosition: Double? = nil

    private var indicatorPosition: Double { dragPosition ?? state.tab.position }

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / CGFloat(MusicfyTab.allCases.count)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(reduceTransparency ? MusicfyTheme.opaqueSelection : MusicfyTheme.selected)
                    .overlay {
                        Capsule().strokeBorder(
                            MusicfyTheme.primary.opacity(contrast == .increased ? 0.65 : 0.16), lineWidth: 1)
                    }
                    .frame(width: max(0, cellWidth - 4), height: MusicfySpacing.navigationItemHeight)
                    .scaleEffect(x: dragPosition != nil && !reduceMotion ? 1.04 : 1)
                    .offset(x: CGFloat(indicatorPosition) * cellWidth + 2)
                    .animation(reduceMotion || dragPosition != nil ? nil : .spring(response: 0.30, dampingFraction: 0.82), value: indicatorPosition)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                HStack(spacing: 0) {
                    ForEach(MusicfyTab.allCases) { tab in
                        Button { state.tab = tab } label: {
                            Image(systemName: state.tab == tab && tab == .home ? "house.fill" : tab.symbol)
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundStyle(state.tab == tab ? MusicfyTheme.primary : MusicfyTheme.navigationSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: MusicfySpacing.navigationItemHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tab.rawValue)
                        .accessibilityAddTraits(state.tab == tab ? [.isSelected] : [])
                        .accessibilityIdentifier("tab.\(tab.rawValue.lowercased())")
                    }
                }
            }
            .contentShape(Rectangle())
            // Confined to the dock. Vertical motion never selects a tab; ordinary
            // screen scrolling and each individual Button remain independent.
            .simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .updating($dragPosition) { value, position, transaction in
                        guard position != nil || abs(value.translation.width) > abs(value.translation.height) * 1.25 else { return }
                        guard cellWidth > 0 else { return }
                        transaction.animation = nil
                        position = MusicfyTab.clampedPosition(state.tab.position + Double(value.translation.width / cellWidth))
                    }
                    .onEnded { value in
                        guard cellWidth > 0,
                              abs(value.translation.width) > abs(value.translation.height) * 1.25 else { return }
                        let position = state.tab.position + Double(value.translation.width / cellWidth)
                        state.tab = MusicfyTab.nearest(to: position)
                    }
            )
        }
        .frame(height: MusicfySpacing.navigationItemHeight)
        .padding(MusicfySpacing.chromePadding)
        .modifier(MusicfyGlass(radius: MusicfySpacing.navigationHeight / 2, interactive: true))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
}
