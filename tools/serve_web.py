#!/usr/bin/env python3
"""Serve the Godot Web export on localhost for MVP testing.

Usage:  python3 tools/serve_web.py            -> http://localhost:8060
        python3 tools/serve_web.py 9000       -> custom port

Serves export/web/. Correct MIME for .wasm/.pck, no-cache so new builds show up.
COOP/COEP headers are sent only with --threads (needed only if Thread Support is ON in the export preset).
"""
import http.server, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "export", "web")
args = [a for a in sys.argv[1:] if not a.startswith("--")]
PORT = int(args[0]) if args else 8060
THREADS = "--threads" in sys.argv

class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map,
                      ".wasm": "application/wasm", ".pck": "application/octet-stream", ".js": "text/javascript"}

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        if THREADS:
            self.send_header("Cross-Origin-Opener-Policy", "same-origin")
            self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

if not os.path.isfile(os.path.join(ROOT, "index.html")):
    sys.exit("export/web/index.html belum ada. Export dulu dari Godot (lihat README).")

print(f"Jelajah-Kampung -> http://localhost:{PORT}  (Ctrl+C untuk berhenti)")
http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
