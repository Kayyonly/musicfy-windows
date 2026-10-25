import AVFoundation
import Combine
import Foundation

/// A directly playable audio source. Musicfy never fabricates one of these from a
/// YouTube video id: a value only exists when an approved provider supplied a real,
/// playable audio URL.
struct PlaybackSource: Equatable {
    let url: URL
    /// Sent with each range request (e.g. a Referer a provider requires). Empty by default.
    let headers: [String: String]
    /// Human-readable origin, shown while the source is unavailable or buffering.
    let label: String
    /// Duration advertised by the provider, used until the player reports its own.
    let durationHint: TimeInterval?

    init(url: URL, headers: [String: String] = [:], label: String, durationHint: TimeInterval? = nil) {
        self.url = url
        self.headers = headers
        self.label = label
        self.durationHint = durationHint
    }
}

enum PlayerStatus: Equatable {
    case idle
    case loading
    case ready
    case playing
    case paused
    case buffering
    case failed(String)

    var isTerminalFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

/// Native playback engine built on AVPlayer. It plays a supplied `PlaybackSource`
/// and nothing else; without one it stays idle and never claims to be playing.
@MainActor
final class PlayerController: ObservableObject {
    @Published private(set) var status: PlayerStatus = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var loadedSource: PlaybackSource?

    private let player = AVPlayer()
    private let audioSession = AVAudioSession.sharedInstance()
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var bufferingObservation: NSKeyValueObservation?
    private var notificationTokens: [NSObjectProtocol] = []
    private var wasPlayingBeforeInterruption = false
    private var isInvalidated = false

    var isReady: Bool { loadedSource != nil }
    var hasMedia: Bool { loadedSource != nil && !status.isTerminalFailure }

    /// True only once AVPlayer itself reports the current item as ready to play.
    /// Playback is never claimed before this is true.
    var isItemReady: Bool { player.currentItem?.status == .readyToPlay }

    /// 0...1 progress for the UI. Zero whenever nothing real is loaded or the
    /// duration is not yet known, so a stale value is never shown as playback.
    var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    init() {
        player.actionAtItemEnd = .pause
        observePlayerTimeControl()
        observeBuffering()
        registerAudioSessionNotifications()
    }

    /// Explicit, main-actor lifecycle end. `deinit` is not actor-isolated, so cleanup is
    /// never performed from deinit: the owner calls this before releasing the controller.
    /// Safe to call more than once.
    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        teardown()
        loadedSource = nil
        status = .idle
        errorMessage = nil
        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
    }

    // MARK: - Loading

    /// Loads a source and prepares it for playback. `nil` keeps the controller idle
    /// with a truthful unavailable state.
    func load(_ source: PlaybackSource?) {
        teardown()
        isInvalidated = false

        guard let source else {
            loadedSource = nil
            status = .idle
            errorMessage = nil
            isPlaying = false
            isBuffering = false
            currentTime = 0
            duration = 0
            return
        }

        loadedSource = source
        currentTime = 0
        duration = source.durationHint ?? 0
        errorMessage = nil
        isPlaying = false
        status = .loading
        isBuffering = false

        let asset = AVURLAsset(url: source.url, options: ["AVURLAssetHTTPHeaderFieldsKey": source.headers])
        let item = AVPlayerItem(asset: asset)
        observeItemStatus(item)
        observeNotifications(for: item)
        player.replaceCurrentItem(with: item)
        activateAudioSession()
        // The item is not ready yet, so this cannot report playback; it only keeps
        // buffering/playing state aligned with the player if a status change is missed.
        applyTimeControlStatus()
    }

    // MARK: - Transport

    /// Requests playback. It does not assert that playback started: `isPlaying` and
    /// `status` are derived from AVPlayer's own `timeControlStatus` and the item's
    /// readiness, so a request made while the player is waiting or failed stays honest.
    func play() {
        guard hasMedia, isItemReady else { return }
        activateAudioSession()
        player.play()
        applyTimeControlStatus()
    }

    func pause() {
        guard hasMedia else { return }
        player.pause()
        isPlaying = false
        if !status.isTerminalFailure { status = .paused }
    }

    func togglePlayPause() {
        guard hasMedia else { return }
        player.timeControlStatus == .playing ? pause() : play()
    }

    func stop() {
        guard hasMedia else { return }
        player.pause()
        player.seek(to: .zero)
        currentTime = 0
        isPlaying = false
        isBuffering = false
        status = .ready
    }

    /// Seeks to a 0...1 fraction of the loaded source, clamped to valid bounds.
    func seek(toFraction fraction: Double) {
        guard duration > 0 else { return }
        seek(to: min(max(fraction, 0), 1) * duration)
    }

