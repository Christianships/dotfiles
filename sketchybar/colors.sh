#!/usr/bin/env bash
# Monotone liquid-glass palette.
#
# Everything is white at varying opacity over a blurred dark pane, so
# hierarchy is carried by brightness instead of hue. Red is the one hue that
# survives, and it is spent only on clocks you must not misread at a glance:
# the record/live signal, and the countdown on the current calendar event.
#
# SketchyBar colour format is 0xAARRGGBB (alpha first).

# ── White ramp ────────────────────────────────────────────────────
export W100=0xffffffff
export W95=0xf2ffffff
export W80=0xccffffff
export W65=0xa6ffffff
export W50=0x80ffffff
export W35=0x59ffffff
export W20=0x33ffffff
export W12=0x1fffffff
export W08=0x14ffffff
export W05=0x0dffffff

# Dark ink, for text sitting on a bright (near-white) pill.
export INK=0xff0e0e10

export TRANSPARENT=0x00000000

# ── Bar ───────────────────────────────────────────────────────────
# Fully transparent: no frosted pane. Only the group pills are drawn, so
# the wallpaper shows through everywhere between them.
export BAR_COLOR=$TRANSPARENT
export BAR_BORDER_COLOR=$TRANSPARENT

# ── Frosted surfaces ──────────────────────────────────────────────
export GLASS=$W08
export GLASS_SOFT=$W05
export GLASS_STRONG=0xe60e0e10

export EDGE=$W20
export EDGE_SOFT=$W12
export EDGE_HOT=$W35

# ── Semantic ──────────────────────────────────────────────────────
export FG=$W95
export FG_DIM=$W50
export ACCENT=$W100        # focused workspace fill
export ACCENT_ALT=$W80

# The one colour left in the bar.
export LIVE=0xffff453a
# Mid-tone, for a red that should read as red without shouting -- the
# countdown on an event that has not started yet. LIVE_DIM is the trough of
# the last-minute pulse and is deliberately too faint to rest at.
export LIVE_SOFT=0xb3ff453a
export LIVE_DIM=0x59ff453a
# Low battery, same hue as the record dot.
export CRITICAL=0xffff453a

# Mouse-follow indicator. The second deliberate splash of colour.
export FOLLOW=0xff32d74b
export FOLLOW_DIM=0x4032d74b

# ── Legacy names, remapped to the white ramp ──────────────────────
# The item and plugin scripts refer to these by name; pointing them at
# grey levels turns every former hue ramp into a brightness ramp.
export TEXT=$W95
export SUBTEXT1=$W80
export SUBTEXT0=$W50
export OVERLAY2=$W50
export OVERLAY1=$W35
export OVERLAY0=$W35
export SURFACE2=$W20
export SURFACE1=$W12
export SURFACE0=$W08
export CRUST=$INK
export MANTLE=$INK
export BASE=$INK

# Former accent hues -> ascending brightness, so "hotter" reads brighter.
export SAPPHIRE=$W50
export BLUE=$W50
export MAUVE=$W50
export LAVENDER=$W65
export TEAL=$W65
export SKY=$W65
export YELLOW=$W65
export GREEN=$W80
export PEACH=$W80
export FLAMINGO=$W80
export ROSEWATER=$W95
export PINK=$W95
export MAROON=$W65
export RED=$W95
export DANGER=$W95
export WARN=$W80
export OK=$W80
