import SwiftUI

struct MusicfyBottomNavigation: View {
    @EnvironmentObject private var state: MusicfyDemoState
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MusicfyTab.allCases) { tab in
                Button { state.tab = tab } label: {
                    Image(systemName: state.tab == tab && tab == .home ? "house.fill" : tab.symbol)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(state.tab == tab ? .white : .white.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(state.tab == tab ? MusicfyTheme.selected : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(state.tab == tab ? [.isSelected] : [])
                .accessibilityIdentifier("tab.\(tab.rawValue.lowercased())")
            }
        }
        .padding(8)
        .frame(minHeight: MusicfySpacing.navigationHeight)
        .modifier(MusicfyGlass(radius: 32))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
    }
}
