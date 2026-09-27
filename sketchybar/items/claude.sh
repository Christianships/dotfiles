#!/usr/bin/env bash
# Claude usage: 5-hour window · weekly window, one pill. Added in reverse
# visual order (right region stacks right-to-left), so this renders as
# "<hourglass> NN% · <calendar> NN% · <$> today's cost".
#
# Only claude_wk runs the usage script; it updates both items in one request.
# claude_cost has its own script: it shells out to ccusage (~1s), which
# should not hold up the usage numbers.
# update_freq is 120s, but that only re-reads a local cache: see
# plugins/claude_usage.sh for when it actually touches the network.

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

RAYCAST_USAGE="open -g 'raycast://extensions/nyatinte/ccusage/ccusage'"

# No icon: the "$" is part of the green label so it reads as one "$107".
# Sized to its text, not a fixed width: a fixed 44pt was narrower than
# "$1.81" plus padding, so the text spilled left into the gap. The gap to the
# weekly % is 4 + 1 + 1 + 6 = 12pt, the same as between 5h and weekly
# (4 + 1 + 7). The pill only grows when the cost gains a digit.
sketchybar --add item claude_cost right \
    --subscribe claude_cost system_woke \
    --set claude_cost \
        update_freq=120 \
        icon.drawing=off \
        label="\$--" \
        label.font="$FONT:SemiBold:12.0" \
        label.color="$MONEY" \
        label.padding_left=6 \
        label.padding_right=9 \
        padding_left=1 \
        click_script="$RAYCAST_USAGE" \
        script="$PLUGIN_DIR/claude_cost.sh"

# Fired by plugins/claude_statusline.sh when Claude Code reports new numbers.
sketchybar --add event claude_usage_update

sketchybar --add item claude_wk right \
    --subscribe claude_wk system_woke claude_usage_update \
    --set claude_wk \
        update_freq=120 \
        icon="$ICON_CLAUDE_WK" \
        icon.color="$W50" \
        icon.padding_left=7 \
        icon.padding_right=5 \
        label="--" \
        label.font="$FONT:SemiBold:12.0" \
        label.color="$FG" \
        label.padding_right=4 \
        padding_right=1 \
        click_script="$RAYCAST_USAGE" \
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
        padding_right=1 \
        click_script="$RAYCAST_USAGE"

sketchybar --add item claude_gap_left right \
    --set claude_gap_left \
        width="$GAP" \
        icon.drawing=off \
        label.drawing=off \
        padding_left=0 \
        padding_right=0

sketchybar --add bracket claude claude_5h claude_wk claude_cost \
    --set claude \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=9 \
        background.height=26
