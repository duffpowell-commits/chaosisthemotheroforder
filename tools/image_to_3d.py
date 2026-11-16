"""Front + back A-pose art -> textured GLB via the free Hunyuan3D-2 Space.

Usage: HF_TOKEN=... python3 tools/image_to_3d.py duff [more names...]
Reads <dir>/<name>_front.png and <name>_back.png (1024x1024, white bg),
writes assets/characters/3d/<name>.glb (textured) and <name>_white.glb.
ZeroGPU: anonymous calls from cloud IPs get no quota; a free account token
gives a small daily quota (about two characters a day).
"""
import os, shutil, sys
from gradio_client import Client, handle_file

SRC = os.environ.get("TO3D_DIR", "/mnt/project-files/chaos-art/to-3d")
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "characters", "3d")


def main(names):
    os.makedirs(OUT, exist_ok=True)
    c = Client("tencent/Hunyuan3D-2", hf_token=os.environ.get("HF_TOKEN"))
    for n in names:
        front = handle_file(f"{SRC}/{n}_front.png")
        back = f"{SRC}/{n}_back.png"
        r = c.predict(caption=None, image=front, mv_image_front=front,
                      mv_image_back=handle_file(back) if os.path.exists(back) else None,
                      mv_image_left=None, mv_image_right=None, steps=30, guidance_scale=5.0,
                      seed=1234, octree_resolution=256, check_box_rembg=True, num_chunks=8000,
                      randomize_seed=False, api_name="/generation_all")
        shutil.copy(r[0], f"{OUT}/{n}_white.glb")
        shutil.copy(r[1], f"{OUT}/{n}.glb")
        print(n, r[3])


if __name__ == "__main__":
    main(sys.argv[1:] or ["duff"])
