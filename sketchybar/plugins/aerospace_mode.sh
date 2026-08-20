#!/usr/bin/env bash
source "$CONFIG_DIR/plugins/_env.sh"
# Shows the active AeroSpace binding mode, mirroring a Hyprland submap
# indicator. Hidden while in the default "main" mode.

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

mode="${MODE:-main}"

case "$mode" in
    resize)
        sketchybar --set aerospace_mode drawing=on \
            icon="$ICON_RESIZE" label="RESIZE" background.color="$PEACH"
        ;;
    service)
        sketchybar --set aerospace_mode drawing=on \
            icon="$ICON_COG" label="SERVICE" background.color="$MAROON"
        ;;
    *)
        sketchybar --set aerospace_mode drawing=off
        ;;
esac
