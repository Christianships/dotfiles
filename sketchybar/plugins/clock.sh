#!/usr/bin/env bash
source "$CONFIG_DIR/plugins/_env.sh"
sketchybar --set clock label="$(date '+%a %-I:%M %p')"
