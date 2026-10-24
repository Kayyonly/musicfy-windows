import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Minimal native client for YouTube Music's private InnerTube search endpoint.
/// InnerTube is not a stable public API; response structure/client versions can change.
struct InnerTubeTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let albumTitle: String?
    let durationText: String?
    let thumbnailURL: URL?
}

enum InnerTubeSearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build the YouTube Music search URL."
        case .invalidResponse:
            return "YouTube Music returned an unexpected search response."
        case .httpStatus(let code):
            return "YouTube Music search failed (HTTP \(code))."
        }
    }
}

struct InnerTubeSearchService {
    private let session: URLSession
    // Kept aligned with the WEB_REMIX client version in Musicfy Android's InnerTube provider.
    private let clientVersion = "1.20260707.12.00"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String) async throws -> [InnerTubeTrack] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        var components = URLComponents(string: "https://music.youtube.com/youtubei/v1/search")
        components?.queryItems = [URLQueryItem(name: "prettyPrint", value: "false")]
        guard let url = components?.url else { throw InnerTubeSearchError.invalidURL }

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": clientVersion,
                    "hl": "en",
                    "gl": "ID"
                ]
            ],
            "query": trimmedQuery
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(clientVersion, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue("1", forHTTPHeaderField: "X-Goog-Api-Format-Version")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) Gecko/20100101 Firefox/140.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw InnerTubeSearchError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw InnerTubeSearchError.httpStatus(response.statusCode)
        }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw InnerTubeSearchError.invalidResponse
        }
        return Self.parseTracks(from: root)
    }

    /// Kept internal so fixture-based XCTest can verify the parser without network access.
    static func parseTracks(from root: [String: Any]) -> [InnerTubeTrack] {
        guard
            let contents = root["contents"] as? [String: Any],
            let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
            let tabs = tabbed["tabs"] as? [[String: Any]],
            let tab = tabs.first?["tabRenderer"] as? [String: Any],
            let tabContent = tab["content"] as? [String: Any],
            let sectionList = tabContent["sectionListRenderer"] as? [String: Any],
            let sections = sectionList["contents"] as? [[String: Any]]
        else { return [] }

        var tracks: [InnerTubeTrack] = []
        var seenIDs = Set<String>()
        for section in sections {
            guard
                let shelf = section["musicShelfRenderer"] as? [String: Any],
                let items = shelf["contents"] as? [[String: Any]]
            else { continue }

            for item in items {
                guard
                    let renderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                    let columns = renderer["flexColumns"] as? [[String: Any]],
                    let firstColumn = columns.first,
                    let title = Self.runs(in: firstColumn).compactMap({ $0["text"] as? String }).joined().nilIfEmpty
                else { continue }
                let videoID = (renderer["playlistItemData"] as? [String: Any])?["videoId"] as? String
                    ?? (((renderer["navigationEndpoint"] as? [String: Any])?["watchEndpoint"] as? [String: Any])?["videoId"] as? String)
                guard let videoID, !videoID.isEmpty, !seenIDs.contains(videoID) else { continue }

                let allRuns = columns.flatMap { Self.runs(in: $0) }
                var uniqueArtistNames: [String] = []
                for run in allRuns {
                    guard
                        let text = run["text"] as? String,
                        let endpoint = run["navigationEndpoint"] as? [String: Any],
                        let browse = endpoint["browseEndpoint"] as? [String: Any],
                        let browseID = browse["browseId"] as? String,
                        browseID.hasPrefix("UC")
                    else { continue }
                    if !uniqueArtistNames.contains(text) { uniqueArtistNames.append(text) }
                }
                let fallbackArtist = columns.dropFirst().first
                    .flatMap { Self.runs(in: $0).compactMap { $0["text"] as? String }.first }
                    .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }
                let artist = uniqueArtistNames.isEmpty ? (fallbackArtist ?? "Unknown artist") : uniqueArtistNames.joined(separator: ", ")

                let albumTitle = allRuns.first { run in
                    guard
                        run["text"] is String,
                        let endpoint = run["navigationEndpoint"] as? [String: Any],
                        let browse = endpoint["browseEndpoint"] as? [String: Any],
                        let browseID = browse["browseId"] as? String
                    else { return false }
                    return browseID.hasPrefix("MPRE") || browseID.hasPrefix("OLAK")
                }?["text"] as? String

                let durationText = allRuns.compactMap { $0["text"] as? String }.first {
                    $0.range(of: #"^\d{1,2}:\d{2}(?::\d{2})?$"#, options: .regularExpression) != nil
                }
                let thumbnailContainer = ((renderer["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any])
                let thumbnailObject = thumbnailContainer?["thumbnail"] as? [String: Any]
                let thumbnailString = (thumbnailObject?["thumbnails"] as? [[String: Any]])?.last?["url"] as? String
                let thumbnailURL = thumbnailString.flatMap(URL.init(string:))

                tracks.append(InnerTubeTrack(
                    id: videoID,
                    title: title,
                    artist: artist,
                    albumTitle: albumTitle,
                    durationText: durationText,
                    thumbnailURL: thumbnailURL
                ))
                seenIDs.insert(videoID)
            }
        }
        return tracks
    }

    private static func runs(in column: [String: Any]) -> [[String: Any]] {
        guard
            let flexColumn = column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
            let text = flexColumn["text"] as? [String: Any],
            let runs = text["runs"] as? [[String: Any]]
        else { return [] }
        return runs
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
