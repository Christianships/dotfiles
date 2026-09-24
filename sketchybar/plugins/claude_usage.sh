#!/usr/bin/env bash
# Claude plan usage: the 5-hour session window and the weekly window, as
# percentages. Same numbers as `/usage` in Claude Code.
#
# Reads Claude Code's own OAuth token from the login keychain and asks the
# usage endpoint it uses. Claude Code refreshes that token whenever it runs;
# if it has gone stale (no session for a while) the request 401s and the
# labels fall back to "--" rather than showing stale numbers.
source "$CONFIG_DIR/plugins/_env.sh"
source "$CONFIG_DIR/colors.sh"

fail() {
    sketchybar --set claude_5h label="--" label.color="$FG_DIM" \
               --set claude_wk label="--" label.color="$FG_DIM"
    exit 0
}

token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
    | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
[ -z "$token" ] && fail

usage=$(curl -sf -m 10 https://api.anthropic.com/api/oauth/usage \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "Content-Type: application/json") || fail

five=$(printf '%s' "$usage" | jq -r '.five_hour.utilization // empty | round')
week=$(printf '%s' "$usage" | jq -r '.seven_day.utilization // empty | round')
[ -z "$five" ] && [ -z "$week" ] && fail

# Monotone like the rest of the bar; only a nearly spent window turns red.
color_for() {
    if [ -z "$1" ]; then echo "$FG_DIM"
    elif [ "$1" -ge 90 ]; then echo "$CRITICAL"
    else echo "$FG"
    fi
}

sketchybar --set claude_5h label="${five:---}%" label.color="$(color_for "$five")" \
           --set claude_wk label="${week:---}%" label.color="$(color_for "$week")"
