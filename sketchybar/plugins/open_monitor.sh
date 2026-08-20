#!/usr/bin/env bash
# Click target for the CPU / RAM pills: jump to the nearest free workspace
# and open btop there in Ghostty.

source "$CONFIG_DIR/plugins/_env.sh"

MONITOR_CMD="${MONITOR_CMD:-btop}"

current=$(aerospace list-workspaces --focused 2>/dev/null)
[ -z "$current" ] && exit 0

# Workspaces that currently hold at least one window.
occupied=$(aerospace list-windows --all --format '%{workspace}' 2>/dev/null | sort -u)

# Nearest empty workspace by distance from the current one. Iterating
# ascending with -le means a tie resolves to the higher number, so the jump
# is rightward rather than backwards.
best=""
best_d=999
for sid in 1 2 3 4 5 6 7 8 9 10; do
    printf '%s\n' "$occupied" | grep -qx "$sid" && continue
    if [ "$sid" -gt "$current" ]; then d=$(( sid - current )); else d=$(( current - sid )); fi
    if [ "$d" -le "$best_d" ]; then best="$sid"; best_d="$d"; fi
done

# Every workspace busy: fall back to opening it right here.
[ -z "$best" ] && best="$current"

aerospace workspace "$best"
# Let AeroSpace settle on the new workspace before the window appears, so it
# gets tiled there instead of on the workspace we just left.
sleep 0.25
open -na Ghostty --args -e "$MONITOR_CMD"
