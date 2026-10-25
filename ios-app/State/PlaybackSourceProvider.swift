import Foundation

/// Connects a selected YouTube Music result to a real, playable audio source.
///
/// This is the only place an audio source may come from. Musicfy ships with
/// `UnavailablePlaybackSourceProvider`, which returns no source for any result, so the
/// app stays honest: metadata search works, and playback reports "unavailable" until an
/// approved provider is wired in. It never fabricates a URL from a video id.
protocol PlaybackSourceProviding {
    /// Returns a playable source for `track`, or `nil` when none is available.
    /// Throwing signals a transient failure (e.g. network) that the UI can surface.
    func source(for track: InnerTubeTrack) async throws -> PlaybackSource?
}

/// The honest default: no playable audio exists for YouTube Music metadata yet.
struct UnavailablePlaybackSourceProvider: PlaybackSourceProviding {
    func source(for track: InnerTubeTrack) async throws -> PlaybackSource? { nil }
}
