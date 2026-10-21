import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var searchIsFocused: Bool
    @State private var query = ""
    @State private var showsDemoAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MusicfySpacing.section) {
                PageHeader(title: "Library")

                MusicfySearchField(title: "Search library", text: $query, prompt: "Search your library", focus: $searchIsFocused)
                    .accessibilityIdentifier("library.search")

                providerBanner
                localMusicCard
                emptyState
            }
            .padding(.horizontal, MusicfySpacing.page)
            .padding(.top, 8)
            .padding(.bottom, MusicfySpacing.page)
        }
        .scrollContentBackground(.hidden)
        .background(MusicfyTheme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        #if DEBUG
        .onAppear { state.reportScreenshotReady("library") }
        #endif
        .onChange(of: state.tab) { _, newTab in
            if newTab != .library {
                searchIsFocused = false
            }
        }
        .alert(alertTitle, isPresented: $showsDemoAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var providerBanner: some View {
        Button {
            present(title: "Provider unavailable", message: "Provider connections and catalog imports are unavailable in this local UI demo.")
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(["music.note", "waveform", "music.quarternote.3", "music.note.list", "waveform.path.ecg"], id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(MusicfyTheme.primary.opacity(0.9))
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sync and add your music")
                        .font(MusicfyTypography.sectionTitle)
                        .foregroundStyle(MusicfyTheme.primary)
                    Text("Demo only • Provider connections and imports are unavailable.")
                        .font(MusicfyTypography.subtitle)
                        .foregroundStyle(MusicfyTheme.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 172, alignment: .leading)
            .background(MusicfyTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sync and add your music. Demo only. Provider connections and imports are unavailable.")
    }

    private var localMusicCard: some View {
        Button {
            present(title: "Add local music", message: "Adding files is unavailable in this UI prototype.")
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "internaldrive")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(MusicfyTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(MusicfyTheme.selected, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("From your device")
                        .font(MusicfyTypography.cardTitle)
                        .foregroundStyle(MusicfyTheme.primary)
                    Text("Add local music")
                        .font(MusicfyTypography.subtitle)
                        .foregroundStyle(MusicfyTheme.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(MusicfyTheme.primary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .background(MusicfyTheme.field, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("From your device. Add local music.")
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.title2.weight(.medium))
                .foregroundStyle(MusicfyTheme.secondary)
                .accessibilityHidden(true)
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nothing to show here" : "No local results for “\(query)”")
                .font(MusicfyTypography.cardTitle)
                .foregroundStyle(MusicfyTheme.primary)
                .multilineTextAlignment(.center)
            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your local library is empty." : "There are no matching local tracks.")
                .font(MusicfyTypography.subtitle)
                .foregroundStyle(MusicfyTheme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 32 : 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your local library is empty" : "No local results for \(query)")
    }

    private func present(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showsDemoAlert = true
    }
}
