import XCTest
@testable import MusicfyIOS

@MainActor
final class MusicfyDemoStateTests: XCTestCase {
    func testInitialSelectionAndSilentPlaybackToggle() {
        let state = MusicfyDemoState()
        XCTAssertEqual(state.selectedTrack?.id, DemoCatalog.tracks.first?.id)
        XCTAssertFalse(state.isDemoPlaying)
        state.toggleDemoPlayback()
        XCTAssertTrue(state.isDemoPlaying)
        state.toggleDemoPlayback()
        XCTAssertFalse(state.isDemoPlaying)
    }

    func testSearchByTitleArtistAlbumAndWhitespace() {
        let state = MusicfyDemoState()
        XCTAssertEqual(state.filteredTracks(" ini ABADI ").map(\.id), ["abadi"])
        XCTAssertEqual(state.filteredTracks("perunggu").map(\.id), ["abadi"])
        XCTAssertEqual(state.filteredTracks("memorandum").map(\.id), ["abadi"])
        XCTAssertTrue(state.filteredTracks("no-such-demo-track").isEmpty)
        XCTAssertEqual(state.filteredTracks("  ").count, state.tracks.count)
    }

    func testSelectionResetsDemoProgressAndPlayback() {
        let state = MusicfyDemoState()
        state.progress = 0.9
        state.isDemoPlaying = true
        state.select(state.tracks[1])
        XCTAssertEqual(state.selectedID, state.tracks[1].id)
        XCTAssertEqual(state.progress, 0)
        XCTAssertFalse(state.isDemoPlaying)
    }

    func testNextPreviousWrapAround() {
        let state = MusicfyDemoState()
        state.step(-1)
        XCTAssertEqual(state.selectedID, state.tracks.last?.id)
        state.step(1)
        XCTAssertEqual(state.selectedID, state.tracks.first?.id)
    }

    func testFavoriteIsPerTrackAndReversible() {
        let state = MusicfyDemoState()
        state.toggleFavorite()
        XCTAssertTrue(state.isFavorite)
        state.step(1)
        XCTAssertFalse(state.isFavorite)
        state.step(-1)
        XCTAssertTrue(state.isFavorite)
        state.toggleFavorite()
        XCTAssertFalse(state.isFavorite)
    }

    func testMissingSelectionIsSafe() {
        let state = MusicfyDemoState()
        state.selectedID = nil
        state.toggleDemoPlayback()
        state.toggleFavorite()
        XCTAssertNil(state.selectedTrack)
        XCTAssertFalse(state.isDemoPlaying)
        XCTAssertTrue(state.favoriteIDs.isEmpty)
    }

    func testHistoryDeduplicatesAndLimitsToFive() {
        let state = MusicfyDemoState()
        for term in ["one", "two", "three", "four", "five", "six", "SIX"] {
            state.searchQuery = term
            state.rememberSearch()
        }
        XCTAssertEqual(state.searchHistory.count, 5)
        XCTAssertEqual(state.searchHistory.first, "SIX")
        XCTAssertEqual(state.searchHistory.filter { $0.lowercased() == "six" }.count, 1)
    }
}
