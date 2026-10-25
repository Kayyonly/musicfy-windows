import Foundation
import Combine

enum MusicfyTab: String, CaseIterable, Identifiable {
    case home = "Home", search = "Search", library = "Library", profile = "Profile"
    var id: String { rawValue }
    var position: Double { Double(Self.allCases.firstIndex(of: self) ?? 0) }

    static func clampedPosition(_ position: Double) -> Double {
        guard position.isFinite else { return 0 }
        return min(Double(allCases.count - 1), max(0, position))
    }

    static func nearest(to position: Double) -> Self {
        allCases[Int(clampedPosition(position).rounded())]
    }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .search: return "magnifyingglass"
        case .library: return "music.note.square.stack"
        case .profile: return "waveform.path"
        }
    }
}

enum PlayerDestination: String, Identifiable {
    case queue, lyrics
    var id: String { rawValue }
}

@MainActor
final class MusicfyDemoState: ObservableObject {
    init(playbackSourceProvider: PlaybackSourceProviding = UnavailablePlaybackSourceProvider()) {
        self.playbackSourceProvider = playbackSourceProvider
#if DEBUG

        // Launch-argument routing is used only by the simulator screenshot workflow.
        // Normal app launches and Release builds keep the regular Home entry point.
        let arguments = ProcessInfo.processInfo.arguments
        if let markerIndex = arguments.firstIndex(of: "-musicfy-screenshot"),
           markerIndex + 1 < arguments.count {
            switch arguments[markerIndex + 1] {
            case "home", "home-bottom":
                tab = .home
            case "search":
                tab = .search
            case "library":
                tab = .library
            case "profile":
                tab = .profile
            case "now-playing", "queue", "lyrics":
                showsPlayer = true
            default:
                break
            }
        }
#endif
        // Re-publish player changes so views bound to this state refresh when playback moves.
        player.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    /// Ends playback deterministically and releases the player's observers. `deinit` is not
    /// actor-isolated, so cleanup is explicit rather than pushed into a deinitializer.
    /// Idempotent; safe to call from the app lifecycle.
    func endPlayback() {
        sourceLoadTask?.cancel()
        sourceLoadTask = nil
        player.invalidate()
    }

    @Published var tab: MusicfyTab = .home
    @Published var selectedID: String? = DemoCatalog.tracks.first?.id
    @Published var selectedLiveTrack: InnerTubeTrack?
    @Published var isDemoPlaying = false
    @Published var favoriteIDs: Set<String> = []
    @Published var showsPlayer = false
    @Published var progress: Double = 0.25
    @Published var searchQuery = ""
    @Published var searchHistory: [String] = []
    @Published var isShuffle = false
    @Published var isRepeat = false

    /// Native playback engine. It only plays a real, supplied audio source; without one
    /// selected live results report an unavailable state instead of pretending to play.
    let player = PlayerController()
    /// The seam an approved audio provider plugs into. The default supplies nothing.
    private let playbackSourceProvider: PlaybackSourceProviding
    /// Why the currently selected live result cannot play (nil while a source is loaded).
    @Published private(set) var playbackUnavailableReason: String?
    private var sourceLoadTask: Task<Void, Never>?


    let tracks = DemoCatalog.tracks
    var selectedTrack: MockTrack? { tracks.first { $0.id == selectedID } }
    var queue: [MockTrack] { tracks }
    var isFavorite: Bool { selectedID.map { favoriteIDs.contains($0) } ?? false }

    /// True while a silent demo catalog track is the current selection. Used to decide
    /// whether the demo transport is a valid target at all.
    var hasDemoSelection: Bool { !isLiveTrackSelected && selectedTrack != nil }

    /// True while a real audio source is loaded and the native player owns the transport.
    var isLiveAudioAvailable: Bool { selectedLiveTrack != nil && player.hasMedia }

    /// True whenever a live YouTube Music result is selected, whether or not a playable
    /// source was supplied. While this is true the silent demo catalog must not take over.
    var isLiveTrackSelected: Bool { selectedLiveTrack != nil }

    /// The transport's playing state. A selected live result owns the transport even when
    /// its audio is unavailable, so the silent demo flag is only consulted for demo tracks.
    var isPlaying: Bool { isLiveTrackSelected ? player.isPlaying : isDemoPlaying }

    func select(_ track: MockTrack) {
        sourceLoadTask?.cancel()
        selectedLiveTrack = nil
        selectedID = track.id
        progress = 0
        isDemoPlaying = false
        playbackUnavailableReason = nil
        player.load(nil)
    }

    func selectLiveTrack(_ track: InnerTubeTrack) {
        selectedLiveTrack = track
        selectedID = track.id
        progress = 0
        isDemoPlaying = false
        showsPlayer = true
        playbackUnavailableReason = nil
        loadPlaybackSource(for: track)
    }

    /// Asks the (approved) provider for a real audio source. Nothing is fabricated: when
    /// the provider has no source, the result is reported as unavailable rather than played.
    private func loadPlaybackSource(for track: InnerTubeTrack) {
        sourceLoadTask?.cancel()
        player.load(nil)
        sourceLoadTask = Task { [weak self] in
            guard let self else { return }
            defer { self.sourceLoadTask = nil }
            do {
                let source = try await self.playbackSourceProvider.source(for: track)
                guard !Task.isCancelled, self.selectedLiveTrack?.id == track.id else { return }
                if let source {
                    self.playbackUnavailableReason = nil
                    self.player.load(source)
                } else {
                    self.playbackUnavailableReason =
                        "No supported audio source for this result yet. Metadata search works; playback needs an approved provider."
                }
            } catch {
                guard !Task.isCancelled, self.selectedLiveTrack?.id == track.id else { return }
                self.playbackUnavailableReason = error.localizedDescription
            }
        }
    }

    /// Test seam: awaits the in-flight provider task so tests synchronize on real
    /// completion instead of guessing with executor yields.
    func awaitPlaybackSourceLoad() async {
        await sourceLoadTask?.value
    }

    func toggleFavorite() {
        guard let id = selectedID else { return }
        if favoriteIDs.contains(id) { favoriteIDs.remove(id) } else { favoriteIDs.insert(id) }
    }

    /// One transport entry point. A selected live result never falls through to the
    /// silent demo: when its audio source is unavailable, pressing play is a no-op.
    func togglePlayback() {
        guard !isLiveTrackSelected else {
            player.togglePlayPause()
            return
        }
        toggleDemoPlayback()
    }

    /// Silent demo transport. It is refused while a live result is selected so no caller
    /// can fake playback for a YouTube Music track.
    func toggleDemoPlayback() {
        guard !isLiveTrackSelected else { return }
        guard selectedTrack != nil else { return }
        isDemoPlaying.toggle()
    }

    /// Seeks the live player when a live result is selected, otherwise the demo progress.
    /// A selected live result never advances the silent demo progress.
    func seek(to fraction: Double) {
        let clamped = min(max(fraction, 0), 1)
        guard !isLiveTrackSelected else {
            player.seek(toFraction: clamped)
            return
        }
        progress = clamped
    }

    func step(_ offset: Int) {
        guard !tracks.isEmpty else { return }
        let index = tracks.firstIndex { $0.id == selectedID } ?? 0
        select(tracks[(index + offset % tracks.count + tracks.count) % tracks.count])
    }
    func filteredTracks(_ query: String) -> [MockTrack] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tracks }
        return tracks.filter {
            [$0.title, $0.artist, $0.albumTitle].contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    func rememberSearch() {
        let term = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searchHistory.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        searchHistory.insert(term, at: 0)
        searchHistory = Array(searchHistory.prefix(5))
    }

    /// Only the simulator harness requests this route. A screenshot is not ready
    /// until its actual destination appears (and Home's end marker is visible).
    /// Release builds and ordinary Debug launches never write capture metadata.
    func reportScreenshotReady(_ route: String, bottomVisible: Bool? = nil) {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-musicfy-screenshot"),
              index + 1 < arguments.count, arguments[index + 1] == route,
              route != "home-bottom" || bottomVisible == true,
              let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        var evidence: [String: Any] = ["route": route, "ready": true]
        if let bottomVisible { evidence["bottomVisible"] = bottomVisible }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys])
            try data.write(to: directory.appendingPathComponent("musicfy-screenshot-ready.json"), options: .atomic)
        } catch {
            print("Screenshot readiness could not be written: \(error)")
        }
#endif
    }
}
