"""Paint Duff's likeness details into an MPFB character's skin texture.

Positions come from MPFB joint landmarks (metres, Z up, character faces -Y,
character's left is +X). Each painted region is a procedural approximation
of a feature from the reference photos, not a copy of the actual tattoo art.
"""
import os
import numpy as np
import bpy

EYE_DIR = os.path.expanduser("~/.config/blender/4.5/extensions/.user/user_default/mpfb/data/eyes/materials")


def _image_node(mat, hint="diffuse"):
    nodes = [n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image]
    for n in nodes:
        if hint in n.image.name.lower() or hint in n.name.lower():
            return n
    return nodes[0] if nodes else None


def set_eye_color(rig, color="lightblue"):
    path = os.path.join(EYE_DIR, f"{color}_eye.png")
    for o in rig.children_recursive:
        if o.type == "MESH" and "eye" in o.name.lower() and "brow" not in o.name.lower() and "lash" not in o.name.lower():
            for mat in o.data.materials:
                if mat and mat.node_tree:
                    n = _image_node(mat, "eye")
                    if n:
                        n.image = bpy.data.images.load(path, check_existing=True)


def _raster(px_uv, pos):
    """Rasterize one triangle in pixel space; return (rows, cols, positions)."""
    (x0, y0), (x1, y1), (x2, y2) = px_uv
    minx, maxx = int(np.floor(min(x0, x1, x2))), int(np.ceil(max(x0, x1, x2)))
    miny, maxy = int(np.floor(min(y0, y1, y2))), int(np.ceil(max(y0, y1, y2)))
    if maxx - minx < 1 or maxy - miny < 1:
        return None
    xs, ys = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
    den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
    if abs(den) < 1e-12:
        return None
    w0 = ((y1 - y2) * (xs - x2) + (x2 - x1) * (ys - y2)) / den
    w1 = ((y2 - y0) * (xs - x2) + (x0 - x2) * (ys - y2)) / den
    w2 = 1.0 - w0 - w1
    m = (w0 >= -0.01) & (w1 >= -0.01) & (w2 >= -0.01)
    if not m.any():
        return None
    P = w0[m, None] * pos[0] + w1[m, None] * pos[1] + w2[m, None] * pos[2]
    return ys[m].astype(int), xs[m].astype(int), P


def _arm_coords(P, sh, hand):
    axis = hand - sh
    L = np.linalg.norm(axis)
    a = axis / L
    d = P - sh
    t = d @ a / L
    perp = d - np.outer(d @ a, a)
    u = np.cross(a, [0, 0, 1.0]); u /= np.linalg.norm(u)
    v = np.cross(a, u)
    theta = np.arctan2(perp @ v, perp @ u)
    return t, theta, np.linalg.norm(perp, axis=1)


