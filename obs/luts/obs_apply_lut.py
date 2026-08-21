#!/usr/bin/env python3
"""Add/update the Warm Rescue LUT filter on an OBS source over obs-websocket v5.

Pure stdlib: implements just enough of RFC6455 (client handshake + masked text
frames) to avoid pulling in a dependency.

Usage: python3 obs_apply_lut.py [strength] [source-name]
       strength: subtle | medium | strong   (default medium)
"""
import base64, hashlib, json, os, socket, struct, sys

HOST, PORT = "localhost", 4455
FILTER_NAME = "Warm Rescue"
HERE = os.path.dirname(os.path.abspath(__file__))


def read_password():
    cfg = os.path.expanduser(
        "~/Library/Application Support/obs-studio/plugin_config/obs-websocket/config.json")
    with open(cfg) as f:
        return json.load(f)["server_password"]


class WS:
    def __init__(self, host, port):
        self.s = socket.create_connection((host, port), timeout=5)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall(
            f"GET / HTTP/1.1\r\nHost: {host}:{port}\r\nUpgrade: websocket\r\n"
            f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n".encode())
        self.buf = b""
        while b"\r\n\r\n" not in self.buf:
            self.buf += self.s.recv(4096)
        head, self.buf = self.buf.split(b"\r\n\r\n", 1)
        if b"101" not in head.split(b"\r\n")[0]:
            raise RuntimeError(f"handshake failed: {head.decode(errors='replace')[:200]}")

    def _recv(self, n):
        while len(self.buf) < n:
            chunk = self.s.recv(65536)
            if not chunk:
                raise RuntimeError("connection closed")
            self.buf += chunk
        out, self.buf = self.buf[:n], self.buf[n:]
        return out

    def send(self, obj):
        payload = json.dumps(obj).encode()
        n = len(payload)
        header = b"\x81"
        if n < 126:
            header += bytes([0x80 | n])
        elif n < 1 << 16:
            header += b"\xfe" + struct.pack(">H", n)
        else:
            header += b"\xff" + struct.pack(">Q", n)
        mask = os.urandom(4)
        self.s.sendall(header + mask + bytes(c ^ mask[i % 4] for i, c in enumerate(payload)))

    def recv(self):
        while True:
            b0, b1 = self._recv(2)
            opcode, n = b0 & 0x0F, b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._recv(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._recv(8))[0]
            data = self._recv(n)
            if opcode == 0x1:
                return json.loads(data)
            if opcode == 0x8:
                raise RuntimeError("server closed connection")
            # ignore ping/pong/binary


def request(ws, rid, rtype, data=None):
    ws.send({"op": 6, "d": {"requestType": rtype, "requestId": rid, "requestData": data or {}}})
    while True:
        msg = ws.recv()
        if msg["op"] == 7 and msg["d"]["requestId"] == rid:
            return msg["d"]


def main():
    strength = sys.argv[1] if len(sys.argv) > 1 else "medium"
    source = sys.argv[2] if len(sys.argv) > 2 else "Video Capture Device"
    lut = os.path.join(HERE, f"warm-rescue-{strength}.cube")
    if not os.path.exists(lut):
        sys.exit(f"no such LUT: {lut}")

    ws = WS(HOST, PORT)
    hello = ws.recv()["d"]
    ident = {"rpcVersion": 1}
    if "authentication" in hello:
        a = hello["authentication"]
        pw = read_password()
        secret = base64.b64encode(hashlib.sha256((pw + a["salt"]).encode()).digest()).decode()
        ident["authentication"] = base64.b64encode(
            hashlib.sha256((secret + a["challenge"]).encode()).digest()).decode()
    ws.send({"op": 1, "d": ident})
    if ws.recv()["op"] != 2:
        sys.exit("OBS rejected authentication")

    settings = {"image_path": lut}
    r = request(ws, "create", "CreateSourceFilter", {
        "sourceName": source, "filterName": FILTER_NAME,
        "filterKind": "clut_filter", "filterSettings": settings})
    if r["requestStatus"]["result"]:
        print(f"created '{FILTER_NAME}' on '{source}' -> {strength}")
    elif r["requestStatus"]["code"] == 601:      # ResourceAlreadyExists
        r = request(ws, "update", "SetSourceFilterSettings", {
            "sourceName": source, "filterName": FILTER_NAME, "filterSettings": settings})
        if not r["requestStatus"]["result"]:
            sys.exit(f"update failed: {r['requestStatus']}")
        print(f"updated '{FILTER_NAME}' on '{source}' -> {strength}")
    else:
        sys.exit(f"create failed: {r['requestStatus']}")


if __name__ == "__main__":
    main()
