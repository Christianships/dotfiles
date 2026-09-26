#!/usr/bin/env bash
# Claude plan usage: the 5-hour session window and the weekly window, as
# percentages. Same numbers as `/usage` in Claude Code.
#
# Primary source is the cache written by claude_statusline.sh, which Claude
# Code feeds after every response (and which triggers claude_usage_update so
# the bar updates at once). Only when that cache is over POLL_AFTER old --
# no Claude Code session lately, so usage elsewhere (claude.ai, phone) would
# go unseen -- does this ask /api/oauth/usage directly. That endpoint 429s
# easily, so a 429 backs off for BACKOFF seconds, and any failure keeps the
# last known numbers on screen instead of blanking to "--".
source "$CONFIG_DIR/plugins/_env.sh"
source "$CONFIG_DIR/colors.sh"

CACHE_DIR="$HOME/.cache/sketchybar"
CACHE="$CACHE_DIR/claude-usage.json"
BACKOFF_FILE="$CACHE_DIR/claude-usage.backoff"
POLL_AFTER=600    # 10 min
BACKOFF=900       # 15 min
STALE_AFTER=10800 # 3 h: numbers this old are shown dimmed

now=$(date +%s)
mkdir -p "$CACHE_DIR"

poll() {
    local until
    until=$(cat "$BACKOFF_FILE" 2>/dev/null)
    [ -n "$until" ] && [ "$now" -lt "$until" ] && return

    local token body code
    token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    [ -z "$token" ] && return

    body=$(curl -s -m 10 -w '\n%{http_code}' https://api.anthropic.com/api/oauth/usage \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "Content-Type: application/json")
    code=${body##*$'\n'}
    body=${body%$'\n'*}

    if [ "$code" = 429 ]; then
        echo $(( now + BACKOFF )) >"$BACKOFF_FILE"
        return
    fi
    [ "$code" = 200 ] || return
    rm -f "$BACKOFF_FILE"

    # resets_at arrives as ISO 8601 here but epoch seconds from the status
    # line; store epoch so the cache has one shape.
    local tmp
    tmp=$(mktemp "$CACHE_DIR/.claude-usage.XXXXXX")
    printf '%s' "$body" | jq -c --argjson t "$now" '
        def epoch: if . == null then null
                   else (sub("\\.[0-9]+"; "") | sub("[+]00:00$"; "Z") | try fromdateiso8601 catch null) end;
        { five: .five_hour.utilization, five_reset: (.five_hour.resets_at | epoch),
          week: .seven_day.utilization, week_reset: (.seven_day.resets_at | epoch),
          updated: $t, source: "api" }' >"$tmp" 2>/dev/null && [ -s "$tmp" ] \
        && mv "$tmp" "$CACHE" || rm -f "$tmp"
}

updated=$(jq -r '.updated // 0' "$CACHE" 2>/dev/null || echo 0)
[ $(( now - ${updated:-0} )) -ge "$POLL_AFTER" ] && poll

# A window whose reset time has passed is back at 0%, whatever was cached.
read -r five week updated < <(jq -r --argjson now "$now" '
    def pct(v; r): if v == null then "-" elif (r != null and r <= $now) then 0 else (v | round) end;
    "\(pct(.five; .five_reset)) \(pct(.week; .week_reset)) \(.updated // 0)"' "$CACHE" 2>/dev/null)
[ "$five" = "-" ] && five=""
[ "$week" = "-" ] && week=""

stale=0
[ $(( now - ${updated:-0} )) -ge "$STALE_AFTER" ] && stale=1

# Monotone like the rest of the bar; only a nearly spent window turns red.
color_for() {
    if [ -z "$1" ] || [ "$stale" = 1 ]; then echo "$FG_DIM"
    elif [ "$1" -ge 90 ]; then echo "$CRITICAL"
    else echo "$FG"
    fi
}

sketchybar --set claude_5h label="${five:---}%" label.color="$(color_for "$five")" \
           --set claude_wk label="${week:---}%" label.color="$(color_for "$week")"
