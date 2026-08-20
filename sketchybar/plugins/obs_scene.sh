#!/usr/bin/env bash
source "$CONFIG_DIR/plugins/_env.sh"
# Dismiss the scene popup when the pointer leaves the bar. Everything else
# about this item is driven by obs-bridge.mjs.
[ "$SENDER" = "mouse.exited.global" ] && sketchybar --set obs.scene popup.drawing=off
exit 0
