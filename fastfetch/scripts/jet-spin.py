#!/usr/bin/env python3
"""The fastfetch braille jet, animated in the terminal.

    jet-spin             spin 360° on a turntable, like a model in a 3D editor
    jet-spin --orbit     two jets flying in a circle
    jet-spin --orbit 3   any number of jets
    jet-spin --fetch     fastfetch with the logo animated like the Mach Saver
                         afterburner jet, until you press a key
    jet-spin --fetch --once   just the intro, then settle
    jet-spin --fetch --bg PIDFILE SHELLPID
                         fastfetch, then hand back the prompt while the logo keeps
                         animating in the background (used by ~/.zshrc; the shell
                         stops it before any output via the pid in PIDFILE)

Any key stops it. In --fetch the key still goes to your prompt.
"""
import fcntl
import math
import os
import random
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


class Afterburner:
    """The jet from the Mach Saver afterburner screensaver, held still and centred
    in its box, with speed lines streaking off behind it so it looks like it's
    flying. Coordinates are braille dots."""

    ONCE = 3.0   # --once: how long the speed lines run before it settles

    def __init__(self, dots, box):
        """`box` is (left, top, width, height) in dots; the jet is centred in it."""
        self.dots = dots
        self.w = max(x for x, _ in dots) + 1
        self.h = max(y for _, y in dots) + 1
        left, top, bw, bh = box
        self.ox = left + round((bw - self.w) / 2)
        self.oy = top + round((bh - self.h) / 2)
        # Start with a few lines already in flight so it's moving from the first frame.
        self.streaks = [self.new_streak(self.w * random.uniform(0, 0.45)) for _ in range(4)]
        self.last = 0.0

    def new_streak(self, x=None):
        """[x, y, speed, length]: leaves from the body, heads left."""
        return [self.w * random.uniform(0.1, 0.45) if x is None else x, self.h * random.uniform(0.3, 0.72),
                random.uniform(60, 100), random.uniform(6, 16)]

    def draw(self, canvas, t, loop=True):
        dt, self.last = min(0.1, max(0.0, t - self.last)), t

        # Speed lines fade out before the left edge.
        if random.random() < dt * 10:
            self.streaks.append(self.new_streak())
        for st in self.streaks:
            st[0] -= st[2] * dt
        self.streaks = [st for st in self.streaks if st[0] + st[3] > 0]
        for x, y, _, length in self.streaks:
            fade = min(1.0, (x + length) / (self.w * 0.3))
            colour = GRADIENT[7 - int(fade * 3)] if fade < 1 else GRADIENT[4]
            for i in range(int(length)):
                canvas.plot(self.ox + x + i, self.oy + y, colour, prio=0)
        self.draw_static(canvas)

    def draw_static(self, canvas):
        """The settled logo: every dot in its gradient band, nothing moving."""
        for x, y in self.dots:
            canvas.plot(self.ox + x, self.oy + y, GRADIENT[min(5, y * 6 // self.h)], prio=1)


def fetch_layout():
    """fastfetch's info on the right and a box for the jet on the left, centred on
    each other vertically, under fastfetch's usual blank line. The static logo is
    drawn from the same dots as the animation so it settles exactly in place.
    Returns (width, info rows, scene, static logo rows)."""
    dots = load_dots(LOGO)
    jet_cols = (max(x for x, _ in dots) + 2) // 2
    width = 2 + jet_cols + 2
    info = subprocess.run(["fastfetch", "--logo", "none", "--pipe", "false"],
                          capture_output=True, text=True).stdout.split("\n")
    blank = lambda l: not re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", l).strip()
    while info and blank(info[0]):
        info.pop(0)
    while info and blank(info[-1]):
        info.pop()
    # Centre the jet on the boxes to the dot (a quarter row), keeping it below
    # the blank first row. Its top dot sits `overhang` dots above the boxes' top.
    jet_h = max(y for _, y in dots) + 1
    overhang = (jet_h - len(info) * 4) / 2
    info_top = max(1, math.ceil((4 + overhang) / 4))
    jet_top = round(info_top * 4 - overhang)
    rows = max(info_top + len(info), math.ceil((jet_top + jet_h) / 4))
    info = [""] * info_top + info + [""] * (rows - info_top - len(info))
    scene = Afterburner(dots, (0, jet_top, width * 2, jet_h))
    canvas = Canvas(width, rows)
    scene.draw_static(canvas)
    return width, info, scene, canvas.lines()


def fetch(loop):
    """fastfetch with the logo animated, then settling into the normal static logo."""
    width, info, scene, final = fetch_layout()
    height = len(info)
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

    # Watch for a key without reading it, so it's still there for the prompt.
    # TCSANOW (not the default flush) keeps anything already typed.
    fd = sys.stdin.fileno()
    saved = termios.tcgetattr(fd) if sys.stdin.isatty() else None
    if saved:
        tty.setcbreak(fd, termios.TCSANOW)
    out.write("\x1b[?25l" + "\n" * height + "\x1b[%dA" % height)
    start = time.monotonic()
    try:
        while True:
            t = time.monotonic() - start
            if not loop and t >= Afterburner.ONCE:
                break
            if saved and select.select([sys.stdin], [], [], 0)[0]:
                break
            canvas = Canvas(width, height)
            scene.draw(canvas, t, loop)
            show(canvas.lines())
            out.write("\x1b[%dA\r" % (height - 1))
            out.flush()
            time.sleep(1 / 30)
    except KeyboardInterrupt:
        pass
    finally:
        if saved:
            termios.tcsetattr(fd, termios.TCSANOW, saved)
        show(final)
        out.write("\x1b[0m\x1b[?25h\n")
        out.flush()


def cursor_row(fd):
    """Ask the terminal where the cursor is (1-based row). Any keys typed in the
    meantime are pushed back so the prompt still gets them."""
    saved = termios.tcgetattr(fd)
    tty.setcbreak(fd, termios.TCSANOW)
    try:
        os.write(fd, b"\x1b[6n")
        buf, deadline = b"", time.monotonic() + 0.5
        while not re.search(rb"\x1b\[(\d+);(\d+)R", buf) and time.monotonic() < deadline:
            if select.select([fd], [], [], 0.05)[0]:
                buf += os.read(fd, 64)
        m = re.search(rb"\x1b\[(\d+);(\d+)R", buf)
        extra = buf[:m.start()] + buf[m.end():] if m else buf
        for b in extra:
            try:
                fcntl.ioctl(fd, termios.TIOCSTI, bytes([b]))
            except OSError:
                break
        return int(m.group(1)) if m else None
    finally:
        termios.tcsetattr(fd, termios.TCSANOW, saved)


def fetch_background(pidfile, shell_pid):
    """Print fastfetch with the static logo, then fork an animator that redraws just
    the logo in place, animated, while the prompt sits below it. The shell kills it
    before running anything; on SIGTERM it puts the static logo back first."""
    width, info, scene, final = fetch_layout()
    height = len(info)
    out = sys.stdout
    out.write("\r" + "\n".join("\x1b[2K" + l + r for l, r in zip(final, info)) + "\x1b[0m\n")
    out.flush()
    if not (sys.stdin.isatty() and out.isatty()):
        return
    fd = sys.stdin.fileno()
    row = cursor_row(fd)
    top = row - height if row else 0
    if top < 1:
        return
    tty_path = os.ttyname(fd)
    size = os.get_terminal_size(fd)

    if os.fork():
        return  # parent: done, the shell shows its prompt
    os.setsid()
    tty_fd = os.open(tty_path, os.O_WRONLY | os.O_NOCTTY)
    devnull = os.open(os.devnull, os.O_RDWR)
    for f in (0, 1, 2):
        os.dup2(devnull, f)
    with open(pidfile, "w") as fh:
        fh.write(str(os.getpid()))

    def paint(lines):
        # Save cursor, draw each logo row at its absolute position, restore cursor.
        frame = "\x1b7" + "".join("\x1b[%d;1H%s" % (top + i, l) for i, l in enumerate(lines)) + "\x1b8"
        os.write(tty_fd, frame.encode())

    stopping = []
    signal.signal(signal.SIGTERM, lambda *_: stopping.append(1))
    signal.signal(signal.SIGHUP, lambda *_: stopping.append(1))
    start = time.monotonic()
    try:
        while not stopping:
            try:
                os.kill(shell_pid, 0)
                if os.get_terminal_size(tty_fd) != size:
                    return  # resized: the text reflowed, so the rows are no longer ours
            except OSError:
                return
            canvas = Canvas(width, height)
            scene.draw(canvas, time.monotonic() - start)
            paint(canvas.lines())
            time.sleep(1 / 24)
        paint(final)
    finally:
        try:
            os.unlink(pidfile)
        except OSError:
            pass
        os._exit(0)


def main():
    if "--bg" in sys.argv:
        i = sys.argv.index("--bg")
        return fetch_background(sys.argv[i + 1], int(sys.argv[i + 2]))
    if "--fetch" in sys.argv:
        return fetch(loop="--once" not in sys.argv)
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
