#!/usr/bin/env python3
"""Unified stream title/description modal for OBS, served as a Custom Browser Dock.

Sets the title (+ category) on Twitch via Helix and the title + description on
YouTube via Data API v3 in a single submit, so a stream going to both
destinations only needs one edit.

Pure stdlib, matching obs_apply_lut.py next door: no pip install, no venv.

Usage: python3 stream_title.py [--port 7788]
Then in OBS: Docks -> Custom Browser Docks -> URL http://127.0.0.1:7788/
"""
import argparse
import datetime, re, shutil, subprocess, http.server, json, os, sys, threading, time, urllib.error, urllib.parse, urllib.request, webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(HERE, "config.json")
OVERLAYS = os.path.normpath(os.path.join(HERE, "..", "overlays"))
OVERLAY_CFG = os.path.join(OVERLAYS, "config.js")
TOKENS_PATH = os.path.join(HERE, "tokens.json")
PORT = 7788

TWITCH_SCOPES = "channel:manage:broadcast"
GOOGLE_SCOPES = "https://www.googleapis.com/auth/youtube"


# ---------------------------------------------------------------- state

def _load(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def _save(path, obj):
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)
    os.chmod(path, 0o600)


def config():
    return _load(CONFIG_PATH, {})


def tokens():
    return _load(TOKENS_PATH, {})


def put_tokens(platform, data):
    t = tokens()
    t[platform] = data
    _save(TOKENS_PATH, t)


# ---------------------------------------------------------------- http

def request(method, url, headers=None, body=None, form=None):
    """Return (status, parsed_json_or_text). Never raises on HTTP error."""
    data = None
    headers = dict(headers or {})
    if form is not None:
        data = urllib.parse.urlencode(form).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    elif body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            raw = r.read().decode() or "{}"
            return r.status, json.loads(raw) if raw.strip().startswith(("{", "[")) else raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw
    except Exception as e:
        return 0, str(e)


# ---------------------------------------------------------------- oauth

def redirect_uri(platform):
    return f"http://localhost:{PORT}/callback/{platform}"


def auth_url(platform):
    cfg = config().get(platform, {})
    if not cfg.get("client_id"):
        return None
    if platform == "twitch":
        q = {"client_id": cfg["client_id"], "redirect_uri": redirect_uri("twitch"),
             "response_type": "code", "scope": TWITCH_SCOPES, "force_verify": "true"}
        return "https://id.twitch.tv/oauth2/authorize?" + urllib.parse.urlencode(q)
    q = {"client_id": cfg["client_id"], "redirect_uri": redirect_uri("youtube"),
         "response_type": "code", "scope": GOOGLE_SCOPES,
         "access_type": "offline", "prompt": "consent"}
    return "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode(q)


def exchange(platform, code):
    cfg = config().get(platform, {})
    endpoint = ("https://id.twitch.tv/oauth2/token" if platform == "twitch"
                else "https://oauth2.googleapis.com/token")
    status, data = request("POST", endpoint, form={
        "client_id": cfg["client_id"], "client_secret": cfg["client_secret"],
        "code": code, "grant_type": "authorization_code",
        "redirect_uri": redirect_uri(platform)})
    if status != 200 or "access_token" not in data:
        return False, data
    data["expires_at"] = time.time() + int(data.get("expires_in", 3600)) - 60
    put_tokens(platform, data)
    return True, data


def access_token(platform):
    """Valid access token, refreshing transparently. None if not connected."""
    tok = tokens().get(platform)
    if not tok:
        return None
    if tok.get("expires_at", 0) > time.time():
        return tok["access_token"]
    if not tok.get("refresh_token"):
        return None
    cfg = config().get(platform, {})
    endpoint = ("https://id.twitch.tv/oauth2/token" if platform == "twitch"
                else "https://oauth2.googleapis.com/token")
    status, data = request("POST", endpoint, form={
        "client_id": cfg["client_id"], "client_secret": cfg["client_secret"],
        "refresh_token": tok["refresh_token"], "grant_type": "refresh_token"})
    if status != 200 or "access_token" not in data:
        return None
    data.setdefault("refresh_token", tok["refresh_token"])
    data["expires_at"] = time.time() + int(data.get("expires_in", 3600)) - 60
    put_tokens(platform, data)
    return data["access_token"]


