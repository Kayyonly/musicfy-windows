import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isSearchFocused: Bool
    @State private var moodNotice: String?
    @State private var liveResults: [InnerTubeTrack] = []
    @State private var isSearchingLiveCatalog = false
    @State private var liveSearchError: String?
    private let searchService = InnerTubeSearchService()

    private let moods = ["Chill", "Commute", "Energize", "Feel good", "Focus", "Gaming", "Party", "Romance", "Sad", "Sleep"]
    private var query: String { state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MusicfySpacing.section) {
                PageHeader(title: "Search")
                Text("Search real YouTube Music metadata").font(MusicfyTypography.subtitle).foregroundStyle(MusicfyTheme.secondary)
                MusicfySearchField(title: "Search YouTube Music", text: $state.searchQuery, prompt: "Search songs, artists, albums...", focus: $isSearchFocused)
                    .onSubmit { state.rememberSearch() }
                if query.isEmpty {
                    if isSearchFocused && !state.searchHistory.isEmpty { history }
                    browse
                } else {
                    results
                }
            }
            .padding(.horizontal, MusicfySpacing.page)
            .padding(.top, 8)
            .padding(.bottom, MusicfySpacing.page)
        }
        .scrollContentBackground(.hidden)
        .background(MusicfyTheme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .task(id: query) { await searchLiveCatalog(for: query) }
        #if DEBUG
        .onAppear { state.reportScreenshotReady("search") }
        #endif
        .onChange(of: isSearchFocused) { _, focused in if !focused { state.rememberSearch() } }
        .onChange(of: state.tab) { _, tab in if tab != .search { isSearchFocused = false } }
        .alert("Mood browsing is visual only", isPresented: Binding(get: { moodNotice != nil }, set: { if !$0 { moodNotice = nil } })) {
            Button("OK", role: .cancel) { moodNotice = nil }
        } message: {
            Text(moodNotice ?? "Search the local catalog by song title, artist, or album.")
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Recent searches")
            ForEach(state.searchHistory, id: \.self) { term in
                Button { state.searchQuery = term } label: {
                    Label(term, systemImage: "clock").frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: MusicfySpacing.minimumTouch)
                }.buttonStyle(.plain).foregroundStyle(MusicfyTheme.secondary)
            }
        }
    }

    private var browse: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Moods & moments", subtitle: "Local UI demo")
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible(), spacing: MusicfySpacing.cardGap), GridItem(.flexible(), spacing: MusicfySpacing.cardGap)], spacing: MusicfySpacing.cardGap) {
                ForEach(Array(moods.enumerated()), id: \.element) { index, mood in
                    MoodCard(title: mood, artwork: index) { moodNotice = "\(mood) — mood browsing is visual only. Search the local catalog by song title, artist, or album." }
                }
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: MusicfySpacing.section) {
            SectionHeader(title: "YouTube Music results", subtitle: "Live catalog metadata")
            if isSearchingLiveCatalog {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching YouTube Music…").font(MusicfyTypography.subtitle)
                }
                .foregroundStyle(MusicfyTheme.secondary)
                .frame(maxWidth: .infinity, minHeight: 88)
            } else if let liveSearchError {
                ContentUnavailableView(
                    "Search unavailable",
                    systemImage: "wifi.exclamationmark",
                    description: Text(liveSearchError)
                )
                .foregroundStyle(MusicfyTheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MusicfySpacing.page)
            } else if liveResults.isEmpty {
                ContentUnavailableView(
                    "No YouTube Music results",
                    systemImage: "magnifyingglass",
                    description: Text("Try another song, artist, or album name.")
                )
                .foregroundStyle(MusicfyTheme.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, MusicfySpacing.page)
            } else {
                SectionHeader(title: "Songs", subtitle: "\(liveResults.count) metadata results")
                LazyVStack(spacing: 4) {
                    ForEach(liveResults) { track in
                        Button {
                            state.rememberSearch()
                            state.selectLiveTrack(track)
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: track.thumbnailURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    AlbumArtworkView(artwork: 0)
                                }
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .font(MusicfyTypography.cardTitle)
                                        .foregroundStyle(MusicfyTheme.primary)
                                        .lineLimit(2)
                                    Text(track.artist)
                                        .font(MusicfyTypography.subtitle)
                                        .foregroundStyle(MusicfyTheme.secondary)
                                        .lineLimit(1)
                                    if let albumTitle = track.albumTitle, !albumTitle.isEmpty {
                                        Text(albumTitle)
                                            .font(.caption)
                                            .foregroundStyle(MusicfyTheme.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if let durationText = track.durationText {
                                    Text(durationText)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(MusicfyTheme.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Now Playing: \(track.title), \(track.artist)")
                    }
                }
                Text("Metadata only in this step; audio playback is not connected yet.")
                    .font(.caption)
                    .foregroundStyle(MusicfyTheme.secondary)
                    .padding(.top, 8)
            }
        }
    }

    private func searchLiveCatalog(for rawQuery: String) async {
        let term = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2 else {
            liveResults = []
            liveSearchError = nil
            isSearchingLiveCatalog = false
            return
        }

        isSearchingLiveCatalog = true
        liveSearchError = nil
        do {
            try await Task.sleep(nanoseconds: 350_000_000)
            let results = try await searchService.search(query: term)
            try Task.checkCancellation()
            liveResults = results
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            liveResults = []
            liveSearchError = error.localizedDescription
        }
        isSearchingLiveCatalog = false
    }

}
