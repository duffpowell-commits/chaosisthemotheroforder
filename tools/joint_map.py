#!/usr/bin/env python3
"""Measure cutout-rig joints on A-pose sprites by silhouette analysis.

For each assets/characters/<name>/<name>_<view>.png this writes
assets/characters/<name>/joints_<view>.json with the joints
scripts/tactics/cutout_rig.gd uses (head_top, neck, hip, shoulder/elbow/hand,
hip/knee/ankle/toe for L and R, "L"/"R" = screen left/right in the art), in the
rig's source space: height 196, width scaled by the same factor (the rig
computes s = texture_height / src_size.y, so src_size = [W*196/H, 196]).
Wrists, armpits and the crotch are written under "extra".

Usage: python3 tools/joint_map.py [--overlay out.png] [name_view ...]
Per-sprite manual nudges live in OVERRIDES (rig-space px), each with a reason.
"""
import argparse, glob, json, os, sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RIG_H = 196.0

# Manual corrections after visual review, in rig-space pixels: {"name_view": {"joint": [dx, dy]}}
OVERRIDES = {}


def runs(row):
    """[(x0, x1)] inclusive runs of True in a 1-D bool array."""
    d = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
    s = np.where(d == 1)[0]
    e = np.where(d == -1)[0] - 1
    return list(zip(s, e))