# ---------------------------------------------------------------- twitch

def twitch_headers():
    """Prefer this tool's own OAuth, but fall back to the token the overlays
    already hold. Both are user tokens for the same channel, so registering a
    second Twitch app just to rename a stream is pointless - the only extra
    thing the title needs is the channel:manage:broadcast scope."""
    tok = access_token("twitch")
    if tok:
        return {"Authorization": f"Bearer {tok}", "Client-Id": config()["twitch"]["client_id"]}
    ov = overlay_settings()
    if ov.get("token") and ov.get("clientId"):
        return {"Authorization": f"Bearer {ov['token']}", "Client-Id": ov["clientId"]}
    return None


def twitch_user():
    h = twitch_headers()
    if not h:
        return None
    status, data = request("GET", "https://api.twitch.tv/helix/users", headers=h)
    if status != 200 or not data.get("data"):
        return None
    return data["data"][0]


def twitch_state():
    user = twitch_user()
    if not user:
        return {"connected": False}
    h = twitch_headers()
    status, data = request(
        "GET", f"https://api.twitch.tv/helix/channels?broadcaster_id={user['id']}", headers=h)
    ch = (data.get("data") or [{}])[0] if status == 200 else {}
    return {"connected": True, "login": user.get("display_name") or user.get("login"),
            "title": ch.get("title", ""), "category": ch.get("game_name", "")}


def twitch_category_id(name):
    if not name:
        return None
    h = twitch_headers()
    q = urllib.parse.urlencode({"query": name, "first": 10})
    status, data = request("GET", f"https://api.twitch.tv/helix/search/categories?{q}", headers=h)
    if status != 200:
        return None
    for item in data.get("data", []):
        if item["name"].lower() == name.lower():
            return item["id"]
    return data["data"][0]["id"] if data.get("data") else None


def twitch_apply(title, category):
    user = twitch_user()
    if not user:
        return {"ok": False, "error": "not connected"}
    payload = {}
    if title:
        payload["title"] = title[:140]
    if category:
        gid = twitch_category_id(category)
        if gid:
            payload["game_id"] = gid
        else:
            return {"ok": False, "error": f"category not found: {category}"}
    if not payload:
        return {"ok": False, "error": "nothing to set"}
    status, data = request(
        "PATCH", f"https://api.twitch.tv/helix/channels?broadcaster_id={user['id']}",
        headers=twitch_headers(), body=payload)
    if status == 204:
        return {"ok": True}
    return {"ok": False, "error": f"HTTP {status}: {data}"}


# ---------------------------------------------------------------- youtube

def youtube_headers():
    tok = access_token("youtube")
    return {"Authorization": f"Bearer {tok}"} if tok else None


def youtube_broadcast():
    """The stream we should be editing: live first, else the soonest upcoming."""
    h = youtube_headers()
    if not h:
        return None
    for state in ("active", "upcoming"):
        q = urllib.parse.urlencode({"part": "id,snippet,status", "broadcastStatus": state,
                                    "broadcastType": "all", "maxResults": 5})
        status, data = request("GET", f"https://www.googleapis.com/youtube/v3/liveBroadcasts?{q}",
                               headers=h)
        if status == 200 and data.get("items"):
            return data["items"][0]
    return None


def youtube_state():
    if not youtube_headers():
        return {"connected": False}
    b = youtube_broadcast()
    if not b:
        return {"connected": True, "broadcast": None}
    return {"connected": True, "broadcast": b["status"]["lifeCycleStatus"],
            "title": b["snippet"].get("title", ""),
            "description": b["snippet"].get("description", "")}


