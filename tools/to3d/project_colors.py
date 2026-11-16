"""Colour a mesh by projecting the front/back A-pose art straight on (orthographic).
Front art on faces looking +z, mirrored back art on faces looking -z, blended at the sides."""
import sys, numpy as np, trimesh
from PIL import Image
name = sys.argv[1]; d = '/mnt/project-files/chaos-art/to-3d/'
mesh = trimesh.load(f'/tmp/h3d/out/{name}_shape.glb', force='mesh')
# subdivide so vertex colours carry the detail
for _ in range(1):
    mesh = mesh.subdivide()
def load(v):
    im = np.asarray(Image.open(f'{d}{name}_{v}.png').convert('RGB')).astype(np.float32)
    from scipy.ndimage import binary_erosion
    mask = binary_erosion(im.min(axis=2) < 200, iterations=3)
    ys, xs = np.where(mask)
    from scipy.ndimage import distance_transform_edt
    _, (iy, ix) = distance_transform_edt(~mask, return_indices=True)
    im = im[iy, ix]  # bleed edge colours into the background so near-misses don't sample white
    return im, (xs.min(), xs.max(), ys.min(), ys.max())
F, fb = load('front'); B, bb = load('back')
v = mesh.vertices; n = mesh.vertex_normals
lo, hi = v.min(0), v.max(0)
def sample(im, box, x01, y01):
    x0, x1, y0, y1 = box
    px = np.clip((x0 + x01 * (x1 - x0)).astype(int), 0, im.shape[1] - 1)
    py = np.clip((y0 + (1 - y01) * (y1 - y0)).astype(int), 0, im.shape[0] - 1)
    return im[py, px]
# which mesh axis is depth? Hunyuan: +z toward the front view.
x01 = (v[:, 0] - lo[0]) / (hi[0] - lo[0]); y01 = (v[:, 1] - lo[1]) / (hi[1] - lo[1])
cf = sample(F, fb, x01, y01)
cb = sample(B, bb, 1 - x01, y01)
w = np.clip(n[:, 2] * 0.5 + 0.5, 0, 1)[:, None]
w = w ** 2 / (w ** 2 + (1 - w) ** 2 + 1e-6)
col = cf * w + cb * (1 - w)
col = 255 * ((col / 255) ** 2.2)  # glTF vertex colours are linear
mesh.visual = trimesh.visual.ColorVisuals(mesh, vertex_colors=np.hstack([col, np.full((len(col), 1), 255)]).astype(np.uint8))
mesh.export(f'/tmp/h3d/out/{name}_cpu.glb')
print('ok', len(mesh.vertices), lo, hi)
