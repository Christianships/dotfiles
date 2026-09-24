#!/usr/bin/env bash
# Nerd Font glyphs (JetBrainsMono Nerd Font), every codepoint verified
# present in the installed font. Keeping them in one file means
# restyling never turns into grepping through plugins.

export ICON_SCENE=""  # U+F03D
export ICON_REC=""  # U+F111
export ICON_REC_IDLE=""  # U+F10C
export ICON_PAUSE=""  # U+F04C
export ICON_LIVE="󰑙"  # U+F0459
export ICON_CURSOR=""  # U+F245 (fa-mouse-pointer)
export ICON_DOT="󰧞"  # U+F09DE (md-circle-small)
export ICON_VCAM="󰖠"  # U+F05A0
export ICON_KEYBOARD=""  # U+F11C
export ICON_RESIZE="󰩩"  # U+F0A69
export ICON_COG="󰒓"  # U+F0493
export ICON_CPU=""  # U+F2DB
export ICON_GPU="󰢮"  # U+F08AE (md-expansion-card-variant)
export ICON_TEMP="󰔏"  # U+F050F (md-thermometer)
export ICON_MEM=""  # U+F1C0 (fa-database)
export ICON_WIFI=""  # U+F1EB
export ICON_WIFI_OFF="󰖪"  # U+F05AA
export ICON_CLOCK=""  # U+F017
export ICON_CAL=""  # U+F133
export ICON_CLAUDE_5H="󰔟"  # U+F051F (md-timer_sand)
export ICON_CLAUDE_WK="󰨳"  # U+F0A33 (md-calendar_week)

# Circular progress, empty to full in eighths: how far through the current
# calendar event you are. nf-md-circle_outline plus nf-md-circle_slice_1..8
# (U+F0130, U+F0A9E..U+F0AA5). The slice glyphs draw the unfilled remainder as
# an outline, so the ring still reads as a whole circle at 1/8. Space-
# separated rather than an array because bash cannot export one.
export ICON_RING_RAMP="󰄰 󰪞 󰪟 󰪠 󰪡 󰪢 󰪣 󰪤 󰪥"
export ICON_VOL_MUTE="󰝟"  # U+F075F
export ICON_VOL_0=""  # U+F026
export ICON_VOL_1=""  # U+F027
export ICON_VOL_2=""  # U+F028
export ICON_BAT_0=""  # U+F244
export ICON_BAT_1=""  # U+F243
export ICON_BAT_2=""  # U+F242
export ICON_BAT_3=""  # U+F241
export ICON_BAT_4=""  # U+F240
export ICON_BAT_CHARGING="󰂄"  # U+F0084
