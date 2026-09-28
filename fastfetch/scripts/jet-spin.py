#!/usr/bin/env python3
"""Jets flying in circles in the terminal, drawn in braille like the fastfetch logo.

    jet-spin            two jets
    jet-spin 3          any number of jets
    jet-spin 1 --spin   one jet spinning in place

Any key quits.
"""
import math
import os
import re
import select
import signal
import sys
import termios
import time
import tty

LOGO = os.path.expanduser("~/.config/fastfetch/txt/jet.txt")
# Same six-step purple as the fastfetch logo, light to deep.
GRADIENT = [(236, 196, 255), (218, 166, 255), (200, 138, 252), (182, 112, 244), (164, 92, 234), (146, 76, 222)]
TRAIL = (61, 47, 92)
BITS = [(0, 0, 0x01), (0, 1, 0x02), (0, 2, 0x04), (1, 0, 0x08), (1, 1, 0x10), (1, 2, 0x20), (0, 3, 0x40), (1, 3, 0x80)]


def load_dots(path):
    """Braille text -> list of (x, y) dots, centred on the jet."""
    text = re.sub(r"\$[0-9]", "", open(path, encoding="utf-8").read())
    dots = []
    for row, line in enumerate(text.splitlines()):
        for col, ch in enumerate(line):
            v = ord(ch) - 0x2800
            if 0 < v <= 0xFF:
                dots += [(col * 2 + dx, row * 4 + dy) for dx, dy, bit in BITS if v & bit]
    cx = sum(x for x, _ in dots) / len(dots)
    cy = sum(y for _, y in dots) / len(dots)
    return [(x - cx, y - cy) for x, y in dots]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    count = max(1, int(args[0])) if args else 2
    spin_in_place = "--spin" in sys.argv
    source = load_dots(LOGO)
    reach = max(math.hypot(x, y) for x, y in source)

    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    out = sys.stdout
    signal.signal(signal.SIGINT, lambda *_: None)
    tty.setcbreak(fd)
    out.write("\x1b[?1049h\x1b[?25l\x1b[2J")
    trails = [[] for _ in range(count)]
    start = time.monotonic()
    try:
        while True:
            if select.select([sys.stdin], [], [], 0)[0]:
                break
            cols, rows = os.get_terminal_size()
            rows -= 1
            W, H = cols * 2, rows * 4  # canvas in braille dots
            t = time.monotonic() - start

            # Size the jets and the circle to the window.
            if spin_in_place:
                scale = min(W, H) * 0.45 / reach
                radius = 0
            else:
                scale = min(W, H) * 0.16 / reach
                radius = min(W, H) * 0.5 - reach * scale - 2
            jets = []
            for i in range(count):
                a = t * 0.9 + i * 2 * math.pi / count
                x = W / 2 + radius * math.cos(a)
                y = H / 2 + radius * math.sin(a)
                # Nose points +x in the art; face along the circle (or just spin).
                heading = a * 2.5 if spin_in_place else a + math.pi / 2
                jets.append((x, y, heading))

            canvas = {}  # (cell col, cell row) -> [bits, colour]
            for i, (x, y, _) in enumerate(jets):
                if not spin_in_place:
                    trails[i] = (trails[i] + [(x, y)])[-40:]
                    for px, py in trails[i][:-6]:
                        cell = canvas.setdefault((int(px) // 2, int(py) // 4), [0, TRAIL])
                        cell[0] |= next(b for dx, dy, b in BITS if dx == int(px) % 2 and dy == int(py) % 4)
            for x, y, heading in jets:
                c, s = math.cos(heading), math.sin(heading)
                for dx, dy in source:
                    px = int(x + (dx * c - dy * s) * scale)
                    py = int(y + (dx * s + dy * c) * scale)
                    if 0 <= px < W and 0 <= py < H:
                        cell = canvas.setdefault((px // 2, py // 4), [0, None])
                        cell[0] |= next(b for bx, by, b in BITS if bx == px % 2 and by == py % 4)
                        cell[1] = GRADIENT[min(5, py * 6 // H)]

            frame = ["\x1b[H"]
            for r in range(rows):
                line, colour = [], None
                for col in range(cols):
                    cell = canvas.get((col, r))
                    if not cell:
                        line.append(" ")
                        continue
                    if cell[1] != colour:
                        colour = cell[1]
                        line.append("\x1b[38;2;%d;%d;%dm" % colour)
                    line.append(chr(0x2800 + cell[0]))
                frame.append("".join(line) + "\x1b[0m\x1b[K" + ("\n" if r < rows - 1 else ""))
            out.write("".join(frame))
            out.flush()
            time.sleep(1 / 30)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        out.write("\x1b[0m\x1b[?25h\x1b[?1049l")
        out.flush()


if __name__ == "__main__":
    main()