def measure(alpha):
    m = alpha > 128
    H, W = m.shape
    ys = np.where(m.any(1))[0]
    top, bot = int(ys[0]), int(ys[-1])
    h = bot - top
    R = [runs(m[y]) for y in range(H)]
    flags = []

    def run_at(y, x):
        for a, b in R[y]:
            if a <= x <= b:
                return a, b
        # nearest run
        best = min(R[y], key=lambda r: min(abs(r[0] - x), abs(r[1] - x))) if R[y] else None
        return best

    # Head: centroid of the top 8% of the figure.
    hy0, hy1 = top, top + int(0.08 * h)
    hx = np.where(m[hy0:hy1])[1].mean()
    cx = hx
    head_top = (float(np.where(m[top])[0].mean()), float(top))
    # Neck: narrowest row of the centre run between the head's widest row and 0.24h.
    widths = []
    for y in range(top, top + int(0.24 * h)):
        r = run_at(y, cx)
        widths.append((r[1] - r[0]) if r else 0)
    wy = int(np.argmax(widths[:int(0.13 * h)]))
    seg = widths[wy:]
    chin = top + wy + int(np.argmin(seg))
    nw = max(widths[chin - top], 1)
    # Base of the neck: first row below the narrowest one where the centre run
    # widens past 1.5x the neck width (the shoulder line starts there),
    # capped at 0.08h below it for hoods and high collars.
    sh_top = None
    for y in range(chin, top + int(0.3 * h)):
        r = run_at(y, cx)
        if r and (r[1] - r[0]) > 1.5 * nw:
            sh_top = y
            break
    if sh_top is None or sh_top > chin + 0.08 * h:
        flags.append("shoulder line unclear (hood/collar); capped at 0.08h below the chin")
        sh_top = chin + int(0.08 * h)
    ny = int(round(chin + 0.75 * (sh_top - chin)))
    nr = run_at(ny, cx)
    neck = ((nr[0] + nr[1]) / 2.0, float(ny))
    cx = neck[0]

    # Armpits: first row below the neck where a separate run exists on each side
    # of the centre run for 6 consecutive rows.
    def armpit(side):
        streak = 0
        for y in range(ny + int(0.04 * h), top + int(0.6 * h)):
            c = run_at(y, cx)
            others = [r for r in R[y] if (r[1] < c[0] if side == "L" else r[0] > c[1])]
            streak = streak + 1 if others else 0
            if streak >= 6:
                return y - 5
        return None

    arm = {}
    for side in ("L", "R"):
        ap = armpit(side)
        if ap is None:
            flags.append(f"no armpit gap on {side}")
            ap = ny + int(0.12 * h)
        # Trace the arm run downward from the armpit.
        track = []
        prev = None
        for y in range(ap, bot):
            c = run_at(y, cx)
            cand = [r for r in R[y] if (r[1] < c[0] if side == "L" else r[0] > c[1])]
            if prev is not None:
                cand = [r for r in cand if r[0] <= prev[1] + 3 and r[1] >= prev[0] - 3]
            if not cand:
                break
            a = min(r[0] for r in cand)
            b = max(r[1] for r in cand)
            track.append((y, a, b))
            prev = (a, b)
        if not track:
            flags.append(f"arm {side} not traced")
            track = [(ap, cx, cx)]
        arm_w = min(float(np.median([b - a for _, a, b in track[:max(3, int(0.05 * h))]])), 0.075 * h)
        # Shoulder joint: just below the shoulder line, inset from the outer
        # edge of the deltoid by about half an arm width.
        sy = int(sh_top + 0.04 * h)
        c = run_at(sy, cx)
        sx = c[0] + arm_w * 0.6 if side == "L" else c[1] - arm_w * 0.6
        end_y = track[-1][0]
        hand_rows = [t for t in track if t[0] >= end_y - 0.05 * h]
        hand_pts = [(x, y) for y, a, b in hand_rows for x in range(a, b + 1) if m[y, x]]
        hand = (float(np.mean([p[0] for p in hand_pts])), float(np.mean([p[1] for p in hand_pts])))
        wy_ = end_y - 0.075 * h
        wt = min(track, key=lambda t: abs(t[0] - wy_))
        wrist = ((wt[1] + wt[2]) / 2.0, float(wt[0]))
        # Elbow: half way along shoulder->wrist, snapped to the arm's centre
        # line where the arm is already separate from the body.
        ey = sy + 0.5 * (wrist[1] - sy)
        ex = sx + 0.5 * (wrist[0] - sx)
        rows = {t[0]: t for t in track}
        if int(round(ey)) in rows:
            t = rows[int(round(ey))]
            ex = (t[1] + t[2]) / 2.0
        elbow = (float(ex), float(ey))
        if end_y < top + 0.42 * h:
            flags.append(f"arm {side} trace ends high (y={end_y}); check hand")
        arm[side] = dict(shoulder=(float(sx), float(sy)), elbow=elbow, wrist=wrist, hand=hand,
                         armpit=(float(track[0][1] if side == "L" else track[0][2]), float(ap)), track=track)

    # Legs: from the feet upward, two runs inside the span between the arms.
    def in_body(y, r):
        for side in ("L", "R"):
            for ty, a, b in arm[side]["track"]:
                if ty == y and r[0] <= b and r[1] >= a:
                    return False
        return True

    leg_rows = {}
    crotch = None
    for y in range(bot, top + int(0.35 * h), -1):
        rr = [r for r in R[y] if in_body(y, r) and (r[1] - r[0]) > 2]
        if len(rr) >= 2:
            # keep the two widest, left and right of centre
            l = [r for r in rr if (r[0] + r[1]) / 2 < cx]
            rgt = [r for r in rr if (r[0] + r[1]) / 2 >= cx]
            if l and rgt:
                leg_rows[y] = (max(l, key=lambda r: r[1] - r[0]), max(rgt, key=lambda r: r[1] - r[0]))
                crotch = y
                continue
        if crotch is not None and y < crotch - 3:
            break
    if crotch is None:
        flags.append("legs never separate")
        crotch = top + int(0.55 * h)
    coat = crotch > top + 0.62 * h
    if coat:
        flags.append(f"legs separate only below y={crotch} (coat/long jacket): hips estimated from proportions")
        hip_y = top + 0.49 * h
    else:
        hip_y = crotch - 0.05 * h
    legs = {}
    for i, side in enumerate(("L", "R")):
        ys_ = sorted(leg_rows)
        foot_bot = max(ys_)
        # bottom of this foot: last row where this leg's run exists
        fb = max(y for y in ys_)
        ay = fb - 0.045 * h
        at = leg_rows[min(ys_, key=lambda y: abs(y - ay))][i]
        ankle = ((at[0] + at[1]) / 2.0, float(ay))
        # toe: outermost foot pixel in the bottom 2.5% rows
        tys = [y for y in ys_ if y >= fb - 0.025 * h]
        if side == "L":
            tx = min(leg_rows[y][0][0] for y in tys)
            ty = np.mean([y for y in tys if leg_rows[y][0][0] <= tx + 2])
        else:
            tx = max(leg_rows[y][1][1] for y in tys)
            ty = np.mean([y for y in tys if leg_rows[y][1][1] >= tx - 2])
        toe = (float(tx), float(ty))
        # hip x: leg centre just below the crotch, or proportional for coats
        if not coat:
            hy_ = min(ys_, key=lambda y: abs(y - (crotch + 0.03 * h)))
            hr = leg_rows[hy_][i]
            hip = ((hr[0] + hr[1]) / 2.0, float(hip_y))
        else:
            c = run_at(int(hip_y), cx)
            wd = c[1] - c[0]
            hip = (c[0] + 0.3 * wd if side == "L" else c[1] - 0.3 * wd, float(hip_y))
        ky = (hip[1] + ankle[1]) / 2.0
        if int(round(ky)) in leg_rows:
            kr = leg_rows[int(round(ky))][i]
            knee = ((kr[0] + kr[1]) / 2.0, float(ky))
        else:
            knee = ((hip[0] + ankle[0]) / 2.0, float(ky))
        legs[side] = dict(hip=hip, knee=knee, ankle=ankle, toe=toe)
    hipc = ((legs["L"]["hip"][0] + legs["R"]["hip"][0]) / 2.0, legs["L"]["hip"][1] - 0.02 * h)
    j = {"head_top": head_top, "neck": neck, "hip": hipc}
    for s in ("L", "R"):
        j["shoulder_" + s] = arm[s]["shoulder"]
        j["elbow_" + s] = arm[s]["elbow"]
        j["hand_" + s] = arm[s]["hand"]
        j["hip_" + s] = legs[s]["hip"]
        j["knee_" + s] = legs[s]["knee"]
        j["ankle_" + s] = legs[s]["ankle"]
        j["toe_" + s] = legs[s]["toe"]
    extra = {"wrist_L": arm["L"]["wrist"], "wrist_R": arm["R"]["wrist"],
             "armpit_L": arm["L"]["armpit"], "armpit_R": arm["R"]["armpit"],
             "crotch": (cx, float(crotch))}
    return j, extra, flags


