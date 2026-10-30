#!/usr/bin/env python3
"""Rei's silhouette from the 'Fly Me to the Moon' credits GIF (the 540x380
teal one) as braille dot art, one braille frame per GIF frame, no in-betweens.

Lit by the moon on her left: the silhouette is treated as a rounded body
(blurred into a height field), shaded from the moon's direction, and the
light sets how many dots are on (ordered dithering, fixed to the dot grid so
it doesn't shimmer as she turns). A faint dotted outline keeps her shape on
the shadow side. --flat gives the plain, fully dotted silhouette.
Each frame also gets its own time, so she turns at a steady pace (see below).
Usage: fly2braille.py GIF OUT_JSON ROWS INTERVAL_MS [PREVIEW_DIR] [--flat]"""
import json, math, subprocess, sys
from collections import deque

flat = "--flat" in sys.argv
argv = [a for a in sys.argv if a != "--flat"]
gif, out, rows, interval = argv[1], argv[2], int(argv[3]), int(argv[4])
preview = argv[5] if len(argv) > 5 else None
LIGHT = (-0.85, 0.05, 0.55)   # toward the moon: left of her, a touch below, and toward us
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
BLANK = 0x2800
DOT_ASPECT = 0.947   # a braille dot cell is 4.5 px wide, 4.75 px tall on screen (15 px Meslo)

def frames_rgb(path):
    info = subprocess.run(["magick", "identify", "-format", "%w %h\n", path], capture_output=True, text=True).stdout.split("\n")[0]
    w, h = map(int, info.split())
    # a slight blur averages out the GIF's checkerboard dithering along her
    # edges, which otherwise traces as comb-like fringes on the feet and hair
    raw = subprocess.run(["magick", path, "-coalesce", "-alpha", "off", "-type", "TrueColor", "-blur", "0x1.1",
                          "-depth", "8", "rgb:-"], capture_output=True).stdout
    n = len(raw) // (w * h * 3)
    return [raw[i * w * h * 3:(i + 1) * w * h * 3] for i in range(n)], w, h

def figure(px, w, h):
    """Rei is dark navy (blue above green); the water around her is teal (green
    above blue), even where the vignette makes it nearly as dark."""
    m = bytearray(w * h)
    for i in range(w * h):
        r, g, b = px[3 * i], px[3 * i + 1], px[3 * i + 2]
        s = (b - g) + 0.6 * (r - 18) - 0.5 * max(0, g - 46)
        m[i] = s > 4
    # 3x3 majority vote: drops dither specks along her edges, closes pinholes
    sm = bytearray(w * h)
    for y in range(1, h - 1):
        row = y * w
        for x in range(1, w - 1):
            i = row + x
            n = (m[i - w - 1] + m[i - w] + m[i - w + 1] + m[i - 1] + m[i] + m[i + 1]
                 + m[i + w - 1] + m[i + w] + m[i + w + 1])
            sm[i] = n >= 5
    m = sm
    # largest 8-connected shape is her
    seen = bytearray(w * h)
    best = []
    for start in range(w * h):
        if not m[start] or seen[start]:
            continue
        comp, q = [], deque([start])
        seen[start] = 1
        while q:
            i = q.popleft()
            comp.append(i)
            x, y = i % w, i // w
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if m[j] and not seen[j]:
                            seen[j] = 1
                            q.append(j)
        if len(comp) > len(best):
            best = comp
    fig = bytearray(w * h)
    for i in best:
        fig[i] = 1
    # fill small enclosed specks (dither noise); real gaps (arm and body) stay open
    seen = bytearray(w * h)
    for start in range(w * h):
        if fig[start] or seen[start]:
            continue
        comp, q, edge = [], deque([start]), False
        seen[start] = 1
        while q:
            i = q.popleft()
            comp.append(i)
            x, y = i % w, i // w
            edge = edge or x in (0, w - 1) or y in (0, h - 1)
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if not fig[j] and not seen[j]:
                        seen[j] = 1
                        q.append(j)
        if not edge and len(comp) < 40:
            for i in comp:
                fig[i] = 1
    return fig

def blur(img, w, h, r, passes=3):
    """Box blur, `passes` times (about a Gaussian), on a flat w*h list."""
    for _ in range(passes):
        tmp = [0.0] * (w * h)
        for y in range(h):
            acc, row = 0.0, y * w
            for x in range(-r, w + r):
                if x + r < w: acc += img[row + x + r]
                if x - r - 1 >= 0: acc -= img[row + x - r - 1]
                if 0 <= x < w: tmp[row + x] = acc / (2 * r + 1)
        img = [0.0] * (w * h)
        for x in range(w):
            acc = 0.0
            for y in range(-r, h + r):
                if y + r < h: acc += tmp[(y + r) * w + x]
                if y - r - 1 >= 0: acc -= tmp[(y - r - 1) * w + x]
                if 0 <= y < h: img[y * w + x] = acc / (2 * r + 1)
    return img

