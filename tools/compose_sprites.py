"""Compose baked sprite frames (scripts/sprite_bake.gd) into review sheets.

Usage: python3 tools/compose_sprites.py /tmp/bake docs/renders/sprites

Outputs two looks of the same frames:
  prerendered  smooth downscale, like late-90s pre-rendered isometric games
  pixel        hard downscale + limited palette + outline, read as pixel art
plus walk-cycle GIFs and a mock of sprites sitting on the tactical street.
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageOps

SRC, OUT = Path(sys.argv[1]), Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
CAST = [("police", "Riot police"), ("rebel", "Rebel"), ("rebel_f", "Rebel (respirator)"), ("duff", "Duff")]
DIRS, WALK = 8, 8
CROP = (64, 20, 192, 236)        # fixed crop of the 256px frame, same for every frame
BG = (52, 54, 60, 255)


def frame(who, anim, d, f=0):
    return Image.open(SRC / f"{who}_{anim}_d{d}_f{f}.png").convert("RGBA").crop(CROP)


def prerendered(img, h=108):
    w = round(img.width * h / img.height)
    return img.resize((w, h), Image.LANCZOS)


def pixel(img, h=54, scale=2, colors=28):
    w = round(img.width * h / img.height)
    small = img.resize((w, h), Image.BOX)
    alpha = small.getchannel("A").point(lambda a: 255 if a > 110 else 0)
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    # 1px dark outline so the figure reads on any ground
    ring = alpha.filter(ImageFilter.MaxFilter(3))
    outline = Image.new("RGBA", out.size, (14, 14, 18, 255))
    outline.putalpha(ring)
    outline.alpha_composite(out)
    return outline.resize((outline.width * scale, outline.height * scale), Image.NEAREST)


def sheet(look, name, title):
    cells = [[look(frame(w, "idle", d)) for d in range(DIRS)] for w, _ in CAST]
    cw = max(c.width for row in cells for c in row) + 12
    ch = max(c.height for row in cells for c in row) + 12
    lw, top = 150, 34
    img = Image.new("RGBA", (lw + cw * DIRS, top + ch * len(CAST)), BG)
    dr = ImageDraw.Draw(img)
    dr.text((10, 10), title, fill=(230, 230, 230))
    for r, row in enumerate(cells):
        dr.text((10, top + r * ch + ch // 2 - 6), CAST[r][1], fill=(210, 210, 210))
        for d, c in enumerate(row):
            img.alpha_composite(c, (lw + d * cw + (cw - c.width) // 2, top + r * ch + (ch - c.height)))
    img.convert("RGB").save(OUT / name)


def gif(look, who, d, name):
    frames = []
    for f in range(WALK):
        c = look(frame(who, "walk", d, f))
        bg = Image.new("RGBA", (c.width + 16, c.height + 16), BG)
        bg.alpha_composite(c, (8, 8))
        frames.append(bg.convert("P", palette=Image.ADAPTIVE))
    frames[0].save(OUT / name, save_all=True, append_images=frames[1:], duration=95, loop=0, disposal=2)


def regime_grade(img):
    """Rough stand-in for the Frontline grade: mostly grey, a hint of colour."""
    a = img.getchannel("A")
    grey = ImageOps.grayscale(img.convert("RGB")).convert("RGB")
    out = Image.blend(img.convert("RGB"), grey, 0.75)
    out = out.convert("RGBA")
    out.putalpha(a)
    return out


def in_context(look, name, street):
    bg = Image.open(street).convert("RGBA").crop((420, 90, 1020, 540))
    placed = [("police", 0, (300, 60)), ("police", 1, (420, 150)), ("police", 7, (150, 120)),
              ("rebel", 4, (130, 300)), ("rebel_f", 3, (250, 330)), ("duff", 5, (380, 320))]
    for who, d, (x, y) in placed:
        s = look(frame(who, "idle", d))
        s = s.resize((round(s.width * 0.62), round(s.height * 0.62)), Image.NEAREST if look is pixel else Image.LANCZOS)
        s = regime_grade(s)
        sh = Image.new("RGBA", bg.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).ellipse((x - 14, y + s.height - 6, x + 14 + 6, y + s.height + 4), fill=(0, 0, 0, 120))
        bg.alpha_composite(sh)
        bg.alpha_composite(s, (x - s.width // 2 + 3, y))
    bg.convert("RGB").save(OUT / name)


sheet(prerendered, "sheet_prerendered.png", "Fallback A: pre-rendered sprites (smooth), 8 directions, idle")
sheet(pixel, "sheet_pixel.png", "Fallback B: pixel sprites (hard edge, 28 colours, outline), 8 directions, idle")
gif(prerendered, "rebel", 1, "walk_rebel_prerendered.gif")
gif(pixel, "rebel", 1, "walk_rebel_pixel.gif")
gif(prerendered, "police", 7, "walk_police_prerendered.gif")
gif(pixel, "police", 7, "walk_police_pixel.gif")
street = Path(__file__).resolve().parent.parent / "docs/renders/frontline_regime.png"
if street.exists():
    in_context(prerendered, "context_prerendered.png", street)
    in_context(pixel, "context_pixel.png", street)
print("wrote", sorted(p.name for p in OUT.iterdir()))
