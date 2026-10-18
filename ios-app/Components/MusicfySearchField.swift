import SwiftUI

struct MusicfySearchField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    var focus: FocusState<Bool>.Binding? = nil
    @FocusState private var fallbackFocus: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(MusicfyTheme.secondary)
            TextField(title, text: $text, prompt: Text(prompt).foregroundColor(MusicfyTheme.secondary))
                .focused(focus ?? $fallbackFocus)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel(title)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 16).padding(.trailing, 4)
        .frame(minHeight: 48)
        .background(MusicfyTheme.field, in: Capsule())
    }
}
