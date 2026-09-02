#!/usr/bin/env bash
# Serves the overlays on http://127.0.0.1:7799
# OBS loads the files directly (file:///...), but the simulator needs http so
# its iframes share an origin and can be driven from the page.
cd "$(dirname "$0")" || exit 1
PORT="${1:-7799}"
echo "simulator -> http://127.0.0.1:$PORT/sim.html"
echo "chat     -> http://127.0.0.1:$PORT/chat.html"
echo "alerts   -> http://127.0.0.1:$PORT/alerts.html"
echo "viewers  -> http://127.0.0.1:$PORT/viewers.html"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
