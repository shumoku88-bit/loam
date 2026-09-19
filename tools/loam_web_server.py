#!/usr/bin/env python3
from __future__ import annotations

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys


HOST = "127.0.0.1"
PORT = 8765


def render_current(generator: Path, data_dir: str) -> bytes:
    completed = subprocess.run(
        [str(generator), data_dir, "-"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        message = completed.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(message or f"loamWeb exited with status {completed.returncode}")
    return completed.stdout


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: loam_web_server.py LOAM_WEB_BINARY LOAM_DATA_DIR", file=sys.stderr)
        return 2

    generator = Path(sys.argv[1]).resolve()
    data_dir = sys.argv[2]

    class Handler(BaseHTTPRequestHandler):
        def _send_document(self, include_body: bool) -> None:
            if self.path not in ("/", "/index.html"):
                self.send_error(404, "Not Found")
                return

            try:
                body = render_current(generator, data_dir)
            except RuntimeError as error:
                message = ("LOAM Web unavailable: " + str(error) + "\n").encode("utf-8")
                self.send_response(500)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Cache-Control", "no-store, max-age=0")
                self.send_header("Content-Length", str(len(message)))
                self.end_headers()
                if include_body:
                    self.wfile.write(message)
                return

            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if include_body:
                self.wfile.write(body)

        def do_GET(self) -> None:
            self._send_document(include_body=True)

        def do_HEAD(self) -> None:
            self._send_document(include_body=False)

        def log_message(self, format: str, *args: object) -> None:
            print("LOAM Web:", format % args, file=sys.stderr)

    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"LOAM Web: http://{HOST}:{PORT}")
    print("read-only request-on-read; reload to reread canonical evidence")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
