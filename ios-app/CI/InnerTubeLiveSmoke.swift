import Foundation

private enum InnerTubeSmokeError: LocalizedError {
    case emptyQuery
    case noResults(String)

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Pass a search query, for example: Perunggu"
        case .noResults(let query):
            return "InnerTube returned zero parsed tracks for query: \(query)"
        }
    }
}

/// An opt-in network smoke test. This compiles alongside the app's existing
/// InnerTubeSearchService and probes the real YouTube Music InnerTube endpoint.
/// It does not play or download audio.
@main
struct InnerTubeLiveSmoke {
    static func main() async throws {
        let query = CommandLine.arguments.dropFirst().joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw InnerTubeSmokeError.emptyQuery }

        let tracks = try await InnerTubeSearchService().search(query: query, diagnosticsOnEmpty: true)
        guard !tracks.isEmpty else { throw InnerTubeSmokeError.noResults(query) }

        print("PASS: InnerTube returned \(tracks.count) parsed results for '\(query)'.")
        for track in tracks.prefix(10) {
            let album = track.albumTitle.map { " · \($0)" } ?? ""
            let duration = track.durationText.map { " [\($0)]" } ?? ""
            print("- \(track.title) — \(track.artist)\(album)\(duration)")
        }
    }
}
