#!/usr/bin/env python3
"""Serve the Godot Web export for MVP testing.

Usage:  python3 tools/serve_web.py            -> http://localhost:8060 (this Mac only)
        python3 tools/serve_web.py --lan      -> also reachable from phones on the same WiFi
        python3 tools/serve_web.py 9000       -> custom port

Serves export/web/. Correct MIME for .wasm/.pck, no-cache so new builds show up.
COOP/COEP headers are sent only with --threads (needed only if Thread Support is ON in the export preset).
"""
import http.server, os, socket, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "export", "web")
args = [a for a in sys.argv[1:] if not a.startswith("--")]
PORT = int(args[0]) if args else 8060
THREADS = "--threads" in sys.argv
LAN = "--lan" in sys.argv


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


def lan_ip():
    """IP of this computer on the local network (no packets are sent)."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return None
    finally:
        s.close()


if not os.path.isfile(os.path.join(ROOT, "index.html")):
    sys.exit("export/web/index.html belum ada. Export dulu dari Godot (lihat README).")

host = "0.0.0.0" if LAN else "127.0.0.1"
print(f"Jelajah-Kampung -> http://localhost:{PORT}")
if LAN:
    ip = lan_ip()
    if ip:
        print(f"Dari HP (WiFi yang sama) -> http://{ip}:{PORT}")
    else:
        print("Tidak menemukan IP WiFi. Cek: System Settings > Wi-Fi > Details > IP address")
print("Ctrl+C untuk berhenti")
http.server.ThreadingHTTPServer((host, PORT), Handler).serve_forever()
