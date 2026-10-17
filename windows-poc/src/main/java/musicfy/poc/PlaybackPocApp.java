package musicfy.poc;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.animation.KeyFrame;
import javafx.animation.PauseTransition;
import javafx.animation.Timeline;
import javafx.geometry.Insets;
import javafx.scene.Scene;
import javafx.scene.control.Button;
import javafx.scene.control.ComboBox;
import javafx.scene.control.Label;
import javafx.scene.control.Slider;
import javafx.scene.control.TextArea;
import javafx.scene.layout.BorderPane;
import javafx.scene.layout.HBox;
import javafx.scene.layout.VBox;
import javafx.stage.Stage;
import javafx.util.Duration;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/** Minimal test harness only; this is not the Musicfy product UI. */
public final class PlaybackPocApp extends Application {
    private static final long SEEK_TOLERANCE_MIN_MS = 500;
    private static final long SEEK_TOLERANCE_MAX_MS = 1000;
    private static final int SMOKE_POLL_INTERVAL_MS = 100;
    private static final int SMOKE_SEEK_TIMEOUT_MS = 4000;
    private static final int SMOKE_NEXT_TIMEOUT_MS = 10000;

    private final ComboBox<String> backend = new ComboBox<>();
    private final TextArea sources = new TextArea();
    private final Label status = new Label("Choose an engine and enter test media URIs");
    private final Label time = new Label("00:00 / --:--");
    private final Slider seek = new Slider(0, 1, 0);
    private final List<String> smokeEvents = new ArrayList<>();
    private PlaybackEngine engine;
    private boolean canSeek;
    private long durationMillis;
    private long currentMillis;
    private long smokeSeekTarget;
    private long smokeSeekTolerance;
    private long smokeSeekBaseline;
    private long smokeSeekRequestedAtNanos;
    private boolean smokeSeeked;
    private boolean smokePauseSeen;
    private int smokeNextStartEventIndex;
    private Timeline smokeSeekPoller;
    private Timeline smokeNextTrackPoller;
    private PauseTransition smokeSeekResume;
    private PauseTransition smokeAdvanceToNext;
    private String latestStatus = "";

    @Override
    public void start(Stage stage) {
        List<String> arguments = getParameters().getRaw();
        boolean smokeMode = arguments.size() >= 4 && arguments.get(0).equalsIgnoreCase("--smoke");
        backend.getItems().setAll("JavaFX Media", "LibVLC (vlcj 4.x)");
        backend.setValue(smokeMode && arguments.get(1).equalsIgnoreCase("vlc")
                ? "LibVLC (vlcj 4.x)" : "JavaFX Media");
        backend.valueProperty().addListener((obs, oldValue, newValue) -> switchBackend(newValue));

        sources.setPromptText("Enter one legal test media URI or local file path per line.\nExample: http://127.0.0.1:8765/sample.mp3");
        sources.setPrefRowCount(4);
        Button start = new Button("Load & Play");
        Button pause = new Button("Pause");
        Button resume = new Button("Resume");
        Button next = new Button("Next track");
        Button retry = new Button("Retry current");
        start.setOnAction(e -> startQueue());
        pause.setOnAction(e -> withEngine(PlaybackEngine::pause));
        resume.setOnAction(e -> withEngine(PlaybackEngine::play));
        next.setOnAction(e -> withEngine(PlaybackEngine::next));
        retry.setOnAction(e -> withEngine(PlaybackEngine::retry));

        seek.setDisable(true);
        seek.setOnMouseReleased(e -> seekToSlider());
        seek.setOnKeyReleased(e -> seekToSlider());
        seek.valueChangingProperty().addListener((obs, wasChanging, isChanging) -> {
            if (wasChanging && !isChanging) seekToSlider();
        });

        HBox controls = new HBox(8, start, pause, resume, next, retry);
        HBox timeRow = new HBox(10, time, seek);
        seek.setMaxWidth(Double.MAX_VALUE);
        HBox.setHgrow(seek, javafx.scene.layout.Priority.ALWAYS);
        VBox center = new VBox(8, new Label("One media URI/path per line (use generated MP3/AAC/HLS test media)"), sources, controls, timeRow);
        center.setPadding(new Insets(12));
        VBox header = new VBox(8, new Label("Playback engine"), backend);
        header.setPadding(new Insets(12, 12, 0, 12));
        BorderPane root = new BorderPane(center, header, null, status, null);
        BorderPane.setMargin(status, new Insets(8, 12, 12, 12));
        stage.setTitle("Musicfy Windows — Playback Engine PoC");
        stage.setScene(new Scene(root, 680, 310));
        stage.show();
        switchBackend(backend.getValue());
        if (smokeMode) {
            sources.setText(String.join("\n", arguments.subList(2, arguments.size())));
            Platform.runLater(this::runSmoke);
        }
    }

