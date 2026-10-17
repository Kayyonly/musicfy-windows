package musicfy.poc;

import java.util.List;

/** Minimal playback contract shared by the two experimental backends. */
public interface PlaybackEngine extends AutoCloseable {
    interface Listener {
        void onStatus(String message);
        void onPosition(long currentMillis, long durationMillis, boolean seekable);
    }

    void setQueue(List<String> sources);
    void play();
    void pause();
    void next();
    void retry();
    void seek(long positionMillis);

    @Override
    void close();
}
