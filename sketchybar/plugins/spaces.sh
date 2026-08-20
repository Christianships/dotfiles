#!/usr/bin/env bash
# Repaints every workspace pill from one pair of AeroSpace queries.
#
# Previously each of the ten pills ran its own copy of this script and they
# shared results through a temp-file cache with a 1s TTL -- which meant ten
# forks per event and a window where pills could disagree. One script that
# queries once and emits a single batched --set is both cheaper and always
# self-consistent.

source "$CONFIG_DIR/plugins/_env.sh"
source "$CONFIG_DIR/colors.sh"
source "$PLUGIN_DIR/app_icon.sh"

WORKSPACES=(1 2 3 4 5 6 7 8 9 10)

# An empty pill is a 1:1 square. SQUARE is the pill's side (it must match
# background.height in items/spaces.sh) and GLYPH is the measured advance
# width of one digit in JetBrainsMono Nerd Font Bold 12.0. Padding is
# derived so the digit lands dead centre, which also keeps "10" close to
# square instead of stretching it.
SQUARE=21
GLYPH=7

# AeroSpace hands us the new workspace on its own events; other senders
# (app launched, window closed, periodic resync) have to ask.
focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
windows=$(aerospace list-windows --all --format '%{workspace}|%{app-name}' 2>/dev/null)

args=()
for sid in "${WORKSPACES[@]}"; do
    icons=""
    seen=""
    while IFS= read -r app; do
        [ -z "$app" ] && continue
        app_icon "$app"
        # Two windows of the same app should not draw the glyph twice.
        case " $seen " in *" $icon_result "*) continue ;; esac
        seen="$seen $icon_result"
        icons="${icons}${icons:+ }${icon_result}"
    done < <(printf '%s\n' "$windows" | awk -F'|' -v ws="$sid" '$1 == ws { print $2 }' | sort -u)

    args+=(--set "space.$sid")

    if [ "$sid" = "$focused" ]; then
        # Focused: solid white pill, dark glyphs. Always drawn, even when the
        # workspace is empty, so switching to an empty workspace still shows
        # you where you are.
        args+=(drawing=on
               icon.color="$INK"
               label.color="$INK"
               background.color="$ACCENT"
               background.border_color="$EDGE_HOT")
    elif [ -n "$icons" ]; then
        # Occupied but not focused.
        args+=(drawing=on
               icon.color="$W80"
               label.color="$W65"
               background.color="$GLASS_SOFT"
               background.border_color="$TRANSPARENT")
    else
        # Empty and unfocused: hidden entirely.
        args+=(drawing=off)
    fi

    if [ -n "$icons" ]; then
        # Occupied: grow rightwards to fit the app glyphs.
        args+=(label="$icons"
               label.drawing=on
               icon.padding_left=7
               icon.padding_right=6
               label.padding_left=0
               label.padding_right=7)
    else
        # Empty: symmetric padding, so width == height == SQUARE.
        pad=$(( (SQUARE - GLYPH * ${#sid}) / 2 ))
        [ "$pad" -lt 2 ] && pad=2
        args+=(label.drawing=off
               icon.padding_left="$pad"
               icon.padding_right="$pad")
    fi
done

sketchybar "${args[@]}"
