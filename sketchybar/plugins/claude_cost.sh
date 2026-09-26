#!/usr/bin/env bash
# Claude Code spend for today, in dollars at API list prices -- the same
# figure ccusage / the Raycast extension shows. Computed from the local
# session logs in ~/.claude/projects, so it counts this machine only.
#
# Not --offline: ccusage's bundled price table lags new models (it prices
# them at $0), so let it fetch current pricing. Pinned to a major version so
# bunx doesn't resolve @latest on every run.
source "$CONFIG_DIR/plugins/_env.sh"
source "$CONFIG_DIR/colors.sh"

today=$(date +%Y%m%d)
cost=$(bunx ccusage@20 daily --json --since "$today" --until "$today" 2>/dev/null \
    | jq -r '.totals.totalCost // empty' 2>/dev/null)

if [ -z "$cost" ]; then
    sketchybar --set claude_cost label="\$--" label.color="$FG_DIM"
    exit 0
fi

# Cents while small, whole dollars once it reaches three digits.
label=$(awk -v c="$cost" 'BEGIN { printf (c >= 100 ? "$%.0f" : "$%.2f"), c }')
sketchybar --set claude_cost label="$label" label.color="$MONEY"
