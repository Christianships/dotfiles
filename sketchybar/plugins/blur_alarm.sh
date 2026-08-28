#!/usr/bin/env bash
# Flood the bar with the privacy-blur alarm colour, or put it back to normal.
#
#   blur_alarm.sh on|off
#
# The bar is normally fully transparent -- only the item pills are drawn -- so
# painting it is a total change of appearance and reads instantly across the
# room. Driven by `obs-control.mjs blur`, which owns the actual blur state.
set -u

source "$HOME/.config/sketchybar/colors.sh"
SKETCHYBAR=/opt/homebrew/bin/sketchybar

# The bar normally draws nothing, so its own corner radius is 0 and never
# shows. Once it is painted the square ends read as a hard slab against the
# 8pt margin, so round it to match the item pills -- their background radius
# is 8, and 12 on a 32pt bar keeps the same soft-capsule feel at bar scale.
ALARM_RADIUS=12

if [ "${1:-off}" = on ]; then
    "$SKETCHYBAR" --bar color="$ALARM" border_color="$ALARM" corner_radius="$ALARM_RADIUS"
else
    "$SKETCHYBAR" --bar color="$BAR_COLOR" border_color="$BAR_BORDER_COLOR" corner_radius=0
fi
