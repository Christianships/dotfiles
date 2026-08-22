#!/usr/bin/env bash
# Current calendar event: [10:12-10:14pm] brushing teeth [1:48]
#
# Renders as four items inside the `calendar` bracket -- time range, divider
# and title, progress ring, time remaining -- so each piece can be styled and
# hidden on its own. The group appears and disappears outright; the only
# motion in it is the ring stepping and the countdown pulsing in the last
# minute.
#
# Two clocks are at work here. EventKit is queried at most once a
# CACHE_TTL-second window (helpers/calendar-now is a process launch and a
# store query, far too heavy to run at 1 Hz), while the countdown and the
# progress bar are recomputed locally every tick from the cached start/end
# timestamps. State transitions that are derivable from those timestamps --
# upcoming becoming current, current running out -- are handled locally too,
# and only force a refetch at the moment they happen.
#
# Setup, once:
#   helpers/build-calendar-now.sh && helpers/calendar-now now
# The second command has to be run from a terminal so the calendar-access
# prompt is attributed to a foreground app. Until it is granted the item shows
# a "cal ?" affordance rather than disappearing.
#
# Mock an event to see it work:
#   helpers/cal-add 15 "brushing teeth"          real event, needs access
#   helpers/cal-mock add "Nighttime task" 2:20am 10   no access needed

source "$CONFIG_DIR/plugins/_env.sh"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

HELPER="$CONFIG_DIR/helpers/calendar-now"
CACHE="/tmp/sketchybar-calendar.json"
STATE="/tmp/sketchybar-calendar.state"
# When present, this file replaces EventKit entirely -- see helpers/cal-mock.
# It exists so the item can be built, styled and demoed on a machine where
# calendar access has not been granted, and so a specific scenario (an event
# about to start, an event down to its last seconds) can be produced on
# demand instead of waited for.
MOCK="/tmp/sketchybar-calendar.mock"
CACHE_TTL=45
FONT="${FONT:-JetBrainsMono Nerd Font}"

# Remaining time below which the countdown starts breathing.
URGENT=60
# Tick rates: seconds-resolution while something is on screen, lazy otherwise.
LIVE_FREQ=1
IDLE_FREQ=15

NOW=$(date +%s)

# ── Cache ─────────────────────────────────────────────────────────
read_cache() {
    [ -f "$CACHE" ] || return 1
    IFS=$'\t' read -r C_STATE C_TITLE C_START C_END < "$CACHE" || return 1
    [ -n "$C_STATE" ]
}

# Rows of `title \t start \t end`, reduced to the one row the bar should show
# using the same rules helpers/calendar-now applies: shortest event currently
# running wins, else the earliest starting within the next half hour.
select_mock() {
    awk -F'\t' -v now="$NOW" '
        NF < 3 { next }
        { title = $1; start = $2 + 0; finish = $3 + 0 }
        finish <= now { next }
        start <= now {
            if (!have_cur || finish - start < cur_len) {
                have_cur = 1; cur_len = finish - start
                cur = title "\t" start "\t" finish
            }
            next
        }
        start < now + 1800 {
            if (!have_next || start < next_at) {
                have_next = 1; next_at = start
                nxt = title "\t" start "\t" finish
            }
        }
        END {
            if (have_cur) print "current\t" cur
            else if (have_next) print "upcoming\t" nxt
            else print "none\t\t0\t0"
        }
    ' "$MOCK"
}

refresh() {
    if [ -f "$MOCK" ]; then
        select_mock > "$CACHE".tmp && mv "$CACHE".tmp "$CACHE"
        read_cache
        return
    fi

    local json
    json=$("$HELPER" now 2>/dev/null) || json=""
    # osascript-free JSON read: the payload is flat and helper-authored, so a
    # single node pass is cheaper than dragging in jq as a dependency.
    printf '%s' "$json" | node -e '
        let raw = "";
        process.stdin.on("data", (d) => (raw += d));
        process.stdin.on("end", () => {
            let o;
            try { o = JSON.parse(raw); } catch { o = { state: "error" }; }
            const cell = (v) => String(v ?? "").replace(/[\t\n]/g, " ");
            process.stdout.write([
                cell(o.state || "none"),
                cell(o.title),
                Math.round(o.start || 0),
                Math.round(o.end || 0),
            ].join("\t") + "\n");
        });
    ' > "$CACHE".tmp 2>/dev/null && mv "$CACHE".tmp "$CACHE"
    read_cache
}

cache_age=$CACHE_TTL
[ -f "$CACHE" ] && cache_age=$((NOW - $(stat -f %m "$CACHE" 2>/dev/null || echo 0)))

if [ "$SENDER" = "calendar_refresh" ] || [ "$cache_age" -ge "$CACHE_TTL" ] || ! read_cache; then
    refresh || { C_STATE=error; C_TITLE=""; C_START=0; C_END=0; }
fi

# The cached row can go stale between fetches in exactly two ways, both of
# which are visible from the timestamps alone. Refetch immediately rather than
# waiting out the TTL, so the bar never shows an event that already ended.
if [ "$C_STATE" = "current" ] && [ "$NOW" -ge "$C_END" ]; then
    refresh || C_STATE=none
elif [ "$C_STATE" = "upcoming" ] && [ "$NOW" -ge "$C_START" ]; then
    refresh || C_STATE=none
fi

# ── Formatting ────────────────────────────────────────────────────
# "10:12-10:14pm", collapsing the shared meridiem onto the end time.
range_label() {
    local start=$1 end=$2
    local s_time s_mer e_time e_mer
    s_time=$(date -r "$start" '+%-I:%M')
    s_mer=$(date -r "$start" '+%p' | tr 'APM' 'apm')
    e_time=$(date -r "$end" '+%-I:%M')
    e_mer=$(date -r "$end" '+%p' | tr 'APM' 'apm')
    if [ "$s_mer" = "$e_mer" ]; then
        printf '%s-%s%s' "$s_time" "$e_time" "$e_mer"
    else
        printf '%s%s-%s%s' "$s_time" "$s_mer" "$e_time" "$e_mer"
    fi
}

