#!/usr/bin/env python3
"""Emit aerospace.toml's keybindings as JSON for the keys overlay.

Parsed straight from the live config, so the overlay can never drift out of date.
Section comments in the binding blocks become the group headings.
"""
import json
import os
import re
import sys

CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "aerospace.toml")


MODS = {"ctrl": "⌃", "alt": "⌥", "shift": "⇧", "cmd": "⌘"}
MOD_WORDS = {"ctrl": "super", "alt": "alt", "shift": "shift", "cmd": "cmd"}
MOD_ORDER = ["ctrl", "alt", "shift", "cmd"]
KEYS = {
    "enter": "↩", "tab": "⇥", "space": "␣", "esc": "⎋",
    "backspace": "⌫", "delete": "⌦", "left": "←", "down": "↓",
    "up": "↑", "right": "→", "slash": "/", "backslash": "\\",
    "comma": ",", "period": ".", "semicolon": ";", "quote": "'", "minus": "-",
    "equal": "=", "leftSquareBracket": "[", "rightSquareBracket": "]",
}
KEY_WORDS = {
    "slash": "/", "backslash": "\\", "comma": ",", "period": ".",
    "semicolon": ";", "quote": "'", "minus": "-", "equal": "=",
    "leftSquareBracket": "[", "rightSquareBracket": "]",
}


def pretty_key(chord):
    parts = chord.split("-")
    mods = [p for p in parts if p in MODS]
    rest = [p for p in parts if p not in MODS]
    key = "-".join(rest)
    key = KEYS.get(key, key.upper() if len(key) == 1 else key)
    glyphs = "".join(MODS[m] for m in MOD_ORDER if m in mods)
    return (glyphs + " " if glyphs else "") + key


def spoken_key(chord):
    """The same chord written out: 'super + shift + c'."""
    parts = chord.split("-")
    mods = [MOD_WORDS[m] for m in MOD_ORDER if m in parts]
    key = "-".join(p for p in parts if p not in MODS)
    return " + ".join(mods + [KEY_WORDS.get(key, key)])


def describe(cmd):
    """Turn an AeroSpace command into something readable."""
    cmd = cmd.strip()
    m = re.match(r"exec-and-forget\s+(.*)", cmd)
    if m:
        body = m.group(1)
        m2 = re.search(r"obs-control\.mjs\s+(.*)", body)
        if m2:
            return "OBS: " + m2.group(1)
        m2 = re.match(r"open -na \"?([^\"]+?)\"?(?:\s+--args.*)?$", body)
        if m2:
            return "Launch " + m2.group(1)
        if "keys.sh" in body:
            return "This overlay"
        m2 = re.search(r"([\w.-]+)\.(?:sh|py|mjs)\b(.*)", body)
        if m2:
            return (m2.group(1).replace("-", " ").capitalize() + m2.group(2)).strip()
        if body == "true":
            return "(disabled)"
        return body if len(body) < 40 else body[:37] + "..."
    if cmd.startswith("mode "):
        return cmd[5:].capitalize() + " mode"
    m = re.match(r"move-node-to-workspace (\S+)", cmd)
    if m:
        return "Send window to " + m.group(1)
    m = re.match(r"workspace (\S+)$", cmd)
    if m:
        return "Workspace " + m.group(1)
    m = re.match(r"focus (\S+)$", cmd)
    if m:
        return "Focus " + m.group(1)
    m = re.match(r"move (\S+)$", cmd)
    if m:
        return "Move window " + m.group(1)
    m = re.match(r"resize (\w+) ([-+]\d+)", cmd)
    if m:
        return f"{m.group(1).capitalize()} {m.group(2)}"
    if cmd.startswith("layout "):
        return "Layout: " + " / ".join(cmd[7:].split())
    if cmd.startswith("close"):
        return "Close window"
    # Bare hyphenated commands (fullscreen, balance-sizes, reload-config, ...)
    # read fine as plain English once the hyphens go.
    if re.fullmatch(r"[a-z-]+", cmd):
        return cmd.replace("-", " ").capitalize()
    return cmd


