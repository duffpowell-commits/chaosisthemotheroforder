#!/usr/bin/env python3
"""Desk-dossier textures for the action picker (Nov 25, Duff picked "Desk dossier").
All made here from noise, free; rerun to tweak. Writes assets/ui/dossier/*.png.
Needs Pillow + numpy."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import os, math
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "dossier")
os.makedirs(OUT, exist_ok=True)


def noise(w, h, scale, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    acc = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(1, int(scale / (2 ** o)))
        small = r.random((h // s + 2, w // s + 2))
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((w + 2 * s, h + 2 * s), Image.BICUBIC)
        acc += amp * (np.asarray(im, float)[:h, :w] / 255.0)
        tot += amp
        amp *= 0.5
    return acc / tot


def save(a, name):
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name), optimize=True)


def paper(w, h, base, seed, stains=2, fibers=True):
    n = noise(w, h, 64, 5, seed)
    fine = rng.random((h, w))
    img = np.zeros((h, w, 3))
    for c in range(3):
        img[..., c] = base[c] * (0.93 + 0.09 * n + 0.03 * (fine - 0.5))
    if fibers:  # short dark fibres
        pil = Image.fromarray(img.astype(np.uint8))
        d = ImageDraw.Draw(pil)
        r = np.random.default_rng(seed + 1)
        for _ in range(w * h // 900):
            x, y = r.random() * w, r.random() * h
            a = r.random() * math.pi
            l = 3 + r.random() * 9
            d.line([(x, y), (x + math.cos(a) * l, y + math.sin(a) * l)],
                   fill=tuple(int(v * 0.86) for v in base), width=1)
        img = np.asarray(pil, float)
    r = np.random.default_rng(seed + 2)
    yy, xx = np.mgrid[0:h, 0:w]
    for _ in range(stains):  # coffee rings / damp blooms
        cx, cy, rad = r.random() * w, r.random() * h, (0.08 + r.random() * 0.12) * min(w, h)
        dist = np.hypot(xx - cx, yy - cy)
        ring = np.exp(-((dist - rad) / (rad * 0.05)) ** 2) * 0.07 + (dist < rad) * 0.02
        img *= (1 - ring[..., None] * np.array([0.6, 0.9, 1.3]))
    # darker, yellowed edges
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]) / (0.08 * min(w, h))
    img *= (0.86 + 0.14 * np.clip(edge, 0, 1))[..., None]
    return img


def torn_alpha(w, h, seed, depth=7):
    r = np.random.default_rng(seed)
    a = np.ones((h, w)) * 255
    for side in range(4):
        L = w if side % 2 == 0 else h
        prof = noise(L, 1, 18, 3, seed + side)[0] * depth + r.random(L) * 2
        for i in range(L):
            d = int(prof[i])
            if side == 0: a[:d, i] = 0
            elif side == 2: a[h - d:, i] = 0
            elif side == 1: a[i, w - d:] = 0
            else: a[i, :d] = 0
    return np.asarray(Image.fromarray(a.astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), float)


# desk: dark walnut, grain along x
W, H = 640, 360
g = noise(W * 4, H, 6, 4, 11)[:, ::4] if False else None
yy, xx = np.mgrid[0:H, 0:W]
grain = noise(W, H // 8 + 1, 3, 4, 11)
grain = np.asarray(Image.fromarray((grain * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), float) / 255
wave = 0.5 + 0.5 * np.sin(yy * 0.35 + noise(W, H, 90, 3, 12) * 14)
v = 0.55 + 0.25 * grain + 0.2 * wave
desk = np.stack([62 * v, 40 * v, 27 * v], -1)
vign = 1 - 0.55 * (np.hypot((xx - W / 2) / W, (yy - H / 2) / H) * 1.6) ** 2
save(desk * vign[..., None], "desk.png")

# sheet: aged page, torn edges, faint fold
W, H = 1024, 576
sh = paper(W, H, (233, 224, 204), 21, stains=2)
sh[:, W // 2 - 2:W // 2 + 2] *= np.array([0.94, 0.94, 0.92])
save(np.dstack([sh, torn_alpha(W, H, 22, 6)]), "sheet.png")

# index card: off-white, faint blue rules, red header line, soft torn edges
W, H = 512, 168
cd = paper(W, H, (246, 241, 228), 31, stains=0)
cd[9:11] = cd[9:11] * 0.4 + np.array([200, 80, 70]) * 0.6  # red top rule, inside the 14 px 9-patch margin
save(np.dstack([cd, torn_alpha(W, H, 32, 3)]), "card.png")

# manila folder card (story beats): tan, no rules
mn = paper(W, H, (222, 196, 146), 41, stains=1)
save(np.dstack([mn, torn_alpha(W, H, 42, 3)]), "manila.png")

# paper clip, drawn at 4x then shrunk
S = 4
cw, ch = 40, 104
im = Image.new("RGBA", (cw * S, ch * S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
def loop(x0, y0, x1, y1, col, wd):
    d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=(x1 - x0) * S // 2, outline=col, width=wd * S)
shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
ds = ImageDraw.Draw(shadow)
ds.rounded_rectangle([7 * S, 7 * S, 37 * S, 101 * S], radius=15 * S, outline=(0, 0, 0, 110), width=4 * S)
shadow = shadow.filter(ImageFilter.GaussianBlur(3 * S))
im.alpha_composite(shadow)
loop(4, 2, 34, 98, (120, 124, 130, 255), 4)
loop(10, 12, 28, 80, (120, 124, 130, 255), 4)
loop(4, 2, 34, 98, (205, 210, 216, 255), 2)
loop(10, 12, 28, 80, (205, 210, 216, 255), 2)
d.rectangle([16 * S, 0, 22 * S, 12 * S], fill=(0, 0, 0, 0))
im.resize((cw, ch), Image.LANCZOS).save(os.path.join(OUT, "clip.png"))

# ink noise for stamps (tileable-ish grey blotches + speckle)
W = 256
n = noise(W, W, 24, 4, 51) * 0.7 + rng.random((W, W)) * 0.3
save(n * 255, "ink_noise.png")
print("dossier textures ->", os.path.abspath(OUT))

# label-maker tape (near white so the game tints it green / red / black), 9-patch
W, H = 96, 32
t = np.ones((H, W)) * 235
t *= 0.9 + 0.1 * noise(W, H, 8, 3, 61)
yy = np.arange(H)[:, None]
t *= (0.82 + 0.18 * np.exp(-((yy - 9) / 5.0) ** 2))  # glossy band
t[1:2] *= 1.08
a = np.ones((H, W)) * 255
for x in range(5):  # crimped short ends
    for y in range(H):
        if (y // 3) % 2 == 0 and x < 2: a[y, x] = 0; a[y, W - 1 - x] = 0
a[0, :] = 120; a[-1, :] = 120
save(np.dstack([t, t, t, a]), "tape_label.png")

# masking tape strip, torn ends, see-through
W, H = 72, 24
mk = paper(W, H, (212, 196, 150), 71, stains=0, fibers=False)
ma = torn_alpha(W, H, 72, 4) * 0.9
save(np.dstack([mk, ma]), "tape_mask.png")

# staple
im = Image.new("RGBA", (26 * S, 8 * S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle([1 * S, 2 * S, 25 * S, 6 * S], radius=2 * S, fill=(60, 62, 66, 170))
d.rounded_rectangle([1 * S, 1 * S, 24 * S, 4 * S], radius=2 * S, fill=(178, 182, 188, 255))
d.line([3 * S, 2 * S, 22 * S, 2 * S], fill=(235, 238, 242, 255), width=S)
im.resize((26, 8), Image.LANCZOS).save(os.path.join(OUT, "staple.png"))