def moonlight(m, w, h):
    """0..1 brightness inside her silhouette, lit from the moon's side."""
    n0 = math.sqrt(sum(c * c for c in LIGHT))
    lx, ly, lz = (c / n0 for c in LIGHT)
    hgt = blur(m, w, h, 3)
    b = [0.0] * (w * h)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            i = y * w + x
            if not m[i]:
                continue
            gx = (hgt[i + 1] - hgt[i - 1]) * 2.2
            gy = (hgt[i + w] - hgt[i - w]) * 2.2
            d = max(0.0, (-gx * lx - gy * ly + lz) / math.sqrt(gx * gx + gy * gy + 1))
            b[i] = min(1.0, 0.06 + 1.15 * d ** 1.6)
    return b

frames, W, H = frames_rgb(gif)
masks = [figure(f, W, H) for f in frames]

# one box around her in every frame, so she turns in place
xs = [i % W for m in masks for i in range(W * H) if m[i]]
ys = [i // W for m in masks for i in range(W * H) if m[i]]
x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
py = (y1 - y0 + 1) / (rows * 4)
pxw = py * DOT_ASPECT
cols = int((x1 - x0 + 1) / (pxw * 2)) + 1
BITS = [(0, 0, 0x01), (0, 1, 0x02), (0, 2, 0x04), (1, 0, 0x08), (1, 1, 0x10), (1, 2, 0x20), (0, 3, 0x40), (1, 3, 0x80)]

text = []
for k, m in enumerate(masks):
    light = None if flat else moonlight(m, W, H)
    def sample(img, dx, dy):
        tot = 0.0
        for sy in (0.17, 0.5, 0.83):
            for sx in (0.17, 0.5, 0.83):
                x = min(W - 1, int(x0 + (dx + sx) * pxw))
                y = min(H - 1, int(y0 + (dy + sy) * py))
                tot += img[y * W + x]
        return tot / 9
    R, C = rows * 4, cols * 2
    cov = [[sample(m, x, y) for x in range(C)] for y in range(R)]
    inside = [[cov[y][x] >= 0.44 for x in range(C)] for y in range(R)]   # 4 of 9 samples
    on = [row[:] for row in inside]
    if light is not None:
        for y in range(R):
            for x in range(C):
                if not inside[y][x]:
                    continue
                v = sample(light, x, y) / max(cov[y][x], 1e-6)
                edge = any(not (0 <= y + dy < R and 0 <= x + dx < C) or not inside[y + dy][x + dx]
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                on[y][x] = v > (BAYER[y % 4][x % 4] + 0.5) / 16 or (edge and (x + y) % 2 == 0)
    lines = []
    for r in range(rows):
        lines.append("".join(chr(BLANK + sum(v for ox, oy, v in BITS if on[r * 4 + oy][c * 2 + ox]))
                             for c in range(cols)))
    text.append("\n".join(lines))
    if preview:
        pgm = f"P5 {W} {H} 255\n".encode() + bytes(255 * v for v in m)
        open(f"{preview}/m_{k:03d}.pgm", "wb").write(pgm)

# Timing. She doesn't move evenly between the GIF's drawings: she drifts while
# facing you, then swings an arm in over two drawings when side-on, which at an
# even pace reads as a jump. Timing every frame by how much she changes fixes
# that but overcorrects (her outline barely changes while she faces you or away,
# so those parts race by). So: halfway between the two, from a lightly smoothed
# measure of change, so neighbouring frames don't jitter. Same loop length.
def moved(a, b):
    both = either = 0
    for i in range(W * H):
        if a[i] or b[i]:
            either += 1
            both += a[i] and b[i]
    return 1 - both / either
n = len(masks)
motion = [moved(masks[i], masks[(i + 1) % n]) for i in range(n)]
motion = [0.25 * motion[i - 1] + 0.5 * motion[i] + 0.25 * motion[(i + 1) % n] for i in range(n)]
BLEND, LO, HI = 0.5, 60, 125   # share timed by change (0 = even, 1 = fully); limits in ms
weight = [(1 - BLEND) / n + BLEND * m / sum(motion) for m in motion]
delays = [interval * n * w for w in weight]
for _ in range(10):   # clamp, then share what's left among the rest
    delays = [min(HI, max(LO, v)) for v in delays]
    free = [i for i, v in enumerate(delays) if LO < v < HI]
    spare = interval * n - sum(delays)
    if abs(spare) < 0.5 or not free:
        break
    for i in free:
        delays[i] += spare * weight[i] / sum(weight[j] for j in free)
delays = [round(v) for v in delays]

json.dump({"interval": interval, "delays": delays, "frames": text}, open(out, "w"), ensure_ascii=False)
print("delays (ms):", delays, "loop", sum(delays), "ms")
print(f"{len(text)} frames{' (flat)' if flat else ', moonlit'}, {rows} rows x {cols} cols, "
      f"figure box {x1 - x0 + 1}x{y1 - y0 + 1} px at {x0},{y0}")
