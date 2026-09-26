#!/usr/bin/env bash
# TEMP + GPU + CPU + RAM. Added in reverse visual order (right region stacks
# right-to-left), so this renders as: temp · gpu · cpu · mem.
#
# Neither item has a script or update_freq: plugins/stats-daemon.mjs owns
# both, pushing a fresh reading every second. CPU has no instantaneous
# reading on macOS, only cumulative counters, so it needs a process that
# remembers the previous sample -- an item script that re-execs each time
# cannot do that without blocking to take two samples of its own.

# Every label gets a fixed, right-aligned width so the pill never changes
# size as readings tick over (and never shoves the items to its left).
# Sized for two-digit values in JetBrains Mono SemiBold 12 (~7.2pt/char):
# "99°" / "99%" = 3 chars, "99.9GB" = 6 chars.
LABEL_W3=22
LABEL_W6=44

# mem and cpu are one pill, so they override $GAP back down -- the default
# would put a 10pt hole between the two readings inside a single background.
sketchybar --add item mem right \
    --set mem \
        icon="$ICON_MEM" \
        icon.color="$W50" \
        icon.padding_left=7 \
        icon.padding_right=5 \
        label="--" \
        label.font="$FONT:SemiBold:12.0" \
        label.width=$LABEL_W6 \
        label.align=right \
        label.color="$FG" \
        label.padding_right=9 \
        padding_left=1 \
        click_script="$PLUGIN_DIR/open_monitor.sh"

sketchybar --add item cpu right \
    --set cpu \
        icon="$ICON_CPU" \
        icon.color="$W50" \
        icon.padding_left=7 \
        icon.padding_right=5 \
        label="--" \
        label.font="$FONT:SemiBold:12.0" \
        label.width=$LABEL_W3 \
        label.align=right \
        label.color="$FG" \
        label.padding_right=4 \
        padding_right=1 \
        click_script="$PLUGIN_DIR/open_monitor.sh"

sketchybar --add item gpu right \
    --set gpu \
        icon="$ICON_GPU" \
        icon.color="$W50" \
        icon.padding_left=7 \
        icon.padding_right=5 \
        label="--" \
        label.font="$FONT:SemiBold:12.0" \
        label.width=$LABEL_W3 \
        label.align=right \
        label.color="$FG" \
        label.padding_right=4 \
        padding_right=1 \
        click_script="$PLUGIN_DIR/open_monitor.sh"

sketchybar --add item temp right \
    --set temp \
        icon="$ICON_TEMP" \
        icon.color="$W50" \
        icon.padding_left=9 \
        icon.padding_right=4 \
        label="--" \
        label.font="$FONT:SemiBold:12.0" \
        label.width=$LABEL_W3 \
        label.align=right \
        label.color="$FG" \
        label.padding_right=4 \
        padding_right=1 \
        click_script="$PLUGIN_DIR/open_monitor.sh"

sketchybar --add bracket system temp gpu cpu mem \
    --set system \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=9 \
        background.height=26

# Restart the stats daemon on every config reload so it never doubles up.
# Pattern is anchored to the node executable so it cannot match a shell that
# merely mentions the filename.
if [ -f /tmp/sketchybar-stats-daemon.pid ]; then
    kill "$(cat /tmp/sketchybar-stats-daemon.pid)" 2>/dev/null
fi
pkill -f "^[^ ]*/node .*stats-daemon[.]mjs" 2>/dev/null
NODE_BIN="$(command -v node || echo /opt/homebrew/bin/node)"
nohup "$NODE_BIN" "$PLUGIN_DIR/stats-daemon.mjs" \
    >/tmp/sketchybar-stats-daemon.log 2>&1 &
disown 2>/dev/null || true
