package musicfy.poc;

import javafx.scene.media.Media;
import javafx.scene.media.MediaPlayer;
import javafx.util.Duration;

import java.net.URI;
import java.nio.file.Path;
import java.util.List;
import java.util.Objects;

/** JavaFX Media backend. All methods are called on the JavaFX application thread. */
final class JavaFxMediaEngine implements PlaybackEngine {
    private final Listener listener;
    private List<String> queue = List.of();
    private int index;
    private MediaPlayer player;
    private boolean loaded;

    JavaFxMediaEngine(Listener listener) {
        this.listener = Objects.requireNonNull(listener);
    }

    @Override
    public void setQueue(List<String> sources) {
        disposePlayer();
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
        if (!loaded) {
            loadCurrent(true);
        } else if (player != null) {
            player.play();
        }
    }

    @Override
    public void pause() {
        if (player != null) {
            player.pause();
        }
    }

    @Override
    public void next() {
        if (queue.isEmpty()) {
            listener.onStatus("Queue is empty");
            return;
        }
        index = (index + 1) % queue.size();
        loadCurrent(true);
    }

    @Override
    public void retry() {
        if (queue.isEmpty()) {
            listener.onStatus("Queue is empty");
            return;
        }
        loadCurrent(true);
    }

    @Override
    public void seek(long positionMillis) {
        if (player == null || !loaded || player.getStatus() == MediaPlayer.Status.STOPPED) {
            listener.onStatus("Seek unavailable until media is ready");
            return;
        }
        Duration duration = player.getTotalDuration();
        if (duration == null || duration.isUnknown() || duration.isIndefinite()) {
            listener.onStatus("Seek unavailable for unknown/indefinite duration");
            return;
        }
        player.seek(Duration.millis(Math.max(0, Math.min(positionMillis, duration.toMillis()))));
    }

    private void loadCurrent(boolean autoplay) {
        disposePlayer();
        loaded = true;
        String source = toMediaUri(queue.get(index));
        listener.onStatus("Opening item " + (index + 1) + "/" + queue.size() + " (JavaFX Media)");

        try {
            Media media = new Media(source);
            media.setOnError(() -> listener.onStatus("Media error: " + safeMessage(media.getError())));
            MediaPlayer next = new MediaPlayer(media);
            player = next;
            next.setOnReady(() -> {
                if (player != next) return;
                listener.onStatus("READY — JavaFX Media");
                publishPosition(next);
                if (autoplay) next.play();
            });
            next.setOnError(() -> {
                if (player == next) listener.onStatus("Playback error: " + safeMessage(next.getError()));
            });
            next.setOnEndOfMedia(() -> next());
            next.statusProperty().addListener((obs, oldStatus, newStatus) -> {
                if (player == next) listener.onStatus("JavaFX Media: " + newStatus);
            });
            next.currentTimeProperty().addListener((obs, oldTime, newTime) -> {
                if (player == next) publishPosition(next);
            });
            next.bufferProgressTimeProperty().addListener((obs, oldTime, newTime) -> {
                if (player == next && next.getStatus() == MediaPlayer.Status.STALLED) {
                    listener.onStatus("Buffering — buffered through " + format(newTime));
                }
            });
        } catch (RuntimeException ex) {
            loaded = false;
            listener.onStatus("Could not open media: " + safeMessage(ex));
        }
    }

    private void publishPosition(MediaPlayer current) {
        Duration duration = current.getTotalDuration();
        Duration at = current.getCurrentTime();
        long durationMs = knownMillis(duration);
        long currentMs = knownMillis(at);
        boolean seekable = durationMs > 0 && durationMs < Long.MAX_VALUE;
        listener.onPosition(currentMs, durationMs, seekable);
    }

    private static long knownMillis(Duration value) {
        if (value == null || value.isUnknown() || value.isIndefinite() || !Double.isFinite(value.toMillis())) return 0;
        return Math.max(0, (long) value.toMillis());
    }

    private static String format(Duration duration) {
        if (duration == null || duration.isUnknown() || duration.isIndefinite()) return "unknown";
        return String.format("%.1f s", duration.toSeconds());
    }

    private static String toMediaUri(String input) {
        try {
            URI uri = URI.create(input.trim());
            if (uri.getScheme() != null) return uri.toASCIIString();
        } catch (IllegalArgumentException ignored) {
            // Treat paths containing URI-reserved characters as local paths.
        }
        return Path.of(input.trim()).toAbsolutePath().toUri().toString();
    }

    private static String safeMessage(Throwable throwable) {
        if (throwable == null) return "unknown error";
        String message = throwable.getMessage();
        return message == null || message.isBlank() ? throwable.getClass().getSimpleName() : message;
    }

    private void disposePlayer() {
        if (player != null) {
            player.stop();
            player.dispose();
            player = null;
        }
    }

    @Override
    public void close() {
        disposePlayer();
    }
}
