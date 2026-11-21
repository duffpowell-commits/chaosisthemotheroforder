#!/usr/bin/env python3
"""Set real lettering onto the blank type areas of woodcut art.

Reads the JSON spec in docs/art/type-sheet.md and writes each piece's
`*_lettered.png` beside the blank original. The blank original is never
modified. Usage:
    python3 tools/letter.py               # every piece
    python3 tools/letter.py <out.png> ... # only these outputs
"""
import json, os, re, sys, zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "docs", "art", "type-sheet.md")


def load_spec(path=SHEET):
    text = open(path, encoding="utf-8").read()
    m = re.search(r"```json\s*(\{.*?\})\s*```", text, re.S)
    if not m:
        raise SystemExit(f"no ```json block in {path}")
    return json.loads(m.group(1))


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def line_width(font, line, tracking_px):
    if not line:
        return 0
    return sum(font.getlength(ch) for ch in line) + tracking_px * (len(line) - 1)


def layout(font_path, text, box, tracking, line_gap, max_size):
    """Largest font size whose lines fit the box."""
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    lines = text.split("\n")
    lo, hi, best = 6, max_size or 400, None
    while lo <= hi:
        size = (lo + hi) // 2
        f = ImageFont.truetype(font_path, size)
        asc, desc = f.getmetrics()
        lh = asc + desc
        tr = tracking * size
        w = max(line_width(f, ln, tr) for ln in lines)
        h = lh * len(lines) + int(line_gap * size) * (len(lines) - 1)
        if w <= bw and h <= bh:
            best = (size, f, tr, lh)
            lo = size + 1
        else:
            hi = size - 1
    if best is None:
        raise ValueError(f"text {text!r} cannot fit box {box}")
    return lines, best


def render_mask(size, font_path, block):
    """Text coverage mask (L) for one block, with a worn-print pass."""
    W, H = size
    box = block["box"]
    lines, (fs, font, tr, lh) = layout(font_path, block["text"], box, block.get("tracking", 0.05),
                                       block.get("line_gap", 0.1), block.get("max_size"))
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    gap = int(block.get("line_gap", 0.1) * fs)
    total_h = lh * len(lines) + gap * (len(lines) - 1)
    # Optical centring: use the cap height, not ascender+descender.
    cap_top = font.getbbox("H")[1]
    cap_h = font.getbbox("H")[3] - cap_top
    vis_h = total_h - (lh - cap_h) + 0  # approx visible block height
    y = box[1] + ((box[3] - box[1]) - vis_h) / 2 - cap_top
    for ln in lines:
        w = line_width(font, ln, tr)
        align = block.get("align", "center")
        x = box[0] if align == "left" else box[2] - w if align == "right" else box[0] + ((box[2] - box[0]) - w) / 2
        for ch in ln:
            d.text((x, y), ch, font=font, fill=255)
            x += font.getlength(ch) + tr
        y += lh + gap
    # Worn print: soften, then knock out speckles with seeded noise.
    rng = np.random.default_rng(zlib.crc32(block["text"].encode("utf-8")))
    m = np.asarray(mask.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255
    noise = rng.random((H, W)).astype(np.float32)
    noise = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255
    wear = np.clip((noise - 0.36) * 6, 0, 1) * 0.9 + 0.1  # ~10% speckle loss
    m = m * np.clip(wear + 0.25, 0, 1)
    return np.clip(m * block.get("opacity", 0.95), 0, 1)


def letter_piece(spec, piece):
    src = os.path.join(ROOT, piece["src"])
    out = os.path.join(ROOT, piece["out"])
    if os.path.abspath(src) == os.path.abspath(out) or not out.endswith("_lettered.png"):
        raise SystemExit(f"refusing to overwrite the blank original: {piece['out']}")
    base = Image.open(src).convert("RGB")
    a = np.asarray(base).astype(np.float32)
    for block in piece["blocks"]:
        font_path = os.path.join(ROOT, spec["fonts"][block.get("font", "display")])
        col = np.array(hex_rgb(spec["colors"][block.get("color", "ink")]), np.float32)
        m = render_mask(base.size, font_path, block)[..., None]
        # Multiply-style ink so the paper grain shows through the letters.
        inked = a * (col / 255.0) * 0.55 + col * 0.45
        a = a * (1 - m) + np.minimum(inked, a) * m
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(out, optimize=True)
    return piece["out"]


def main(argv):
    spec = load_spec()
    want = set(argv)
    for piece in spec["pieces"]:
        if want and piece["out"] not in want:
            continue
        print("lettered", letter_piece(spec, piece))


if __name__ == "__main__":
    main(sys.argv[1:])