    /// Seeks to an absolute time, clamped to `0...duration`.
    func seek(to seconds: TimeInterval) {
        guard duration > 0, seconds.isFinite else { return }
        let clamped = min(max(seconds, 0), duration)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
    }

    // MARK: - Observation

    /// The single source of truth for playing/buffering state. Both the KVO callback and
    /// `play()` funnel through here, so `isPlaying` only becomes true when AVPlayer
    /// actually reports `.playing` for a ready item. A terminal failure is never masked.
    private func applyTimeControlStatus() {
        guard !status.isTerminalFailure else {
            isPlaying = false
            isBuffering = false
            return
        }

        switch player.timeControlStatus {
        case .playing:
            isBuffering = false
            isPlaying = isItemReady
            if isPlaying { status = .playing }
        case .waitingToPlayAtSpecifiedRate:
            isPlaying = false
            isBuffering = true
            if loadedSource != nil { status = .buffering }
        case .paused:
            isPlaying = false
            isBuffering = false
            if loadedSource != nil { status = .paused }
        @unknown default:
            isPlaying = false
        }
    }

    private func observePlayerTimeControl() {
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.applyTimeControlStatus() }
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                let seconds = time.seconds
                if seconds.isFinite {
                    self.currentTime = min(max(seconds, 0), self.duration > 0 ? self.duration : seconds)
                }
                let itemDuration = self.player.currentItem?.duration.seconds ?? 0
                if itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
            }
        }
    }

    private func observeBuffering() {
        bufferingObservation = player.observe(\.reasonForWaitingToPlay, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                guard let self else { return }
                let waiting = player.reasonForWaitingToPlay != nil
                self.isBuffering = waiting
                if waiting, !self.status.isTerminalFailure, self.loadedSource != nil {
                    self.status = .buffering
                } else if !waiting, self.isPlaying, !self.status.isTerminalFailure {
                    self.status = .playing
                }
            }
        }
    }

    private func observeItemStatus(_ item: AVPlayerItem) {
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    let seconds = item.duration.seconds
                    if seconds.isFinite, seconds > 0 { self.duration = seconds }
                    self.errorMessage = nil
                    if !self.status.isTerminalFailure && !self.isPlaying {
                        self.status = .ready
                    }
                    // Readiness changed: re-derive playing/buffering from the player.
                    if self.player.timeControlStatus != .paused {
                        self.applyTimeControlStatus()
                    }
                case .failed:
                    self.fail(with: item.error)
                case .unknown:
                    if !self.status.isTerminalFailure { self.status = .loading }
                @unknown default:
                    break
                }
            }
        }
    }

    private func observeNotifications(for item: AVPlayerItem) {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor in self?.fail(with: error) }
        })
        notificationTokens.append(center.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = false
                self.currentTime = self.duration
                if !self.status.isTerminalFailure { self.status = .paused }
            }
        })
        notificationTokens.append(center.addObserver(
            forName: .AVPlayerItemPlaybackStalled, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isBuffering = true
                if !self.status.isTerminalFailure { self.status = .buffering }
            }
        })
    }

    private func fail(with error: Error?) {
        isPlaying = false
        isBuffering = false
        let message = error?.localizedDescription ?? "This audio source could not be played."
        errorMessage = message
        status = .failed(message)
    }

    // MARK: - Audio session

    private func activateAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            // A session failure is not fatal to loading; playback may still be offered
            // by the system, and the error surfaces through the item if it truly fails.
            errorMessage = error.localizedDescription
        }
    }

    private func registerAudioSessionNotifications() {
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification, object: audioSession, queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleInterruption(notification) }
        })
        notificationTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: audioSession, queue: .main
        ) { [weak self] notification in
            Task { @MainActor in self?.handleRouteChange(notification) }
        })
    }

    private func handleInterruption(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying { pause() }
        case .ended:
            let options = (notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            if wasPlayingBeforeInterruption, options.contains(.shouldResume) {
                play()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        // Headphones unplugged: stop rather than blast audio from the speaker.
        if reason == .oldDeviceUnavailable, isPlaying {
            pause()
        }
    }

    // MARK: - Cleanup

    /// Detaches all observers and releases them so a reload starts clean without leaks.
    private func teardown() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        bufferingObservation?.invalidate()
        bufferingObservation = nil

        let center = NotificationCenter.default
        for token in notificationTokens { center.removeObserver(token) }
        notificationTokens.removeAll()

        player.replaceCurrentItem(with: nil)
    }
}
