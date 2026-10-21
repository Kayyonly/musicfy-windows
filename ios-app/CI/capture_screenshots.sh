#!/usr/bin/env bash
set -euo pipefail

: "${MUSICFY_DESTINATION:?Missing selected simulator destination from CI selection step}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required on the GitHub-hosted runner}"

# MUSICFY_DESTINATION is written by select_destination.py and contains a validated UUID.
device_id="${MUSICFY_DESTINATION##*id=}"
if [[ ! "$device_id" =~ ^[A-Fa-f0-9-]{36}$ ]]; then
  echo "Invalid simulator destination; refusing to launch screenshot capture." >&2
  exit 2
fi

bundle_id="com.musicfy.MusicfyIOS"
app_path="$RUNNER_TEMP/MusicfyIOS-DerivedData/Build/Products/Debug-iphonesimulator/MusicfyIOS.app"
out_dir="CI-output/screenshots"
settle_seconds="${MUSICFY_SCREENSHOT_SETTLE_SECONDS:-3}"
routes=(home search library profile now-playing queue lyrics home-bottom)
mkdir -p "$out_dir"

collect_diagnostics() {
  status=$?
  {
    printf 'capture_exit_status=%s\n' "$status"
    printf 'destination=%s\n' "$MUSICFY_DESTINATION"
    printf 'device_id=%s\n' "$device_id"
    printf 'settle_seconds=%s\n' "$settle_seconds"
    date -u '+captured_at_utc=%Y-%m-%dT%H:%M:%SZ'
    xcrun simctl list devices "$device_id" 2>&1 || true
    xcrun simctl list runtimes 2>&1 || true
  } > "$out_dir/diagnostics.txt"
  if [[ $status -ne 0 ]]; then
    xcrun simctl spawn "$device_id" log show --last 2m --style compact \
      --predicate 'process == "MusicfyIOS"' > "$out_dir/app-log.txt" 2>&1 || true
  fi
  return "$status"
}
trap collect_diagnostics EXIT

if [[ ! -d "$app_path" ]]; then
  echo "Built simulator app not found: $app_path" >&2
  exit 3
fi

# Build/test may leave the chosen simulator booted already. Reusing it avoids creating
# or downloading devices/runtimes and keeps this step within the selected destination.
xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app_path"
xcrun simctl status_bar "$device_id" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 \
  >/dev/null 2>&1 || true

for screen in "${routes[@]}"; do
  echo "Capturing Musicfy iPhone screen: $screen"
  xcrun simctl terminate "$device_id" "$bundle_id" >/dev/null 2>&1 || true
  # Clear stale metadata before every launch so a prior route cannot satisfy this one.
  data_container="$(xcrun simctl get_app_container "$device_id" "$bundle_id" data)"
  readiness_file="$data_container/Documents/musicfy-screenshot-ready.json"
  rm -f "$readiness_file"
  xcrun simctl launch --terminate-running-process "$device_id" "$bundle_id" \
    -musicfy-screenshot "$screen"
  readiness_deadline=$((SECONDS + 20))
  readiness_ok=false
  while (( SECONDS < readiness_deadline )); do
    if [[ -f "$readiness_file" ]] && python3 - "$readiness_file" "$screen" <<'PY'
import json
import sys
from pathlib import Path
path, route = sys.argv[1:]
try:
    payload = json.loads(Path(path).read_text())
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)
expected = {"route": route, "ready": True}
if route == "home-bottom":
    expected["bottomVisible"] = True
raise SystemExit(0 if payload == expected else 1)
PY
    then
      readiness_ok=true
      break
    fi
    sleep 1
  done
  if [[ "$readiness_ok" != true ]]; then
    echo "Readiness timeout or invalid JSON for route: $screen" >&2
    echo "Expected route readiness was not observed within 20 seconds." >&2
    exit 5
  fi
  cp "$readiness_file" "$out_dir/$screen-readiness.json"
  # Readiness confirms the destination mounted and required geometry marker is present.
  # Allow SwiftUI layout and sheet/navigation transitions to settle before capture.
  sleep "$settle_seconds"
  for attempt in 1 2 3; do
    if xcrun simctl io "$device_id" screenshot "$out_dir/$screen.png" >/dev/null 2>&1 &&
       test -s "$out_dir/$screen.png"; then
      break
    fi
    [[ "$attempt" -eq 3 ]] && { echo "Could not capture route: $screen" >&2; exit 4; }
    sleep 1
  done
done

cat > "$out_dir/index.html" <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Musicfy iPhone UI screenshots</title>
  <style>
    body{margin:0;padding:24px;background:#111;color:#f5f5f7;font:16px system-ui,sans-serif}
    h1{font-size:24px}p{color:#aaa;max-width:800px;line-height:1.5}
    nav{display:flex;flex-wrap:wrap;gap:8px;margin:16px 0 24px}
    nav a{color:#b8d8ff;padding:8px 12px;border-radius:8px;background:#25252a}
    main{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px}
    figure{margin:0;padding:12px;background:#1b1b1d;border-radius:14px}
    img{display:block;width:100%;height:auto;border-radius:8px;background:#000}
    figcaption{padding-top:10px;font-weight:600}
  </style>
</head>
<body>
  <h1>Musicfy iPhone — simulator screenshots</h1>
  <p>Captured from the Debug build in an existing installed iPhone simulator. These images document the local UI prototype only; they do not demonstrate real audio playback, production-device compatibility, or visual correctness on a physical device.</p>
  <nav aria-label="Screenshot routes">
    <a href="home.png">Home</a><a href="search.png">Search</a><a href="library.png">Library</a><a href="profile.png">Profile</a><a href="now-playing.png">Now Playing</a><a href="queue.png">Queue</a><a href="lyrics.png">Lyrics</a><a href="home-bottom.png">Home — bottom</a><a href="diagnostics.txt">Diagnostics</a>
  </nav>
  <main>
    <figure><a href="home.png"><img src="home.png" alt="Home screen"></a><figcaption>Home</figcaption></figure>
    <figure><a href="search.png"><img src="search.png" alt="Search screen"></a><figcaption>Search</figcaption></figure>
    <figure><a href="library.png"><img src="library.png" alt="Library screen"></a><figcaption>Library</figcaption></figure>
    <figure><a href="profile.png"><img src="profile.png" alt="Profile screen"></a><figcaption>Profile</figcaption></figure>
    <figure><a href="now-playing.png"><img src="now-playing.png" alt="Now Playing screen"></a><figcaption>Now Playing</figcaption></figure>
    <figure><a href="queue.png"><img src="queue.png" alt="Queue screen"></a><figcaption>Queue</figcaption></figure>
    <figure><a href="lyrics.png"><img src="lyrics.png" alt="Lyrics screen"></a><figcaption>Lyrics</figcaption></figure>
    <figure><a href="home-bottom.png"><img src="home-bottom.png" alt="Home screen scrolled to bottom"></a><figcaption>Home — bottom</figcaption></figure>
  </main>
</body>
</html>
HTML

echo "Screenshot gallery created in $out_dir/index.html"