def youtube_apply(title, description):
    h = youtube_headers()
    if not h:
        return {"ok": False, "error": "not connected"}
    b = youtube_broadcast()
    if not b:
        return {"ok": False, "error": "no active or upcoming broadcast"}
    snippet = dict(b["snippet"])
    if title:
        snippet["title"] = title[:100]
    if description is not None:
        snippet["description"] = description[:5000]
    # scheduledStartTime is required by the API whenever snippet is written.
    snippet.setdefault("scheduledStartTime", b["snippet"].get("scheduledStartTime"))
    keep = {k: snippet[k] for k in ("title", "description", "scheduledStartTime") if snippet.get(k)}
    status, data = request("PUT", "https://www.googleapis.com/youtube/v3/liveBroadcasts?part=snippet",
                           headers=h, body={"id": b["id"], "snippet": keep})
    if status == 200:
        return {"ok": True}
    return {"ok": False, "error": f"HTTP {status}: {data}"}


# ---------------------------------------------------------------- server

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # keep the terminal readable

    def _send(self, status, body, ctype="application/json"):
        payload = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        path, query = url.path, urllib.parse.parse_qs(url.query)

        if path == "/":
            try:
                with open(os.path.join(HERE, "dock.html"), "rb") as f:
                    return self._send(200, f.read(), "text/html; charset=utf-8")
            except FileNotFoundError:
                return self._send(500, b"dock.html missing", "text/plain")

        if path in ("/panel", "/panel/"):
            try:
                with open(os.path.join(HERE, "panel.html"), "rb") as f:
                    return self._send(200, f.read(), "text/html; charset=utf-8")
            except FileNotFoundError:
                return self._send(500, b"panel.html missing", "text/plain")

        # the overlays folder, so the chat window and sources have one
        # always-on origin instead of a second server you have to remember
        if path.startswith("/overlays/"):
            rel = urllib.parse.unquote(path[len("/overlays/"):]) or "index.html"
            full = os.path.normpath(os.path.join(OVERLAYS, rel))
            if not full.startswith(OVERLAYS + os.sep):
                return self._send(403, {"error": "nope"})
            types = {".html": "text/html; charset=utf-8", ".js": "text/javascript",
                     ".css": "text/css", ".json": "application/json", ".svg": "image/svg+xml",
                     ".png": "image/png", ".jpg": "image/jpeg", ".mp3": "audio/mpeg",
                     ".woff2": "font/woff2"}
            try:
                with open(full, "rb") as f:
                    ext = os.path.splitext(full)[1].lower()
                    return self._send(200, f.read(), types.get(ext, "application/octet-stream"))
            except (FileNotFoundError, IsADirectoryError):
                return self._send(404, {"error": "not found"})

        if path == "/api/overlays":
            return self._send(200, overlay_settings())

        if path == "/api/day":
            n = day_number()
            return self._send(200, {"day": n, "template": show_cfg()["template"],
                                    "start": show_cfg()["start"]})

        if path == "/api/status":
            cfg = config()
            has_twitch = cfg.get("twitch", {}).get("client_id") or overlay_settings().get("token")
            return self._send(200, {
                "twitch": twitch_state() if has_twitch else {"connected": False, "unconfigured": True},
                "youtube": youtube_state() if cfg.get("youtube", {}).get("client_id") else {"connected": False, "unconfigured": True},
            })

        if path.startswith("/auth/"):
            platform = path.split("/")[2]
            target = auth_url(platform)
            if not target:
                return self._send(400, {"ok": False, "error": f"{platform} client_id missing from config.json"})
            webbrowser.open(target)  # system browser, not the CEF dock
            return self._send(200, {"ok": True})

        if path.startswith("/callback/"):
            platform = path.split("/")[2]
            code = query.get("code", [None])[0]
            if not code:
                return self._send(400, b"<h2>No code returned.</h2>", "text/html")
            ok, data = exchange(platform, code)
            msg = (f"<h2>{platform} connected.</h2><p>Close this tab and return to OBS.</p>"
                   if ok else f"<h2>Failed</h2><pre>{data}</pre>")
            return self._send(200 if ok else 400, msg.encode(), "text/html")

        return self._send(404, {"error": "not found"})

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        length = int(self.headers.get("Content-Length", 0))
        try:
            body = json.loads(self.rfile.read(length) or "{}")
        except json.JSONDecodeError:
            return self._send(400, {"error": "bad json"})

        if path == "/api/overlays":
            res = put_overlay_settings(body)
            if res.get("ok") and body.get("refresh") is not False:
                res["refresh"] = refresh_overlays()
            return self._send(200 if res.get("ok") else 400, res)

        if path == "/api/refresh":
            return self._send(200, refresh_overlays())

        if path != "/api/update":
            return self._send(404, {"error": "not found"})

        # the panel sends just the description part and lets the server apply
        # the Day N template, so the CLI and the dock cannot drift apart
        if body.get("desc") is not None:
            body["title"] = compose(body.get("desc") or "", body.get("day"))
        title = (body.get("title") or "").strip()
        description = body.get("description")
        category = (body.get("category") or "").strip()
        targets = body.get("targets") or ["twitch", "youtube"]

        result = {}
        if "twitch" in targets:
            result["twitch"] = twitch_apply(title, category)
        if "youtube" in targets:
            result["youtube"] = youtube_apply(title, description)
        return self._send(200, result)


