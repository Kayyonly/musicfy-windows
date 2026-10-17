#!/usr/bin/env python3
"""Generate short, original sine-wave audio fixtures with FFmpeg (no copyrighted media)."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "test-media"
HLS = OUT / "hls"


def run(args: list[str]) -> None:
    print("+", " ".join(args))
    subprocess.run(args, check=True)


def main() -> None:
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is required; install it and ensure it is on PATH")
    OUT.mkdir(parents=True, exist_ok=True)
    HLS.mkdir(parents=True, exist_ok=True)

    base = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-f", "lavfi"]
    run(base + ["-i", "sine=frequency=440:sample_rate=44100:duration=10",
                "-c:a", "libmp3lame", "-b:a", "128k", str(OUT / "sample.mp3")])
    run(base + ["-i", "sine=frequency=550:sample_rate=44100:duration=10",
                "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", str(OUT / "sample.m4a")])
    run(base + ["-i", "sine=frequency=660:sample_rate=44100:duration=12",
                "-c:a", "aac", "-b:a", "96k", "-f", "hls", "-hls_time", "3",
                "-hls_playlist_type", "vod", "-hls_segment_type", "fmp4",
                "-hls_fmp4_init_filename", "init.mp4",
                "-hls_segment_filename", str(HLS / "segment_%03d.m4s"),
                str(HLS / "sample.m3u8")])
    print(f"Generated legal local fixtures under {OUT}")
    print("HTTP URLs when served from the test server:")
    print("  http://127.0.0.1:8765/sample.mp3")
    print("  http://127.0.0.1:8765/sample.m4a")
    print("  http://127.0.0.1:8765/hls/sample.m3u8")


if __name__ == "__main__":
    main()
