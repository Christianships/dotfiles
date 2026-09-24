#!/usr/bin/env bash
# Battery. padding_left is the full $PILL_GAP because the stats bracket to
# its left contributes none of the gap.
#
# Wi-Fi and volume were removed deliberately: both are transient
# information macOS already surfaces on change, and the right cluster has to
# stay clear of the notch.

sketchybar --add item battery right \
    --subscribe battery power_source_change system_woke \
    --set battery \
        update_freq=60 \
        icon.color="$FG" \
        icon.padding_left=9 \
        icon.padding_right=6 \
        label.font="$FONT:SemiBold:12.0" \
        label.color="$FG" \
        label.padding_right=10 \
        padding_left="$PILL_GAP" \
        background.color="$GLASS" \
        background.border_color="$EDGE_SOFT" \
        background.border_width=1 \
        background.corner_radius=9 \
        background.height=26 \
        script="$PLUGIN_DIR/battery.sh"
