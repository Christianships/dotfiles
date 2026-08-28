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

if [ "${1:-off}" = on ]; then
    "$SKETCHYBAR" --bar color="$ALARM" border_color="$ALARM"
else
    "$SKETCHYBAR" --bar color="$BAR_COLOR" border_color="$BAR_BORDER_COLOR"
fi
