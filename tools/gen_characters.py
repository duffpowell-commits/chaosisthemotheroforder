"""Generate CC0 MakeHuman characters with MPFB and export them for Godot.

Run: blender -b --python tools/gen_characters.py -- <out_dir>
Each character is exported twice:
  <name>.glb        posed (arms relaxed), rig removed: static props for render tests
  <name>_rig.glb    rest pose with a Mixamo-compatible rig (only with --with-rigs)
"""
import sys, os, math, bpy
from bl_ext.user_default.mpfb.services.humanservice import HumanService
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paint_likeness

OUT = sys.argv[sys.argv.index("--") + 1]

BASE = {"eyes": "high-poly.mhclo", "eyebrows": "eyebrow001.mhclo", "eyelashes": "eyelashes01.mhclo",
        "teeth": "teeth_base.mhclo", "tongue": "", "proxy": "", "rig": "mixamo",
        "targets": [], "expressions": [], "skin_material_type": "MAKESKIN", "eyes_material_type": "MAKESKIN",
        "skin_material_settings": {}, "eyes_material_settings": {}}

def race(c=0.0, a=0.0, f=0.0):
    return {"caucasian": c, "asian": a, "african": f}

CHARS = {
    "riot_police": dict(phenotype=dict(gender=1.0, age=0.45, muscle=0.75, weight=0.6, proportions=0.6, height=0.65,
                                       cupsize=0.5, firmness=0.5, race=race(0.5, 0.2, 0.3)),
                        hair="short02.mhclo", skin_mhmat="middleage_caucasian_male.mhmat",
                        clothes=["male_worksuit01.mhclo", "shoes06.mhclo"]),
    "civilian_man": dict(phenotype=dict(gender=1.0, age=0.6, muscle=0.45, weight=0.55, proportions=0.5, height=0.5,
                                        cupsize=0.5, firmness=0.5, race=race(0.1, 0.0, 0.9)),
                         hair="short04.mhclo", skin_mhmat="middleage_african_male.mhmat",
                         clothes=["male_casualsuit03.mhclo", "shoes02.mhclo"]),
    "civilian_woman": dict(phenotype=dict(gender=0.0, age=0.4, muscle=0.4, weight=0.45, proportions=0.55, height=0.45,
                                          cupsize=0.5, firmness=0.5, race=race(0.2, 0.8, 0.0)),
                           hair="bob02.mhclo", skin_mhmat="young_asian_female.mhmat",
                           clothes=["female_casualsuit01.mhclo", "shoes03.mhclo"]),
    "duff": dict(phenotype=dict(gender=1.0, age=0.58, muscle=0.45, weight=0.6, proportions=0.5, height=0.55,
                                cupsize=0.5, firmness=0.5, race=race(1.0, 0.0, 0.0)),
                 hair="cortu_short_messy_hair.mhclo", skin_mhmat="middleage_caucasian_male.mhmat",
                 clothes=["elvs_crude_t-shirt_male.mhclo", "toigo_wool_pants.mhclo", "toigo_ankle_boots_male.mhclo"],
                 likeness=True),
}

SETTINGS = HumanService.get_default_deserialization_settings()
SETTINGS["subdiv_levels"] = 0
SETTINGS["material_instances"] = "NEVER"


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials):
        for b in list(block):
            if b.users == 0:
                block.remove(b)


def family(rig):
    return [rig] + [c for c in rig.children_recursive]


def shrink_images(limit=1024):
    for img in bpy.data.images:
        w, h = img.size
        if max(w, h) > limit:
            k = limit / max(w, h)
            img.scale(max(1, int(w * k)), max(1, int(h * k)))


def export(objs, path, limit=1024):
    shrink_images(limit)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_apply=True, export_morph=False, export_animations=False,
                              export_yup=True, export_image_format="JPEG", export_jpeg_quality=82)


def relax_pose(rig):
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        n = pb.name.lower()
        pb.rotation_mode = "XYZ"
        if n.endswith("leftarm"):
            pb.rotation_euler = (0, 0, math.radians(-62))
        elif n.endswith("rightarm"):
            pb.rotation_euler = (0, 0, math.radians(62))
        elif n.endswith("leftforearm") or n.endswith("rightforearm"):
            pb.rotation_euler = (math.radians(-12), 0, 0)
    bpy.ops.object.mode_set(mode="OBJECT")


ONLY = [a for a in sys.argv[sys.argv.index("--") + 2:] if not a.startswith("--")]
for name, spec in CHARS.items():
    if ONLY and name not in ONLY:
        continue
    clear()
    info = dict(BASE)
    likeness = spec.pop("likeness", False)
    info.update(spec)
    info["name"] = name
    basemesh = HumanService.deserialize_from_dict(info, SETTINGS)
    rig = basemesh.parent
    assert rig is not None and rig.type == "ARMATURE", "no rig"
    if likeness:
        paint_likeness.paint(basemesh)
        paint_likeness.set_eye_color(rig, "lightblue")
    # Drop MPFB helper geometry (joint cubes, clothes helpers) from the export.
    for m in basemesh.modifiers:
        if m.type == "MASK":
            m.show_viewport = True
    if "--with-rigs" in sys.argv:
        export(family(rig), os.path.join(OUT, f"{name}_rig.glb"))
    # Posed, rig-free copy
    relax_pose(rig)
    meshes = [o for o in family(rig) if o.type == "MESH"]
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        if o.data.shape_keys:
            bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
        for m in list(o.modifiers):
            if m.type == "ARMATURE":
                bpy.ops.object.modifier_apply(modifier=m.name)
        o.parent = None
    export(meshes, os.path.join(OUT, f"{name}.glb"), 2048 if likeness else 1024)
    print("EXPORTED", name)