class Server(http.server.ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True


# ---------------------------------------------------------------- overlays

# The overlays read config.js straight off disk over file://, so it stays the
# source of truth and we edit the values in place rather than adding a fetch
# the browser source could not make.
OVERLAY_FIELDS = {
    "channel":     (r'(channel:\s*")([^"]*)(")',        "twitch"),
    "clientId":    (r'(clientId:\s*")([^"]*)(")',       "twitch"),
    "token":       (r'(token:\s*")([^"]*)(")',          "twitch"),
    "channelId":   (r'(channelId:\s*")([^"]*)(")',      "youtube"),
    "apiKey":      (r'(apiKey:\s*")([^"]*)(")',         "youtube"),
    "accessToken": (r'(accessToken:\s*")([^"]*)(")',    "youtube"),
}


def overlay_settings():
    try:
        text = open(OVERLAY_CFG, encoding="utf-8").read()
    except OSError:
        return {}
    out = {}
    for key, (pat, _) in OVERLAY_FIELDS.items():
        m = re.search(pat, text)
        out[key] = m.group(2) if m else ""
    return out


def put_overlay_settings(values):
    try:
        text = open(OVERLAY_CFG, encoding="utf-8").read()
    except OSError as e:
        return {"ok": False, "error": str(e)}
    for key, val in values.items():
        if key not in OVERLAY_FIELDS:
            continue
        pat = OVERLAY_FIELDS[key][0]
        safe = str(val).replace("\\", "\\\\").replace('"', '\\"')
        text, n = re.subn(pat, lambda m: m.group(1) + safe + m.group(3), text, count=1)
        if not n:
            return {"ok": False, "error": f"could not find {key} in config.js"}
    tmp = OVERLAY_CFG + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, OVERLAY_CFG)
    return {"ok": True}


def node_bin():
    """launchd and the OBS dock start us without a shell PATH, so a bare
    "node" is not findable. Look it up properly."""
    found = shutil.which("node")
    if found:
        return found
    for guess in ("/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"):
        if os.path.exists(guess):
            return guess
    return None


def refresh_overlays():
    """Tell OBS to reload the browser sources - it caches them hard."""
    node = node_bin()
    if not node:
        return {"ok": False, "error": "node not found - reload the sources in OBS by hand"}
    try:
        out = subprocess.run([node, os.path.join(OVERLAYS, "install.mjs"), "--refresh"],
                             capture_output=True, text=True, timeout=15, cwd=OVERLAYS)
        return {"ok": out.returncode == 0, "output": (out.stdout or out.stderr).strip()}
    except Exception as e:
        return {"ok": False, "error": str(e)}


