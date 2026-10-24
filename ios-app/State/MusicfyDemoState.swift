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
    init() {
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

    let tracks = DemoCatalog.tracks
    var selectedTrack: MockTrack? { tracks.first { $0.id == selectedID } }
    var queue: [MockTrack] { tracks }
    var isFavorite: Bool { selectedID.map { favoriteIDs.contains($0) } ?? false }

    func select(_ track: MockTrack) {
        selectedLiveTrack = nil
        selectedID = track.id
        progress = 0
        isDemoPlaying = false
    }

    func selectLiveTrack(_ track: InnerTubeTrack) {
        selectedLiveTrack = track
        selectedID = track.id
        progress = 0
        isDemoPlaying = false
        showsPlayer = true
    }
    func toggleFavorite() {
        guard let id = selectedID else { return }
        if favoriteIDs.contains(id) { favoriteIDs.remove(id) } else { favoriteIDs.insert(id) }
    }
    func toggleDemoPlayback() {
        guard selectedTrack != nil else { return }
        isDemoPlaying.toggle()
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
