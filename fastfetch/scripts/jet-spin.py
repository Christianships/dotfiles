#!/usr/bin/env python3
"""The fastfetch braille jet, animated in the terminal.

    jet-spin             spin 360° on a turntable, like a model in a 3D editor
    jet-spin --orbit     two jets flying in a circle
    jet-spin --orbit 3   any number of jets
    jet-spin --fetch     fastfetch, with the logo doing one 3D spin before it settles

Any key quits the first three.
"""
import math
import os
import re
import select
import signal
import subprocess
import sys
import termios
import time
import tty

LOGO = os.path.expanduser("~/.config/fastfetch/txt/jet.txt")
# The fastfetch purple, light to deep, plus two darker steps for the far side.
GRADIENT = [(236, 196, 255), (218, 166, 255), (200, 138, 252), (182, 112, 244),
            (164, 92, 234), (146, 76, 222), (118, 62, 184), (92, 52, 140)]
TRAIL = (61, 47, 92)
GRID, SHADOW, HUD = (43, 32, 64), (28, 20, 42), (124, 106, 156)
# Blender's axis colours. Z is up; X and Y lie on the floor.
AXIS = {"X": (220, 80, 90), "Y": (120, 200, 100), "Z": (90, 130, 230)}
BITS = {(0, 0): 0x01, (0, 1): 0x02, (0, 2): 0x04, (1, 0): 0x08,
        (1, 1): 0x10, (1, 2): 0x20, (0, 3): 0x40, (1, 3): 0x80}


def load_dots(path):
    """Braille text -> list of integer (x, y) dots."""
    text = re.sub(r"\$[0-9]", "", open(path, encoding="utf-8").read())
    dots = []
    for row, line in enumerate(text.splitlines()):
        for col, ch in enumerate(line):
            v = ord(ch) - 0x2800
            if 0 < v <= 0xFF:
                dots += [(col * 2 + dx, row * 4 + dy) for (dx, dy), bit in BITS.items() if v & bit]
    return dots


def centred(dots):
    cx = sum(x for x, _ in dots) / len(dots)
    cy = sum(y for _, y in dots) / len(dots)
    return [(x - cx, y - cy) for x, y in dots]


class Canvas:
    """Braille cells. Each cell keeps the colour of its highest-priority, nearest dot."""

    def __init__(self, cols, rows):
        self.cols, self.rows = cols, rows
        self.W, self.H = cols * 2, rows * 4
        self.cells = {}
        self.text = {}

    def plot(self, px, py, colour, prio=0, depth=0.0):
        px, py = int(px), int(py)
        if not (0 <= px < self.W and 0 <= py < self.H):
            return
        key = (px >> 1, py >> 2)
        bit = BITS[(px & 1, py & 3)]
        cell = self.cells.get(key)
        if cell is None:
            self.cells[key] = [bit, colour, prio, depth]
            return
        cell[0] |= bit
        if prio > cell[2] or (prio == cell[2] and depth < cell[3]):
            cell[1], cell[2], cell[3] = colour, prio, depth

    def line(self, x0, y0, x1, y1, colour, prio=0, dotted=False):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(0, n + 1, 3 if dotted else 1):
            self.plot(x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, colour, prio)

    def write(self, col, row, s, colour):
        for i, ch in enumerate(s):
            self.text[(col + i, row)] = (ch, colour)

    def render(self):
        rows = self.lines()
        return "\x1b[H" + "".join(l + "\x1b[K" + ("\n" if i < len(rows) - 1 else "") for i, l in enumerate(rows))

    def lines(self):
        """One string per row, each exactly `cols` wide, colours reset at the end."""
        out = []
        for r in range(self.rows):
            line, colour = [], None
            for c in range(self.cols):
                t = self.text.get((c, r))
                cell = self.cells.get((c, r))
                if t:
                    ch, col = t
                elif cell:
                    ch, col = chr(0x2800 + cell[0]), cell[1]
                else:
                    line.append(" ")
                    continue
                if col != colour:
                    colour = col
                    line.append("\x1b[38;2;%d;%d;%dm" % col)
                line.append(ch)
            out.append("".join(line) + "\x1b[0m")
        return out


