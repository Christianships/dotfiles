#!/bin/bash
# Hyprland-style tiling for AeroSpace.
#
# AeroSpace inserts every new window as a sibling of the focused one, so a
# workspace grows into ever-narrower columns: four windows means four slivers.
# This restores the two layouts people actually want from Hyprland.
#
#   grid   (default) -- the fourth window, and only the fourth, snaps the
#                       workspace into a true 2x2 of equal quarters. Below
#                       that AeroSpace's own tiling is left alone, so one to
#                       three windows open side by side as normal.
#   spiral           -- Hyprland's dwindle proper: each new window halves the
#                       focused window across its longer axis, so the tree
#                       spirals into the last-focused corner.
#
# Mode lives in .dwindle-mode next to this script; dwindle-toggle.sh cycles it
# through grid -> spiral -> off. Both layouts need the two normalizations
# disabled in aerospace.toml, otherwise AeroSpace flattens the tree back into
# a single row and `split` is a documented no-op.
#
# Invoked from on-focus-changed and on-window-detected. Pass --force to rebuild
# unconditionally (that is what the retile keybinding does).

set -u

AEROSPACE=/opt/homebrew/bin/aerospace
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
WINDOW_SIZE="$HERE/bin/window-size"
MODE_FILE="$HERE/.dwindle-mode"
STATE_DIR="${TMPDIR:-/tmp}/aerospace-dwindle"
LOCK_DIR="$STATE_DIR/.lock"
# Grid mode only intervenes at exactly this many windows. Fewer, and plain
# AeroSpace tiling is already what you want; more, and reshuffling the whole
# workspace into an uneven grid is more disruptive than leaving the tree be.
# The retile key (--force) ignores this and rebuilds whatever it finds.
GRID_AT=4

force=0
[ "${1:-}" = "--force" ] && force=1

mode="$(cat "$MODE_FILE" 2>/dev/null)"
[ -n "$mode" ] || mode=grid
[ "$mode" = off ] && exit 0
[ -x "$WINDOW_SIZE" ] || exit 0

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# on-focus-changed and on-window-detected both fire for a newly opened window,
# and a rebuild can itself nudge focus. Without a lock those runs interleave
# and fight over the same tree. A lock older than 5s is assumed dead.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    now="$(date +%s)"
    age=$(( now - $(stat -f %m "$LOCK_DIR" 2>/dev/null || printf '%s' "$now") ))
    [ "$age" -gt 5 ] && rmdir "$LOCK_DIR" 2>/dev/null
    exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

workspace="$("$AEROSPACE" list-workspaces --focused 2>/dev/null)"
[ -n "$workspace" ] || exit 0

# Windows come back in depth-first order, which is also left-to-right on
# screen, so index order is the order we want to lay them out in.
ids=()
count=0

# Is this workspace wider than it is tall? The union of the tiled windows is
# the workspace's usable rect, and it decides whether the grid stacks into
# columns or rows. Only meaningful once the tree is flat and every window is
# actually tiled, so it is called from inside the rebuild.
primary_axis() {
    local min_x=999999 min_y=999999 max_x=-999999 max_y=-999999 id x y w h
    for id in "${ids[@]}"; do
        read -r x y w h <<<"$("$WINDOW_SIZE" "$id" 2>/dev/null)"
        case "${x:-}" in ''|*[!0-9-]*) continue ;; esac
        [ "$x" -lt "$min_x" ] && min_x="$x"
        [ "$y" -lt "$min_y" ] && min_y="$y"
        [ $(( x + w )) -gt "$max_x" ] && max_x=$(( x + w ))
        [ $(( y + h )) -gt "$max_y" ] && max_y=$(( y + h ))
    done
    if [ "$max_x" -lt "$min_x" ] || [ $(( max_x - min_x )) -ge $(( max_y - min_y )) ]; then
        printf horizontal
    else
        printf vertical
    fi
}

read_windows() {
    ids=()
    while read -r id; do
        [ -n "$id" ] && ids+=("$id")
    done < <("$AEROSPACE" list-windows --workspace "$workspace" --format '%{window-id}' 2>/dev/null)
    count="${#ids[@]}"
}

# How many distinct tracks (columns for a horizontal grid, rows for a vertical
# one) the windows currently occupy. Used to tell a finished rebuild from one
# that raced AeroSpace and silently did nothing.
track_count() {
    local axis="$1" id x y w h
    for id in "${ids[@]}"; do
        read -r x y w h <<<"$("$WINDOW_SIZE" "$id" 2>/dev/null)"
        case "${x:-}" in ''|*[!0-9-]*) continue ;; esac
        if [ "$axis" = horizontal ]; then printf '%s\n' "$x"; else printf '%s\n' "$y"; fi
    done | sort -u | grep -c .
}

# ---------------------------------------------------------------- grid mode