def to_rig(pt, f):
    return [round(pt[0] * f, 1), round(pt[1] * f, 1)]


ORDER = ["head_top", "neck", "hip", "shoulder_L", "elbow_L", "hand_L", "shoulder_R", "elbow_R", "hand_R",
         "hip_L", "knee_L", "ankle_L", "toe_L", "hip_R", "knee_R", "ankle_R", "toe_R"]


def process(path):
    name = os.path.basename(os.path.dirname(path))
    view = os.path.splitext(os.path.basename(path))[0].rsplit("_", 1)[1]
    im = Image.open(path).convert("RGBA")
    W, H = im.size
    j, extra, flags = measure(np.asarray(im)[..., 3])
    f = RIG_H / H
    jr = {k: to_rig(j[k], f) for k in ORDER}
    er = {k: to_rig(v, f) for k, v in extra.items()}
    key = f"{name}_{view}"
    for k, (dx, dy) in OVERRIDES.get(key, {}).items():
        tgt = jr if k in jr else er
        tgt[k] = [round(tgt[k][0] + dx, 1), round(tgt[k][1] + dy, 1)]
        flags.append(f"manual nudge {k} {dx:+},{dy:+}")
    out = {
        "texture": "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/"),
        "tex_size": [W, H],
        "src_size": [round(W * f, 2), RIG_H],
        "view": view,
        "lr": "screen left/right in the art (same convention as cutout_rig.gd)",
        "j": jr,
        "extra": er,
        "flags": flags,
        "method": "tools/joint_map.py silhouette analysis, checked on joints_overlay.png",
    }
    dst = os.path.join(os.path.dirname(path), f"joints_{view}.json")
    with open(dst, "w") as fh:
        json.dump(out, fh, indent=2)
        fh.write("\n")
    return dst, out, im


