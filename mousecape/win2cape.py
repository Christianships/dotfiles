#!/usr/bin/env python3
"""Convert a Windows cursor pack (.cur/.ani) into a Mousecape .cape file."""
import io, os, plistlib, struct, sys
from PIL import Image

JIFFY = 1.0 / 60.0


def cur_hotspot(data):
    """Hotspot of the first ICONDIRENTRY in a .cur/.ico blob."""
    reserved, typ, count = struct.unpack_from('<HHH', data, 0)
    if typ != 2 or count == 0:          # type 2 == cursor; icons carry no hotspot
        return None
    hx, hy = struct.unpack_from('<HH', data, 6 + 4)
    return hx, hy


def decode_dib(buf, off, size):
    """Decode one icon image: PNG, or a BMP whose bottom half is the AND mask.

    Pillow ignores that mask for sub-32bpp entries, which turns every
    transparent pixel opaque black, so unpack the DIB by hand.
    """
    if buf[off:off + 8] == b'\x89PNG\r\n\x1a\n':
        return Image.open(io.BytesIO(buf[off:off + size])).convert('RGBA')

    hsize, w, h2, planes, bpp, comp = struct.unpack_from('<IiiHHI', buf, off)
    clr_used = struct.unpack_from('<I', buf, off + 32)[0]
    h = h2 // 2                                  # XOR bitmap stacked over AND mask
    if comp != 0:
        raise ValueError('compressed DIB not supported')

    pos = off + hsize
    palette = []
    if bpp <= 8:
        n = clr_used or (1 << bpp)
        for i in range(n):
            b, g, r, _ = buf[pos + i * 4: pos + i * 4 + 4]
            palette.append((r, g, b))
        pos += n * 4

    xor_stride = ((w * bpp + 31) // 32) * 4
    and_stride = ((w + 31) // 32) * 4
    xor = buf[pos: pos + xor_stride * h]
    mask = buf[pos + xor_stride * h: pos + xor_stride * h + and_stride * h]

    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for y in range(h):
        row = xor[(h - 1 - y) * xor_stride:]     # DIB rows run bottom-up
        mrow = mask[(h - 1 - y) * and_stride:] if mask else b''
        for x in range(w):
            if bpp == 32:
                b, g, r, a = row[x * 4: x * 4 + 4]
            elif bpp == 24:
                b, g, r = row[x * 3: x * 3 + 3]
                a = 255
            elif bpp == 8:
                r, g, b = palette[row[x]]
                a = 255
            elif bpp == 4:
                idx = (row[x // 2] >> 4) if x % 2 == 0 else (row[x // 2] & 0xF)
                r, g, b = palette[idx]
                a = 255
            elif bpp == 1:
                idx = (row[x // 8] >> (7 - x % 8)) & 1
                r, g, b = palette[idx]
                a = 255
            else:
                raise ValueError(f'unsupported bpp {bpp}')
            # AND bit set => transparent. 32bpp files carry real alpha already,
            # but some still ship a meaningful mask, so honour both.
            if mrow and (mrow[x // 8] >> (7 - x % 8)) & 1:
                a = 0
            px[x, y] = (r, g, b, a)
    return im


def load_image(data):
    """Decode the first (largest) entry of a .cur/.ico blob."""
    count = struct.unpack_from('<H', data, 4)[0]
    best, best_area = None, -1
    for i in range(count):
        w, h = data[6 + i * 16], data[6 + i * 16 + 1]
        w, h = w or 256, h or 256
        size, off = struct.unpack_from('<II', data, 6 + i * 16 + 8)
        if w * h > best_area:
            best, best_area = (off, size), w * h
    return decode_dib(data, best[0], best[1])


def parse_cur(path):
    data = open(path, 'rb').read()
    im = load_image(data)
    hs = cur_hotspot(data) or (0, 0)
    return [im], hs, 0.0


def parse_ani(path):
    """Walk the RIFF/ACON tree and return (frames, hotspot, frame_duration)."""
    buf = open(path, 'rb').read()
    if buf[:4] != b'RIFF' or buf[8:12] != b'ACON':
        raise ValueError(f'{path}: not a RIFF/ACON file')

    icons, rates, seq, anih = [], None, None, None

    def walk(start, end):
        nonlocal rates, seq, anih
        pos = start
        while pos + 8 <= end:
            cid = buf[pos:pos + 4]
            size = struct.unpack_from('<I', buf, pos + 4)[0]
            body = pos + 8
            if cid == b'LIST':
                walk(body + 4, body + size)
            elif cid == b'icon':
                icons.append(buf[body:body + size])
            elif cid == b'anih':
                anih = struct.unpack_from('<9I', buf, body)
            elif cid == b'rate':
                rates = list(struct.unpack_from('<%dI' % (size // 4), buf, body))
            elif cid == b'seq ':
                seq = list(struct.unpack_from('<%dI' % (size // 4), buf, body))
            pos = body + size + (size & 1)      # chunks are word-aligned

    walk(12, 8 + struct.unpack_from('<I', buf, 4)[0])
    if not icons:
        raise ValueError(f'{path}: no icon frames')

    order = seq if seq else list(range(len(icons)))
    frames = [load_image(icons[i]) for i in order]

    # Mousecape has one duration for the whole animation, so average the steps.
    default_rate = anih[7] if anih else 6
    steps = rates if rates else [default_rate] * len(order)
    duration = (sum(steps) / len(steps)) * JIFFY

    hs = next((cur_hotspot(icons[i]) for i in order if cur_hotspot(icons[i])), None)
    return frames, hs or (0, 0), duration


MAX_FRAMES = 24          # mousecloak refuses anything above this


def build_cursor(frames, hotspot, duration, retina=True):
    if len(frames) > MAX_FRAMES:
        # Drop to evenly spaced frames and stretch each one so the loop still
        # takes the same wall-clock time as the original animation.
        n = len(frames)
        frames = [frames[round(i * n / MAX_FRAMES)] for i in range(MAX_FRAMES)]
        duration *= n / MAX_FRAMES

    w, h = frames[0].size
    frames = [f if f.size == (w, h) else f.resize((w, h), Image.NEAREST) for f in frames]

    def sheet(scale):
        """Frames stacked vertically into one image, nearest-neighbour for pixel art."""
        sw, sh = w * scale, h * scale
        out = Image.new('RGBA', (sw, sh * len(frames)), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            out.alpha_composite(f.resize((sw, sh), Image.NEAREST) if scale != 1 else f,
                                (0, sh * i))
        b = io.BytesIO()
        out.save(b, 'PNG')
        return b.getvalue()

    reps = [sheet(1)] + ([sheet(2)] if retina else [])
    return {
        'FrameCount': len(frames),
        'FrameDuration': float(duration),
        'HotSpotX': float(hotspot[0]),
        'HotSpotY': float(hotspot[1]),
        'PointsWide': float(w),
        'PointsHigh': float(h),
        'Representations': reps,
    }


def convert(pack_dir, mapping, out_path, meta):
    cursors = {}
    for filename, identifiers in mapping.items():
        path = os.path.join(pack_dir, filename)
        if not os.path.exists(path):
            print(f'  ! missing: {filename}', file=sys.stderr)
            continue
        parse = parse_ani if filename.lower().endswith('.ani') else parse_cur
        frames, hotspot, duration = parse(path)
        cur = build_cursor(frames, hotspot, duration)
        for ident in identifiers:
            cursors[ident] = cur
        print(f'  {filename:34s} {frames[0].size[0]}x{frames[0].size[1]} '
              f'{len(frames):2d}f  hs={hotspot}  -> {", ".join(identifiers)}')

    cape = dict(meta)
    cape['Cursors'] = cursors
    with open(out_path, 'wb') as fh:
        plistlib.dump(cape, fh)
    return cursors
