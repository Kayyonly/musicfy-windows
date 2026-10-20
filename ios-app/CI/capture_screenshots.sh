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

if [[ ! -d "$app_path" ]]; then
  echo "Built simulator app not found: $app_path" >&2
  exit 3
fi
mkdir -p "$out_dir"

# Build/test may leave the chosen simulator booted already. Reusing it avoids creating
# or downloading devices/runtimes and keeps this step within the selected destination.
xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app_path"
xcrun simctl status_bar "$device_id" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 \
  >/dev/null 2>&1 || true

for screen in home search library profile now-playing queue lyrics home-bottom; do
  echo "Capturing Musicfy iPhone screen: $screen"
  xcrun simctl terminate "$device_id" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl launch --terminate-running-process "$device_id" "$bundle_id" \
    -musicfy-screenshot "$screen"
  # Allow the initial SwiftUI layout and sheet/navigation transitions to settle.
  sleep 3
  xcrun simctl io "$device_id" screenshot "$out_dir/$screen.png"
  test -s "$out_dir/$screen.png"
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
    main{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px}
    figure{margin:0;padding:12px;background:#1b1b1d;border-radius:14px}
    img{display:block;width:100%;height:auto;border-radius:8px;background:#000}
    figcaption{padding-top:10px;font-weight:600}
  </style>
</head>
<body>
  <h1>Musicfy iPhone — simulator screenshots</h1>
  <p>Captured from the Debug build in an iPhone simulator. These images document the local UI prototype only; they do not demonstrate real audio playback or production-device compatibility.</p>
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