    private void switchBackend(String name) {
        closeEngine();
        if (name == null) return;
        PlaybackEngine.Listener listener = new PlaybackEngine.Listener() {
            @Override public void onStatus(String message) {
                latestStatus = message;
                smokeEvents.add(message);
                System.out.println("[poc] " + message);
                status.setText(message);
            }
            @Override public void onPosition(long current, long duration, boolean seekable) {
                currentMillis = current;
                durationMillis = duration;
                canSeek = seekable;
                seek.setDisable(!seekable);
                if (!seek.isValueChanging() && seekable) seek.setValue(Math.min(1.0, (double) current / duration));
                time.setText(format(current) + " / " + (duration > 0 ? format(duration) : "--:--"));
            }
        };
        try {
            engine = name.startsWith("JavaFX") ? new JavaFxMediaEngine(listener) : new VlcLibVlcEngine(listener);
            status.setText("Ready — " + name);
        } catch (RuntimeException | LinkageError ex) {
            engine = null;
            String message = "Could not initialize " + name + ": " + safeMessage(ex);
            System.err.println("[poc] " + message);
            status.setText(message);
        }
    }

    private void startQueue() {
        if (engine == null) return;
        List<String> items = Arrays.stream(sources.getText().split("\\R"))
                .map(String::trim).filter(s -> !s.isEmpty()).toList();
        engine.setQueue(items);
        engine.play();
    }

    private void runSmoke() {
        if (engine == null) {
            System.err.println("SMOKE FAIL: selected backend could not initialize");
            finishSmoke(false);
            return;
        }
        smokeEvents.clear();
        latestStatus = "";
        smokeSeeked = false;
        smokePauseSeen = false;
        smokeNextStartEventIndex = 0;
        startQueue();
        Timeline pauseAndSeek = new Timeline(
                new KeyFrame(Duration.seconds(2.5), e -> withEngine(PlaybackEngine::pause)),
                new KeyFrame(Duration.seconds(3.2), e -> beginSmokeSeek())
        );
        pauseAndSeek.play();
    }

    private void beginSmokeSeek() {
        smokePauseSeen = smokeEvents.stream().anyMatch(s -> s.contains("PAUSED"));
        System.out.println("SMOKE pauseEvent=" + smokePauseSeen + " status=" + latestStatus);
        boolean seekAvailable = canSeek && durationMillis > 0;
        System.out.println("SMOKE seekAvailable=" + seekAvailable + " durationMs=" + durationMillis);
        if (!seekAvailable) {
            System.out.println("SMOKE seekReached=false reason=duration-or-seekability-unavailable");
            finishSmoke(false);
            return;
        }

        smokeSeekTarget = durationMillis / 2;
        smokeSeekTolerance = Math.max(SEEK_TOLERANCE_MIN_MS,
                Math.min(SEEK_TOLERANCE_MAX_MS, durationMillis / 20));
        smokeSeekBaseline = currentMillis;
        smokeSeekRequestedAtNanos = System.nanoTime();
        engine.seek(smokeSeekTarget);
        System.out.println("SMOKE seekRequested=true targetMs=" + smokeSeekTarget
                + " baselineMs=" + smokeSeekBaseline + " toleranceMs=" + smokeSeekTolerance);

        smokeSeekPoller = new Timeline(new KeyFrame(Duration.millis(SMOKE_POLL_INTERVAL_MS), e -> pollSmokeSeek()));
        smokeSeekPoller.setCycleCount(SMOKE_SEEK_TIMEOUT_MS / SMOKE_POLL_INTERVAL_MS);
        smokeSeekPoller.setOnFinished(e -> {
            if (!smokeSeeked) {
                System.out.println("SMOKE seekReached=false actualMs=" + currentMillis
                        + " targetMs=" + smokeSeekTarget + " timeoutMs=" + SMOKE_SEEK_TIMEOUT_MS);
                finishSmoke(false);
            }
        });
        smokeSeekPoller.play();

        // Some backends only publish timeChanged after playback resumes; keep observing actual position.
        smokeSeekResume = new PauseTransition(Duration.millis(250));
        smokeSeekResume.setOnFinished(e -> withEngine(PlaybackEngine::play));
        smokeSeekResume.play();
    }

    private void pollSmokeSeek() {
        long actual = currentMillis;
        long elapsedMs = (System.nanoTime() - smokeSeekRequestedAtNanos) / 1_000_000;
        long expectedWithoutSeek = smokeSeekBaseline + Math.max(0, elapsedMs - 250);
        boolean positionJumped = actual > expectedWithoutSeek + smokeSeekTolerance;
        if (positionJumped && Math.abs(actual - smokeSeekTarget) <= smokeSeekTolerance) {
            smokeSeeked = true;
            if (smokeSeekPoller != null) smokeSeekPoller.stop();
            System.out.println("SMOKE seekReached=true actualMs=" + actual + " targetMs=" + smokeSeekTarget
                    + " toleranceMs=" + smokeSeekTolerance);
            smokeAdvanceToNext = new PauseTransition(Duration.millis(350));
            smokeAdvanceToNext.setOnFinished(e -> beginSmokeNextTrack());
            smokeAdvanceToNext.play();
        }
    }

