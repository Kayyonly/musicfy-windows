import XCTest
@testable import MusicfyIOS

/// A provider that can be told exactly what to return, so playback state can be
/// exercised without any real audio or network.
private struct StubPlaybackSourceProvider: PlaybackSourceProviding {
    var source: PlaybackSource?
    var error: Error?

    func source(for track: InnerTubeTrack) async throws -> PlaybackSource? {
        if let error { throw error }
        return source
    }
}

/// A provider whose completion is controlled by the test, so awaiting the load is a
/// deterministic signal instead of a timing guess.
private actor GatedPlaybackSourceProvider: PlaybackSourceProviding {
    private var continuation: CheckedContinuation<PlaybackSource?, Error>?
    private var started = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func source(for track: InnerTubeTrack) async throws -> PlaybackSource? {
        started = true
        resumeStartWaiters()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    /// Resolves once `source(for:)` has actually been entered.
    func awaitStart() async {
        if started { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func finish(returning source: PlaybackSource?) {
        continuation?.resume(returning: source)
        continuation = nil
    }

    func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    private func resumeStartWaiters() {
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}

private struct StubFailure: LocalizedError {
    var errorDescription: String? { "provider offline" }
}

private func makeTrack(id: String = "live-1") -> InnerTubeTrack {
    InnerTubeTrack(
        id: id,
        title: "Ini Abadi",
        artist: "Perunggu",
        albumTitle: "Memorandum",
        durationText: "3:52",
        thumbnailURL: nil
    )
}

/// A real, locally generated audio file path so `load(_:)` builds a genuine AVPlayerItem
/// without any network access or fabricated YouTube URL.
private func makeTemporaryAudioFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("musicfy-test-\(UUID().uuidString).m4a")
    try Data().write(to: url)
    return url
}

private func makeSource(url: URL) -> PlaybackSource {
    PlaybackSource(url: url, label: "test source", durationHint: 12)
}

@MainActor
final class PlayerControllerTests: XCTestCase {

    // MARK: - PlayerController in isolation

    func testPlayerStartsIdleWithoutMedia() {
        let player = PlayerController()
        XCTAssertEqual(player.status, .idle)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isReady)
        XCTAssertFalse(player.hasMedia)
        XCTAssertFalse(player.isItemReady)
        XCTAssertEqual(player.progressFraction, 0)
    }

    func testTransportIsInertWithoutASource() {
        let player = PlayerController()
        player.play()
        player.pause()
        player.stop()
        player.seek(toFraction: 0.5)
        player.seek(to: 30)
        XCTAssertEqual(player.status, .idle)
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.currentTime, 0)
        XCTAssertEqual(player.duration, 0)
    }

    func testLoadingNilSourceStaysIdleAndClearsError() {
        let player = PlayerController()
        player.load(nil)
        XCTAssertEqual(player.status, .idle)
        XCTAssertNil(player.loadedSource)
        XCTAssertNil(player.errorMessage)
    }

    func testSeekClampsToValidBounds() {
        let player = PlayerController()
        // No duration yet: every seek is a no-op, never a fabricated position.
        player.seek(to: 100)
        XCTAssertEqual(player.currentTime, 0)
        player.seek(to: -5)
        XCTAssertEqual(player.currentTime, 0)
    }

    // MARK: - Positive path: a supplied source is loaded and never over-claims

    func testLoadingASuppliedSourceEntersLoadingAndKeepsPlaybackUnclaimed() throws {
        let url = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let player = PlayerController()
        player.load(makeSource(url: url))

        XCTAssertEqual(player.loadedSource, makeSource(url: url))
        XCTAssertTrue(player.isReady)
        XCTAssertTrue(player.hasMedia)
        XCTAssertEqual(player.duration, 12, "A provider duration hint is used until AVPlayer reports its own")
        // Nothing real has been decoded yet, so playback must not be claimed.
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.isBuffering)
        XCTAssertNotEqual(player.status, .playing)
    }

    func testPlayBeforeTheItemIsReadyDoesNotReportPlayback() throws {
        let url = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let player = PlayerController()
        player.load(makeSource(url: url))

        // The item is not decoded yet at this point in a test process.
        XCTAssertFalse(player.isItemReady)

        player.play()

        XCTAssertFalse(player.isPlaying, "A play request must not claim playback before AVPlayer is actually playing")
        XCTAssertNotEqual(player.status, .playing)
    }

    func testInvalidateReleasesTheLoadedSource() throws {
        let url = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let player = PlayerController()
        player.load(makeSource(url: url))
        XCTAssertNotNil(player.loadedSource)

        player.invalidate()

        XCTAssertNil(player.loadedSource)
        XCTAssertEqual(player.status, .idle)
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(player.hasMedia)
        XCTAssertNil(player.errorMessage)
    }

    func testLoadingAfterInvalidateWorksAgain() throws {
        let url = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let player = PlayerController()
        player.invalidate()
        player.load(makeSource(url: url))

        XCTAssertNotNil(player.loadedSource)
        XCTAssertTrue(player.isReady)
    }

    // MARK: - MusicfyDemoState integration

    func testSelectingLiveTrackWithoutProviderReportsUnavailable() async {
        let state = MusicfyDemoState(playbackSourceProvider: UnavailablePlaybackSourceProvider())
        state.selectLiveTrack(makeTrack())
        await state.awaitPlaybackSourceLoad()

        XCTAssertEqual(state.selectedLiveTrack?.id, "live-1")
        XCTAssertTrue(state.isLiveTrackSelected)
        XCTAssertFalse(state.isLiveAudioAvailable)
        XCTAssertFalse(state.isPlaying)
        XCTAssertNotNil(state.playbackUnavailableReason)
    }

    func testPlayWithUnavailableSourceDoesNotClaimPlaybackAndDoesNotStartDemo() async {
        let state = MusicfyDemoState(playbackSourceProvider: UnavailablePlaybackSourceProvider())
        state.selectLiveTrack(makeTrack())
        await state.awaitPlaybackSourceLoad()

        state.togglePlayback()

        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.player.isPlaying)
        XCTAssertFalse(state.isDemoPlaying, "An unavailable live track must not fall through to the silent demo")
        XCTAssertNotNil(state.playbackUnavailableReason)
    }

    func testDemoTransportIsRefusedWhileALiveTrackIsSelected() async {
        let state = MusicfyDemoState(playbackSourceProvider: UnavailablePlaybackSourceProvider())
        state.selectLiveTrack(makeTrack())
        await state.awaitPlaybackSourceLoad()

        // Even the direct demo entry point must refuse while a live result is selected.
        state.toggleDemoPlayback()
        XCTAssertFalse(state.isDemoPlaying)
        XCTAssertFalse(state.isPlaying)

        // Seeking must not advance the silent demo progress either.
        state.seek(to: 0.8)
        XCTAssertEqual(state.progress, 0, accuracy: 0.0001)
    }

    func testProviderErrorSurfacesAsUnavailableReason() async {
        let state = MusicfyDemoState(
            playbackSourceProvider: StubPlaybackSourceProvider(source: nil, error: StubFailure())
        )
        state.selectLiveTrack(makeTrack())
        await state.awaitPlaybackSourceLoad()

        XCTAssertEqual(state.playbackUnavailableReason, "provider offline")
        XCTAssertFalse(state.isLiveAudioAvailable)
        XCTAssertFalse(state.isPlaying)
    }

    func testSuppliedSourceMakesLiveAudioAvailable() async throws {
        let url = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let state = MusicfyDemoState(
            playbackSourceProvider: StubPlaybackSourceProvider(source: makeSource(url: url))
        )
        state.selectLiveTrack(makeTrack())
        await state.awaitPlaybackSourceLoad()

        XCTAssertNil(state.playbackUnavailableReason)
        XCTAssertTrue(state.isLiveAudioAvailable)
        XCTAssertTrue(state.player.hasMedia)
        XCTAssertFalse(state.isPlaying, "A loaded source is not yet playback")
    }

    func testGatedProviderCompletionIsAwaitedDeterministically() async throws {
        let url = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let provider = GatedPlaybackSourceProvider()
        let state = MusicfyDemoState(playbackSourceProvider: provider)
        state.selectLiveTrack(makeTrack())

        // Block until the provider call is genuinely in flight, then release it.
        await provider.awaitStart()
        XCTAssertFalse(state.isLiveAudioAvailable, "Still waiting on the provider")

        await provider.finish(returning: makeSource(url: url))
        await state.awaitPlaybackSourceLoad()

        XCTAssertTrue(state.isLiveAudioAvailable)
        XCTAssertNil(state.playbackUnavailableReason)
    }

    func testDemoSelectionClearsLiveAudioState() async {
        let state = MusicfyDemoState(playbackSourceProvider: UnavailablePlaybackSourceProvider())
        state.selectLiveTrack(makeTrack())
        await state.awaitPlaybackSourceLoad()
        XCTAssertNotNil(state.playbackUnavailableReason)

        state.select(state.tracks[1])

        XCTAssertNil(state.selectedLiveTrack)
        XCTAssertFalse(state.isLiveTrackSelected)
        XCTAssertNil(state.playbackUnavailableReason)
        XCTAssertFalse(state.isLiveAudioAvailable)
        XCTAssertFalse(state.isPlaying)
    }

    func testDemoTransportStillWorksWithoutLiveAudio() {
        let state = MusicfyDemoState()
        XCTAssertFalse(state.isLiveTrackSelected)
        XCTAssertTrue(state.hasDemoSelection)
        state.togglePlayback()
        XCTAssertTrue(state.isPlaying)
        state.seek(to: 0.5)
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.0001)
        state.togglePlayback()
        XCTAssertFalse(state.isPlaying)
    }
}
