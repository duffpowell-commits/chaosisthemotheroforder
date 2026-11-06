"""Stitch autoplay frames into a GIF Duff can watch on his phone.

Usage: python3 tools/make_gif.py /tmp/autoplay docs/renders/autoplay_quiet.gif [width]
"""
import sys
from pathlib import Path
from PIL import Image

src, out = Path(sys.argv[1]), Path(sys.argv[2])
width = int(sys.argv[3]) if len(sys.argv) > 3 else 640
frames = []
for p in sorted(src.glob("f*.png")):
    im = Image.open(p).convert("RGB")
    im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    frames.append(im.convert("P", palette=Image.ADAPTIVE, colors=128))
if not frames:
    sys.exit("no frames in " + str(src))
durations = [700] * len(frames)
durations[-1] = 2500  # hold on the result
frames[0].save(out, save_all=True, append_images=frames[1:], duration=durations, loop=0)
print(f"{out}: {len(frames)} frames")
