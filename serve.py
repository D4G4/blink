#!/usr/bin/env python3
"""Tiny static server for the Blink site preview that disables caching, so
every reload reflects the latest edits (avoids stale .jsx/HTML during dev)."""
import http.server
import socketserver
import sys

port = int(sys.argv[1]) if len(sys.argv) > 1 else 4555
directory = sys.argv[2] if len(sys.argv) > 2 else "website"


class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        super().end_headers()


with socketserver.TCPServer(("", port), NoCacheHandler) as httpd:
    httpd.serve_forever()
