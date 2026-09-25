#!/usr/bin/env python3
from __future__ import annotations

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import secrets
import subprocess
import sys
from urllib.parse import parse_qs


HOST = "127.0.0.1"
PORT = 8765


def run_generator(generator: Path, args: list[str]) -> bytes:
    completed = subprocess.run(
        [str(generator), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if completed.returncode != 0:
        message = completed.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(message or f"loamWeb exited with status {completed.returncode}")
    return completed.stdout


def render_current(generator: Path, data_dir: str) -> bytes:
    return run_generator(generator, [data_dir, "-"])


def render_record_form(generator: Path, data_dir: str, operation: str) -> bytes:
    return run_generator(generator, ["--record-form", data_dir, operation])


def render_record_preview(
    generator: Path, data_dir: str, fields: dict[str, str]
) -> bytes:
    return run_generator(
        generator,
        [
            "--record-preview",
            data_dir,
            fields["operation"],
            fields["date"],
            fields["description"],
            fields["measure"],
            fields["from_locus"],
            fields["from_amount"],
            fields["to_locus"],
            fields["to_amount"],
        ],
    )


def render_record_confirm(
    generator: Path, data_dir: str, fields: dict[str, str]
) -> bytes:
    return run_generator(
        generator,
        [
            "--record-confirm",
            data_dir,
            fields["operation"],
            fields["date"],
            fields["description"],
            fields["measure"],
            fields["from_locus"],
            fields["from_amount"],
            fields["to_locus"],
            fields["to_amount"],
        ],
    )


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: loam_web_server.py LOAM_WEB_BINARY LOAM_DATA_DIR", file=sys.stderr)
        return 2

    generator = Path(sys.argv[1]).resolve()
    data_dir = sys.argv[2]

    class Handler(BaseHTTPRequestHandler):
        def _send_html(self, body: bytes, include_body: bool = True) -> None:
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.send_header("Pragma", "no-cache")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if include_body:
                self.wfile.write(body)

        def _send_runtime_error(self, error: RuntimeError, include_body: bool = True) -> None:
            message = ("LOAM Web unavailable: " + str(error) + "\n").encode("utf-8")
            self.send_response(500)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Cache-Control", "no-store, max-age=0")
            self.send_header("Content-Length", str(len(message)))
            self.end_headers()
            if include_body:
                self.wfile.write(message)

        def _render_get(self) -> bytes | None:
            if self.path in ("/", "/index.html"):
                return render_current(generator, data_dir)
            if self.path == "/record":
                operation = "web-" + secrets.token_hex(16)
                return render_record_form(generator, data_dir, operation)
            return None

        def do_GET(self) -> None:
            try:
                body = self._render_get()
            except RuntimeError as error:
                self._send_runtime_error(error)
                return
            if body is None:
                self.send_error(404, "Not Found")
                return
            self._send_html(body)

        def do_HEAD(self) -> None:
            try:
                body = self._render_get()
            except RuntimeError as error:
                self._send_runtime_error(error, include_body=False)
                return
            if body is None:
                self.send_error(404, "Not Found")
                return
            self._send_html(body, include_body=False)

        def do_POST(self) -> None:
            if self.path not in ("/record/preview", "/record/confirm"):
                self.send_error(404, "Not Found")
                return
            content_type = self.headers.get("Content-Type", "")
            if not content_type.startswith("application/x-www-form-urlencoded"):
                self.send_error(415, "Expected form-encoded input")
                return
            try:
                length = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                self.send_error(400, "Invalid Content-Length")
                return
            if length < 0 or length > 16384:
                self.send_error(413, "Form too large")
                return
            try:
                raw = self.rfile.read(length).decode("utf-8", errors="strict")
                parsed = parse_qs(raw, keep_blank_values=True, max_num_fields=16)
            except (UnicodeDecodeError, ValueError):
                self.send_error(400, "Malformed form input")
                return

            names = (
                "operation",
                "date",
                "description",
                "measure",
                "from_locus",
                "from_amount",
                "to_locus",
                "to_amount",
            )
            fields: dict[str, str] = {}
            for name in names:
                values = parsed.get(name)
                if values is None or len(values) != 1:
                    self.send_error(400, f"Expected one {name} field")
                    return
                fields[name] = values[0]

            try:
                if self.path == "/record/preview":
                    body = render_record_preview(generator, data_dir, fields)
                else:
                    body = render_record_confirm(generator, data_dir, fields)
            except RuntimeError as error:
                self._send_runtime_error(error)
                return
            self._send_html(body)

        def log_message(self, format: str, *args: object) -> None:
            print("LOAM Web:", format % args, file=sys.stderr)

    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"LOAM Web: http://{HOST}:{PORT}")
    print("request-on-read plus explicit retry-safe Record confirmation")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
