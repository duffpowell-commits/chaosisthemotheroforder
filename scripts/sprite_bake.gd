extends "res://scripts/render_test.gd"
## Fallback art test: bake the 3D characters into 8-direction 2D sprites,
## the way pre-rendered isometric games did. Reuses the street script's
## character loader (rigs, retargeted Mixamo clips, gear attachments).
##
## Run: xvfb-run -a godot --path . --rendering-driver opengl3 res://scenes/sprite_bake.tscn -- --out /tmp/bake
## Then compose sheets: python3 tools/compose_sprites.py /tmp/bake docs/renders/sprites

var CELL := 256            # render size per frame; downscaled when composing (--cell N)
const DIRS := 8
const ELEVATION := 35.0    # camera pitch in degrees (isometric-ish)
const WALK_FRAMES := 8

var vp: SubViewport
var stage: Node3D
var out_dir := "/tmp/bake"
var only := ""           # --only duff: bake one character
var only_idle := false    # --idle: skip walk cycles


func _ready() -> void:
	rng.seed = 7
	var args := OS.get_cmdline_user_args()
	var i := args.find("--out")
	if i >= 0 and i + 1 < args.size():
		out_dir = args[i + 1]
	var c := args.find("--cell")
	if c >= 0 and c + 1 < args.size():
		CELL = int(args[c + 1])
	var o := args.find("--only")
	if o >= 0 and o + 1 < args.size():
		only = args[o + 1]
	only_idle = "--idle" in args
	DirAccess.make_dir_recursive_absolute(out_dir)
	_build_stage()
	await _bake_all()
	get_tree().quit()


func _build_stage() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	stage = Node3D.new()
	vp.add_child(stage)

	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.65)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = e
	stage.add_child(we)

	# Lights stay fixed to the camera while the character turns, so every
	# direction is lit the same way (that's what keeps baked sprites consistent).
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 1.25
	key.shadow_enabled = false
	stage.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 160, 0)
	rim.light_energy = 0.9
	rim.light_color = Color(0.7, 0.8, 1.0)
	stage.add_child(rim)

	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.size = 2.25
	var pitch := deg_to_rad(ELEVATION)
	var target := Vector3(0, 0.88, 0)
	c.position = target + Vector3(0, sin(pitch), cos(pitch)) * 10.0
	stage.add_child(c)
	c.look_at(target)
	c.current = true


## name -> [rig kind, riot gear?, tints, extra gear]
func _cast() -> Dictionary:
	return {
		"police": ["riot_police", false, {
			"suit": Color(0.1, 0.12, 0.17), "shoes": Color(0.05, 0.05, 0.06)}, "visor"],
		"rebel": ["civilian_man", false, {
			"suit": Color(0.42, 0.45, 0.28), "shoes": Color(0.25, 0.2, 0.15),
			"hair": Color(0.15, 0.11, 0.08)}, "bandana"],
		"rebel_f": ["civilian_woman", false, {
			"suit": Color(0.55, 0.32, 0.22), "shoes": Color(0.2, 0.18, 0.16),
			"hair": Color(0.2, 0.13, 0.09)}, "hood"],
		"duff": ["duff", false, {
			"shirt": Color(0.09, 0.09, 0.1), "pants": Color(0.16, 0.19, 0.27),
			"boot": Color(0.22, 0.18, 0.15), "hair": Color(0.74, 0.52, 0.33)}, "bandana"],
	}


func _bake_all() -> void:
	var cast := _cast()
	for who: String in cast:
		if only != "" and who != only:
			continue
		var spec: Array = cast[who]
		for anim: String in (["idle"] if only_idle else ["idle", "walk"]):
			var clip := "walk_f" if who == "rebel_f" and anim == "walk" else anim
			var n := _person(spec[0], Vector3.ZERO, 0.0, stage, spec[1], spec[2], clip)
			_add_gear(n, spec[3])
			var ap := n.find_children("*", "AnimationPlayer", false, false)[0] as AnimationPlayer
			ap.pause()
			var length := ap.current_animation_length
			var frames := 1 if anim == "idle" else WALK_FRAMES
			for d in range(DIRS):
				# Direction 0 faces the camera, then clockwise in 45 degree steps.
				n.rotation.y = deg_to_rad(d * 45.0)
				for f in range(frames):
					ap.seek(length * float(f) / float(frames), true)
					await RenderingServer.frame_post_draw
					await RenderingServer.frame_post_draw
					var img := vp.get_texture().get_image()
					img.save_png("%s/%s_%s_d%d_f%d.png" % [out_dir, who, anim, d, f])
			n.queue_free()
			await get_tree().process_frame


## Faceless gear: the regime hides behind visors, the movement behind cloth.
func _add_gear(n: Node3D, kind: String) -> void:
	var skel := n.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if skel == null:
		return
	var head := BoneAttachment3D.new()
	head.bone_name = "Head"
	skel.add_child(head)
	match kind:
		"visor":
			_cap(head, Color(0.04, 0.05, 0.07), 0.14, 0.35)
			var v := _box(Vector3(0.21, 0.07, 0.03), Vector3(0, 0.08, 0.115), _flat(Color(0.25, 0.32, 0.4), 0.05, Color(0.4, 0.55, 0.7), 0.25), head)
			v.rotation_degrees = Vector3(-8, 0, 0)
		"bandana":
			var b := _box(Vector3(0.19, 0.1, 0.2), Vector3(0, 0.05, 0.03), _flat(Color(0.62, 0.1, 0.08), 0.9), head)
			b.rotation_degrees = Vector3(8, 0, 0)
			_cap(head, Color(0.12, 0.12, 0.13), 0.125, 0.95)
		"hood":
			_cap(head, Color(0.2, 0.22, 0.24), 0.13, 0.95)
			# Respirator: grey mask plate with two filter cans.
			var mask := _box(Vector3(0.15, 0.08, 0.06), Vector3(0, 0.05, 0.1), _flat(Color(0.3, 0.31, 0.32), 0.5), head)
			mask.rotation_degrees = Vector3(8, 0, 0)
			for sx in [-0.07, 0.07]:
				var can := _box(Vector3(0.05, 0.05, 0.05), Vector3(sx, 0.03, 0.13), _flat(Color(0.15, 0.15, 0.16), 0.5), head)
				can.rotation_degrees = Vector3(8, 0, 0)


func _cap(head: Node3D, color: Color, radius: float, rough: float) -> void:
	var cap := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = radius
	hs.height = radius * 1.05
	hs.is_hemisphere = true
	cap.mesh = hs
	cap.material_override = _flat(color, rough)
	cap.position = Vector3(0, 0.1, -0.005)
	cap.scale = Vector3(1.0, 1.0, 1.12)
	head.add_child(cap)
