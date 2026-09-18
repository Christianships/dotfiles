#!/usr/bin/env bash
# Time only. First item added, so it sits furthest right.
# Format mirrors the macOS menu bar clock preference (day of week + AM/PM).
#
# Clicking opens Raycast's built-in "My Schedule". Deeplink shape is
# raycast://extensions/<owner>/<extension>/<command>, and for built-ins the
# owner is literally "raycast" -- so this needs no extension installed.

sketchybar --add item clock right \
    --set clock \
        update_freq=10 \
        icon.drawing=off \
        label.font="$FONT:Bold:12.0" \
        label.color="$FG" \
        label.padding_left=11 \
        label.padding_right=11 \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=9 \
        background.height=26 \
        script="$PLUGIN_DIR/clock.sh" \
        click_script="open -g 'raycast://extensions/raycast/calendar/my-schedule'"
