import Foundation

struct MockTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let albumTitle: String
    let duration: TimeInterval
    let artwork: Int

    var durationLabel: String {
        let seconds = Int(duration)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
