#!/usr/bin/env python3
"""Chaos: import settings for every texture, so the APK and the web build stay small (item 7, Nov 26).

Every texture used to import lossless (compress/mode=0): a 2048 px body map shipped as ~7 MB and the
Nov 26 APK was 242 MB. This sets lossy WebP (compress/mode=1) by folder, and caps the size of body
maps the camera never shows big. Run it after adding art, then `godot --headless --path . --import`.

    python3 tools/texture_policy.py          # rewrites the [params] of matching .import files
    python3 tools/texture_policy.py --check  # exit 1 if any texture is off policy (a rule test runs this logic too)

Duff's body colour map keeps 2048 px: his hand tattoos must stay exact (the camera zooms to 0.5x).
"""
import fnmatch
import glob
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# (glob under ROOT, lossy quality, size limit in px or 0 = none). First match wins.
POLICY = [
    ("assets/characters/meshy/duff_texture_0.png", 0.85, 2048),
    ("assets/characters/*_normal*", 0.9, 1024),          # normal maps band less at higher quality
    ("assets/polyhaven/**/*nor_gl*", 0.9, 0),
    ("assets/characters/meshy/*", 0.8, 1024),
    ("assets/characters/rigged/*", 0.8, 1024),
    ("assets/polyhaven/models/**/*", 0.8, 0),
    ("assets/polyhaven/textures/**/*", 0.8, 0),
    ("assets/portraits/*", 0.85, 0),
    ("assets/ui/backdrop_*", 0.85, 0),
    ("assets/ui/dossier/*", 0.85, 0),
    ("assets/ui/woodcut/*", 0.9, 0),
    ("assets/props/*", 0.85, 512),
]
SKIP_EXT = (".hdr", ".exr")   # HDR skies keep their own import


def policy_for(rel):
    for pat, q, lim in POLICY:
        if fnmatch.fnmatch(rel, pat):
            return q, lim
    return None


def textures():
    for imp in glob.glob(os.path.join(ROOT, "assets", "**", "*.import"), recursive=True):
        txt = open(imp).read()
        if 'importer="texture"' not in txt:
            continue
        rel = os.path.relpath(imp[:-7], ROOT).replace(os.sep, "/")
        if rel.endswith(SKIP_EXT):
            continue
        yield imp, rel, txt


def want(txt, q, lim):
    out = re.sub(r"^compress/mode=\d+$", "compress/mode=1", txt, flags=re.M)
    out = re.sub(r"^compress/lossy_quality=[\d.]+$", "compress/lossy_quality=%s" % q, out, flags=re.M)
    # The editor (Duff's Android editor too) would flip a 3D-used texture to VRAM-compressed and undo this.
    out = re.sub(r"^detect_3d/compress_to=\d+$", "detect_3d/compress_to=0", out, flags=re.M)
    if lim:
        if re.search(r"^process/size_limit=", out, flags=re.M):
            out = re.sub(r"^process/size_limit=\d+$", "process/size_limit=%d" % lim, out, flags=re.M)
        else:
            out = out.replace("process/hdr_as_srgb=", "process/size_limit=%d\nprocess/hdr_as_srgb=" % lim, 1)
    return out


def main():
    check = "--check" in sys.argv
    off = 0
    for imp, rel, txt in textures():
        p = policy_for(rel)
        if p is None:
            continue
        new = want(txt, *p)
        if new != txt:
            off += 1
            if check:
                print("off policy:", rel)
            else:
                open(imp, "w").write(new)
    print(("%d off policy" if check else "%d .import files updated") % off)
    sys.exit(1 if check and off else 0)


if __name__ == "__main__":
    main()
