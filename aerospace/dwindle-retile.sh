#!/bin/bash
# Force the focused workspace back into shape in the current tiling mode.
#
# Useful after closing windows, dragging one to another workspace, or any
# manual rearranging that left the grid lopsided.
set -u
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"
exec "$HERE/dwindle.sh" --force
