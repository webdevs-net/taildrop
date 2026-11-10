#!/usr/bin/env python3
"""Tailnet Share daemon: serves token-scoped files over localhost HTTP.

Tailscale Serve proxies https://<node>.<tailnet>.ts.net:PORT/ to this server,
so only tailnet members can reach it. Each share lives under a random token.
Expired shares are pruned and return 404.
"""
import html
import http.server
import json
import mimetypes
import os
import socketserver
import sys
import time
import urllib.parse

ROOT = os.path.expanduser("~/Library/Application Support/TailnetShare")
SHARES = os.path.join(ROOT, "shares")
PORT = int(os.environ.get("TNSHARE_PORT", "8731"))


def load(token):
    meta_path = os.path.join(SHARES, token, "meta.json")
    try:
        with open(meta_path) as fh:
            meta = json.load(fh)
    except (OSError, ValueError):
        return None
    if meta.get("expires") and time.time() > meta["expires"]:
        return None
    return meta


def prune():
    try:
        tokens = os.listdir(SHARES)
    except OSError:
        return
    now = time.time()
    for token in tokens:
        meta_path = os.path.join(SHARES, token, "meta.json")
        try:
            with open(meta_path) as fh:
                meta = json.load(fh)
        except (OSError, ValueError):
            continue
        if meta.get("expires") and now > meta["expires"]:
            import shutil
            shutil.rmtree(os.path.join(SHARES, token), ignore_errors=True)


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "TailnetShare/1.0"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.address_string(), fmt % args))

    def fail(self, code=404):
        body = (b"Forbidden.\n" if code == 403 else b"Not found or expired.\n")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def resolve(self):
        """Map the request path to a real file inside a live share."""
        path = urllib.parse.unquote(urllib.parse.urlparse(self.path).path)
        parts = [p for p in path.split("/") if p not in ("", ".")]
        if not parts or ".." in parts:
            return None, None
        token = parts[0]
        meta = load(token)
        if meta is None:
            return None, None
        base = os.path.realpath(meta["path"])
        if not os.path.exists(base):
            return None, None
        if os.path.isdir(base):
            target = os.path.realpath(os.path.join(base, *parts[1:]))
            if target != base and not target.startswith(base + os.sep):
                return None, None
        else:
            # Single file: any name after the token maps to the file itself.
            target = base
        return meta, target

    def do_HEAD(self):
        self.serve(head=True)

    def do_GET(self):
        self.serve(head=False)

    def serve(self, head):
        meta, target = self.resolve()
        if meta is None or not os.path.exists(target):
            return self.fail()
        if os.path.isdir(target):
            return self.listing(target, head)
        return self.sendfile(target, head)

    def listing(self, target, head):
        names = sorted(os.listdir(target))
        rows = "\n".join(
            '<li><a href="%s">%s</a></li>'
            % (urllib.parse.quote(n), html.escape(n))
            for n in names
        )
        body = ("<!doctype html><meta charset=utf-8><title>Shared</title>"
                "<ul>%s</ul>" % rows).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def sendfile(self, target, head):
        # Open before any header goes out, so a read failure is a clean error
        # rather than a truncated download.
        try:
            fh = open(target, "rb")
        except OSError as exc:
            self.log_message("cannot open %s: %s", target, exc)
            return self.fail(403 if isinstance(exc, PermissionError) else 404)
        with fh:
            self.sendopen(fh, target, head)

    def sendopen(self, fh, target, head):
        size = os.fstat(fh.fileno()).st_size
        ctype = mimetypes.guess_type(target)[0] or "application/octet-stream"
        start, end = 0, size - 1
        status = 200
        rng = self.headers.get("Range")
        if rng and rng.startswith("bytes="):
            try:
                first, _, last = rng[6:].partition("-")
                if first:
                    start = int(first)
                    end = int(last) if last else size - 1
                else:  # suffix range: bytes=-N
                    start = max(0, size - int(last))
                if start >= size or start > end:
                    raise ValueError
                end = min(end, size - 1)
                status = 206
            except ValueError:
                self.send_response(416)
                self.send_header("Content-Range", "bytes */%d" % size)
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
        length = end - start + 1
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(length))
        self.send_header("Accept-Ranges", "bytes")
        self.send_header(
            "Content-Disposition",
            'attachment; filename*=UTF-8\'\'%s'
            % urllib.parse.quote(os.path.basename(target)),
        )
        if status == 206:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
        self.end_headers()
        if head:
            return
        fh.seek(start)
        remaining = length
        while remaining > 0:
            chunk = fh.read(min(1 << 20, remaining))
            if not chunk:
                break
            try:
                self.wfile.write(chunk)
            except (BrokenPipeError, ConnectionResetError):
                return
            remaining -= len(chunk)


class Server(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    os.makedirs(SHARES, exist_ok=True)
    prune()
    with Server(("127.0.0.1", PORT), Handler) as httpd:
        httpd.serve_forever()


if __name__ == "__main__":
    main()
