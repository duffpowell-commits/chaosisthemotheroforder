"""Point Godot's humanoid retargeter at our Mixamo-named skeletons.

Rewrites the `_subresources` of each character and animation .import file so
Godot maps `mixamorig_*` bones onto its SkeletonProfileHumanoid, normalises
rest poses (rest fixer + silhouette fix) and loops the cyclic animations.
Run after Godot has created the .import files once, then re-import.
"""
import glob
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
NO_LOOP = {"death_front", "angry", "nod_yes", "shake_no", "acknowledge", "look_away", "dismiss"}

M = "mixamorig_"
MAP = {
    "Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2",
    "Neck": "Neck", "Head": "Head",
}
for side in ("Left", "Right"):
    MAP.update({
        f"{side}Shoulder": f"{side}Shoulder", f"{side}UpperArm": f"{side}Arm",
        f"{side}LowerArm": f"{side}ForeArm", f"{side}Hand": f"{side}Hand",
        f"{side}UpperLeg": f"{side}UpLeg", f"{side}LowerLeg": f"{side}Leg",
        f"{side}Foot": f"{side}Foot", f"{side}Toes": f"{side}ToeBase",
        f"{side}ThumbMetacarpal": f"{side}HandThumb1", f"{side}ThumbProximal": f"{side}HandThumb2",
        f"{side}ThumbDistal": f"{side}HandThumb3",
    })
    for prof, mix in (("Index", "Index"), ("Middle", "Middle"), ("Ring", "Ring"), ("Little", "Pinky")):
        MAP.update({f"{side}{prof}Proximal": f"{side}Hand{mix}1",
                    f"{side}{prof}Intermediate": f"{side}Hand{mix}2",
                    f"{side}{prof}Distal": f"{side}Hand{mix}3"})


def bone_map(skip=()):
    entries = ",".join(f'"bone_map/{k}":&"{M}{v}"' for k, v in MAP.items() if k not in skip)
    profile = 'Object(SkeletonProfileHumanoid,"resource_local_to_scene":false,"resource_name":"","script":null)'
    return f'Object(BoneMap,"resource_local_to_scene":false,"resource_name":"","profile":{profile},{entries},"script":null)'


def node_settings(skip=(), silhouette=True):
    return ('{"retarget/bone_map": ' + bone_map(skip) +
            ', "retarget/bone_renamer/unique_node/skeleton_name": "GeneralSkeleton"'
            ', "retarget/rest_fixer/overwrite_axis": true'
            ', "retarget/rest_fixer/fix_silhouette/enable": ' + ("true" if silhouette else "false") + '}')


def rewrite(path, skeleton_path, anim_loop=None, skip=(), silhouette=True):
    text = open(path).read()
    sub = '{\n"nodes": {\n"PATH:' + skeleton_path + '": ' + node_settings(skip, silhouette) + '\n}'
    if anim_loop is not None:
        sub += ',\n"animations": {\n"mixamo_com": {"settings/loop_mode": ' + str(anim_loop) + '}\n}'
    sub += '\n}'
    text = re.sub(r"_subresources=\{.*?\n(?=[a-z_]+/|\Z)", "_subresources=" + sub + "\n", text, flags=re.S)
    open(path, "w").write(text)


for f in glob.glob(os.path.join(ROOT, "assets/characters/rigged/*_rig.glb.import")):
    name = os.path.basename(f).replace("_rig.glb.import", "")
    # MPFB's Mixamo rig is already in a Mixamo-like rest pose; the silhouette
    # fix over-corrects it (it tipped the head back), so only axes are fixed.
    rewrite(f, f"{name}/Skeleton3D", silhouette=False)
for f in glob.glob(os.path.join(ROOT, "assets/animations/*.fbx.import")):
    name = os.path.basename(f).replace(".fbx.import", "")
    rewrite(f, "Skeleton3D", 0 if name in NO_LOOP else 1)
print("retarget settings written")
