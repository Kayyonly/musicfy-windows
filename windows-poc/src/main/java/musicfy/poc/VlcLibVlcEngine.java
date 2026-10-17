package musicfy.poc;

import javafx.application.Platform;
import uk.co.caprica.vlcj.factory.MediaPlayerFactory;
import uk.co.caprica.vlcj.player.base.MediaPlayer;
import uk.co.caprica.vlcj.player.base.MediaPlayerEventAdapter;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * vlcj 4.x adapter. All LibVLC API calls and factory/player lifecycle operations
 * are serialized on the JavaFX application thread; native callbacks only publish
 * UI work or schedule controls back onto that thread.
 */
final class VlcLibVlcEngine implements PlaybackEngine {
    private static final Set<String> AUDIO_OUTPUTS = Set.of("default", "directsound", "mmdevice");

    private final Listener listener;
    private final MediaPlayerFactory factory;
    private final MediaPlayer player;
    private final AtomicInteger lastBufferingBucket = new AtomicInteger(-1);
    private List<String> queue = List.of();
    private int index;
    private volatile long durationMillis;
    private volatile String activeTrackLabel = "no track";
    private volatile boolean closed;
    private boolean loaded;

    VlcLibVlcEngine(Listener listener) {
        requireFxThread();
        this.listener = Objects.requireNonNull(listener);

        String audioOutput = configuredAudioOutput();
        List<String> options = new ArrayList<>(List.of("--no-video"));
        if (!audioOutput.equals("default")) {
            options.add("--aout=" + audioOutput);
        }
        System.out.println("[poc] LibVLC startup options: " + options
                + " (audio output=" + audioOutput + "; requested configuration is not proof of audible output)");
        factory = new MediaPlayerFactory(options);
        player = factory.mediaPlayers().newMediaPlayer();
        player.events().addMediaPlayerEventListener(new MediaPlayerEventAdapter() {
            @Override public void mediaPlayerReady(MediaPlayer ignored) {
                String track = activeTrackLabel;
                onFx(() -> listener.onStatus("READY — LibVLC " + track));
            }
            @Override public void opening(MediaPlayer ignored) {
                String track = activeTrackLabel;
                onFx(() -> listener.onStatus("Opening — LibVLC " + track));
            }
            @Override public void buffering(MediaPlayer ignored, float cache) {
                int percent = Math.max(0, Math.min(100, Math.round(cache)));
                int bucket = percent == 100 ? 100 : (percent / 25) * 25;
                if (lastBufferingBucket.getAndSet(bucket) != bucket) {
                    String track = activeTrackLabel;
                    onFx(() -> listener.onStatus(String.format(
                            "Buffering — LibVLC %s %d%%", track, bucket)));
                }
            }
            @Override public void playing(MediaPlayer ignored) {
                lastBufferingBucket.set(-1);
                String track = activeTrackLabel;
                onFx(() -> listener.onStatus("PLAYING — LibVLC " + track));
            }
            @Override public void paused(MediaPlayer ignored) {
                String track = activeTrackLabel;
                onFx(() -> listener.onStatus("PAUSED — LibVLC " + track));
            }
            @Override public void stopped(MediaPlayer ignored) {
                String track = activeTrackLabel;
                onFx(() -> listener.onStatus("STOPPED — LibVLC " + track));
            }
            @Override public void finished(MediaPlayer ignored) {
                // vlcj 4.x callbacks run on a native thread; never re-enter LibVLC there.
                onFx(VlcLibVlcEngine.this::next);
            }
            @Override public void error(MediaPlayer ignored) {
                String track = activeTrackLabel;
                onFx(() -> listener.onStatus("LibVLC playback error — " + track));
            }
            @Override public void lengthChanged(MediaPlayer ignored, long length) {
                durationMillis = Math.max(0, length);
                publishPosition(0);
            }
            @Override public void timeChanged(MediaPlayer ignored, long time) {
                publishPosition(time);
            }
            @Override public void seekableChanged(MediaPlayer ignored, int seekable) {
                String track = activeTrackLabel;
                onFx(() -> listener.onStatus("LibVLC seekable " + track + ": " + (seekable != 0)));
            }
        });
    }

