# Musicfy Windows Playback Engine PoC

Standalone desktop experiment comparing **JavaFX Media** with **vlcj 4.x + native LibVLC**. It is only a small test harness, not the Musicfy product UI. Android sources and build configuration are outside this experiment and remain unchanged.

The harness provides the controls needed to compare the backends: load a queue, play, pause, resume, seek, skip, and retry. Generated fixtures are short original sine waves; no copyrighted/provider media or credentials are included.

## Build and run

Requirements: JDK 21, Python 3, and FFmpeg on `PATH` to create local samples.

From this directory, in PowerShell:

```powershell
python .\scripts\generate_test_media.py
.\gradlew.bat clean build
.\gradlew.bat run
```

On Linux/macOS use `python3 scripts/generate_test_media.py`, `./gradlew clean build`, and `./gradlew run`.

To serve the generated media over HTTP, start a second terminal in this directory:

```powershell
python .\scripts\http_fixture.py --root .\test-media --port 8765
```

Enter these URLs in the harness, one per line, and select an engine:

- `http://127.0.0.1:8765/sample.mp3`
- `http://127.0.0.1:8765/sample.m4a`
- `http://127.0.0.1:8765/hls/sample.m3u8`

Automated local-file smoke mode checks play, pause, seek, resume, and next on a pair of files. On Windows, after generating fixtures, run each command separately:

```powershell
.\gradlew.bat run --args="--smoke javafx .\test-media\sample.mp3 .\test-media\sample.m4a"
.\gradlew.bat run --args="--smoke vlc .\test-media\sample.mp3 .\test-media\sample.m4a"
```

For a one-command Windows setup, use `powershell -ExecutionPolicy Bypass -File .\windows-smoke.ps1` if the local execution policy blocks the script. It builds, generates fixtures, starts the local HTTP server, and opens the manual harness. Close the harness to stop the server.

For a deliberate first-request failure and manual retry check, launch the fixture server with `--fail-first /sample.mp3`. Load that MP3; the fixture returns one HTTP 401, then press **Retry current**. To exercise a provider-header requirement, launch with `--require-header X-PoC-Only=musicfy-test`. This is a non-secret test fixture value. Neither backend is configured to inject arbitrary custom headers in this PoC; JavaFX Media has no documented per-request header argument, and the exact LibVLC options/header behavior still needs an end-to-end test against the required Windows runtime and provider.

## Candidate comparison

| Capability | JavaFX Media 21.0.12 | vlcj 4.12.1 + LibVLC 3.x |
|---|---|---|
| Core controls | `MediaPlayer` documents play, pause, seek, async status/error, duration, and buffer progress. | Native controls/events provide play, pause, time, seek, and buffering; next is scheduled off LibVLC's native callback thread. |
| MP3/AAC | Documented MP3 and AAC support, subject to supported container/profile details. | Broad codec capability is expected from LibVLC, but the exact runtime/plugin build still needs playback tests. |
| HLS | Documented HLS profiles include audio MP3 and audio-only AAC/fMP4; non-conforming profiles are not guaranteed. | Depends on the specific LibVLC build/plugins; not claimed tested or guaranteed here. |
| HTTP | HTTP/HTTPS is documented. | HTTP is a native input path; exact provider/CDN behavior remains to test. |
| Arbitrary custom headers | No public JavaFX Media API for arbitrary per-request headers is documented. A short-lived local proxy or provider-issued signed URL is a possible workaround to validate. | Per-media input options exist, but option names/semantics vary by LibVLC build. Arbitrary `Authorization` or provider-specific headers are not established by this PoC. |
| Runtime/distribution | JavaFX native modules must match the target platform; package the Windows runtime/image. No separate VLC plugin tree. | Needs matching LibVLC DLLs and plugin/data tree in addition to vlcj/JNA. `vlcj-natives` is not a substitute for the VLC runtime. Validate architecture and DLL/plugin discovery. |
| License notes | OpenJFX is GPL with the Classpath Exception; verify exact runtime notices. | `vlcj` and `vlcj-natives` declare GPL v3 (the vlcj 4 README says v3 or later), compatible with this fork's GPL-3.0 license. JNA 5.16.0 is dual-licensed LGPL-2.1-or-later or Apache-2.0. VideoLAN describes the LibVLC core as LGPL-2.1; audit each distributed plugin/codec separately. |

The selected vlcj 4.12.1 release documents JDK 11+ and VLC 3.0.0+ (Windows is supported upstream); this standalone build uses JDK 21. The version line is pinned because vlcj 5 milestones require the VLC 4 development runtime and are not interchangeable with this setup.

### Initial recommendation (not a final engine decision)

