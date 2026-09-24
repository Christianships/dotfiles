#!/usr/bin/env bash
# AeroSpace workspace pills + the resize/service mode indicator.

sketchybar --add event aerospace_workspace_change
sketchybar --add event aerospace_focus_change
sketchybar --add event aerospace_mode_change

# Static slots matching the ctrl-1..ctrl-0 bindings in aerospace.toml.
# `aerospace list-workspaces --all` only reports workspaces that currently
# exist, so the full set is declared here; plugins/spaces.sh hides the ones
# that are empty and unfocused.
WORKSPACES=(1 2 3 4 5 6 7 8 9 10)

SPACE_ITEMS=()
for sid in "${WORKSPACES[@]}"; do
    SPACE_ITEMS+=("space.$sid")
    sketchybar --add item "space.$sid" left \
        --set "space.$sid" \
            drawing=off \
            icon="$sid" \
            icon.font="$FONT:Bold:12.0" \
            icon.color="$FG_DIM" \
            icon.padding_left=7 \
            icon.padding_right=7 \
            label.font="$APP_FONT" \
            label.color="$FG_DIM" \
            label.padding_left=0 \
            label.padding_right=8 \
            label.y_offset=-1 \
            background.corner_radius=7 \
            background.height=21 \
            background.border_width=1 \
            background.color="$TRANSPARENT" \
            background.border_color="$TRANSPARENT" \
            padding_left=2 \
            padding_right=2 \
            click_script="/opt/homebrew/bin/aerospace workspace $sid"
done

# A single invisible watcher repaints all ten pills. Subscribing each pill
# separately would fan one event out into ten near-identical queries.
#
# front_app_switched is what catches "a new app just opened" -- launching an
# app makes it frontmost. update_freq is a slow safety net so the pills
# resync even if an event is ever missed.
sketchybar --add item spaces_watcher left \
    --subscribe spaces_watcher aerospace_workspace_change \
                               aerospace_focus_change \
                               front_app_switched \
                               space_windows_change \
    --set spaces_watcher \
        drawing=off \
        updates=on \
        update_freq=3 \
        script="$PLUGIN_DIR/spaces.sh"

sketchybar --add bracket spaces "${SPACE_ITEMS[@]}" \
    --set spaces \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=9 \
        background.height=26

# Hyprland-style submap indicator: only visible outside the main mode.
sketchybar --add item aerospace_mode left \
    --subscribe aerospace_mode aerospace_mode_change \
    --set aerospace_mode \
        drawing=off \
        icon="$ICON_KEYBOARD" \
        icon.color="$INK" \
        icon.padding_left=8 \
        icon.padding_right=5 \
        label.font="$FONT:Bold:11.0" \
        label.color="$INK" \
        label.padding_right=9 \
        background.color="$ACCENT" \
        background.corner_radius=8 \
        background.height=24 \
        padding_left="$PILL_GAP" \
        script="$PLUGIN_DIR/aerospace_mode.sh"