def overlay(results, dst, h=520):
    tiles = []
    for _, out, im in results:
        W, H = im.size
        sc = h / H
        bg = Image.new("RGB", (int(W * sc) + 20, h + 40), (205, 202, 195))
        sp = im.resize((int(W * sc), h), Image.LANCZOS)
        bg.paste(sp, (10, 30), sp)
        d = ImageDraw.Draw(bg)
        f = (H / RIG_H) * sc
        P = {k: (10 + v[0] * f, 30 + v[1] * f) for k, v in out["j"].items()}
        bones = [("head_top", "neck"), ("neck", "hip"), ("shoulder_L", "elbow_L"), ("elbow_L", "hand_L"),
                 ("shoulder_R", "elbow_R"), ("elbow_R", "hand_R"), ("hip_L", "knee_L"), ("knee_L", "ankle_L"),
                 ("ankle_L", "toe_L"), ("hip_R", "knee_R"), ("knee_R", "ankle_R"), ("ankle_R", "toe_R"),
                 ("neck", "shoulder_L"), ("neck", "shoulder_R"), ("hip", "hip_L"), ("hip", "hip_R")]
        for a, b in bones:
            col = (0, 170, 255) if a.endswith("_L") or b.endswith("_L") else (255, 140, 0) if a.endswith("_R") or b.endswith("_R") else (40, 220, 90)
            d.line([P[a], P[b]], fill=col, width=2)
        for k, p in P.items():
            col = (0, 120, 255) if k.endswith("_L") else (255, 90, 0) if k.endswith("_R") else (20, 180, 60)
            d.ellipse((p[0] - 3.5, p[1] - 3.5, p[0] + 3.5, p[1] + 3.5), fill=col, outline=(0, 0, 0))
        for k in ("wrist_L", "wrist_R"):
            v = out["extra"][k]
            p = (10 + v[0] * f, 30 + v[1] * f)
            d.rectangle((p[0] - 2, p[1] - 2, p[0] + 2, p[1] + 2), fill=(255, 255, 0), outline=(0, 0, 0))
        label = os.path.basename(os.path.dirname(out["texture"])) + " " + out["view"] + (" *" if out["flags"] else "")
        d.text((8, 6), label, fill=(0, 0, 0))
        tiles.append(bg)
    cols = 6
    rows = (len(tiles) + cols - 1) // cols
    tw = max(t.width for t in tiles)
    th = max(t.height for t in tiles)
    sheet = Image.new("RGB", (cols * tw, rows * th + 40), (60, 60, 60))
    for i, t in enumerate(tiles):
        sheet.paste(t, ((i % cols) * tw, (i // cols) * th))
    ImageDraw.Draw(sheet).text((10, rows * th + 12),
                               "blue = screen-left (L), orange = screen-right (R), green = centre, yellow squares = wrists; * = see flags in JSON",
                               fill=(255, 255, 255))
    sheet.save(dst)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("only", nargs="*")
    ap.add_argument("--overlay")
    a = ap.parse_args(argv)
    paths = sorted(p for p in glob.glob(os.path.join(ROOT, "assets/characters/*/*_front.png")) +
                   glob.glob(os.path.join(ROOT, "assets/characters/*/*_back.png"))
                   if "/rigged/" not in p)
    res = []
    for p in paths:
        key = os.path.splitext(os.path.basename(p))[0]
        if a.only and key not in a.only:
            continue
        dst, out, im = process(p)
        res.append((dst, out, im))
        print(os.path.relpath(dst, ROOT), "; ".join(out["flags"]))
    if a.overlay:
        overlay(res, a.overlay)
        print("overlay", a.overlay)


if __name__ == "__main__":
    main(sys.argv[1:])