class Turntable:
    """The jet lying flat, spun about the vertical axis under a raised 3/4 camera."""

    ELEVATION = math.radians(52)
    AZIMUTH = math.radians(-35)

    def __init__(self, dots):
        # Thickness from how crowded each dot's neighbourhood is: the fuselage
        # comes out fat, wingtips and fins stay thin.
        occupied = set(dots)
        density = [sum((x + dx, y + dy) in occupied for dx in range(-3, 4) for dy in range(-3, 4)) for x, y in dots]
        top = max(density)
        pts = centred(dots)
        self.reach = max(math.hypot(x, y) for x, y in pts)
        thick = self.reach * 0.1
        # (X, Y, Z, shade): art x -> X (nose), art y -> Z, height -> Y. shade -1 top, 0 middle, +1 underside.
        self.model = []
        for (u, v), d in zip(pts, density):
            d /= top
            self.model.append((u, 0.0, v, 0))
            if d > 0.3:
                self.model.append((u, d * thick, v, -1))
                self.model.append((u, -d * thick, v, 1))
        self.floor = -self.reach * 0.55
        self.grid_cache = None

    def project(self, X, Y, Z, yaw_c, yaw_s):
        """Y is height here; yaw is the turntable angle plus the camera's azimuth."""
        x1 = X * yaw_c - Z * yaw_s
        z1 = X * yaw_s + Z * yaw_c
        ce, se = math.cos(self.ELEVATION), math.sin(self.ELEVATION)
        yv = Y * ce + z1 * se           # far side sits higher on screen
        zv = z1 * ce - Y * se           # depth away from the camera
        p = self.focal / (self.focal + zv)
        return self.cx + x1 * p * self.scale, self.cy - yv * p * self.scale, zv

    def draw(self, canvas, t):
        W, H = canvas.W, canvas.H
        self.cx, self.cy = W / 2, H * 0.5
        self.scale = min(W * 0.3, H * 0.5) / self.reach
        self.focal = self.reach * 4
        yaw = t * 0.9

        az_c, az_s = math.cos(self.AZIMUTH), math.sin(self.AZIMUTH)
        # Floor grid, fixed like a 3D viewport, with the X (red) and Y (green) axes.
        if self.grid_cache != (W, H):
            self.grid_cache = (W, H)
            self.grid = []
            R, n = self.reach * 1.15, 4
            for i in range(-n, n + 1):
                k = R * i / n
                for a, b, colour in (((-R, k), (R, k), AXIS["X"] if i == 0 else GRID),
                                     ((k, -R), (k, R), AXIS["Y"] if i == 0 else GRID)):
                    x0, y0, _ = self.project(a[0], self.floor, a[1], az_c, az_s)
                    x1, y1, _ = self.project(b[0], self.floor, b[1], az_c, az_s)
                    dim = colour if colour == GRID else tuple(c // 2 for c in colour)
                    self.grid.append((x0, y0, x1, y1, dim))
        for x0, y0, x1, y1, colour in self.grid:
            canvas.line(x0, y0, x1, y1, colour, prio=0, dotted=colour == GRID)

        c, s = math.cos(yaw + self.AZIMUTH), math.sin(yaw + self.AZIMUTH)
        # Shadow straight down on the floor.
        for X, Y, Z, shade in self.model:
            if shade == 0:
                px, py, _ = self.project(X, self.floor, Z, c, s)
                canvas.plot(px, py, SHADOW, prio=1)
        for X, Y, Z, shade in self.model:
            px, py, zv = self.project(X, Y, Z, c, s)
            near = (zv / self.reach + 1) / 2             # 0 near .. 1 far
            idx = min(len(GRADIENT) - 1, max(0, int(near * 6) + shade + 1))
            canvas.plot(px, py, GRADIENT[idx], prio=2, depth=zv)

        # Axis gizmo, bottom right, same camera without perspective.
        gx, gy, L = W - 24, H - 20, 12
        ce, se = math.cos(self.ELEVATION), math.sin(self.ELEVATION)
        # (floor-x, height, floor-y) in this file's coordinates.
        for name, (X, Y, Z) in (("X", (1, 0, 0)), ("Y", (0, 0, 1)), ("Z", (0, 1, 0))):
            x1 = X * az_c - Z * az_s
            z1 = X * az_s + Z * az_c
            ex, ey = gx + x1 * L, gy - (Y * ce + z1 * se) * L
            canvas.line(gx, gy, ex, ey, AXIS[name], prio=3)
            canvas.write(int(ex + (ex - gx) * 0.35) // 2, int(ey + (ey - gy) * 0.35) // 4, name, AXIS[name])

        deg = int(math.degrees(yaw)) % 360
        canvas.write(2, 1, "User Perspective", HUD)
        canvas.write(2, 2, "(1) Scene | jet", HUD)
        canvas.write(2, canvas.rows - 2, "Rotation Z  %3d°" % deg, HUD)


class Orbit:
    """Jets flying in a circle, each facing along it, with contrails."""

    def __init__(self, dots, count):
        self.source = centred(dots)
        self.reach = max(math.hypot(x, y) for x, y in self.source)
        self.count = count
        self.trails = [[] for _ in range(count)]

    def draw(self, canvas, t):
        W, H = canvas.W, canvas.H
        scale = min(W, H) * 0.16 / self.reach
        radius = min(W, H) * 0.5 - self.reach * scale - 2
        for i in range(self.count):
            a = t * 0.9 + i * 2 * math.pi / self.count
            x, y = W / 2 + radius * math.cos(a), H / 2 + radius * math.sin(a)
            self.trails[i] = (self.trails[i] + [(x, y)])[-40:]
            for px, py in self.trails[i][:-6]:
                canvas.plot(px, py, TRAIL, prio=0)
            h = a + math.pi / 2
            c, s = math.cos(h), math.sin(h)
            for dx, dy in self.source:
                py = y + (dx * s + dy * c) * scale
                canvas.plot(x + (dx * c - dy * s) * scale, py, GRADIENT[min(5, int(py * 6 // H))], prio=1)


def smoothstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


class FetchSpin(Turntable):
    """The fastfetch logo: starts flat exactly as fastfetch draws it, tilts back,
    spins once, and lays flat again. No grid or labels, just the jet."""

    DURATION = 3.6

    def __init__(self, dots, pad):
        super().__init__(dots)
        self.pad = pad
        xs, ys = [x for x, _ in dots], [y for _, y in dots]
        self.art_h = max(ys) + 1
        # Where fastfetch puts the jet: `pad` columns in, top row flush.
        self.origin = (pad * 2 + sum(xs) / len(xs), sum(ys) / len(ys))
        # Keep each model point's original art row for the fastfetch colour bands.
        self.rows = []
        cy = self.origin[1]
        for X, Y, Z, shade in self.model:
            self.rows.append(Z + cy)

    def draw(self, canvas, t):
        tilt = smoothstep(t / 0.7) * (1 - smoothstep((t - (self.DURATION - 0.7)) / 0.7))
        yaw = 2 * math.pi * smoothstep((t - 0.3) / (self.DURATION - 0.6))
        elevation = math.radians(90 - 40 * tilt)
        ce, se = math.cos(elevation), math.sin(elevation)
        c, s = math.cos(yaw), math.sin(yaw)
        focal = self.reach * 4
        ox, oy = self.origin
        for (X, Y, Z, shade), row in zip(self.model, self.rows):
            Y *= tilt  # thickness grows in as it tilts, so flat frames match the static logo
            x1 = X * c - Z * s
            z1 = X * s + Z * c
            # Art-down (+Z) faces the camera, so looking straight down (90°)
            # gives back the art exactly; height (Y) points up the screen.
            sy = z1 * se - Y * ce
            depth = -z1 * ce - Y * se
            p = focal / (focal + depth)
            band = min(5, int(row * 6 // self.art_h))
            shading = int(round(depth / self.reach * 1.5 * tilt))
            idx = min(len(GRADIENT) - 1, max(0, band + shading + (shade if tilt > 0.3 else 0)))
            canvas.plot(ox + x1 * p, oy + sy * p, GRADIENT[idx], prio=2, depth=depth)


def static_logo(path, width):
    """The logo exactly as fastfetch prints it: $1..$6 switch colours, padded to `width`."""
    lines = []
    colour = GRADIENT[0]
    for raw in open(path, encoding="utf-8").read().splitlines():
        out, visible = [], 0
        for part in re.split(r"(\$[1-6])", raw):
            if re.fullmatch(r"\$[1-6]", part):
                colour = GRADIENT[int(part[1]) - 1]
            elif part:
                out.append("\x1b[38;2;%d;%d;%dm%s" % (colour + (part,)))
                visible += len(part)
        lines.append(" " * 2 + "".join(out) + "\x1b[0m" + " " * max(0, width - 2 - visible))
    return lines


def fetch():
    """fastfetch with the logo spinning once in 3D before it settles into the normal static logo."""
    pad, gap = 2, 2
    art = [l for l in re.sub(r"\$[0-9]", "", open(LOGO, encoding="utf-8").read()).splitlines()]
    width = pad + max(len(l) for l in art) + gap
    info = subprocess.run(["fastfetch", "--logo", "none", "--pipe", "false"],
                          capture_output=True, text=True).stdout.rstrip("\n").split("\n")
    final = static_logo(LOGO, width)
    height = max(len(final), len(info))
    final += [" " * width] * (height - len(final))
    info += [""] * (height - len(info))
    out = sys.stdout

    def show(left):
        out.write("\r" + "\n".join("\x1b[2K" + l + r for l, r in zip(left, info)))

    try:
        rows_available = os.get_terminal_size().lines
    except OSError:
        rows_available = 0
    if not out.isatty() or rows_available <= height:
        show(final)
        out.write("\n")
        return

    scene = FetchSpin(load_dots(LOGO), pad)
    out.write("\x1b[?25l" + "\n" * height + "\x1b[%dA" % height)
    start = time.monotonic()
    try:
        while (t := time.monotonic() - start) < FetchSpin.DURATION:
            canvas = Canvas(width, height)
            scene.draw(canvas, t)
            show(canvas.lines())
            out.write("\x1b[%dA\r" % (height - 1))
            out.flush()
            time.sleep(1 / 30)
    except KeyboardInterrupt:
        pass
    finally:
        show(final)
        out.write("\x1b[0m\x1b[?25h\n")
        out.flush()


def main():
    if "--fetch" in sys.argv:
        return fetch()
    dots = load_dots(LOGO)
    if "--orbit" in sys.argv:
        nums = [a for a in sys.argv[1:] if a.isdigit()]
        scene = Orbit(dots, max(1, int(nums[0])) if nums else 2)
    else:
        scene = Turntable(dots)

    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd)
    out = sys.stdout
    signal.signal(signal.SIGINT, lambda *_: None)
    tty.setcbreak(fd)
    out.write("\x1b[?1049h\x1b[?25l\x1b[2J")
    start = time.monotonic()
    try:
        while not select.select([sys.stdin], [], [], 0)[0]:
            frame_start = time.monotonic()
            cols, rows = os.get_terminal_size()
            canvas = Canvas(cols, rows - 1)
            scene.draw(canvas, frame_start - start)
            out.write(canvas.render())
            out.flush()
            time.sleep(max(0, 1 / 30 - (time.monotonic() - frame_start)))
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, saved)
        out.write("\x1b[0m\x1b[?25h\x1b[?1049l")
        out.flush()


if __name__ == "__main__":
    main()