def parse():
    """-> [(mode, [(group, [(chord, desc), ...]), ...]), ...]"""
    modes, mode, group, pending = [], None, None, None
    with open(CONFIG) as fh:
        for raw in fh:
            line = raw.strip()
            m = re.match(r"\[mode\.([\w-]+)\.binding\]", line)
            if m:
                mode = (m.group(1), [])
                modes.append(mode)
                group, pending = None, None
                continue
            if line.startswith("[") and not line.startswith("[["):
                mode = None
                continue
            if mode is None:
                continue
            if line.startswith("#"):
                # First comment line of a run becomes the heading candidate.
                if pending is None:
                    pending = line.lstrip("# ").rstrip(".")
                continue
            if not line:
                pending = None
                continue
            m = re.match(r"([\w-]+)\s*=\s*(.+)", line)
            if not m:
                continue
            chord, value = m.group(1), m.group(2)
            cmds = re.findall(r"'([^']*)'", value)
            if not cmds:
                continue
            # A heading only counts if it is short enough to read as a label.
            if pending is not None and len(pending) <= 24:
                group = (pending, [])
                mode[1].append(group)
            pending = None
            if group is None:
                group = ("", [])
                mode[1].append(group)
            # Skip the bar-notification half of multi-command binds.
            useful = [c for c in cmds if "sketchybar" not in c] or cmds
            launch = [c for c in useful if c.startswith("exec-and-forget")]
            if launch:
                desc = describe(launch[0])
            else:
                desc = describe(useful[0])
                # 'move-node-to-workspace N' then 'workspace N' is one idea.
                if len(useful) > 1 and re.match(r"move-node-to-workspace (\S+)", useful[0]) \
                        and useful[1] == "workspace " + useful[0].split()[-1]:
                    desc += " & follow"
                # Returning to main mode is implicit in every mode binding.
                elif len(useful) > 1 and not useful[0].startswith("mode ") \
                        and useful[1] != "mode main":
                    desc += " + " + describe(useful[1])
            group[1].append((pretty_key(chord), spoken_key(chord), desc))
    return modes


# Not AeroSpace binds -- these are the standard emacs/readline-style line
# editing shortcuts that zsh, bash, Claude Code, and Codex CLI all honor in
# their input line. Hardcoded (nothing to parse out of aerospace.toml) and
# appended to the bottom of the main-mode list.
TERMINAL_BINDS = [
    ("⌃C", "control + c", "Cancel / interrupt current line"),
    ("⌃D", "control + d", "Delete char forward (exits on an empty line)"),
    ("⌃A", "control + a", "Jump to start of line"),
    ("⌃E", "control + e", "Jump to end of line"),
    ("⌥←", "option + left", "Jump back one word"),
    ("⌥→", "option + right", "Jump forward one word"),
    ("⌃W", "control + w", "Delete one word backward"),
    ("⌥⌫", "option + delete", "Delete one word backward"),
    ("⌃U", "control + u", "Delete from cursor to start of line"),
    ("⌃K", "control + k", "Delete from cursor to end of line"),
    ("⌃Y", "control + y", "Paste back the last deleted text"),
    ("⌃L", "control + l", "Clear the screen"),
    ("⌃R", "control + r", "Search command history"),
    ("⌃T", "control + t", "Swap the two characters before cursor"),
    ("⌃_", "control + /", "Undo last edit"),
]


def main():
    out = []
    for name, groups in parse():
        out.append({
            "mode": name,
            "groups": [{"title": t, "binds": [list(b) for b in binds]}
                       for t, binds in groups if binds],
        })
    for entry in out:
        if entry["mode"] == "main":
            entry["groups"].append({
                "title": "Terminal editing (shell / Claude Code / Codex)",
                "binds": [list(b) for b in TERMINAL_BINDS],
            })
            break
    json.dump(out, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