If Musicfy needs only the documented MP3/AAC and standard HLS profiles over ordinary HTTP(S), JavaFX Media is the lower-integration-cost baseline: it fits a JavaFX desktop shell and avoids a separate VLC plugin/DLL tree. If providers require arbitrary request headers, less common formats, or broader HLS behavior, neither engine is accepted yet. LibVLC may be more adaptable, but that must be demonstrated with the real provider protocol, Windows runtime, and license/packaging audit. Do not begin a migration from this PoC alone.

## Verification status and evidence

- Repository: fork `Kayyonly/musicfy-windows`, starting commit `67c88a2066cffadd766f883384c020798f2b5561`; new branch `feat/windows-playback-poc`.
- `./gradlew clean build`: **passed on Linux x86_64 with OpenJDK 21.0.12.1**. This resolves dependencies and compiles both adapters; it is not playback-compatibility evidence.
- `python3 scripts/generate_test_media.py` and `ffprobe`: **passed** for 10-second MP3, 10-second AAC/M4A, and 12-second AAC/fMP4 HLS fixtures.
- Local fixture HTTP checks: **passed** — plain MP3 and HLS playlist returned HTTP 200; header challenge returned 401 without the test header and 200 with it; fail-once fixture returned 401 then 200 on the following request.
- JavaFX runtime smoke test on Linux: **failed before playback controls could be verified**. The log reported `Could not create player!` and `Could not open audio device for playback.` `/dev/snd` is absent, PulseAudio was unavailable, and a usable audio sink could not be established. No audible playback is claimed.
- vlcj/LibVLC runtime playback, actual HTTP media playback, custom header injection, HLS playback, buffering/recovery in an engine, URL-expiry refresh, memory use, Windows native compatibility, and DLL packaging: **not verified**. The current host is Linux, not Windows. Use the Windows runner procedure; never infer runtime success from compilation.
- Resolved runtime dependencies: JavaFX controls/media `21.0.12`; `vlcj 4.12.1` → `vlcj-natives 4.12.0` → JNA/JNA-platform `5.16.0`. The fork's root [`LICENSE`](../LICENSE) is GNU GPL v3.
- No secrets/cookies/provider keys are part of the PoC. Never paste credential-bearing provider URLs into a committed file or test log.

## LibVLC audio-output and COM diagnostics

On Windows, the LibVLC adapter requests DirectSound at instance startup using `--aout=directsound`, passed through vlcj 4.x's `MediaPlayerFactory` arguments. This is a diagnostic configuration, not evidence that the output initialized or that sound was heard. To compare the installed VLC 3.x runtime, set `MUSICFY_VLC_AOUT` to `directsound`, `mmdevice`, or `default` before launching. `default` omits the `--aout` argument so LibVLC chooses its default module. A build without the selected module may reject the startup option; the harness intentionally reports that initialization error instead of silently falling back.

The `mmdevice audio output error: cannot initialize COM (error 0x80010106)` message is not proof that DirectSound will fix playback. Microsoft documents `RPC_E_CHANGED_MODE` as an incompatible COM concurrency model already initialized on that same thread. This PoC does not call `CoInitializeEx` itself. vlcj callbacks arrive on native threads; they only publish to the JavaFX thread, and player controls plus factory/player release are kept on that UI thread. Do not add speculative COM initialization calls. Compare the output choices on the target Windows machine and retain the complete native VLC log.

The smoke test waits asynchronously for an actual position update near the requested midpoint, with a bounded tolerance, and rejects ordinary forward progress as proof of a seek. It also waits for the second track's `mediaPlayerReady`/`READY` event and its own `PLAYING` status; buffering alone is not sufficient. `SMOKE RESULT: PASS` proves only the observed state/events, never audible output.

## Windows runner procedure

1. Use a Windows x64 runner with JDK 21, Python 3, and FFmpeg. To test LibVLC, install a matching VLC 3.x x64 runtime and set `$env:VLC_HOME` to the installation directory. Do not mix VLC 4 development files with vlcj 4.12.1.
2. Generate samples with `python .\scripts\generate_test_media.py`, then run `powershell -ExecutionPolicy Bypass -File .\windows-smoke.ps1` from this directory. If VLC is installed elsewhere, set `$env:VLC_HOME` first.
3. Run the two automated local-file smoke commands above, one engine at a time. A pass means the harness observed pause, an actual seek result, and the second track's event plus `PLAYING` state. It does not establish audible playback; verify the speakers/headphones manually with both local sample formats.
4. For each LibVLC audio-output option, run this PowerShell command from `windows-poc` after generating the fixtures. Capture the startup options and all native VLC messages, including COM/audio errors, for each run:

   ```powershell
   # DirectSound
   $env:MUSICFY_VLC_AOUT = "directsound"
   .\gradlew.bat run --args="--smoke vlc .\test-media\sample.mp3 .\test-media\sample.m4a"

   # LibVLC default output
   $env:MUSICFY_VLC_AOUT = "default"
   .\gradlew.bat run --args="--smoke vlc .\test-media\sample.mp3 .\test-media\sample.m4a"

   # Windows Media Device (MMDevice)
   $env:MUSICFY_VLC_AOUT = "mmdevice"
   .\gradlew.bat run --args="--smoke vlc .\test-media\sample.mp3 .\test-media\sample.m4a"

   Remove-Item Env:MUSICFY_VLC_AOUT
   ```
