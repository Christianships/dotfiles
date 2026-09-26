#!/usr/bin/env bash
# Claude Code status line (settings.json -> statusLine), doubling as the feed
# for the SketchyBar usage pill.
#
# Claude Code hands this script the session JSON after every response,
# including rate_limits.five_hour / seven_day -- the same numbers as /usage,
# at no extra request. Saving them here means the bar rarely has to poll
# /api/oauth/usage, which rate-limits (429) easily.
input=$(cat)

CACHE_DIR="$HOME/.cache/sketchybar"
CACHE="$CACHE_DIR/claude-usage.json"

rl=$(printf '%s' "$input" | jq -c '.rate_limits // empty
    | select(.five_hour or .seven_day)
    | { five: .five_hour.used_percentage, five_reset: .five_hour.resets_at,
        week: .seven_day.used_percentage, week_reset: .seven_day.resets_at }' 2>/dev/null)

if [ -n "$rl" ]; then
    mkdir -p "$CACHE_DIR"
    old=$(jq -c '{five, five_reset, week, week_reset}' "$CACHE" 2>/dev/null)
    tmp=$(mktemp "$CACHE_DIR/.claude-usage.XXXXXX")
    jq -c --argjson t "$(date +%s)" '. + {updated: $t, source: "statusline"}' <<<"$rl" >"$tmp" \
        && mv "$tmp" "$CACHE"
    # Only poke the bar when a number actually moved.
    [ "$rl" != "$old" ] && sketchybar --trigger claude_usage_update >/dev/null 2>&1 &
fi

printf '%s' "$input" | jq -r '
    [ .model.display_name,
      (.workspace.current_dir // .cwd // "" | split("/") | last),
      (.context_window.used_percentage // empty | "ctx \(round)%"),
      (.rate_limits.five_hour.used_percentage // empty | "5h \(round)%"),
      (.rate_limits.seven_day.used_percentage // empty | "wk \(round)%")
    ] | map(select(. != null and . != "")) | join(" · ")'
