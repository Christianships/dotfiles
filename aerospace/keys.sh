#!/bin/sh
# Toggle the keybinding overlay. Rebuilds the panel binary whenever its source
# is newer, so editing keys.swift is enough -- no separate compile step.
set -e
dir="$(cd "$(dirname "$0")" && pwd)"

if pkill -x keys 2>/dev/null; then
    exit 0
fi

if [ ! -x "$dir/bin/keys" ] || [ "$dir/bin/keys.swift" -nt "$dir/bin/keys" ]; then
    swiftc -O -o "$dir/bin/keys" "$dir/bin/keys.swift"
fi

/usr/bin/env python3 "$dir/cheatsheet.py" | "$dir/bin/keys"