5. Test each engine with the HTTP URLs and HLS playlist in the UI. Record displayed status and whether audio is audible. Test seeks near the start/middle/end; HLS live streams may have different seek semantics than these VOD fixtures.
6. For a deliberate one-time failure, run `python .\scripts\http_fixture.py --root .\test-media --port 8765 --fail-first /sample.mp3` in place of the normal server; observe the first 401 and check whether manual Retry recovers.
7. For custom-header validation, run the fixture with `--require-header X-PoC-Only=musicfy-test`. Inspect actual outgoing requests or use a non-production provider test endpoint. This PoC does not claim arbitrary header injection; a local proxy/signed-URL workaround needs its own end-to-end test.
8. For memory and distribution, capture idle/playing working set and private bytes with Windows Performance Monitor. Inspect packaged files for JavaFX native modules (JavaFX route), or `libvlc.dll`, `libvlccore.dll`, and the complete compatible plugin tree (LibVLC route). Record OS/architecture, JDK, JavaFX, vlcj, LibVLC, and plugin versions.

## Sources

- [JavaFX Media package API](https://openjfx.io/javadoc/21/javafx.media/javafx/scene/media/package-summary.html) — MP3/AAC/HLS profiles and HTTP(S) support.
- [JavaFX MediaPlayer API](https://openjfx.io/javadoc/21/javafx.media/javafx/scene/media/MediaPlayer.html) — asynchronous status, controls, seek, duration, and buffer-progress properties.
- [OpenJFX project](https://openjfx.io/) — OpenJFX licensing statement (GPL with the Classpath Exception).
- [vlcj 4.12.1 release POM](https://repo.maven.apache.org/maven2/uk/co/caprica/vlcj/4.12.1/vlcj-4.12.1.pom) — exact version, Java target, GPL v3 metadata, and `vlcj-natives` dependency.
- [vlcj 4.x README](https://raw.githubusercontent.com/caprica/vlcj/vlcj-4.x/README.md) — JDK 11+, minimum VLC 3.0, Windows support, callback threading warning, and GPL v3-or-later statement.
- [vlcj 4.x Media Info tutorial](https://capricasoftware.co.uk/tutorials/vlcj/4/media-info) — recommends waiting for `mediaPlayerReady` when checking media state instead of treating `playing` as readiness.
- [vlcj-natives 4.12.0 POM](https://repo.maven.apache.org/maven2/uk/co/caprica/vlcj-natives/4.12.0/vlcj-natives-4.12.0.pom) — transitive native binding dependency and GPL v3 metadata.
- [JNA 5.16.0 POM](https://repo.maven.apache.org/maven2/net/java/dev/jna/jna-jpms/5.16.0/jna-jpms-5.16.0.pom) — declares LGPL-2.1-or-later or Apache-2.0.
- [vlcj project README](https://github.com/caprica/vlcj) — distinguish vlcj 5/LibVLC 4 development notes from stable vlcj 4.
- [LibVLC media options API](https://videolan.videolan.me/vlc-3.0/group__libvlc__media.html) — per-media options and warning that option names/semantics vary across builds.
- [LibVLC 3.0 `libvlc_new` API](https://videolan.videolan.me/vlc-3.0/group__libvlc__core.html) — accepts VLC command-line-like startup arguments; validity depends on build, platform, and plugins, and is not guaranteed across versions.
- [VLC 3.0 DirectSound module](https://github.com/videolan/vlc-3.0/blob/master/modules/audio_output/directsound.c) — confirms the `directsound` module alias used by the startup option.
- [Microsoft `CoInitializeEx` reference](https://learn.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-coinitializeex) — defines `RPC_E_CHANGED_MODE` as an incompatible COM concurrency model already initialized on the calling thread.
- [VideoLAN LibVLC overview](https://www.videolan.org/vlc/libvlc.html) — platform and LibVLC core license overview.

This is an engineering comparison, not legal advice. Review exact dependencies, native libraries, codecs/plugins, and notices before redistribution.
