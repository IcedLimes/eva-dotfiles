#!/usr/bin/env python3
"""Bake the night sky that fills in behind Unit-01 while the vinyl record sits
in the moon (~/.config/quickshell/eva/Stars.qml).

Writes ~/.config/eva/stars.png, the size of the wallpaper (which the bar draws
24 px bigger than the screen on every side, for the parallax), one texel per
wallpaper pixel:

  R  how bright the star is there (its dot, and the halo of a bright one)
  G  when it comes out, 0..1 of SPAN seconds after the record docks
  B  unused
  A  sky: 1 over the black background, 0 over Unit-01, soft at the edge

Stars only sit in the sky, clear of Unit-01, the moon (the record covers it)
and mostly clear of Rei. The brightest come out first, like at dusk: one star
on its own, then a few, then all of them.

Run again after changing the wallpaper, the moon or Rei:
  python3 ~/.config/eva/tools/make-stars.py
"""
import os
import subprocess

import numpy as np

HOME = os.path.expanduser("~")
WALL = f"{HOME}/Pictures/wallpapers/eva01-mono-parallax-flipped.png"
OUT = f"{HOME}/.config/eva/stars.png"

MARGIN = 24                      # Wallpaper.qml: the image overhangs the screen by this much
MOON = (1576, 831, 395)          # screen px: Moon.qml's cx, cy, radius
REI = (2290, 800, 175, 490)      # screen px: Rei.qml's centerX/Y, half her width/height (+ room)
FIRST = (2050, 190)              # screen px: the first star, alone in the open sky

COUNT = 720                      # ~1 per 4000 px of sky, as dense as Spotify's StarryNight
HALOED = 0.2                     # share with a soft halo (StarryNight's twinklers: 1 in 5)
HALO = 9                         # px: the halo's radius
SEAL = 30                        # px: sky reaching into Unit-01 through a gap narrower than twice this isn't sky
# The black strip down Unit-01's left side (between its wing, the cables, its
# arm and its hand) is mostly its own shadow. The only sky there is the
# triangle between the lower cable and the forearm, traced on a screenshot.
# Wallpaper px.
LEFT_ZONE = (0, 518, 549, 1591)  # x0, y0, x1, y1
LEFT_SKY = [(0, 867), (14, 852), (21, 840), (36, 841), (77, 857), (296, 954), (308, 962),
            (96, 1120), (82, 1130), (53, 1146), (37, 1152), (25, 1153), (0, 1142)]
FIRST_AT = 0.35                  # s after docking: the first star
RAMP_FROM, RAMP_LEN = 1.5, 3.0   # s: then from 1 to COUNT, doubling every ~0.3 s
SPAN = 4.6                       # s that G = 1 stands for (Stars.qml has the same)

rng = np.random.default_rng(1997)


