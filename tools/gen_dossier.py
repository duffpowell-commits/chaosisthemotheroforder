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


# ---- "Often carried" wear (Duff, Nov 25: "make them look more worn ... often carried") ----
# Re-makes sheet / card / manila with folds, crumple creases, a dog-ear, thumb grime,
# dirty edges and nibbled corners. Overwrites the clean versions above.
def wear(img, alpha, seed, folds_x=(), folds_y=(), dogear=None, creases=6, thumbs=2, grime=0.18):
    h, w = alpha.shape
    r = np.random.default_rng(seed)
    img = img.copy()
    yy, xx = np.mgrid[0:h, 0:w]
    # low-frequency dirt, heavier toward the edges (hands hold the edges)
    dirt = noise(w, h, max(8, min(w, h) // 3), 4, seed + 5)
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy]) / (0.12 * min(w, h))
    edge_dirt = (1 - np.clip(edge, 0, 1)) ** 1.5
    img *= (1 - grime * (dirt * 0.6 + edge_dirt * 0.9))[..., None] * np.array([1.0, 0.98, 0.94])
    # folds: a soft shaded band one side, dark crease line, light ridge, dirt in the fold
    for fx in folds_x:
        x0 = int(fx * w) + int(r.integers(-4, 5))
        d = (xx - x0 - (yy - h / 2) * r.uniform(-0.01, 0.01)).astype(float)
        img *= (1 - 0.10 * np.exp(-np.maximum(d, 0) / (w * 0.06)) * (d > 0))[..., None]
        img *= (1 - 0.35 * np.exp(-(d / 1.2) ** 2))[..., None]
        img *= (1 + 0.10 * np.exp(-((d + 2.5) / 1.5) ** 2))[..., None]
        img *= (1 - 0.12 * dirt * np.exp(-(d / 6) ** 2))[..., None]
    for fy in folds_y:
        y0 = int(fy * h) + int(r.integers(-3, 4))
        d = (yy - y0 - (xx - w / 2) * r.uniform(-0.01, 0.01)).astype(float)
        img *= (1 - 0.08 * np.exp(-np.maximum(d, 0) / (h * 0.08)) * (d > 0))[..., None]
        img *= (1 - 0.32 * np.exp(-(d / 1.2) ** 2))[..., None]
        img *= (1 + 0.10 * np.exp(-((d + 2.5) / 1.5) ** 2))[..., None]
        img *= (1 - 0.12 * dirt * np.exp(-(d / 6) ** 2))[..., None]
    # crumple creases: short jagged light/dark line pairs
    pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    lay = Image.new("RGBA", pil.size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(lay)
    for _ in range(creases):
        x, y = r.random() * w, r.random() * h
        a = r.random() * math.pi
        pts = []
        for k in range(5):
            pts.append((x, y))
            a += r.uniform(-0.5, 0.5)
            step = min(w, h) * r.uniform(0.06, 0.16)
            x += math.cos(a) * step
            y += math.sin(a) * step
        dr.line(pts, fill=(60, 45, 30, 38), width=2)
        dr.line([(p[0] + 2, p[1] + 2) for p in pts], fill=(255, 250, 240, 46), width=2)
    pil = Image.alpha_composite(pil.convert("RGBA"), lay.filter(ImageFilter.GaussianBlur(1.1)))
    # thumb grime where it's held: smudged grey ovals near the side edges
    sm = Image.new("L", pil.size, 0)
    ds = ImageDraw.Draw(sm)
    for t in range(thumbs):
        side = t % 2
        cx = (0.03 + r.random() * 0.08) * w if side == 0 else (0.89 + r.random() * 0.08) * w
        cy = (0.25 + r.random() * 0.5) * h
        rx, ry = min(w, h) * 0.07, min(w, h) * 0.10
        ds.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=int(60 + r.random() * 40))
    sm = np.asarray(sm.filter(ImageFilter.GaussianBlur(min(w, h) * 0.03)), float) / 255
    sm *= 0.6 + 0.4 * noise(w, h, 3, 2, seed + 9)  # whorl-ish breakup
    arr = np.asarray(pil, float)[..., :3] * (1 - 0.45 * sm[..., None])
    alpha = alpha.copy()
    # nibbled, rounded corners
    for (cx, cy) in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        rad = r.uniform(3, 7) * (min(w, h) / 160)
        dist = np.hypot(xx - cx, yy - cy)
        alpha[dist < rad * 1.4] = 0
    # dog-ear: fold one corner over; the back of the flap shows, with a shadow
    if dogear:
        corner, s = dogear
        cx = 0 if "l" in corner else w - 1
        cy = 0 if "t" in corner else h - 1
        u = np.abs(xx - cx) + np.abs(yy - cy)
        cut = u < s
        # the flap mirrors the cut triangle across the fold line
        fx = np.abs(xx - cx)
        fy = np.abs(yy - cy)
        tri = (fx + fy >= s) & (fx < s) & (fy < s)  # region the folded flap covers
        shadow = (fx + fy >= s) & (fx + fy < s + 5)
        arr[shadow] *= 0.72
        back = np.array([0.80, 0.77, 0.70]) * arr[tri].mean(axis=0) / 0.85
        arr[tri] = arr[tri] * 0.25 + back * 0.75 * (0.95 + 0.05 * dirt[tri][:, None])
        # crease along the fold
        arr[(fx + fy >= s - 1) & (fx + fy < s + 1)] *= 0.7
        alpha[cut] = 0
    return np.dstack([arr, alpha])


W, H = 1024, 576
sh = paper(W, H, (228, 218, 196), 21, stains=3)
save(wear(sh, torn_alpha(W, H, 22, 11), 23, folds_x=(0.5,), folds_y=(0.48,), dogear=("br", 72),
          creases=22, thumbs=3, grime=0.32), "sheet.png")
W, H = 512, 168
cd = paper(W, H, (243, 236, 220), 31, stains=1)
cd[9:11] = cd[9:11] * 0.45 + np.array([200, 80, 70]) * 0.55
save(wear(cd, torn_alpha(W, H, 32, 4), 33, folds_x=(0.62,), dogear=("tr", 24), creases=8, thumbs=2, grime=0.26), "card.png")
mn = paper(W, H, (216, 188, 138), 41, stains=2)
save(wear(mn, torn_alpha(W, H, 42, 4), 43, folds_y=(0.55,), dogear=("bl", 24), creases=8, thumbs=2, grime=0.26), "manila.png")
print("worn sheet / card / manila")