def paint(basemesh, seed=3):
    rng = np.random.default_rng(seed)
    mat = basemesh.data.materials[0]
    node = _image_node(mat, "diffuse")
    src = node.image
    w, h = src.size
    pix = np.empty(w * h * 4, dtype=np.float32)
    src.pixels.foreach_get(pix)
    pix = pix.reshape(h, w, 4)

    # Unmasked, shape-keyed vertex positions
    shown = [(m, m.show_viewport) for m in basemesh.modifiers]
    for m, _ in shown:
        m.show_viewport = False
    dg = bpy.context.evaluated_depsgraph_get()
    me = basemesh.evaluated_get(dg).to_mesh()
    co = np.empty(len(me.vertices) * 3, dtype=np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    basemesh.evaluated_get(dg).to_mesh_clear()
    for m, s in shown:
        m.show_viewport = s

    def lm(name):
        g = basemesh.vertex_groups[name].index
        idx = [v.index for v in basemesh.data.vertices if any(x.group == g for x in v.groups)]
        return co[idx].mean(0)

    sh_l, sh_r = lm("joint-l-shoulder"), lm("joint-r-shoulder")
    hand_l = lm("joint-l-hand")
    hand_r = hand_l * np.array([-1, 1, 1])
    body_g = basemesh.vertex_groups["body"].index
    in_body = np.zeros(len(co), bool)
    for v in basemesh.data.vertices:
        if any(x.group == body_g for x in v.groups):
            in_body[v.index] = True

    uv = basemesh.data.uv_layers.active.data
    rows, cols, Ps = [], [], []
    for poly in basemesh.data.polygons:
        vids = list(poly.vertices)
        if not in_body[vids].all():
            continue
        cz = co[vids, 2].mean()
        if cz < 0.95:
            continue
        loops = list(poly.loop_indices)
        uvs = np.array([uv[l].uv[:] for l in loops]) * [w, h]
        pos = co[vids]
        for k in range(1, len(vids) - 1):
            r = _raster(uvs[[0, k, k + 1]], pos[[0, k, k + 1]])
            if r:
                rows.append(r[0]); cols.append(r[1]); Ps.append(r[2])
    R = np.clip(np.concatenate(rows), 0, h - 1)
    C = np.clip(np.concatenate(cols), 0, w - 1)
    P = np.concatenate(Ps)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    noise = rng.random(n)
    color = np.zeros((n, 3), np.float32)
    alpha = np.zeros(n, np.float32)

    def put(mask, rgb, a):
        a = np.where(mask, a, 0.0)
        keep = a > alpha
        color[keep] = rgb if np.ndim(rgb) == 1 else rgb[keep]
        alpha[keep] = a[keep]

    def soft(v, lo, hi, edge):
        """1 inside [lo, hi], fading to 0 over `edge` outside it."""
        return np.clip(np.minimum(v - lo, hi - v) / edge + 1.0, 0.0, 1.0)

    front = np.clip((-y - 0.03) / 0.02, 0, 1)
    speck = (noise > 0.55).astype(np.float32)
    # Freckles on face, shoulders and arms
    put((z > 1.25) & (noise > 0.985), np.array([0.62, 0.38, 0.27]), 0.4)
    # Stubble: jaw, chin, upper lip, under the chin (soft edges, speckled)
    lips = soft(np.abs(x), -1, 0.026, 0.004) * soft(z, 1.598, 1.616, 0.004)
    jaw_top = 1.632 - 0.5 * np.maximum(np.abs(x) - 0.03, 0)
    beard = front * soft(np.abs(x), -1, 0.072, 0.01) * soft(z, 1.548, 1.0, 0.012) * np.clip((jaw_top - z) / 0.01, 0, 1) * (1 - lips)
    under = soft(z, 1.525, 1.565, 0.01) * soft(np.abs(x), -1, 0.055, 0.01) * np.clip((-y + 0.02) / 0.02, 0, 1)
    b = np.maximum(beard, under)
    put(b > 0.02, np.array([0.45, 0.26, 0.15]), b * (0.12 + 0.5 * speck))
    # Undercut: buzzed sides and back of the scalp
    side = np.clip((np.abs(x) - 0.055) / 0.01, 0, 1)
    back = np.clip((y - 0.0) / 0.02, 0, 1)
    sc = soft(z, 1.668, 2.0, 0.012) * np.maximum(side, back) * np.clip((y + 0.1) / 0.02, 0, 1)
    put(sc > 0.02, np.array([0.5, 0.37, 0.25]), sc * (0.3 + 0.45 * speck))
    # Neck (his right side): wolf in dark teal-grey, with a blue rose
    nk = soft(z, 1.475, 1.575, 0.012) * np.clip((-x - 0.022) / 0.012, 0, 1) * soft(y, -0.075, 0.05, 0.015)
    shade_ = 0.6 + 0.4 * np.sin(z * 260) * np.cos(y * 210)
    put(nk > 0.02, np.array([0.16, 0.21, 0.23]) * shade_[:, None], nk * 0.85)
    rose = np.clip(1 - np.hypot(x + 0.055, z - 1.525) / 0.014, 0, 1) * (nk > 0.3)
    put(rose > 0.02, np.array([0.34, 0.5, 0.72]), np.minimum(rose * 3, 0.9))
    # Chest (his right): skull with pink crystals
    chest = y < -0.06
    sk = ((x + 0.085) / 0.052) ** 2 + ((z - 1.37) / 0.062) ** 2
    put(chest & (sk < 1.0), np.array([0.5, 0.5, 0.52]), 0.85)
    put(chest & (sk > 0.8) & (sk < 1.0), np.array([0.12, 0.12, 0.13]), 0.95)
    for ex in (-0.105, -0.066):
        put(chest & (np.hypot(x - ex, z - 1.378) < 0.013), np.array([0.08, 0.08, 0.09]), 0.95)
    crystals = chest & (z > 1.425) & (z < 1.47) & (x > -0.125) & (x < -0.045) & (np.abs(np.sin(x * 160)) * 0.045 > z - 1.425)
    put(crystals, np.array([0.86, 0.45, 0.62]), 0.85)
    # Chest (his left): two lines of script
    script_l = chest & (x > 0.05) & (x < 0.14) & ((np.abs(z - 1.395) < 0.004) | (np.abs(z - 1.382) < 0.004)) & (np.sin(x * 900) > -0.2)
    put(script_l, np.array([0.1, 0.1, 0.11]), 0.85)
    # Stomach: arched script
    arc = 1.12 + 1.6 * x ** 2
    belly = (y < -0.05) & (np.abs(x) < 0.15) & (np.abs(z - arc) < 0.0065) & (np.sin(x * 700) > -0.3)
    put(belly, np.array([0.12, 0.13, 0.15]), 0.85)
    # Left arm: geometric blackwork full sleeve
    t, th, rad = _arm_coords(P, sh_l, hand_l)
    arm_l = (x > sh_l[0] - 0.03) & (t > -0.02) & (t < 0.9)
    lattice = (np.abs(np.sin(th * 6 + t * 30)) > 0.86) | (np.abs(np.sin(th * 6 - t * 30)) > 0.86)
    bands = np.abs(np.sin(t * 70)) > 0.94
    rings = np.abs(np.sin(np.hypot((t - 0.3) * 8, np.sin(th) * 1.4) * 22)) > 0.8
    solid = (np.abs(t - 0.52) < 0.045) | (t > 0.82)
    sleeve = arm_l & (lattice | bands | (rings & (t < 0.45)) | solid)
    put(sleeve, np.array([0.07, 0.08, 0.09]), 0.9)
    put(arm_l & ~sleeve, np.array([0.3, 0.32, 0.34]), 0.18)
    # Right arm: separate illustrative pieces (upper arm and forearm)
    t2, th2, _ = _arm_coords(P, sh_r, hand_r)
    arm_r = (x < sh_r[0] + 0.03)
    piece1 = arm_r & (np.abs(t2 - 0.25) < 0.09) & (np.cos(th2 - 0.6) > 0.2)
    piece2 = arm_r & (np.abs(t2 - 0.68) < 0.1) & (np.cos(th2 + 2.0) > 0.1)
    put(piece1 | piece2, np.array([0.18, 0.2, 0.22]) + 0.1 * noise[:, None], 0.75)

    idx = alpha > 0
    base = pix[R[idx], C[idx], :3]
    pix[R[idx], C[idx], :3] = base * (1 - alpha[idx, None]) + color[idx] * alpha[idx, None]
    img = bpy.data.images.new("duff_skin_diffuse", w, h, alpha=True)
    img.pixels.foreach_set(pix.ravel())
    img.pack()
    node.image = img
    return img
