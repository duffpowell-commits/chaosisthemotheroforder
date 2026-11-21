#!/usr/bin/env python3
"""Automated QA for the Rail Yards art assets.

Checks every PNG matched by a group in tools/art_qa.json for:
  * readable text (Tesseract OCR on the image composited on paper and grey,
    at several scales; a token must be confirmed by 2+ runs, or hit the
    "single_conf" bar once, so painted texture doesn't trip it),
  * palette rules per group (movement red / maroon / saturated blue limits,
    as a % of opaque pixels),
  * exact sizes and image mode,
  * sprites: real alpha (no baked grey background) and not touching the
    frame edge.
Known, approved exceptions live in the config's "exceptions" block, each with
a reason, rather than loosening a rule for everyone.

Usage:
  python tools/art_qa.py                 # check everything in the config
  python tools/art_qa.py --require-ocr   # fail if Tesseract is missing (CI)
  python tools/art_qa.py --no-ocr        # skip OCR
  python tools/art_qa.py path/a.png ...  # check only these files
Exit code 1 if anything fails.
"""
import argparse, fnmatch, glob, json, os, re, shutil, sys
from concurrent.futures import ProcessPoolExecutor

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CONFIG = os.path.join(ROOT, "tools", "art_qa.json")


# ---------------------------------------------------------------- config

def load_config(path):
    with open(path) as f:
        return json.load(f)


def rel(p):
    return os.path.relpath(os.path.abspath(p), ROOT).replace(os.sep, "/")


def match_group(cfg, path):
    """First group whose globs match (and excludes don't)."""
    r = rel(path)
    for pat in cfg.get("ignore", []):
        if fnmatch.fnmatch(r, pat):
            return None
    for g in cfg["groups"]:
        if any(fnmatch.fnmatch(r, pat) for pat in g["globs"]) and not any(
                fnmatch.fnmatch(r, pat) for pat in g.get("exclude", [])):
            return g
    return None


def all_files(cfg):
    out = set()
    for g in cfg["groups"]:
        for pat in g["globs"]:
            for p in glob.glob(os.path.join(ROOT, pat)):
                if match_group(cfg, p) is g:
                    out.add(rel(p))
    return sorted(out)


def exception_for(cfg, r):
    return cfg.get("exceptions", {}).get(r, {})


# ---------------------------------------------------------------- checks

def palette_stats(img, defs):
    """% of opaque pixels that are movement red, maroon, saturated blue."""
    rgba = np.asarray(img.convert("RGBA"))
    opaque = rgba[..., 3] > 200
    n = max(int(opaque.sum()), 1)
    hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(np.float32)
    h = hsv[..., 0] * 360.0 / 255.0
    s = hsv[..., 1] / 255.0
    v = hsv[..., 2] / 255.0
    out = {}
    for name, d in defs.items():
        lo, hi = d["hue"]
        hue = (h >= lo) & (h <= hi) if lo <= hi else (h >= lo) | (h <= hi)
        m = hue & (s >= d["s_min"]) & (v >= d["v_min"]) & (v <= d.get("v_max", 1.0)) & opaque
        out[name] = 100.0 * float(m.sum()) / n
    return out


def check_size(img, g):
    errs = []
    want = g.get("size", {})
    w, h = img.size
    if "w" in want and w != want["w"]:
        errs.append(f"width {w} != {want['w']}")
    if "h" in want and h != want["h"]:
        errs.append(f"height {h} != {want['h']}")
    if "mode" in g and img.mode not in g["mode"]:
        errs.append(f"mode {img.mode} not in {g['mode']}")
    return errs


def check_sprite(img, g, skip):
    errs = []
    if img.mode != "RGBA":
        return ["sprite has no alpha channel"]
    a = np.asarray(img)[..., 3]
    transparent = float((a < 8).mean())
    if "alpha" not in skip:
        if transparent < g.get("min_transparent", 0.3):
            errs.append(f"only {transparent:.0%} transparent: baked background?")
        k = 4
        corners = np.concatenate([a[:k, :k].ravel(), a[:k, -k:].ravel(), a[-k:, :k].ravel(), a[-k:, -k:].ravel()])
        if corners.max() > 8:
            errs.append("opaque corners: baked background?")
    if "edge" not in skip:
        ring = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
        if ring.max() > g.get("edge_alpha_max", 16):
            sides = [n for n, row in (("top", a[0]), ("bottom", a[-1]), ("left", a[:, 0]), ("right", a[:, -1]))
                     if row.max() > g.get("edge_alpha_max", 16)]
            errs.append("touches the frame edge (" + ", ".join(sides) + ")")
    return errs


# ---------------------------------------------------------------- OCR

_TESS = None


def tesseract_cmd():
    global _TESS
    if _TESS is None:
        _TESS = os.environ.get("TESSERACT_CMD") or shutil.which("tesseract") or ""
    return _TESS


