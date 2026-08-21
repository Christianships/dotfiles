#!/usr/bin/env bash
# Rebuild helpers/calendar-now.
#
# Two things here are not optional:
#
#   * The Info.plist is linked in as a __TEXT,__info_plist section. A bare
#     command-line tool has no bundle, so this is the only place TCC can find
#     NSCalendarsUsageDescription -- without it macOS kills the process on the
#     first EventKit call instead of prompting.
#
#   * The ad-hoc signature gives the binary a stable code identity, which is
#     what the granted calendar permission is attached to. Recompiling changes
#     the cdhash and therefore drops the grant, so expect to re-approve the
#     prompt after every rebuild.
#
# Run this from Terminal, not from SketchyBar, and run `./calendar-now now`
# once afterwards so the prompt is attributed to a foreground app.
set -euo pipefail
cd "$(dirname "$0")"

swiftc -O calendar-now.swift -o calendar-now \
    -framework EventKit -framework Foundation \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist \
    -Xlinker calendar-now.plist

codesign --force --sign - calendar-now
echo "built helpers/calendar-now"
