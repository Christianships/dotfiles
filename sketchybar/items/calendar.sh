#!/usr/bin/env bash
# Current calendar event — [10:12-10:14pm] | brushing teeth | [1:48]
#
# Four items in one bracket, all owned by plugins/calendar.sh. Only
# calendar.time carries the script and the update frequency; the others are
# driven by it, so the group updates as a unit and cannot tear.
#
# Lives in the left region, immediately right of the workspace pills, and is
# therefore added in plain visual order: the left region stacks left-to-right
# in the order items are added, unlike the right region. Rendered order ends
# up: time · | · title · ring · remaining.
#
# Everything starts hidden. An empty calendar should leave no trace in the
# bar. There is no entrance or exit transition -- the group cuts in and out.

# Anything that changes the calendar can push a refresh instead of waiting out
# the plugin's cache:  sketchybar --trigger calendar_refresh
# Declared before the subscription below, which would otherwise name an event
# that does not exist yet.
sketchybar --add event calendar_refresh

# Start-end range, and the item that owns the group's update loop.
#
# updates=on is load-bearing, not a stylistic choice. The bar's default is
# when_shown, and this item hides itself when the calendar is clear -- under
# when_shown that is a one-way door, because a hidden item's script never runs
# again to notice the next event.
#
# update_freq starts at the idle rate. plugins/calendar.sh drops it to 1s once
# something is on screen, since that is what a seconds countdown and a
# creeping progress bar need, and raises it again on the way out. Polling an
# empty calendar once a second would be a second of work an hour for nothing.
#
# padding_left holds the group off the workspace pill to its left. The
# workspace pills override $GAP down to 2 for their own internals, so this
# side supplies the remainder of the gap rather than a plain half of it.
#
# padding_right, and the paddings on the three items below, override $GAP back
# down: all four share one pill, and the default gap between pills would tear
# a 10pt hole through the middle of it.
# A bracket's background spans from its first item's padding edge to its
# last, so padding can never separate this group from the workspace pills to
# its left -- it just makes the bracket wider. A spacer item belonging to
# neither bracket is the only thing that opens a real gap. It has to be
# declared before calendar.time, because the left region stacks in add order.
sketchybar --add item calendar.gap left \
    --set calendar.gap \
        width=10 \
        icon.drawing=off \
        label.drawing=off \
        background.drawing=off

sketchybar --add item calendar.time left \
    --subscribe calendar.time calendar_refresh system_woke \
    --set calendar.time \
        drawing=off \
        updates=on \
        update_freq=15 \
        icon="$ICON_CAL" \
        icon.font="$FONT:Bold:12.0" \
        icon.color="$W50" \
        icon.padding_left=10 \
        icon.padding_right=5 \
        label="--" \
        label.font="$FONT:Bold:12.0" \
        label.color="$FG" \
        label.padding_right=0 \
        padding_left=8 \
        padding_right=1 \
        script="$PLUGIN_DIR/calendar.sh" \
        click_script="open -a Calendar"

# Event title, with the divider between the schedule and the task riding in
# its icon slot. A pipe in a fifth item would be a fifth item to show, hide
# and colour in lockstep with the rest for the sake of one glyph; as an icon
# it inherits this item's visibility for free and still gets its own padding
# and colour. Dimmed well below the text it separates -- a divider that
# competes with its neighbours stops reading as punctuation.
sketchybar --add item calendar.title left \
    --set calendar.title \
        drawing=off \
        icon="|" \
        icon.font="$FONT:Bold:12.0" \
        icon.color="$W35" \
        icon.padding_left=8 \
        icon.padding_right=8 \
        label="--" \
        label.font="$FONT:SemiBold:12.0" \
        label.color="$FG" \
        label.padding_left=0 \
        label.padding_right=2 \
        padding_left=1 \
        padding_right=1

# Progress through the event, as a filling circle. This was a slider used as
# a bar; a ring says the same thing in a fifth of the width, which matters in
# a group that already carries a time range, a title and a countdown.
#
# The cost is resolution: the glyph ramp has nine steps, so on a ten-minute
# event the ring advances about once every 75 seconds rather than creeping.
# plugins/calendar.sh picks the step; the countdown beside it is what carries
# second-by-second precision.
sketchybar --add item calendar.ring left \
    --set calendar.ring \
        drawing=off \
        icon.font="$FONT:Regular:14.0" \
        icon.color="$W80" \
        icon.padding_left=2 \
        icon.padding_right=2 \
        icon.y_offset=0 \
        label.drawing=off \
        padding_left=4 \
        padding_right=0

# Remaining time. The one red thing in this group -- see colors.sh for why
# the monotone palette makes an exception for clocks. plugins/calendar.sh
# pulses it through LIVE_DIM in the last minute of an event.
sketchybar --add item calendar.left left \
    --set calendar.left \
        drawing=off \
        icon.drawing=off \
        label="--" \
        label.font="$FONT:Bold:11.0" \
        label.color="$LIVE" \
        label.padding_left=6 \
        label.padding_right=10 \
        padding_left=1

sketchybar --add bracket calendar \
        calendar.time calendar.title calendar.ring calendar.left \
    --set calendar \
        background.color="$TRANSPARENT" \
        background.border_color="$TRANSPARENT" \
        background.border_width=1 \
        background.corner_radius=9 \
        background.height=26

# Clear stale cache and render state, so a config reload starts from a
# known-hidden group rather than mid-event.
rm -f /tmp/sketchybar-calendar.json /tmp/sketchybar-calendar.state
