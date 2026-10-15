#!/usr/bin/env python3
"""Local HTTP gate the T3 Gate extension asks whether to block a site.

Listens on 127.0.0.1 and answers GET /status with

    {"busy": bool, "checkedAt": iso, "hosts": {"<label>": {"ok": bool, "running": int}}}

Busy is true when this host, or any host reachable over SSH, has a T3 Code run
with status 'running'. Unreachable hosts count as not busy: nothing is running
there, which is exactly the case that should keep the block in place.

Remotes come from T3_GATE_REMOTES (space separated SSH targets) and are queried
with the fleet-wide `t3-running-count` helper. A short cache keeps a poll from
hammering SSH.
"""
import json
import os
import subprocess
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote

PORT = int(os.environ.get("T3_GATE_PORT", "4599"))
REMOTES = [h for h in os.environ.get("T3_GATE_REMOTES", "").split() if h]
CACHE_SECONDS = float(os.environ.get("T3_GATE_CACHE", "8"))
SSH_TIMEOUT = os.environ.get("T3_GATE_SSH_TIMEOUT", "5")

DB_RELATIVE = os.path.join("userdata", "statev2.sqlite")
RUNNING_SQL = (
    "select count(*) from orchestration_v2_projection_runs where status = 'running'"
)


def db_path():
    home = os.environ.get("T3CODE_HOME") or os.path.join(os.path.expanduser("~"), ".t3")
    return os.path.join(home, DB_RELATIVE)


def local_running():
    import sqlite3

    path = db_path()
    if not os.path.exists(path):
        return 0
    try:
        con = sqlite3.connect("file:%s?mode=ro" % quote(path), uri=True, timeout=2)
    except sqlite3.Error:
        return 0
    try:
        return int(con.execute(RUNNING_SQL).fetchone()[0])
    except sqlite3.Error:
        return 0
    finally:
        con.close()


def remote_running(host):
    cmd = [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=%s" % SSH_TIMEOUT,
        "-o",
        "StrictHostKeyChecking=accept-new",
        host,
        "t3-running-count",
    ]
    try:
        out = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=float(SSH_TIMEOUT) + 4,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0:
        return None
    for line in out.stdout.splitlines():
        line = line.strip()
        if line.isdigit():
            return int(line)
    return None


def snapshot():
    hosts = {}
    local = local_running()
    hosts[os.uname().nodename] = {"ok": True, "running": local}
    busy = local > 0
    for host in REMOTES:
        count = remote_running(host)
        hosts[host] = {"ok": count is not None, "running": count or 0}
        if count and count > 0:
            busy = True
    return {
        "busy": busy,
        "checkedAt": datetime.now(timezone.utc).isoformat(),
        "hosts": hosts,
    }


_cache = {"at": 0.0, "value": None}
_lock = threading.Lock()


def get_snapshot(force=False):
    now = time.monotonic()
    with _lock:
        if (
            not force
            and _cache["value"] is not None
            and now - _cache["at"] < CACHE_SECONDS
        ):
            return _cache["value"]
    value = snapshot()
    with _lock:
        _cache["at"] = time.monotonic()
        _cache["value"] = value
    return value


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/status"):
            self._send(200, json.dumps(get_snapshot()))
        elif path == "/health":
            self._send(200, json.dumps({"ok": True}))
        else:
            self._send(404, json.dumps({"error": "not found"}))

    def log_message(self, *args):
        pass


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(
        "t3-gate listening on http://127.0.0.1:%d (remotes: %s)"
        % (PORT, ", ".join(REMOTES) or "none"),
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
