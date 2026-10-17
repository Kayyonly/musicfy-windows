package musicfy.poc;

import javafx.application.Platform;
import uk.co.caprica.vlcj.factory.MediaPlayerFactory;
import uk.co.caprica.vlcj.player.base.MediaPlayer;
import uk.co.caprica.vlcj.player.base.MediaPlayerEventAdapter;

import java.util.List;
import java.util.Objects;

/** vlcj 4.x adapter. A compatible native VLC/LibVLC installation is required at runtime. */
final class VlcLibVlcEngine implements PlaybackEngine {
    private final Listener listener;
    private final MediaPlayerFactory factory;
    private final MediaPlayer player;
    private List<String> queue = List.of();
    private int index;
    private long durationMillis;
    private boolean loaded;

    VlcLibVlcEngine(Listener listener) {
        this.listener = Objects.requireNonNull(listener);
        factory = new MediaPlayerFactory("--no-video");
        player = factory.mediaPlayers().newMediaPlayer();
        player.events().addMediaPlayerEventListener(new MediaPlayerEventAdapter() {
            @Override public void opening(MediaPlayer ignored) { onFx(() -> listener.onStatus("Opening — LibVLC")); }
            @Override public void buffering(MediaPlayer ignored, float cache) {
                onFx(() -> listener.onStatus(String.format("Buffering — LibVLC %.0f%%", cache)));
            }
            @Override public void playing(MediaPlayer ignored) { onFx(() -> listener.onStatus("PLAYING — LibVLC")); }
            @Override public void paused(MediaPlayer ignored) { onFx(() -> listener.onStatus("PAUSED — LibVLC")); }
            @Override public void stopped(MediaPlayer ignored) { onFx(() -> listener.onStatus("STOPPED — LibVLC")); }
            @Override public void finished(MediaPlayer ignored) { onFx(VlcLibVlcEngine.this::next); }
            @Override public void error(MediaPlayer ignored) { onFx(() -> listener.onStatus("LibVLC playback error")); }
            @Override public void lengthChanged(MediaPlayer ignored, long length) {
                durationMillis = Math.max(0, length);
                publishPosition(0);
            }
            @Override public void timeChanged(MediaPlayer ignored, long time) { publishPosition(time); }
            @Override public void seekableChanged(MediaPlayer ignored, int seekable) {
                onFx(() -> listener.onStatus("LibVLC seekable: " + (seekable != 0)));
            }
        });
    }

    @Override
    public void setQueue(List<String> sources) {
        player.controls().stop();
        queue = List.copyOf(sources);
        index = 0;
        loaded = false;
        listener.onStatus(queue.isEmpty() ? "No media items" : "Queue loaded: " + queue.size() + " item(s)");
    }

    @Override
    public void play() {
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
        player.controls().pause();
    }

    @Override
    public void next() {
        if (queue.isEmpty()) {
            listener.onStatus("Queue is empty");
            return;
        }
        index = (index + 1) % queue.size();
        playCurrent();
    }

    @Override
    public void retry() {
        if (queue.isEmpty()) {
            listener.onStatus("Queue is empty");
            return;
        }
        playCurrent();
    }

    @Override
    public void seek(long positionMillis) {
        if (!loaded || durationMillis <= 0) {
            listener.onStatus("Seek unavailable until duration is known");
            return;
        }
        player.controls().setTime(Math.max(0, Math.min(positionMillis, durationMillis)));
    }

    private void playCurrent() {
        durationMillis = 0;
        loaded = true;
        String source = queue.get(index);
        listener.onStatus("Opening item " + (index + 1) + "/" + queue.size() + " (LibVLC)");
        if (!player.media().play(source)) {
            loaded = false;
            listener.onStatus("LibVLC rejected the media source");
        }
    }

    private void publishPosition(long currentMillis) {
        long duration = durationMillis;
        onFx(() -> listener.onPosition(Math.max(0, currentMillis), duration, duration > 0));
    }

    private static void onFx(Runnable action) {
        if (Platform.isFxApplicationThread()) action.run();
        else Platform.runLater(action);
    }

    @Override
    public void close() {
        try {
            player.controls().stop();
        } finally {
            player.release();
            factory.release();
        }
    }
}
