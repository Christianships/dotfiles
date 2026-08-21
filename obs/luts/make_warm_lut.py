#!/usr/bin/env python3
"""Generate warm-recovery 3D LUTs (.cube) for cheap webcams.

Cheap UVC webcams (here: PC-LM1E) tend to run an aggressive auto white balance
that pushes the image blue/cyan, then desaturate reds and oranges so warm light
reads as muddy grey-brown. This builds a LUT that undoes that in three steps:

  1. white balance  - gain red / cut blue, weighted away from highlights so
                      white walls and blown windows don't turn orange.
  2. warm vibrance  - hue-selective saturation boost over red->yellow, scaled by
                      (1 - saturation) so already-vivid pixels are left alone.
                      This is what makes warm colors actually *show*.
  3. soft clip      - tanh rolloff near 1.0 so the boosted red channel rolls off
                      instead of clipping into flat crimson blobs.

Usage: python3 make_warm_lut.py   (writes subtle/medium/strong next to this file)
"""
import math, os

SIZE = 33
HUE_CENTER = 25.0    # degrees: orange, between red (0) and yellow (60)
HUE_WIDTH = 65.0     # falloff half-width in degrees
WB_AMOUNT = 0.050    # red gain / blue cut at strength 1.0
VIB_AMOUNT = 0.60    # peak vibrance at strength 1.0
KNEE = 0.82          # soft clip starts here
SAT_GATE = (0.06, 0.18)  # below this original saturation, no vibrance at all
_CLIP_NORM = math.tanh(1.0)


def rgb_to_hsv(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        h = 0.0
    elif mx == r:
        h = 60.0 * (((g - b) / d) % 6)
    elif mx == g:
        h = 60.0 * ((b - r) / d + 2)
    else:
        h = 60.0 * ((r - g) / d + 4)
    return h, (d / mx if mx > 0 else 0.0), mx


def hsv_to_rgb(h, s, v):
    c = v * s
    x = c * (1 - abs((h / 60.0) % 2 - 1))
    m = v - c
    i = int(h // 60) % 6
    r, g, b = [(c, x, 0), (x, c, 0), (0, c, x), (0, x, c), (x, 0, c), (c, 0, x)][i]
    return r + m, g + m, b + m


def hue_weight(h):
    """Smooth 0..1 bump over the warm hues, zero everywhere else."""
    d = abs((h - HUE_CENTER + 180) % 360 - 180)
    if d >= HUE_WIDTH:
        return 0.0
    return math.cos(math.pi / 2 * (d / HUE_WIDTH)) ** 2


def soft_clip(x):
    """Rolloff above KNEE, normalized so 1.0 still maps to exactly 1.0."""
    if x <= KNEE:
        return max(x, 0.0)
    return KNEE + (1 - KNEE) * math.tanh((x - KNEE) / (1 - KNEE)) / _CLIP_NORM


def smoothstep(lo, hi, x):
    t = min(1.0, max(0.0, (x - lo) / (hi - lo)))
    return t * t * (3 - 2 * t)


def transform(r, g, b, strength):
    # Saturation of the *input* pixel, so the white-balance shift below can't
    # tint a neutral into the warm hue band and then have vibrance amplify it.
    sat_in = rgb_to_hsv(r, g, b)[1]
    gate = smoothstep(SAT_GATE[0], SAT_GATE[1], sat_in)

    # 1. white balance, backed off in the highlights
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    protect = 1.0 - lum ** 3
    wb = WB_AMOUNT * strength * protect
    r *= 1 + wb
    b *= 1 - wb * 0.9

    # 2. hue-selective vibrance
    h, s, v = rgb_to_hsv(min(r, 1.6), min(g, 1.6), min(b, 1.6))
    w = hue_weight(h) * gate
    if w > 0 and s > 0:
        s = min(1.0, s * (1 + VIB_AMOUNT * strength * w * (1 - s)))
        v *= 1 + 0.04 * strength * w * (1 - v)   # tiny lift so deep reds don't go black
        r, g, b = hsv_to_rgb(h, s, v)

    # 3. soft clip
    return soft_clip(r), soft_clip(g), soft_clip(b)


def write_cube(path, title, strength):
    with open(path, "w") as f:
        f.write(f"TITLE \"{title}\"\nLUT_3D_SIZE {SIZE}\nDOMAIN_MIN 0.0 0.0 0.0\nDOMAIN_MAX 1.0 1.0 1.0\n\n")
        for bi in range(SIZE):
            for gi in range(SIZE):
                for ri in range(SIZE):
                    r, g, b = transform(ri / (SIZE - 1), gi / (SIZE - 1), bi / (SIZE - 1), strength)
                    f.write(f"{r:.6f} {g:.6f} {b:.6f}\n")


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    for name, strength in (("subtle", 0.5), ("medium", 1.0), ("strong", 1.6)):
        out = os.path.join(here, f"warm-rescue-{name}.cube")
        write_cube(out, f"Warm Rescue ({name})", strength)
        print("wrote", out)