# "1:48" under an hour, "1h04" over it. Seconds matter for the last stretch of
# a meeting and are noise for the first hour of one.
duration_label() {
    local secs=$1
    [ "$secs" -lt 0 ] && secs=0
    if [ "$secs" -ge 3600 ]; then
        printf '%dh%02d' $((secs / 3600)) $(((secs % 3600) / 60))
    else
        printf '%d:%02d' $((secs / 60)) $((secs % 60))
    fi
}

# Percentage to one of the nine ring glyphs. The ramp is indexed rather than
# thresholded so adding or removing steps in icons.sh needs no change here.
ring_icon() {
    local pct=$1
    local ramp=($ICON_RING_RAMP)
    local last=$(( ${#ramp[@]} - 1 ))
    local i=$(( pct * last / 100 ))
    [ "$i" -lt 0 ] && i=0
    [ "$i" -gt "$last" ] && i=$last
    printf '%s' "${ramp[$i]}"
}

truncate_title() {
    local title=$1 limit=20
    [ -z "$title" ] && title="Busy"
    if [ "${#title}" -gt "$limit" ]; then
        printf '%s…' "${title:0:$((limit - 1))}"
    else
        printf '%s' "$title"
    fi
}

# ── Show / hide ───────────────────────────────────────────────────
# Straight cut, no transition. Colours live on the items themselves rather
# than being driven from here, so showing the group is just drawing=on.
MEMBERS="calendar.time calendar.title calendar.ring calendar.left"

reveal() {
    local args=()
    for item in $MEMBERS; do
        args+=(--set "$item" drawing=on)
    done
    # No transition: the group is either there or it is not. Nothing needs
    # resetting -- every item's content is written outright on the same tick.
    sketchybar --set calendar.time update_freq="$LIVE_FREQ" \
        "${args[@]}" \
        --set calendar background.color="$GLASS" background.border_color="$EDGE_SOFT"
}

conceal() {
    local args=()
    for item in $MEMBERS; do
        args+=(--set "$item" drawing=off)
    done
    sketchybar "${args[@]}" \
        --set calendar background.color="$TRANSPARENT" background.border_color="$TRANSPARENT" \
        --set calendar.time update_freq="$IDLE_FREQ"
}

prev_state=""
[ -f "$STATE" ] && prev_state=$(cat "$STATE")
printf '%s' "$C_STATE" > "$STATE"

hidden() { [ "$1" = "none" ] || [ "$1" = "error" ]; }

if hidden "$C_STATE"; then
    hidden "$prev_state" || conceal
    exit 0
fi

# Access has never been granted: say so instead of looking broken. Clicking
# runs the helper, which is enough to raise the prompt.
if [ "$C_STATE" = "denied" ]; then
    if [ "$prev_state" != "denied" ]; then
        reveal
    fi
    sketchybar --set calendar.time label="cal ?" \
        --set calendar.title icon.drawing=off \
            label="grant access" label.color="$W50" \
        --set calendar.ring drawing=off \
        --set calendar.left drawing=off
    exit 0
fi

[ "$prev_state" = "$C_STATE" ] || reveal

# ── Render ────────────────────────────────────────────────────────
RANGE=$(range_label "$C_START" "$C_END")
TITLE=$(truncate_title "$C_TITLE")

if [ "$C_STATE" = "upcoming" ]; then
    # Nothing has started yet, so there is no progress to draw. The countdown
    # runs toward the start instead of away from it.
    sketchybar --set calendar.time icon="$ICON_CAL" icon.color="$W35" \
            label="$RANGE" label.color="$W50" \
        --set calendar.title icon.drawing=on icon.color="$W20" \
            label="$TITLE" label.color="$W80" \
        --set calendar.ring drawing=off \
        --set calendar.left drawing=on label="in $(duration_label $((C_START - NOW)))" \
            label.color="$LIVE_SOFT"
    exit 0
fi

ELAPSED=$((NOW - C_START))
TOTAL=$((C_END - C_START))
[ "$TOTAL" -le 0 ] && TOTAL=1
LEFT=$((C_END - NOW))
PCT=$((ELAPSED * 100 / TOTAL))
[ "$PCT" -lt 0 ] && PCT=0
[ "$PCT" -gt 100 ] && PCT=100

sketchybar --set calendar.time icon="$ICON_CAL" icon.color="$W50" \
        label="$RANGE" label.color="$FG" \
    --set calendar.title icon.drawing=on icon.color="$W35" \
        label="$TITLE" label.color="$FG" \
    --set calendar.ring drawing=on icon="$(ring_icon "$PCT")" \
    --set calendar.left drawing=on label="$(duration_label "$LEFT")"

# Last minute: breathe. The countdown swings between full red and LIVE_DIM
# once a second, and the pill's edge brightens with it. The pulse is carried
# by alpha rather than by hue so it reads as the same red getting louder,
# instead of as a second colour arriving; the edge stays white, because two
# things pulsing in red would compete rather than reinforce.
if [ "$LEFT" -le "$URGENT" ]; then
    if [ $((NOW % 2)) -eq 0 ]; then
        left_color="$LIVE"; edge_color="$EDGE_HOT"
    else
        left_color="$LIVE_DIM"; edge_color="$EDGE_SOFT"
    fi
    sketchybar --animate sin 30 \
        --set calendar.left label.color="$left_color" \
        --set calendar background.border_color="$edge_color"
else
    sketchybar --set calendar.left label.color="$LIVE"
fi