def magick_rgb(*args):
    raw = subprocess.run(["magick", WALL, *args, "-depth", "8", "rgb:-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(raw, np.uint8)


def size():
    out = subprocess.run(["magick", "identify", "-format", "%w %h", WALL],
                         check=True, capture_output=True, text=True).stdout
    w, h = map(int, out.split())
    return w, h


def shift_max(a, r):
    """Dilate a boolean image by a disk of radius r."""
    h, w = a.shape
    p = np.pad(a, r, mode="edge")
    out = a.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy > r * r or (dx == 0 and dy == 0):
                continue
            out |= p[r + dy:r + dy + h, r + dx:r + dx + w]
    return out


def erode(a, r):
    return ~shift_max(~a, r)


def connected_from(free, y, x):
    """The part of `free` joined to pixel (y, x) (ImageMagick's flood fill)."""
    h, w = free.shape
    img = np.where(free, 255, 0).astype(np.uint8)
    out = subprocess.run(["magick", "-size", f"{w}x{h}", "-depth", "8", "gray:-",
                          "-fill", "gray(128)", "-draw", f"color {x},{y} floodfill",
                          "-depth", "8", "gray:-"],
                         input=img.tobytes(), check=True, capture_output=True).stdout
    return np.frombuffer(out, np.uint8).reshape(h, w) == 128


def polygon(w, h, pts):
    """A filled polygon as a boolean image."""
    out = subprocess.run(["magick", "-size", f"{w}x{h}", "xc:black", "-fill", "white",
                          "-draw", "polygon " + " ".join(f"{x},{y}" for x, y in pts),
                          "-depth", "8", "gray:-"], check=True, capture_output=True).stdout
    return np.frombuffer(out, np.uint8).reshape(h, w) > 127


def box_blur(a, r):
    k = 2 * r + 1
    p = np.pad(a, r, mode="edge")
    c = p.cumsum(0)
    c = np.vstack([np.zeros((1, c.shape[1])), c])
    v = (c[k:] - c[:-k]) / k
    c = v.cumsum(1)
    c = np.hstack([np.zeros((c.shape[0], 1)), c])
    return (c[:, k:] - c[:, :-k]) / k


def main():
    w, h = size()

    # The sky: black pixels joined to the corners (Unit-01's own black shadows
    # are enclosed by its outline, so they stay out).
    rgb = magick_rgb("-colorspace", "gray", "-threshold", "1%", "-colorspace", "sRGB",
                     "-fill", "red", "-draw", f"color {w - 8},5 floodfill",
                     "-draw", "color 5,5 floodfill").reshape(h, w, 3)
    sky = (rgb[..., 0] > 128) & (rgb[..., 1] < 128)

    # Close the thin black seams that reach into Unit-01 (cables, gaps between
    # plates), and keep 2 px off its outline.
    mech = erode(shift_max(~sky, 6), 4)

    # Unit-01's own shadows are pure black too, and some open onto the sky
    # through narrow gaps, so the corner fill took them for sky. Seal openings
    # narrower than ~2 * SEAL px and keep only the sky joined to the top right
    # (the screen's left edge counts as sky: the pocket above the lower hand
    # is background; Unit-01 goes on past the bottom edge).
    pad = SEAL + 4
    walled = np.pad(mech, ((pad, pad), (pad, pad)), constant_values=False)
    walled[-pad:, :] = True                     # bottom edge
    sealed = walled
    for _ in range(SEAL // 3):
        sealed = shift_max(sealed, 3)
    for _ in range(SEAL // 3):
        sealed = erode(sealed, 3)
    sealed[-pad:, :] = True
    sealed[:, :pad] = False
    joined = connected_from(~sealed, pad, walled.shape[1] - pad - 1)
    sky = joined[pad:-pad, pad:-pad] & ~mech

    # Down Unit-01's left side, only the triangle (LEFT_SKY) is sky.
    zone = np.zeros((h, w), bool)
    x0, y0, x1, y1 = LEFT_ZONE
    zone[y0:y1, x0:x1] = True
    sky = (sky & ~zone) | (polygon(w, h, LEFT_SKY) & ~mech)
    alpha = box_blur(box_blur(sky.astype(np.float32), 1), 1)

    # Where stars may sit: well clear of Unit-01 (a halo can't touch it) and
    # of the moon; sparse around Rei, so her braille dots stay hers.
    room = ~shift_max(~sky, HALO + 3)
    yy, xx = np.mgrid[0:h, 0:w]
    sx, sy = xx - MARGIN, yy - MARGIN                 # screen px (parallax at rest)
    mx, my, mr = MOON
    room &= np.hypot(sx - mx, sy - my) > mr * 1.01
    rx, ry, rw, rh = REI
    near_rei = ((sx - rx) / rw) ** 2 + ((sy - ry) / rh) ** 2 < 1
    room[:HALO + 2, :] = room[-HALO - 2:, :] = False
    room[:, :HALO + 2] = room[:, -HALO - 2:] = False

    taken = np.zeros((h, w), bool)
    stars = []

    def claim(x, y, r):
        taken[max(0, y - r):y + r + 1, max(0, x - r):x + r + 1] = True

    def free(x, y, r):
        return not taken[max(0, y - r):y + r + 1, max(0, x - r):x + r + 1].any()

    fx, fy = FIRST[0] + MARGIN, FIRST[1] + MARGIN
    stars.append(dict(x=fx, y=fy, big=True, bright=1.0, halo=True, first=True))
    claim(fx, fy, 2 * HALO + 2)

    tries = 0
    while len(stars) < COUNT and tries < COUNT * 400:
        tries += 1
        x, y = int(rng.integers(0, w)), int(rng.integers(0, h))
        if not room[y, x] or (near_rei[y, x] and rng.random() > 0.12):
            continue
        haloed = rng.random() < HALOED
        r = 2 * HALO + 2 if haloed else 5
        if not free(x, y, r):
            continue
        claim(x, y, r)
        stars.append(dict(x=x, y=y, big=rng.random() < 0.5, bright=float(rng.uniform(0.5, 1.0)),
                          halo=haloed, first=False))

    # The brightest come out first (with some shuffle).
    rest = sorted(stars[1:], key=lambda s: -(s["bright"] * (1.25 if s["big"] else 1.0)
                                              + (0.25 if s["halo"] else 0) + rng.normal(0, 0.18)))
    n = len(rest)
    for i, s in enumerate(rest, start=1):
        s["at"] = RAMP_FROM + RAMP_LEN * np.log(i) / np.log(max(2, n))
    stars[0]["at"] = FIRST_AT
    stars = [stars[0]] + rest

    R = np.zeros((h, w), np.float32)
    G = np.zeros((h, w), np.float32)
    for s in stars:
        x, y, b = s["x"], s["y"], s["bright"]
        g = s["at"] / SPAN
        if s["halo"]:
            ys, xs = np.mgrid[-HALO:HALO + 1, -HALO:HALO + 1]
            d2 = (xs + (0.5 if s["big"] else 0)) ** 2 + (ys + (0.5 if s["big"] else 0)) ** 2
            halo = 0.42 * b * np.exp(-d2 / (2 * 3.2 ** 2))
            halo[d2 > HALO * HALO] = 0
            sl = np.s_[y - HALO:y + HALO + 1, x - HALO:x + HALO + 1]
            R[sl] = np.maximum(R[sl], halo)
            G[sl] = np.where(halo > 0, g, G[sl])
        core = np.s_[y:y + 2, x:x + 2] if s["big"] else np.s_[y:y + 1, x:x + 1]
        R[core] = b * (0.9 if s["big"] else 1.0)
        G[core] = g

    rgba = np.stack([R, G, np.zeros_like(R), alpha], -1)
    data = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    # A star texel always has sky = 1, so premultiplying on upload changes nothing.
    data[..., 3] = np.where(R > 0, 255, data[..., 3])
    tmp = OUT + ".tmp.png"
    subprocess.run(["magick", "-size", f"{w}x{h}", "-depth", "8", "rgba:-", tmp],
                   input=data.tobytes(), check=True)
    os.replace(tmp, OUT)
    haloed = sum(s["halo"] for s in stars)
    print(f"{OUT}: {len(stars)} stars ({haloed} with a halo), all out {max(s['at'] for s in stars):.2f} s after docking")


if __name__ == "__main__":
    main()
