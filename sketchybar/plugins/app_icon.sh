#!/usr/bin/env bash
source "$CONFIG_DIR/plugins/_env.sh"
# Wraps the upstream sketchybar-app-font map with local overrides.
# Sets $icon_result, same contract as __icon_map.

source "$PLUGIN_DIR/icon_map.sh"

app_icon() {
    case "$1" in
        # Upstream keys this as "OBS"; AeroSpace reports the real app name.
        "OBS Studio") icon_result=":obsstudio:" ;;
        *) __icon_map "$1" ;;
    esac
}
