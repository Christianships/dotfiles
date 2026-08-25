#!/bin/bash
# Cycle the tiling mode: grid -> spiral -> off -> grid.
#
# dwindle.sh reads this file on every event, so the switch takes effect
# immediately; switching to grid also retiles the current workspace so the
# change is visible rather than waiting for the next window.
set -u

HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
MODE_FILE="$HERE/.dwindle-mode"

case "$(cat "$MODE_FILE" 2>/dev/null)" in
    spiral) next=off ;;
    off)    next=grid ;;
    *)      next=spiral ;;
esac

printf '%s' "$next" >"$MODE_FILE"
[ "$next" = grid ] && "$HERE/dwindle.sh" --force

/opt/homebrew/bin/sketchybar --trigger aerospace_focus_change 2>/dev/null
/usr/bin/osascript -e "display notification \"Tiling mode: $next\" with title \"AeroSpace\"" 2>/dev/null