def ocr_available():
    try:
        import pytesseract  # noqa: F401
    except ImportError:
        return False
    return bool(tesseract_cmd())


def _norm(t):
    return re.sub(r"[^A-Za-z0-9]", "", t).upper()


def ocr_tokens(path, ocfg):
    """Return {token: [conf, ...]} across composites and scales."""
    import pytesseract
    pytesseract.pytesseract.tesseract_cmd = tesseract_cmd()
    im = Image.open(os.path.join(ROOT, path)).convert("RGBA")
    has_alpha = im.getextrema()[3][0] < 255
    bgs = [tuple(c) for c in ocfg["backgrounds"]] if has_alpha else [None]
    hits = {}
    for bg in bgs:
        base = im.convert("RGB") if bg is None else Image.new("RGB", im.size, bg)
        if bg is not None:
            base.paste(im, (0, 0), im)
        for sc in ocfg["scales"]:
            img = base.resize((int(base.width * sc), int(base.height * sc)), Image.LANCZOS)
            d = pytesseract.image_to_data(img, config=f"--psm {ocfg.get('psm', 11)}",
                                          output_type=pytesseract.Output.DICT)
            for t, c in zip(d["text"], d["conf"]):
                n = _norm(t)
                c = float(c)
                if len(n) < ocfg["min_len"] or c < ocfg["min_conf"] or len(set(n)) < 2:
                    continue
                hits.setdefault(n, []).append(c)
    return hits


def ocr_findings(path, ocfg, allow):
    out = []
    for tok, confs in ocr_tokens(path, ocfg).items():
        if tok in allow:
            continue
        if len(confs) >= ocfg["confirm_runs"] or max(confs) >= ocfg["single_conf"]:
            out.append((tok, len(confs), max(confs)))
    return out


def _ocr_job(args):
    path, ocfg, allow = args
    os.environ.setdefault("OMP_THREAD_LIMIT", "1")
    return path, ocr_findings(path, ocfg, allow)


# ---------------------------------------------------------------- main

def run(cfg, files, use_ocr, jobs=None, verbose=False):
    failures = {}
    notes = []
    ocr_queue = []
    for r in files:
        g = match_group(cfg, r)
        if g is None:
            notes.append(f"skip (no group): {r}")
            continue
        exc = exception_for(cfg, r)
        skip = set(exc.get("skip", []))
        img = Image.open(os.path.join(ROOT, r))
        errs = []
        if "size" not in skip:
            errs += check_size(img, g)
        if g.get("sprite"):
            errs += check_sprite(img, g, skip)
        pal = dict(g.get("palette", {}))
        pal.update(exc.get("palette", {}))
        if pal and "palette" not in skip:
            st = palette_stats(img, cfg["palette_defs"])
            for k, lim in pal.items():
                name = k[:-4]  # "red_max" -> "red"
                if st[name] > lim:
                    errs.append(f"{name} {st[name]:.2f}% > {lim}% ({g['name']})")
        if errs:
            failures.setdefault(r, []).extend(errs)
        if use_ocr and g.get("ocr", True) and "ocr" not in skip:
            allow = set(_norm(t) for t in cfg["ocr"].get("allow_tokens", []) + exc.get("allow_tokens", []))
            ocr_queue.append((r, cfg["ocr"], allow))
    if ocr_queue:
        os.environ.setdefault("OMP_THREAD_LIMIT", "1")
        with ProcessPoolExecutor(jobs or os.cpu_count()) as ex:
            for r, found in ex.map(_ocr_job, ocr_queue):
                for tok, n, c in found:
                    failures.setdefault(r, []).append(f"readable text '{tok}' (runs {n}, conf {c:.0f})")
    return failures, notes


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("files", nargs="*")
    ap.add_argument("--config", default=DEFAULT_CONFIG)
    ap.add_argument("--require-ocr", action="store_true")
    ap.add_argument("--no-ocr", action="store_true")
    ap.add_argument("-j", "--jobs", type=int)
    ap.add_argument("-v", "--verbose", action="store_true")
    a = ap.parse_args(argv)
    cfg = load_config(a.config)
    files = [rel(f) for f in a.files] if a.files else all_files(cfg)
    use_ocr = not a.no_ocr
    if use_ocr and not ocr_available():
        if a.require_ocr:
            print("art_qa: Tesseract/pytesseract not available and --require-ocr set", file=sys.stderr)
            return 2
        print("art_qa: WARNING Tesseract not available; skipping the OCR check", file=sys.stderr)
        use_ocr = False
    failures, notes = run(cfg, files, use_ocr, a.jobs, a.verbose)
    if a.verbose:
        for n in notes:
            print(n)
    for r in sorted(failures):
        for e in failures[r]:
            print(f"FAIL {r}: {e}")
    n_exc = len(cfg.get("exceptions", {}))
    print(f"art_qa: {len(files)} files, {len(failures)} failing, {n_exc} logged exceptions, OCR {'on' if use_ocr else 'off'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
