# Characters

Generated with MPFB (MakeHuman for Blender) from CC0 MakeHuman asset packs.

Regenerate the rigged characters:

    blender -b --python tools/gen_characters.py -- assets/characters/rigged --with-rigs
    rm assets/characters/rigged/{riot_police,civilian_man,civilian_woman,duff}.glb
    python3 tools/setup_retarget.py   # after Godot has imported them once

The protagonist's skin is painted by `tools/paint_likeness.py`, which reads
private reference photos from `reference/private/` (never committed).
