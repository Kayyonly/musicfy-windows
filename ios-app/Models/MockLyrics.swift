import Foundation

struct MockLyrics: Identifiable {
    let id: String
    let lines: [String]

    // Original demonstration text, not the lyrics of any listed recording.
    static let demo = MockLyrics(id: "original-demo", lines: [
        "A little light across the room",
        "A quiet road beneath the moon",
        "We draw a map of somewhere new",
        "And leave a space to wander through"
    ])
}
