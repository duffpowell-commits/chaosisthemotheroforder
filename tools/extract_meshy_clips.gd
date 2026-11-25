extends SceneTree
## Turns Meshy clip GLBs into small Animation resources the game loads.
## Every Meshy rig shares one 24-bone skeleton (Armature/Skeleton3D), so one set of clips drives
## the whole cast (Meshy credit rule 4: reuse clips). The clip GLBs each carry a full textured
## mesh (~15 MB), so they stay out of git: the sources live in project files
## chaos-art/meshy/clips_src/. Copy them to assets/characters/meshy/clips_src/, then run:
##   godot --headless --path . --import
##   godot --headless --path . --script tools/extract_meshy_clips.gd
## Writes assets/characters/meshy/clips/<name>.res. Root motion is taken off the hips (x/z) so a
## unit stays where the tactical scene's tweens put it.

const SRC := "res://assets/characters/meshy/clips_src/"
const OUT := "res://assets/characters/meshy/clips/"
const LOOPING := ["idle", "walk", "run", "crouch_walk", "injured_walk", "sneak"]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var made := 0
	for f in DirAccess.get_files_at(SRC):
		if not f.ends_with(".glb"):
			continue
		var clip := f.get_basename()
		var scene: Node = (load(SRC + f) as PackedScene).instantiate()
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var a: Animation = ap.get_animation(ap.get_animation_list()[0]).duplicate(true)
		scene.free()
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D and str(a.track_get_path(t)).ends_with(":Hips") and a.track_get_key_count(t) > 0:
				var v0: Vector3 = a.track_get_key_value(t, 0)
				for k in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Vector3(v0.x, v.y, v0.z))
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
		a.resource_name = clip
		var err := ResourceSaver.save(a, OUT + clip + ".res")
		print("clip %s %.2fs %s" % [clip, a.length, "ok" if err == OK else "FAILED %d" % err])
		made += 1
	print("CLIPS %d" % made)
	quit(0 if made > 0 else 1)