# ---------------------------------------------------------------- show

def show_cfg():
    """Defaults so the template works before anyone edits config.json."""
    c = config().get("show") or {}
    return {
        "start": c.get("start", ""),                       # YYYY-MM-DD of day 1
        "template": c.get("template", "Day {day} | Vibe Coding My Startup | {desc}"),
        "category": c.get("category", "Software and Game Development"),
        "offset": int(c.get("offset", 0)),                 # nudge if you miss a day
    }


def day_number(cfg=None):
    """Day 1 is the start date itself. Missed days still advance the count -
    it is a calendar streak, which is how viewers read it."""
    cfg = cfg or show_cfg()
    if not cfg["start"]:
        return None
    try:
        start = datetime.date.fromisoformat(cfg["start"])
    except ValueError:
        return None
    return (datetime.date.today() - start).days + 1 + cfg["offset"]


def compose(desc, day=None):
    cfg = show_cfg()
    n = day if day is not None else day_number(cfg)
    if n is None:
        return desc.strip()
    return cfg["template"].format(day=n, desc=desc.strip()).strip()


def cli_set(desc, day=None, dry=False, targets=("twitch", "youtube")):
    cfg = show_cfg()
    title = compose(desc, day)
    print(title)
    print(f"  {len(title)} chars  (twitch caps at 140, youtube at 100)")
    if len(title) > 100:
        print("  ! over 100 - youtube will reject or truncate it")
    if dry:
        return 0
    bad = False
    if "twitch" in targets:
        r = twitch_apply(title, cfg["category"])
        print(f"  twitch  {'ok' if r.get('ok') else 'FAILED: ' + str(r.get('error'))}")
        bad |= not r.get("ok")
    if "youtube" in targets:
        r = youtube_apply(title, None)
        print(f"  youtube {'ok' if r.get('ok') else 'FAILED: ' + str(r.get('error'))}")
        bad |= not r.get("ok")
    return 1 if bad else 0


def main():
    global PORT
    ap = argparse.ArgumentParser(description="stream title for twitch + youtube")
    ap.add_argument("--port", type=int, default=PORT)
    sub = ap.add_subparsers(dest="cmd")

    p_set = sub.add_parser("set", help="compose Day N | Show | desc and push it to both")
    p_set.add_argument("desc", help="the part after the second pipe")
    p_set.add_argument("--day", type=int, help="override the computed day number")
    p_set.add_argument("--dry", action="store_true", help="print it, send nothing")
    p_set.add_argument("--only", choices=["twitch", "youtube"], help="one platform only")

    sub.add_parser("day", help="print today's day number and exit")

    args = ap.parse_args()
    PORT = args.port

    if args.cmd == "day":
        n = day_number()
        print(n if n is not None else 'set show.start ("YYYY-MM-DD") in config.json first')
        return
    if args.cmd == "set":
        targets = (args.only,) if args.only else ("twitch", "youtube")
        raise SystemExit(cli_set(args.desc, args.day, args.dry, targets))

    if not os.path.exists(CONFIG_PATH):
        _save(CONFIG_PATH, {"twitch": {"client_id": "", "client_secret": ""},
                            "youtube": {"client_id": "", "client_secret": ""}})
        print(f"Wrote a blank {CONFIG_PATH} - fill in credentials (see README.md).")

    print(f"Stream title dock on http://127.0.0.1:{PORT}/")
    print(f"  Twitch  redirect URI: {redirect_uri('twitch')}")
    print(f"  YouTube redirect URI: {redirect_uri('youtube')}")
    print("Add that first URL as an OBS Custom Browser Dock. Ctrl-C to stop.")
    try:
        Server(("127.0.0.1", PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()
