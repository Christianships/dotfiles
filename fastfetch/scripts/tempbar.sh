#!/bin/sh
# draws a temperature bar styled like fastfetch's percent bars (0-100 °C scale)
t=$(fastfetch -c "$HOME/.config/fastfetch/scripts/temp.jsonc" --format json 2>/dev/null |
  awk -F': *' '/"temperature"/ { gsub(/[, ]/, "", $2); print $2; exit }')
[ -z "$t" ] && { printf 'n/a'; exit 0; }

awk -v t="$t" 'BEGIN {
  w = 13; n = int(t / 100 * w + 0.5); if (n > w) n = w; if (n < 0) n = 0
  border = "\033[38;2;124;106;156m"; fill = "\033[38;2;200;138;252m"; reset = "\033[0m"
  bar = ""; for (i = 0; i < w; i++) bar = bar (i < n ? "▬" : (i == n ? border : "") "-")
  printf "%s[ %s%s%s]%s %s%.0f°C%s", border, fill, bar, border " ", reset, "\033[38;2;168;85;247m", t, reset
}'