# Rebuild the workspace as an even grid of two rows (or two columns on a
# portrait display). Nothing here moves focus: join-with and layout both take
# --window-id, so the user's focused window is untouched throughout.
#
# Columns hold at most two windows each, which matters more than it looks:
# join-with only ever merges a window with one neighbour, so a three-deep
# column would come out nested and unevenly sized. Capping at two keeps every
# tile an exact, equal share.
rebuild_grid() {
    local axis primary secondary join_dir cols pairs i built

    "$AEROSPACE" flatten-workspace-tree --workspace "$workspace" >/dev/null 2>&1
    sleep 0.15
    # Re-read after flattening: the depth-first order is what decides which
    # windows get paired, and flattening can reshuffle it.
    read_windows
    [ "$count" -lt 2 ] && return 1

    axis="$(primary_axis)"
    if [ "$axis" = horizontal ]; then
        primary=h_tiles; secondary=v_tiles; join_dir=right
    else
        primary=v_tiles; secondary=h_tiles; join_dir=down
    fi

    # h_tiles/v_tiles rather than `tiles horizontal`: a multi-argument layout
    # call toggles between its arguments instead of setting one, which is the
    # opposite of what a rebuild wants.
    "$AEROSPACE" layout --window-id "${ids[0]}" "$primary" >/dev/null 2>&1
    sleep 0.12

    # ceil(count/2) tracks, so the first (count - cols) of them are doubled up
    # and any leftover track runs the full length.
    cols=$(( (count + 1) / 2 ))
    pairs=$(( count - cols ))
    i=0
    built=0
    while [ "$built" -lt "$pairs" ]; do
        "$AEROSPACE" join-with --window-id "${ids[$i]}" "$join_dir" >/dev/null 2>&1
        sleep 0.1
        "$AEROSPACE" layout --window-id "${ids[$i]}" "$secondary" >/dev/null 2>&1
        sleep 0.1
        i=$(( i + 2 ))
        built=$(( built + 1 ))
    done

    "$AEROSPACE" balance-sizes --workspace "$workspace" >/dev/null 2>&1
    sleep 0.2

    # A join that lost a race leaves the workspace as one flat track. Report
    # that so the caller can try again rather than leaving a broken layout.
    [ "$(track_count "$axis")" -eq "$cols" ]
}

# -------------------------------------------------------------- spiral mode

# Pre-set the focused window's split orientation to its short axis, so the
# next window to appear halves it rather than adding another column. This is
# the trick i3/sway autotiling scripts use, and it reproduces dwindle exactly.
prepare_spiral() {
    local window_id fullscreen layout size settled x y w h orientation state_file
    read -r window_id fullscreen layout <<<"$(
        "$AEROSPACE" list-windows --focused \
            --format '%{window-id} %{window-is-fullscreen} %{window-layout}' 2>/dev/null
    )"
    case "${window_id:-}" in ''|*[!0-9]*) return ;; esac
    [ "$fullscreen" = true ] && return
    [ "$layout" = floating ] && return

    # AeroSpace reports focus before the new frames have settled, so sample
    # once the layout pass has landed and prefer the later reading.
    sleep 0.09
    size="$("$WINDOW_SIZE" "$window_id" 2>/dev/null)" || return
    sleep 0.06
    settled="$("$WINDOW_SIZE" "$window_id" 2>/dev/null)"
    [ -n "$settled" ] && size="$settled"

    read -r x y w h <<<"$size"
    case "${w:-}${h:-}" in ''|*[!0-9]*) return ;; esac
    if [ "$w" -ge "$h" ]; then orientation=horizontal; else orientation=vertical; fi

    # `split` is not idempotent -- re-running it keeps nesting single-child
    # containers -- so act only when the window's proportions have actually
    # flipped, which is exactly when the tree needs a new split anyway.
    state_file="$STATE_DIR/split-$window_id"
    [ "$(cat "$state_file" 2>/dev/null)" = "$orientation" ] && return
    "$AEROSPACE" split --window-id "$window_id" "$orientation" >/dev/null 2>&1 \
        && printf '%s' "$orientation" >"$state_file"
}

# ------------------------------------------------------------------ dispatch

read_windows

if [ "$mode" = grid ]; then
    # Rebuilding on every focus change would thrash the tree, so only look
    # when the window count moved. That also covers closes, which AeroSpace
    # has no event for.
    count_file="$STATE_DIR/count-$workspace"
    if [ "$force" -eq 0 ] && [ "$(cat "$count_file" 2>/dev/null)" = "$count" ]; then
        exit 0
    fi

    # on-window-detected fires while AeroSpace is still inserting the window,
    # and rebuilding against a half-placed tree is what makes joins silently
    # fail. Wait for the count to hold steady before touching anything.
    for _ in 1 2 3 4 5 6; do
        previous="$count"
        sleep 0.2
        read_windows
        [ "$count" = "$previous" ] && break
    done

    # Record the settled count before bailing out, so the next event compares
    # against reality and the fourth window still triggers a rebuild.
    printf '%s' "$count" >"$count_file"
    if [ "$force" -eq 0 ] && [ "$count" -ne "$GRID_AT" ]; then
        exit 0
    fi
    [ "$count" -lt 2 ] && exit 0

    for _ in 1 2 3; do
        rebuild_grid && break
        sleep 0.25
        read_windows
    done
    printf '%s' "$count" >"$count_file"
else
    prepare_spiral
fi
