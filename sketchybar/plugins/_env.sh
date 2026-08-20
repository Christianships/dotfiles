#!/usr/bin/env bash
# Sourced first by every plugin.
#
# SketchyBar exports CONFIG_DIR (and NAME/SENDER/INFO) to scripts, but not
# the variables set in sketchybarrc, so PLUGIN_DIR is rebuilt here. PATH is
# pinned because launching via `brew services` gives scripts a minimal PATH
# that lacks /opt/homebrew/bin (aerospace, node, sketchybar).

export PLUGIN_DIR="$CONFIG_DIR/plugins"
export ITEM_DIR="$CONFIG_DIR/items"
case ":$PATH:" in
    *":/opt/homebrew/bin:"*) ;;
    *) export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" ;;
esac
