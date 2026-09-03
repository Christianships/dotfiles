# Stream setup dock

One modal inside OBS that sets the **title** on Twitch and the **title +
description** on YouTube in a single submit. Pure stdlib Python, no venv.

    python3 ~/.config/obs/stream-title/stream_title.py

Then in OBS: **Docks -> Custom Browser Docks**. Two worth adding:

| dock | URL |
|---|---|
| `Setup` | `http://127.0.0.1:7788/panel` |
| `Chat` | `http://127.0.0.1:7788/overlays/chatwindow.html` |

The original single-purpose title modal is still at `http://127.0.0.1:7788/`.

## The panel

`/panel` is the pre-stream page. It does three things:

- **Title** - type the description, it shows the composed `Day N | ... | ...`
  live with a character count, and pushes to both platforms in one click.
- **Status** - whether chat, the viewer count, the YouTube stats and both title
  APIs are actually configured. An empty overlay on stream is almost always one
  of these being blank, and this is where you see that before going live.
- **Overlay sources** - the Twitch channel, tokens and YouTube keys. Saving
  writes `../overlays/config.js` and reloads the OBS browser sources, which
  otherwise keep serving a cached copy.

Chat needs **only** the Twitch channel. The viewer count needs a client ID and
token as well.

## The chat window

`/overlays/chatwindow.html` is the same renderer as the on-stream overlay with
window furniture around it: solid background, 400 messages of scrollback,
auto-scroll that releases when you scroll up to read something, and a header
pip showing whether it is actually connected. Add it as a dock or pop it onto a
second monitor.

## One-time credentials

Both platforms need an OAuth app you own. Put the results in `config.json`
(created blank on first run, chmod 600).

### Twitch

1. <https://dev.twitch.tv/console/apps> -> Register Your Application
2. OAuth Redirect URL: `http://localhost:7788/callback/twitch`
3. Category: Application Integration. Client Type: **Confidential**
4. Copy Client ID, then New Secret -> into `config.json` under `twitch`

Scope used: `channel:manage:broadcast`

### YouTube

1. <https://console.cloud.google.com/> -> new project
2. APIs & Services -> Library -> enable **YouTube Data API v3**
3. OAuth consent screen -> External -> add yourself under Test users
4. Credentials -> Create Credentials -> OAuth client ID -> **Web application**
5. Authorized redirect URI: `http://localhost:7788/callback/youtube`
6. Copy Client ID + Client Secret into `config.json` under `youtube`

Scope used: `https://www.googleapis.com/auth/youtube`

Then click **connect** next to each platform in the dock. Tokens land in
`tokens.json` (chmod 600) and refresh themselves after that.

## Day counter

`config.json` holds a `show` block:

    "show": {
      "start": "2026-09-03",
      "template": "Day {day} | Vibe Coding My Startup | {desc}",
      "category": "Software and Game Development",
      "offset": 0
    }

`start` is day 1. The number is calendar days since then, so a missed stream
still advances it - that is how viewers read a day count. `offset` nudges it if
you ever need to correct.

    python3 stream_title.py day
    python3 stream_title.py set "I Think We Finally Found Product-Market Fit"
    python3 stream_title.py set "..." --dry            # print it, send nothing
    python3 stream_title.py set "..." --day 62         # override the number
    python3 stream_title.py set "..." --only twitch

One command sets both platforms. It prints the character count and warns past
100, which is where YouTube cuts. Twitch allows 140, so the description part
has about 66 characters before YouTube becomes the binding constraint.

## Notes

- Twitch titles cap at 140 chars, YouTube at 100. The counter warns past 100.
- YouTube edits the **active** broadcast, or the soonest **upcoming** one if
  you are not live yet. With no broadcast it reports so rather than failing
  silently.
- The Twitch category is resolved by name through Helix search; an exact
  match wins, otherwise the top hit.
- `connect` opens your system browser deliberately - OAuth does not work
  inside the OBS CEF dock.
- This does not start or stop streams. obs-multi-rtmp exposes no
  obs-websocket vendor API, so its targets are dock-button only.

## Keeping it running

    launchctl load -w ~/Library/LaunchAgents/com.obs.stream-title.plist

Starts at login and restarts on crash. Unload with `launchctl unload -w` on
the same path.
