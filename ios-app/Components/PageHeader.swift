import SwiftUI

struct PageHeader: View {
    let title: String
    @EnvironmentObject private var state: MusicfyDemoState
    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(MusicfyTypography.pageTitle).tracking(-1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button { state.tab = .profile } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Open demo profile")
        }
    }
}
