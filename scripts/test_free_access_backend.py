#!/usr/bin/env python3
"""Exercise real free-access HTTP routes against an isolated disposable database."""
import json
import os
from pathlib import Path
import socket
import sqlite3
import subprocess
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="macdictate-free-api-") as temp:
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    env = os.environ.copy()
    env.update(PORT=str(port), DB_PATH=str(Path(temp) / "test.sqlite"),
               TINKOFF_TERMINAL_KEY="", TINKOFF_PASSWORD="", OUTBOUND_PROXY_URL="")
    process = subprocess.Popen(["node", str(ROOT / "backend/server.js")], cwd=temp,
                               env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    def request(path, body=None):
        req = Request(f"http://127.0.0.1:{port}{path}",
                      data=json.dumps(body).encode() if body is not None else None,
                      headers={"Content-Type": "application/json"})
        try:
            with urlopen(req, timeout=3) as response:
                return response.status, json.load(response)
        except HTTPError as error:
            return error.code, json.load(error)
    try:
        for _ in range(100):
            if process.poll() is not None:
                raise RuntimeError(process.stderr.read().decode())
            try:
                if request("/api/health")[0] == 200:
                    break
            except (URLError, TimeoutError):
                time.sleep(.05)
        else:
            raise RuntimeError("Backend did not start")
        status, access = request("/api/license/status?deviceId=MD-FREE-TEST")
        assert status == 200 and access["isActive"] is True
        assert access["isPaid"] is False and access["expiresAt"] is None, access
        assert access["accessMode"] == "free"
        assert request("/api/license/status")[0] == 400
        status, plans = request("/api/plans")
        assert status == 200 and plans["plans"] == []
        for body in [{}, {"deviceId": "MD-FREE-TEST", "email": "synthetic@example.invalid", "planId": "yearly"}]:
            status, result = request("/api/payment/create", body)
            assert status == 410 and result["code"] == "PAYMENTS_DISABLED", result
        with sqlite3.connect(env["DB_PATH"]) as database:
            assert database.execute("SELECT COUNT(*) FROM devices").fetchone()[0] == 0
            assert database.execute("SELECT COUNT(*) FROM orders").fetchone()[0] == 0
        print("Free backend HTTP tests passed; no device/order writes or payment requests.")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
