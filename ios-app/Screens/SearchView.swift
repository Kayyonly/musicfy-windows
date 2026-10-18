import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @FocusState private var isSearchFocused: Bool
    @State private var category: SearchCategory = .all
    @State private var moodNotice: String?

    private enum SearchCategory: String, CaseIterable, Identifiable {
        case all = "All", music = "Music", artist = "Artist", album = "Album"
        var id: String { rawValue }
    }

    private let moods = ["Chill", "Commute", "Energize", "Feel good", "Focus", "Gaming", "Party", "Romance", "Sad", "Sleep"]
    private var query: String { state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var matches: [MockTrack] {
        guard !query.isEmpty else { return [] }
        return state.tracks.filter { track in
            switch category {
            case .all, .music: return [track.title, track.artist, track.albumTitle].contains { $0.localizedCaseInsensitiveContains(query) }
            case .artist: return track.artist.localizedCaseInsensitiveContains(query)
            case .album: return track.albumTitle.localizedCaseInsensitiveContains(query)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MusicfySpacing.section) {
                PageHeader(title: "Search")
                Text("Local UI demo").font(MusicfyTypography.subtitle).foregroundStyle(MusicfyTheme.secondary)
                MusicfySearchField(title: "Search local demo catalog", text: $state.searchQuery, prompt: "Search tracks, artists, albums...", focus: $isSearchFocused)
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
            .padding(.bottom, MusicfySpacing.home)
        }
        .scrollContentBackground(.hidden)
        .background(MusicfyTheme.background.ignoresSafeArea())
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
            LazyVGrid(columns: [GridItem(.flexible(), spacing: MusicfySpacing.cardGap), GridItem(.flexible(), spacing: MusicfySpacing.cardGap)], spacing: MusicfySpacing.cardGap) {
                ForEach(Array(moods.enumerated()), id: \.element) { index, mood in
                    MoodCard(title: mood, artwork: index) { moodNotice = "\(mood) — mood browsing is visual only. Search the local catalog by song title, artist, or album." }
                }
            }
        }
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(SearchCategory.allCases) { item in
                        Button { category = item } label: {
                            Text(item.rawValue).font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: MusicfySpacing.minimumTouch)
                                .background(category == item ? MusicfyTheme.primary : MusicfyTheme.field, in: Capsule())
                                .foregroundStyle(category == item ? MusicfyTheme.background : MusicfyTheme.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(category == item ? .isSelected : [])
                        .accessibilityLabel("Filter by \(item.rawValue)")
                    }
                }
            }
            SectionHeader(title: "Top Results", subtitle: "Matching local metadata only")
            if let top = matches.first {
                Button {
                    state.select(top)
                    state.showsPlayer = true
                } label: {
                    HStack(spacing: 16) {
                        AlbumArtworkView(artwork: top.artwork).frame(width: 144, height: 144)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("TOP RESULT").font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(MusicfyTheme.secondary)
                            Text(top.title).font(MusicfyTypography.cardTitle).foregroundStyle(MusicfyTheme.primary).lineLimit(2)
                            Text(top.artist).font(MusicfyTypography.subtitle).foregroundStyle(MusicfyTheme.secondary).lineLimit(2)
                            Image(systemName: "play.circle.fill").font(.title).foregroundStyle(MusicfyTheme.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(MusicfyTheme.artworkColors(top.artwork)[0].opacity(0.42), in: RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play demo preview for \(top.title) by \(top.artist)")
                .accessibilityHint("Opens the local now playing demo; no audio is played")
            }
            SectionHeader(title: "Songs", subtitle: category == .all || category == .music ? "Matching title, artist, or album metadata" : "Matching \(category.rawValue.lowercased()) metadata")
            if matches.isEmpty {
                ContentUnavailableView("No local matches", systemImage: "magnifyingglass", description: Text("Try a title, artist, or album from this demo catalog."))
                    .foregroundStyle(MusicfyTheme.secondary)
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(matches) { track in
                        TrackRow(track: track, isSelected: state.selectedID == track.id) { state.select(track) }
                    }
                }
            }
        }
    }
}
