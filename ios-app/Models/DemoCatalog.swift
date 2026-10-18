import Foundation

// Metadata only. No recordings or commercial cover art are bundled.
enum DemoCatalog {
    static let tracks: [MockTrack] = [
        MockTrack(id: "akhir", title: "Di Akhir Perang", artist: "Nadin Amizah", albumTitle: "Untuk Dunia, Cinta", duration: 268, artwork: 0),
        MockTrack(id: "abadi", title: "Ini Abadi", artist: "Perunggu", albumTitle: "Memorandum", duration: 232, artwork: 1),
        MockTrack(id: "nadir", title: "Titik Nadir (feat. Monita Tahalea)", artist: "Kahitna, Monita Tahalea", albumTitle: "Titik Nadir", duration: 250, artwork: 2),
        MockTrack(id: "kebun", title: "Lihat Kebunku (Taman Bunga)", artist: "Aku Jeje", albumTitle: "Lihat Kebunku", duration: 198, artwork: 3),
        MockTrack(id: "waktu", title: "Terbuang Dalam Waktu", artist: "Barasuara", albumTitle: "Jalaran Sadrah", duration: 309, artwork: 4),
        MockTrack(id: "kata", title: "Kata Mereka Ini Berlebihan", artist: "Bernadya", albumTitle: "Sialnya, Hidup Harus Tetap Berjalan", duration: 235, artwork: 5),
        MockTrack(id: "nadi", title: "Tulang dan Nadi", artist: "Tiara Andini", albumTitle: "Tulang dan Nadi", duration: 216, artwork: 6)
    ]
    static let albums: [MockAlbum] = tracks.map {
        MockAlbum(id: $0.id, title: $0.title, artist: $0.artist, artwork: $0.artwork, trackID: $0.id)
    }
    static let playlist = MockPlaylist(id: "demo", title: "Jump Back In", subtitle: "Local UI demo", trackIDs: tracks.map(\.id))
}
