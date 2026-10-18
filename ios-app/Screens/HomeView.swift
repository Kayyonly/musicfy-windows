import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var state: MusicfyDemoState

    private var heroTrack: MockTrack { state.selectedTrack ?? state.tracks[0] }
    private var recentTracks: [MockTrack] { Array(state.tracks.prefix(5)) }
    private var mostPlayed: [MockTrack] { Array(state.tracks.suffix(3).reversed()) }
    private var demoAlbums: [MockAlbum] { Array(DemoCatalog.albums.prefix(4)) }

    var body: some View {
        GeometryReader { proxy in
            let inset = proxy.size.width < 390 ? MusicfySpacing.page : MusicfySpacing.home
            ScrollView {
                VStack(alignment: .leading, spacing: MusicfySpacing.section) {
                    PageHeader(title: "Home")
                    hero
                    section(title: "Recently Played") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: MusicfySpacing.cardGap) {
                                ForEach(recentTracks) { track in
                                    AlbumCard(album: album(for: track)) { state.select(track) }
                                }
                            }
                        }
                    }
                    section(title: "Most Played") {
                        VStack(spacing: 4) {
                            ForEach(Array(mostPlayed.enumerated()), id: \.element.id) { index, track in
                                TrackRow(track: track, rank: index + 1, isSelected: state.selectedID == track.id) { state.select(track) }
                            }
                        }
                    }
                    section(title: "More like Kahitna", subtitle: "Local demo selection · not recommendations") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: MusicfySpacing.cardGap) {
                                ForEach(demoAlbums) { album in
                                    AlbumCard(album: album) { select(album) }
                                }
                            }
                        }
                    }
                    section(title: "Jump Back In", subtitle: "Local UI demo adaptation") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: MusicfySpacing.cardGap) {
                                ForEach(demoAlbums) { album in
                                    AlbumCard(album: album) { select(album) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, inset)
                .padding(.top, 8)
                .padding(.bottom, MusicfySpacing.home)
            }
        }
        .scrollContentBackground(.hidden)
        .background(MusicfyTheme.background.ignoresSafeArea())
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous)
                    .fill(LinearGradient(colors: MusicfyTheme.artworkColors(heroTrack.artwork), startPoint: .topLeading, endPoint: .bottomTrailing))
                AlbumArtworkView(artwork: heroTrack.artwork)
                    .frame(width: 220, height: 260)
                    .rotationEffect(.degrees(8))
                    .offset(x: 82, y: -18)
                    .opacity(0.86)
                Circle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .offset(x: 150, y: 80)
                LinearGradient(colors: [.black.opacity(0.02), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                HStack(alignment: .bottom, spacing: 18) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 74, weight: .black))
                        .foregroundStyle(.white.opacity(0.94))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RANDOM PLAYS").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(.white.opacity(0.72))
                        Text("Gacha here!").font(MusicfyTypography.pageTitle).foregroundStyle(.white).lineLimit(1)
                        Text("\(heroTrack.title) · \(heroTrack.artist)").font(MusicfyTypography.subtitle).foregroundStyle(.white.opacity(0.78)).lineLimit(1)
                        Text("LOCAL UI DEMO · NO AUDIO").font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.white.opacity(0.62))
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: MusicfySpacing.radius, style: .continuous))
            .clipped()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Random plays, Gacha here. \(heroTrack.title) by \(heroTrack.artist). Local UI demo with no audio.")

            HStack(spacing: 10) {
                Button { state.toggleDemoPlayback() } label: {
                    Label(state.isDemoPlaying ? "Pause demo" : "Play demo", systemImage: state.isDemoPlaying ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity, minHeight: MusicfySpacing.minimumTouch)
                }
                .buttonStyle(.borderedProminent)
                .tint(MusicfyTheme.primary)
                .foregroundStyle(MusicfyTheme.background)
                Button {
                    state.select(state.tracks.randomElement() ?? heroTrack)
                } label: {
                    Label("Roll!!", systemImage: "die.face.5.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: MusicfySpacing.minimumTouch)
                }
                .buttonStyle(.plain)
                .foregroundStyle(MusicfyTheme.primary)
                .background(MusicfyTheme.field, in: Capsule())
                .overlay(Capsule().stroke(MusicfyTheme.secondary.opacity(0.35), lineWidth: 1))
                .accessibilityLabel("Roll for another local demo track")
            }
        }
    }

    @ViewBuilder private func section<Content: View>(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
    }

    private func album(for track: MockTrack) -> MockAlbum {
        MockAlbum(id: track.id, title: track.title, artist: track.artist, artwork: track.artwork, trackID: track.id)
    }

    private func select(_ album: MockAlbum) {
        if let track = state.tracks.first(where: { $0.id == album.trackID }) { state.select(track) }
    }
}
