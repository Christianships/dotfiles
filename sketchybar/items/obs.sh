#!/usr/bin/env bash
# OBS status group.
#
# These items start hidden and carry no script: plugins/obs-bridge.mjs owns
# their content and visibility, pushing updates over a live obs-websocket
# connection. The whole group disappears when OBS is not running.
#
# The scene pill sits on the LEFT, after the workspaces and calendar (this
# file is sourced after them, so it lands at the end of the left region).
# The tallies stay on the right, added in reverse visual order because the
# right region stacks right-to-left: follow · record · stream · cam.

OBS_REQUEST="$PLUGIN_DIR/obs-request.mjs"
NODE_BIN="$(command -v node || echo /opt/homebrew/bin/node)"

# Virtual camera — indicator only, click toggles it.
sketchybar --add item obs.cam right \
    --set obs.cam \
        drawing=off \
        icon.padding_left=8 \
        icon.padding_right=8 \
        label.drawing=off \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=6 \
        background.height=22 \
        padding_left="$GAP" \
        padding_right="$GAP" \
        click_script="$NODE_BIN '$OBS_REQUEST' cam-toggle"

# LIVE badge. Only drawn while actually streaming; a black chip with a
# blinking red dot, so it reads as a broadcast tally rather than another
# status pill. Content and the blink are driven by obs-bridge.mjs.
sketchybar --add item obs.stream right \
    --set obs.stream \
        drawing=off \
        icon.font="$FONT:Bold:12.0" \
        icon.padding_left=10 \
        icon.padding_right=0 \
        icon.y_offset=0 \
        label.font="$FONT:Bold:13.0" \
        label.padding_left=6 \
        label.padding_right=9 \
        background.color=0xff000000 \
        background.corner_radius=9 \
        background.height=26 \
        background.border_width=0 \
        padding_left="$GAP" \
        padding_right="$GAP" \
        popup.background.color="$GLASS_STRONG" \
        popup.background.corner_radius=10 \
        popup.background.border_width=1 \
        popup.background.border_color="$EDGE" \
        popup.background.shadow.drawing=on \
        popup.align=right \
        popup.y_offset=4 \
        popup.height=24 \
        click_script="sketchybar --set obs.stream popup.drawing=toggle"

# Record tally. Its own black badge, matching the LIVE badge, so the two
# read as broadcast tallies rather than as more status pills.
sketchybar --add item obs.rec right \
    --set obs.rec \
        drawing=off \
        icon.font="$FONT:Bold:12.0" \
        icon.padding_left=10 \
        icon.padding_right=0 \
        label.font="$FONT:Bold:13.0" \
        label.padding_left=6 \
        label.padding_right=9 \
        background.color=0xff000000 \
        background.corner_radius=9 \
        background.height=26 \
        background.border_width=0 \
        padding_left="$GAP" \
        padding_right="$GAP" \
        click_script="$NODE_BIN '$OBS_REQUEST' record-toggle"

# Current scene, on the left side. Click opens a popup listing every scene.
sketchybar --add item obs.scene left \
    --subscribe obs.scene mouse.exited.global \
    --set obs.scene \
        drawing=off \
        icon.padding_left=8 \
        icon.padding_right=6 \
        label.font="$FONT:Bold:12.0" \
        label.max_chars=10 \
        label.padding_right=10 \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=9 \
        background.height=26 \
        padding_left="$GAP" \
        padding_right="$GAP" \
        popup.background.color="$GLASS_STRONG" \
        popup.background.corner_radius=10 \
        popup.background.border_width=1 \
        popup.background.border_color="$EDGE" \
        popup.background.shadow.drawing=on \
        popup.align=center \
        popup.y_offset=4 \
        popup.height=26 \
        click_script="sketchybar --set obs.scene popup.drawing=toggle" \
        script="$PLUGIN_DIR/obs_scene.sh"

# Mouse-follow status. Added last, so it renders at the far LEFT of the OBS
# group. Hidden entirely unless the follower is running; when it is, the dot
# beside the cursor blinks green. State comes from the follower's PID file,
# written by Director's obs-smooth-follow.mjs and removed when it exits.
sketchybar --add item obs.follow right \
    --set obs.follow \
        drawing=off \
        icon="$ICON_CURSOR" \
        icon.color="$FG" \
        icon.padding_left=9 \
        icon.padding_right=4 \
        label.font="$FONT:Bold:13.0" \
        label.padding_left=0 \
        label.padding_right=9 \
        label.y_offset=0 \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=6 \
        background.height=22 \
        padding_left="$GAP" \
        padding_right="$GAP" \
        click_script="$NODE_BIN /Users/christianaguilar/Documents/Director/scripts/obs-control.mjs follow toggle"


# Restart the bridge on every config reload so it never doubles up.
if [ -f /tmp/sketchybar-obs-bridge.pid ]; then
    kill "$(cat /tmp/sketchybar-obs-bridge.pid)" 2>/dev/null
fi
# Anchored to the node executable so the pattern can only ever match the
# daemon itself, never a shell that merely mentions the filename.
pkill -f "^[^ ]*/node .*obs-bridge[.]mjs" 2>/dev/null
nohup "$NODE_BIN" "$PLUGIN_DIR/obs-bridge.mjs" \
    >/tmp/sketchybar-obs-bridge.log 2>&1 &
disown 2>/dev/null || true
