import SwiftUI

#if DEBUG
private struct HomeGeometryPreferenceKey: PreferenceKey {
    struct Value: Equatable {
        var viewport: CGRect? = nil
        var marker: CGRect? = nil
    }

    static var defaultValue = Value()

    static func reduce(value: inout Value, nextValue: () -> Value) {
        let next = nextValue()
        value.viewport = next.viewport ?? value.viewport
        value.marker = next.marker ?? value.marker
    }
}
#endif

struct HomeView: View {
    @EnvironmentObject private var state: MusicfyDemoState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var heroTrack: MockTrack { state.selectedTrack ?? state.tracks[0] }
    private var recentTracks: [MockTrack] { Array(state.tracks.prefix(5)) }
    private var mostPlayed: [MockTrack] { Array(state.tracks.suffix(3).reversed()) }
    private var demoAlbums: [MockAlbum] { Array(DemoCatalog.albums.prefix(4)) }

    var body: some View {
        ScrollViewReader { scrollProxy in
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
                    Color.clear
                        .frame(height: 1)
                        .id("home-scroll-bottom")
                        #if DEBUG
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(key: HomeGeometryPreferenceKey.self, value: .init(marker: proxy.frame(in: .global)))
                            }
                        }
                        #endif
                }
                .padding(.horizontal, MusicfySpacing.page)
                .padding(.top, 8)
                // AppRootView owns the bottom safe-area inset; this is only breathing room
                // after the final section so screenshot scroll-to-bottom reaches real content.
                .padding(.bottom, MusicfySpacing.page)
            }
            .onAppear {
#if DEBUG
                state.reportScreenshotReady("home")
                if ProcessInfo.processInfo.arguments.contains("home-bottom") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        scrollProxy.scrollTo("home-scroll-bottom", anchor: .bottom)
                    }
                }
#endif
            }
            #if DEBUG
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: HomeGeometryPreferenceKey.self, value: .init(viewport: proxy.frame(in: .global)))
                }
            }
            .onPreferenceChange(HomeGeometryPreferenceKey.self) { frames in
                guard ProcessInfo.processInfo.arguments.contains("home-bottom"),
                      let viewport = frames.viewport, let marker = frames.marker else { return }
                let tolerance: CGFloat = 1
                let visible = marker.minY >= viewport.minY - tolerance && marker.maxY <= viewport.maxY + tolerance
                state.reportScreenshotReady("home-bottom", bottomVisible: visible)
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(MusicfyTheme.background.ignoresSafeArea())
        #if DEBUG
        .accessibilityIdentifier("screen.home")
        #endif
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
                AnyLayout(dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .bottom, spacing: 18))) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: "play.fill")
                            .font(.system(size: 74, weight: .black))
                            .foregroundStyle(.white.opacity(0.94))
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RANDOM PLAYS").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(.white.opacity(0.72))
                        Text("Gacha here!")
                            .font(MusicfyTypography.pageTitle)
                            .foregroundStyle(.white)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                            .minimumScaleFactor(0.78)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(heroTrack.title) · \(heroTrack.artist)").font(MusicfyTypography.subtitle).foregroundStyle(.white.opacity(0.78)).lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        Text("LOCAL UI DEMO · NO AUDIO").font(.caption2.weight(.semibold)).tracking(0.8).foregroundStyle(.white.opacity(0.62))
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 360 : 300, alignment: .bottomLeading)
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
