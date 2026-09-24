#!/usr/bin/env bash
# Claude usage: 5-hour window · weekly window, one pill. Added in reverse
# visual order (right region stacks right-to-left), so this renders as
# "<hourglass> NN% · <calendar> NN%".
#
# Only claude_wk runs the script; it updates both items in one request.
# update_freq is 120s -- the numbers move slowly and the endpoint is shared
# with Claude Code itself, so there is no point hammering it.

# The two items share one pill, so they override $GAP back down -- same as
# cpu/mem in system.sh.

# Spacers either side of the pill. They have to be separate empty items:
# padding on claude_wk/claude_5h would land inside the bracket and just widen
# the pill. Toward the stats bracket the spacer is the whole $PILL_GAP; toward
# OBS it is half, since the OBS pills bring their own $GAP.
sketchybar --add item claude_gap right \
    --set claude_gap \
        width="$PILL_GAP" \
        icon.drawing=off \
        label.drawing=off \
        padding_left=0 \
        padding_right=0

sketchybar --add item claude_wk right \
    --subscribe claude_wk system_woke \
    --set claude_wk \
        update_freq=120 \
        icon="$ICON_CLAUDE_WK" \
        icon.color="$W50" \
        icon.padding_left=7 \
        icon.padding_right=5 \
        label="--" \
        label.font="$FONT:SemiBold:12.0" \
        label.color="$FG" \
        label.padding_right=9 \
        padding_left=1 \
        script="$PLUGIN_DIR/claude_usage.sh"

sketchybar --add item claude_5h right \
    --set claude_5h \
        icon="$ICON_CLAUDE_5H" \
        icon.color="$W50" \
        icon.padding_left=9 \
        icon.padding_right=5 \
        label="--" \
        label.font="$FONT:SemiBold:12.0" \
        label.color="$FG" \
        label.padding_right=4 \
        padding_right=1

sketchybar --add item claude_gap_left right \
    --set claude_gap_left \
        width="$GAP" \
        icon.drawing=off \
        label.drawing=off \
        padding_left=0 \
        padding_right=0

sketchybar --add bracket claude claude_5h claude_wk \
    --set claude \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=9 \
        background.height=26