    private void beginSmokeNextTrack() {
        smokeNextStartEventIndex = smokeEvents.size();
        withEngine(PlaybackEngine::next);

        smokeNextTrackPoller = new Timeline(new KeyFrame(
                Duration.millis(SMOKE_POLL_INTERVAL_MS), e -> pollSmokeNextTrack()));
        smokeNextTrackPoller.setCycleCount(SMOKE_NEXT_TIMEOUT_MS / SMOKE_POLL_INTERVAL_MS);
        smokeNextTrackPoller.setOnFinished(e -> {
            boolean readyEvent = hasSecondTrackReadyEvent();
            boolean playingEvent = hasSecondTrackPlayingStatus();
            System.out.println("SMOKE nextTrackTimeout=true track2Event=" + readyEvent
                    + " track2Playing=" + playingEvent + " status=" + latestStatus);
            finishSmoke(false);
        });
        smokeNextTrackPoller.play();
    }

    private void pollSmokeNextTrack() {
        boolean readyEvent = hasSecondTrackReadyEvent();
        boolean playingEvent = hasSecondTrackPlayingStatus();
        if (readyEvent && playingEvent) {
            System.out.println("SMOKE nextTrackEvent=true track2Event=" + readyEvent
                    + " track2Playing=" + playingEvent + " status=" + latestStatus);
            finishSmoke(smokePauseSeen && smokeSeeked);
        }
    }

    private boolean hasSecondTrackReadyEvent() {
        int openingAt = findEventAfter(smokeNextStartEventIndex, "Opening item 2/2");
        if (openingAt < 0) return false;
        String expected = backend.getValue().startsWith("LibVLC")
                ? "READY — LibVLC item 2/2"
                : "READY — JavaFX Media item 2/2";
        return smokeEvents.subList(openingAt + 1, smokeEvents.size()).stream().anyMatch(s -> s.equals(expected));
    }

    private boolean hasSecondTrackPlayingStatus() {
        int openingAt = findEventAfter(smokeNextStartEventIndex, "Opening item 2/2");
        if (openingAt < 0) return false;
        String expected = backend.getValue().startsWith("LibVLC")
                ? "PLAYING — LibVLC item 2/2"
                : "JavaFX Media item 2/2: PLAYING";
        return smokeEvents.subList(openingAt + 1, smokeEvents.size()).stream().anyMatch(s -> s.equals(expected));
    }

    private int findEventAfter(int startIndex, String text) {
        for (int i = Math.max(0, startIndex); i < smokeEvents.size(); i++) {
            if (smokeEvents.get(i).contains(text)) return i;
        }
        return -1;
    }

    private void finishSmoke(boolean passed) {
        System.out.println(passed ? "SMOKE RESULT: PASS" : "SMOKE RESULT: FAIL");
        System.out.println("SMOKE OUTPUT: playback state/events only; audible output is not verified by this test.");
        closeEngine();
        Platform.exit();
        System.exit(passed ? 0 : 1);
    }

    private void seekToSlider() {
        if (engine != null && canSeek && durationMillis > 0) {
            engine.seek((long) (seek.getValue() * durationMillis));
        }
    }

    private void withEngine(java.util.function.Consumer<PlaybackEngine> action) {
        if (engine != null) action.accept(engine);
    }

    private void closeEngine() {
        stopSmokeTimers();
        if (engine != null) {
            try {
                engine.close();
            } catch (RuntimeException | LinkageError ex) {
                String message = "Engine shutdown warning: " + safeMessage(ex);
                System.err.println("[poc] " + message);
                status.setText(message);
            }
            engine = null;
        }
        canSeek = false;
        durationMillis = 0;
        seek.setDisable(true);
        seek.setValue(0);
        time.setText("00:00 / --:--");
    }

    private void stopSmokeTimers() {
        if (smokeSeekPoller != null) smokeSeekPoller.stop();
        if (smokeNextTrackPoller != null) smokeNextTrackPoller.stop();
        if (smokeSeekResume != null) smokeSeekResume.stop();
        if (smokeAdvanceToNext != null) smokeAdvanceToNext.stop();
    }

    private static String format(long millis) {
        long seconds = Math.max(0, millis / 1000);
        return String.format("%02d:%02d", seconds / 60, seconds % 60);
    }

    private static String safeMessage(Throwable error) {
        String message = error.getMessage();
        return message == null || message.isBlank() ? error.getClass().getSimpleName() : message;
    }

    @Override
    public void stop() {
        closeEngine();
    }

    public static void main(String[] args) {
        launch(args);
    }
}
