#!/usr/bin/env bash
source "$CONFIG_DIR/plugins/_env.sh"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

info=$(pmset -g batt 2>/dev/null)
pct=$(printf '%s' "$info" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
[ -z "$pct" ] && exit 0

# Charge level is carried by the glyph shape, so the icon stays plain white
# -- the one exception is a genuinely low battery, which turns red.
if printf '%s' "$info" | grep -q "AC Power"; then
    icon="$ICON_BAT_CHARGING"
elif [ "$pct" -ge 80 ]; then icon="$ICON_BAT_4"
elif [ "$pct" -ge 60 ]; then icon="$ICON_BAT_3"
elif [ "$pct" -ge 40 ]; then icon="$ICON_BAT_2"
elif [ "$pct" -ge 20 ]; then icon="$ICON_BAT_1"
else                         icon="$ICON_BAT_0"
fi

if [ "$pct" -lt 20 ]; then
    color="$CRITICAL"
else
    color="$FG"
fi

sketchybar --set battery icon="$icon" icon.color="$color" label="${pct}%"
