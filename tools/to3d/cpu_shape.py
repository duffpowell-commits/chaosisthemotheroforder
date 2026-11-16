import os, sys, time, torch
from PIL import Image
import numpy as np
from hy3dgen.shapegen import Hunyuan3DDiTFlowMatchingPipeline
torch.set_num_threads(4)
name = sys.argv[1]; d = '/mnt/project-files/chaos-art/to-3d/'
imgs = {}
for v in ('front', 'back'):
    if not os.path.exists(f'{d}{name}_{v}.png'):  # front-only art (visor_operative, guard_defector)
        continue
    a = np.asarray(Image.open(f'{d}{name}_{v}.png').convert('RGB'))
    alpha = (a.min(axis=2) < 240).astype(np.uint8) * 255
    imgs[v] = Image.fromarray(np.dstack([a, alpha]), 'RGBA')
t = time.time()
pipe = Hunyuan3DDiTFlowMatchingPipeline.from_pretrained('tencent/Hunyuan3D-2mv', subfolder='hunyuan3d-dit-v2-mv-turbo', variant='fp16', device='cpu', dtype=torch.float32)
pipe.enable_flashvdm()
pipe.to('cpu', torch.float32)
for m in pipe.vae.modules(): m.float()
print('loaded', time.time() - t, flush=True)
mesh = pipe(image=imgs, num_inference_steps=10, octree_resolution=256, num_chunks=20000, generator=torch.manual_seed(1234), output_type='trimesh')[0]
print('gen', time.time() - t, len(mesh.vertices), len(mesh.faces), flush=True)
os.makedirs('/tmp/h3d/out', exist_ok=True)
mesh.export(f'/tmp/h3d/out/{name}_shape.glb')