    @Override
    public void setQueue(List<String> sources) {
        requireFxThread();
        if (closed) return;
        player.controls().stop();
        queue = List.copyOf(sources);
        index = 0;
        loaded = false;
        activeTrackLabel = queue.isEmpty() ? "no track" : trackLabel();
        listener.onStatus(queue.isEmpty() ? "No media items" : "Queue loaded: " + queue.size() + " item(s)");
    }

    @Override
    public void play() {
        requireFxThread();
        if (closed) return;
        if (queue.isEmpty()) {
            listener.onStatus("Enter one or more media URIs, one per line");
            return;
        }
        if (loaded) {
            player.controls().play();
            return;
        }
        playCurrent();
    }

    @Override
    public void pause() {
        requireFxThread();
        if (!closed) player.controls().pause();
    }

    @Override
    public void next() {
        requireFxThread();
        if (closed) return;
        if (queue.isEmpty()) {
            listener.onStatus("Queue is empty");
            return;
        }
        index = (index + 1) % queue.size();
        playCurrent();
    }

    @Override
    public void retry() {
        requireFxThread();
        if (closed) return;
        if (queue.isEmpty()) {
            listener.onStatus("Queue is empty");
            return;
        }
        playCurrent();
    }

    @Override
    public void seek(long positionMillis) {
        requireFxThread();
        if (closed) return;
        if (!loaded || durationMillis <= 0) {
            listener.onStatus("Seek unavailable until duration is known");
            return;
        }
        player.controls().setTime(Math.max(0, Math.min(positionMillis, durationMillis)));
    }

    private void playCurrent() {
        durationMillis = 0;
        loaded = true;
        activeTrackLabel = trackLabel();
        lastBufferingBucket.set(-1);
        String source = queue.get(index);
        listener.onStatus("Opening item " + (index + 1) + "/" + queue.size() + " (LibVLC)");
        if (!player.media().play(source)) {
            loaded = false;
            listener.onStatus("LibVLC rejected the media source — " + activeTrackLabel);
        }
    }

    private String trackLabel() {
        return "item " + (index + 1) + "/" + queue.size();
    }

    private void publishPosition(long currentMillis) {
        long duration = durationMillis;
        onFx(() -> listener.onPosition(Math.max(0, currentMillis), duration, duration > 0));
    }

    private void onFx(Runnable action) {
        if (closed) return;
        Runnable guarded = () -> {
            if (!closed) action.run();
        };
        if (Platform.isFxApplicationThread()) {
            guarded.run();
        } else {
            try {
                Platform.runLater(guarded);
            } catch (IllegalStateException ignored) {
                // The JavaFX toolkit may already be shutting down after player release.
            }
        }
    }

    private static String configuredAudioOutput() {
        String defaultOutput = isWindows() ? "directsound" : "default";
        String requested = System.getenv().getOrDefault("MUSICFY_VLC_AOUT", defaultOutput)
                .trim().toLowerCase(Locale.ROOT);
        if (!AUDIO_OUTPUTS.contains(requested)) {
            throw new IllegalArgumentException("MUSICFY_VLC_AOUT must be one of: " + AUDIO_OUTPUTS);
        }
        return requested;
    }

    private static boolean isWindows() {
        return System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("win");
    }

    private static void requireFxThread() {
        if (!Platform.isFxApplicationThread()) {
            throw new IllegalStateException("LibVLC creation, control, and release must run on the JavaFX application thread");
        }
    }

    @Override
    public void close() {
        requireFxThread();
        if (closed) return;
        closed = true;
        try {
            player.controls().stop();
        } finally {
            try {
                player.release();
            } finally {
                factory.release();
            }
        }
    }
}
