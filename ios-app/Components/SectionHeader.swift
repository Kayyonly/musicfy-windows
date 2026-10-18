import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let subtitle {
                Text(subtitle).font(MusicfyTypography.subtitle).foregroundStyle(MusicfyTheme.secondary)
            }
            Text(title).font(MusicfyTypography.sectionTitle).tracking(-0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}
