#!/usr/bin/env python3
"""Local-only HTTP fixture server for playback, header, and retry checks."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit
import argparse
import threading


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1] / "test-media")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--require-header", help="test-only header requirement, formatted NAME=VALUE")
    parser.add_argument("--fail-first", help="return HTTP 401 once for this request path, e.g. /sample.mp3")
    args = parser.parse_args()
    root = args.root.resolve()
    if not root.is_dir():
        raise SystemExit(f"Media directory does not exist: {root} (run generate_test_media.py first)")

    required = args.require_header.split("=", 1) if args.require_header else None
    if required and len(required) != 2:
        raise SystemExit("--require-header must be NAME=VALUE")
    fail_once_path = args.fail_first
    lock = threading.Lock()
    failed_once: set[str] = set()

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *handler_args, **handler_kwargs):
            super().__init__(*handler_args, directory=str(root), **handler_kwargs)

        def do_GET(self):
            request_path = urlsplit(self.path).path
            if required and self.headers.get(required[0]) != required[1]:
                self.send_error(401, "Test fixture requires the configured test-only header")
                return
            if fail_once_path and request_path == fail_once_path:
                with lock:
                    should_fail = request_path not in failed_once
                    failed_once.add(request_path)
                if should_fail:
                    self.send_error(401, "Test fixture returned one deliberate 401; press Retry")
                    return
            super().do_GET()

        def log_message(self, fmt, *values):
            # Deliberately log path/status only; no request headers or query parameters.
            print(f"{self.client_address[0]} {self.command} {urlsplit(self.path).path} - {fmt % values}")

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Serving {root} at http://{args.host}:{args.port}/")
    if required:
        print(f"Test-only required header: {required[0]} (value is not logged)")
    if fail_once_path:
        print(f"One deliberate HTTP 401 for {fail_once_path}; retry should request it again")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
