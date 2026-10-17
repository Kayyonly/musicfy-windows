package musicfy.poc;

import javafx.application.Application;
import javafx.application.Platform;
import javafx.animation.KeyFrame;
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
    private boolean smokeSeekRequested;
    private boolean smokeSeeked;
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
            status.setText("Could not initialize " + name + ": " + safeMessage(ex));
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
        startQueue();
        Timeline timeline = new Timeline(
                new KeyFrame(Duration.seconds(2.5), e -> withEngine(PlaybackEngine::pause)),
                new KeyFrame(Duration.seconds(3.2), e -> {
                    boolean paused = smokeEvents.stream().anyMatch(s -> s.contains("PAUSED"));
                    System.out.println("SMOKE pause=" + paused + " status=" + latestStatus);
                    boolean seekAvailable = canSeek && durationMillis > 0;
                    System.out.println("SMOKE seekAvailable=" + seekAvailable + " durationMs=" + durationMillis);
                    if (seekAvailable) {
                        smokeSeekTarget = durationMillis / 2;
                        smokeSeekRequested = true;
                        engine.seek(smokeSeekTarget);
                    }
                }),
                new KeyFrame(Duration.seconds(4.0), e -> {
                    smokeSeeked = smokeSeekRequested && Math.abs(currentMillis - smokeSeekTarget) < 1500;
                    System.out.println("SMOKE seeked=" + smokeSeeked + " currentMs=" + currentMillis
                            + " targetMs=" + smokeSeekTarget);
                    withEngine(PlaybackEngine::play);
                }),
                new KeyFrame(Duration.seconds(5.0), e -> withEngine(PlaybackEngine::next)),
                new KeyFrame(Duration.seconds(8.5), e -> {
                    int nextOpenedAt = -1;
                    for (int i = 0; i < smokeEvents.size(); i++) {
                        if (smokeEvents.get(i).contains("Opening item 2/")) {
                            nextOpenedAt = i;
                            break;
                        }
                    }
                    boolean nextOpened = nextOpenedAt >= 0;
                    boolean nextPlaying = nextOpened && smokeEvents.subList(nextOpenedAt + 1, smokeEvents.size())
                            .stream().anyMatch(s -> s.contains("PLAYING"));
                    boolean pauseSeen = smokeEvents.stream().anyMatch(s -> s.contains("PAUSED"));
                    System.out.println("SMOKE nextOpened=" + nextOpened + " nextPlaying=" + nextPlaying
                            + " pausedEvent=" + pauseSeen + " seeked=" + smokeSeeked + " currentStatus=" + latestStatus);
                    finishSmoke(nextOpened && pauseSeen && smokeSeeked && nextPlaying);
                })
        );
        timeline.play();
    }

    private void finishSmoke(boolean passed) {
        System.out.println(passed ? "SMOKE RESULT: PASS" : "SMOKE RESULT: FAIL");
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
        if (engine != null) {
            try { engine.close(); } catch (RuntimeException | LinkageError ex) { status.setText("Engine shutdown warning: " + safeMessage(ex)); }
            engine = null;
        }
        canSeek = false;
        durationMillis = 0;
        seek.setDisable(true);
        seek.setValue(0);
        time.setText("00:00 / --:--");
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
