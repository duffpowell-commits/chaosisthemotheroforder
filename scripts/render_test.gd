extends Node3D
## Render test for the look of the game: one Rail Yards street in Port Varga.
## Drag the slider to take the district from the regime. Run with
## `-- --capture` to save regime / contested / liberated screenshots.

const TEX := "res://assets/polyhaven/textures/%s/%s.jpg"
const MODEL := "res://assets/polyhaven/models/%s/%s.gltf"

var liberation := 0.0
var rng := RandomNumberGenerator.new()

var env: Environment
var sky_night: PanoramaSkyMaterial
var sky_dawn: PanoramaSkyMaterial
var road_mat: StandardMaterial3D
var grade_mat: ShaderMaterial
var rain: GPUParticles3D
var searchlight: SpotLight3D
var moon: DirectionalLight3D
var lamps: Array[OmniLight3D] = []
var lamp_bulbs: Array[StandardMaterial3D] = []
var windows: Array = []  # [MeshInstance3D, threshold]
var mat_window_off: StandardMaterial3D
var mat_window_cold: StandardMaterial3D
var mat_window_warm: StandardMaterial3D
var regime_nodes: Array[Node3D] = []
var liberated_nodes: Array[Node3D] = []
var slider: HSlider
var duff: Node3D
var cam: Camera3D
var state_label: Label


func _ready() -> void:
	rng.seed = 7
	_build_environment()
	_build_street()
	_build_buildings()
	_build_lamps()
	_build_regime_props()
	_build_liberated_props()
	duff = _person("duff", Vector3(-2.2, 0.0, 4.5), 25, self, false, {
		"shirt": Color(0.09, 0.09, 0.1), "pants": Color(0.16, 0.19, 0.27),
		"boot": Color(0.22, 0.18, 0.15), "hair": Color(1.25, 1.02, 0.78)})
	_build_rain()
	_build_camera()
	_build_grade_and_ui()
	_apply(0.0)
	if "--capture" in OS.get_cmdline_user_args():
		_capture()


# ---------- materials ----------

func _tex_mat(name: String, scale: float, rough: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX % [name, "albedo"])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(TEX % [name, "normal"])
	m.roughness_texture = load(TEX % [name, "rough"])
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


func _flat(color: Color, rough := 0.8, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _model(name: String, pos: Vector3, rot_y := 0.0, scale := 1.0, parent: Node = self) -> Node3D:
	var ps: PackedScene = load(MODEL % [name, name])
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y)
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n


# ---------- world ----------

func _build_environment() -> void:
	sky_night = PanoramaSkyMaterial.new()
	sky_night.panorama = load("res://assets/polyhaven/hdri/night.hdr")
	sky_dawn = PanoramaSkyMaterial.new()
	sky_dawn.panorama = load("res://assets/polyhaven/hdri/dawn.hdr")
	var sky := Sky.new()
	sky.sky_material = sky_night
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_density = 0.035
	env.fog_sky_affect = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38, -35, 0)
	moon.shadow_enabled = true
	add_child(moon)

	var probe := ReflectionProbe.new()
	probe.size = Vector3(30, 20, 60)
	probe.position = Vector3(0, 6, -14)
	probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	add_child(probe)


func _build_street() -> void:
	road_mat = _tex_mat("road", 0.25, 0.25)
	_box(Vector3(8, 0.1, 64), Vector3(0, -0.05, -20), road_mat)
	var walk := _tex_mat("sidewalk", 0.35, 0.6, Color(0.85, 0.85, 0.85))
	for side in [-1, 1]:
		_box(Vector3(3, 0.3, 64), Vector3(side * 5.5, 0.05, -20), walk)
		# Curb
		_box(Vector3(0.2, 0.32, 64), Vector3(side * 4.05, 0.06, -20), _flat(Color(0.35, 0.35, 0.34), 0.7))
	# Lane markings
	var paint := _flat(Color(0.75, 0.73, 0.65), 0.5)
	for i in range(14):
		_box(Vector3(0.15, 0.02, 1.6), Vector3(0, 0.01, 8 - i * 4.0), paint)


func _build_buildings() -> void:
	mat_window_off = _flat(Color(0.05, 0.06, 0.07), 0.15)
	mat_window_cold = _flat(Color(0.5, 0.58, 0.66), 0.3, Color(0.55, 0.7, 0.9), 0.9)
	mat_window_warm = _flat(Color(0.9, 0.72, 0.5), 0.3, Color(1.0, 0.66, 0.36), 1.2)
	var walls := [
		_tex_mat("wall_block", 0.35, 0.9),
		_tex_mat("wall_plaster", 0.25, 0.9, Color(0.8, 0.78, 0.74)),
		_tex_mat("iron", 0.4, 0.7, Color(0.7, 0.72, 0.74)),
	]
	var shutter := _tex_mat("shutter", 0.4, 0.6)
	for side: float in [-1.0, 1.0]:
		var z := 6.0
		while z > -46.0:
			var w := rng.randf_range(5.0, 9.0)
			var h := rng.randf_range(7.0, 19.0)
			var d := 8.0
			var x := side * (7.0 + d / 2.0)
			var cz := z - w / 2.0
			var wall: Material = walls[rng.randi() % walls.size()]
			_box(Vector3(d, h, w - 0.2), Vector3(x, h / 2.0, cz), wall)
			# Roof edge
			_box(Vector3(d + 0.3, 0.4, w), Vector3(x, h + 0.2, cz), _flat(Color(0.16, 0.16, 0.17), 0.9))
			# Ground-floor shutter
			_box(Vector3(0.08, 2.6, w * 0.6), Vector3(side * 7.0 - side * 0.04, 1.6, cz), shutter)
			# Windows on the street-facing facade
			var floors := int((h - 4.0) / 3.0)
			var cols := int(w / 1.8)
			for f in range(floors):
				for c in range(cols):
					var wz: float = cz - w / 2.0 + 0.9 + c * ((w - 1.8) / maxi(1, cols - 1))
					var wy := 4.2 + f * 3.0
					var win := _box(Vector3(0.06, 1.1, 0.7), Vector3(side * 7.0 - side * 0.03, wy, wz), mat_window_off)
					windows.append([win, rng.randf()])
			z -= w


func _build_lamps() -> void:
	var pole_mat := _flat(Color(0.12, 0.12, 0.13), 0.5)
	for i in range(5):
		var z := 4.0 - i * 10.0
		var side := -1 if i % 2 == 0 else 1
		var x := side * 4.6
		_box(Vector3(0.14, 6.5, 0.14), Vector3(x, 3.25, z), pole_mat)
		_box(Vector3(1.2, 0.1, 0.12), Vector3(x - side * 0.6, 6.5, z), pole_mat)
		var bulb := _flat(Color.WHITE, 0.3, Color(1, 0.7, 0.35), 6.0)
		lamp_bulbs.append(bulb)
		_box(Vector3(0.5, 0.12, 0.3), Vector3(x - side * 1.1, 6.38, z), bulb)
		var l := OmniLight3D.new()
		l.position = Vector3(x - side * 1.1, 6.1, z)
		l.omni_range = 13.0
		l.light_energy = 2.2
		l.shadow_enabled = i < 3
		add_child(l)
		lamps.append(l)
	# Electricity poles along the far side
	for i in range(3):
		_model("modular_electricity_poles", Vector3(-6.2, 0.2, -6 - i * 16.0), 90)


func _figure(pos: Vector3, coat: Color, parent: Node3D, height := 1.75, visor := false) -> void:
	var k := height / 1.75
	var pants := coat.darkened(0.45)
	# Legs
	for side: float in [-0.09, 0.09]:
		var leg := MeshInstance3D.new()
		var lc := CylinderMesh.new()
		lc.top_radius = 0.075 * k
		lc.bottom_radius = 0.06 * k
		lc.height = 0.86 * k
		leg.mesh = lc
		leg.material_override = _flat(pants, 0.9)
		leg.position = pos + Vector3(side * k, 0.43 * k, 0)
		parent.add_child(leg)
	# Torso (coat), slightly tapered
	var torso := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.2 * k
	tc.bottom_radius = 0.17 * k
	tc.height = 0.62 * k
	torso.mesh = tc
	torso.material_override = _flat(coat, 0.9)
	torso.position = pos + Vector3(0, 1.17 * k, 0)
	torso.scale = Vector3(1.0, 1.0, 0.62)
	parent.add_child(torso)
	# Arms
	for side: float in [-0.25, 0.25]:
		var arm := MeshInstance3D.new()
		var ac := CylinderMesh.new()
		ac.top_radius = 0.055 * k
		ac.bottom_radius = 0.045 * k
		ac.height = 0.6 * k
		arm.mesh = ac
		arm.material_override = _flat(coat.darkened(0.1), 0.9)
		arm.position = pos + Vector3(side * k, 1.13 * k, 0)
		arm.rotation.z = side * 0.25
		parent.add_child(arm)
	# Head
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.11 * k
	sp.height = 0.25 * k
	head.mesh = sp
	head.material_override = _flat(coat.darkened(0.3) if visor else Color(0.5, 0.39, 0.32), 0.7)
	head.position = pos + Vector3(0, 1.62 * k, 0)
	parent.add_child(head)
	if visor:
		_box(Vector3(0.2, 0.05, 0.04), pos + Vector3(0, 1.63 * k, 0.1), _flat(Color(0.4, 0.5, 0.6), 0.1, Color(0.5, 0.65, 0.8), 0.4), parent)
		# Riot shield
		_box(Vector3(0.55, 0.9, 0.04), pos + Vector3(0, 1.0 * k, 0.28), _flat(Color(0.45, 0.5, 0.55, 1.0), 0.2), parent)


func _person(kind: String, pos: Vector3, rot_y: float, parent: Node3D, shield := false, tints := {}) -> Node3D:
	var ps: PackedScene = load("res://assets/characters/%s.glb" % kind)
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y + 180.0)  # MakeHuman exports face -Z
	parent.add_child(n)
	_fix_character_materials(n, 0.22 if shield else 1.0, tints)
	if shield:
		# The model faces its local -Z, so gear in front goes at negative z.
		var sh := _box(Vector3(0.6, 1.0, 0.03), Vector3(0.05, 1.0, -0.34), _flat(Color(0.36, 0.4, 0.44), 0.15), n)
		sh.rotation.x = deg_to_rad(4)
		var helmet := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.145
		hs.height = 0.15
		hs.is_hemisphere = true
		helmet.mesh = hs
		helmet.material_override = _flat(Color(0.05, 0.06, 0.08), 0.35)
		helmet.position = Vector3(0, 1.69, -0.01)
		helmet.scale = Vector3(1.0, 1.0, 1.12)
		n.add_child(helmet)
		var visor := _box(Vector3(0.25, 0.12, 0.02), Vector3(0, 1.64, -0.155), _flat(Color(0.12, 0.16, 0.2), 0.05), n)
		visor.rotation.x = deg_to_rad(-12)
	return n


## MakeHuman skin materials import as alpha-blended, which makes faces render
## see-through. Skin and clothes become opaque; hair, brows and lashes use
## alpha scissor so strands stay crisp.
func _fix_character_materials(root: Node, cloth_tint := 1.0, tints := {}) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in range(mesh.get_surface_count()):
			var m := mesh.surface_get_material(i) as BaseMaterial3D
			if m == null:
				continue
			var lname := (m.resource_name + " " + mi.name).to_lower()
			for key: String in tints:
				if key in lname:
					m.albedo_color = tints[key]
			if ("eye" in lname or "high-poly" in lname or "cornea" in lname) and not "brow" in lname and not "lash" in lname:
				continue  # eyes keep their layered cornea transparency
			if "hair" in lname or "brow" in lname or "lash" in lname:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				m.alpha_scissor_threshold = 0.4
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			else:
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				# Clothes are thin shells: draw both sides so skin never shows through.
				var is_skin := "skin" in lname or "body" in lname
				m.cull_mode = BaseMaterial3D.CULL_BACK if is_skin else BaseMaterial3D.CULL_DISABLED
				if cloth_tint < 1.0 and not "skin" in lname and not "body" in lname:
					m.albedo_color = Color(cloth_tint, cloth_tint * 1.05, cloth_tint * 1.15)


func _build_regime_props() -> void:
	var g := Node3D.new()
	add_child(g)
	regime_nodes.append(g)
	# Checkpoint across the road
	for i in range(4):
		_model("concrete_road_barrier", Vector3(-3.0 + i * 1.6, 0.0, -8.0), 90 + rng.randf_range(-6, 6), 1.0, g)
	_model("covered_car", Vector3(2.2, 0.0, -13.0), 15, 1.0, g)
	# Riot police
	for p in [Vector3(-1.0, 0, -6.8), Vector3(0.6, 0, -6.6), Vector3(2.4, 0, -7.0), Vector3(3.6, 0, -9.5)]:
		_person("riot_police", p, rng.randf_range(-15, 15), g, true)
	# A lone civilian hurrying past
	_person("civilian_woman", Vector3(-5.2, 0.2, -2.0), 160, g)
	# Regime poster (propaganda layer)
	var poster := _box(Vector3(0.05, 3.2, 2.4), Vector3(6.95, 6.0, -1.5), _flat(Color(0.62, 0.11, 0.09), 0.8), g)
	_box(Vector3(0.06, 1.3, 1.0), Vector3(6.92, 6.4, -1.5), _flat(Color(0.05, 0.04, 0.04), 0.9), g)
	var txt := Label3D.new()
	txt.text = "CONTINUITY\nIS SAFETY"
	txt.font_size = 64
	txt.pixel_size = 0.006
	txt.modulate = Color(0.93, 0.9, 0.84)
	txt.outline_size = 0
	txt.position = Vector3(6.9, 5.1, -1.5)
	txt.rotation_degrees = Vector3(0, -90, 0)
	g.add_child(txt)
	# Searchlight from a drone overhead
	searchlight = SpotLight3D.new()
	searchlight.position = Vector3(-1.5, 16, -6)
	searchlight.rotation_degrees = Vector3(-78, 0, 0)
	searchlight.spot_angle = 14
	searchlight.spot_range = 30
	searchlight.light_energy = 14
	searchlight.light_color = Color(0.85, 0.92, 1.0)
	searchlight.shadow_enabled = true
	g.add_child(searchlight)
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.15
	cyl.bottom_radius = 3.4
	cyl.height = 15.5
	beam.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.albedo_color = Color(0.7, 0.8, 1.0, 0.045)
	beam.material_override = bm
	beam.position = Vector3(-1.5, 8.2, -4.4)
	beam.rotation_degrees = Vector3(-12, 0, 0)
	g.add_child(beam)
	_box(Vector3(0.9, 0.15, 0.9), Vector3(-1.5, 16.1, -6), _flat(Color(0.05, 0.05, 0.06), 0.4), g)


func _build_liberated_props() -> void:
	var g := Node3D.new()
	add_child(g)
	liberated_nodes.append(g)
	# Market stalls where the checkpoint was
	var cloth := [Color(0.55, 0.16, 0.12), Color(0.16, 0.4, 0.38), Color(0.7, 0.5, 0.18), Color(0.42, 0.2, 0.3)]
	for i in range(4):
		var p := Vector3(-2.6 + i * 1.8, 0, -8.5 - (i % 2) * 2.5)
		_box(Vector3(1.4, 0.9, 0.8), p + Vector3(0, 0.45, 0), _flat(Color(0.35, 0.26, 0.18), 0.9), g)
		var awning := _box(Vector3(1.6, 0.05, 1.1), p + Vector3(0, 2.1, 0.1), _flat(cloth[i], 0.9), g)
		awning.rotation_degrees.x = 10
		for leg in [-0.7, 0.7]:
			_box(Vector3(0.05, 2.1, 0.05), p + Vector3(leg, 1.05, -0.35), _flat(Color(0.2, 0.18, 0.15)), g)
		_model("cardboard_box_01", p + Vector3(0.4, 0.9, 0), rng.randf_range(0, 90), 1.0, g)
	# Barrel fires: people gathering, warm light
	for p in [Vector3(-3.2, 0, -3.0), Vector3(3.0, 0, -15.0)]:
		_model("barrel_03", p, 0, 1.0, g)
		var fire := OmniLight3D.new()
		fire.position = p + Vector3(0, 1.3, 0)
		fire.light_color = Color(1.0, 0.55, 0.2)
		fire.light_energy = 3.0
		fire.omni_range = 7.0
		g.add_child(fire)
		_box(Vector3(0.45, 0.25, 0.45), p + Vector3(0, 1.0, 0), _flat(Color(1, 0.5, 0.1), 0.5, Color(1, 0.45, 0.1), 8.0), g)
	# Crowd
	var coats := [Color(0.3, 0.12, 0.1), Color(0.14, 0.24, 0.3), Color(0.35, 0.3, 0.2), Color(0.2, 0.2, 0.22), Color(0.4, 0.22, 0.12), Color(0.18, 0.28, 0.18)]
	for i in range(18):
		var p := Vector3(rng.randf_range(-3.6, 3.6), 0, rng.randf_range(-20, 0))
		_person("civilian_man" if i % 2 == 0 else "civilian_woman", p, rng.randf_range(0, 360), g)
	# String lights across the street
	var bulb := _flat(Color.WHITE, 0.3, Color(1.0, 0.75, 0.4), 5.0)
	for row in range(3):
		var z := -2.0 - row * 7.0
		for j in range(18):
			var t := j / 17.0
			var x := lerpf(-6.5, 6.5, t)
			var y := 5.2 - sin(t * PI) * 1.0
			_box(Vector3(0.12, 0.12, 0.12), Vector3(x, y, z), bulb, g)
		var sl := OmniLight3D.new()
		sl.position = Vector3(0, 4.4, z)
		sl.light_color = Color(1.0, 0.72, 0.42)
		sl.light_energy = 1.6
		sl.omni_range = 9
		g.add_child(sl)
	# Mural over the old poster (propaganda layer, liberated)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.35, 0.15))
	grad.set_color(1, Color(0.95, 0.75, 0.3))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 1.0)
	gt.fill_to = Vector2(0.5, 0.0)
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = gt
	mm.roughness = 0.9
	_box(Vector3(0.05, 4.0, 3.4), Vector3(6.95, 6.0, -1.5), mm, g)
	var txt := Label3D.new()
	txt.text = "WE REMEMBER\nANA RUIZ"
	txt.font_size = 64
	txt.pixel_size = 0.006
	txt.modulate = Color(0.1, 0.08, 0.07)
	txt.position = Vector3(6.9, 5.2, -1.5)
	txt.rotation_degrees = Vector3(0, -90, 0)
	g.add_child(txt)


func _build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 5000
	rain.lifetime = 1.0
	rain.preprocess = 1.0
	rain.position = Vector3(0, 14, -12)
	rain.visibility_aabb = AABB(Vector3(-20, -20, -30), Vector3(40, 30, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 1, 26)
	pm.direction = Vector3(0.15, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -9.8, 0)
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.008, 0.32)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.75, 0.8, 0.88, 0.16)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rm.billboard_keep_scale = true
	q.material = rm
	rain.draw_pass_1 = q
	add_child(rain)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.position = Vector3(5.2, 7.5, 11.0)
	cam.fov = 52
	add_child(cam)
	cam.look_at(Vector3(-0.8, 1.2, -9.0))
	cam.current = true


func _build_grade_and_ui() -> void:
	var post := CanvasLayer.new()
	post.layer = 1
	add_child(post)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_mat = ShaderMaterial.new()
	grade_mat.shader = load("res://shaders/frontline.gdshader")
	rect.material = grade_mat
	post.add_child(rect)

	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -96
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_bottom = -20
	ui.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 22)
	box.add_child(state_label)
	slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(0, 44)
	slider.value_changed.connect(func(v: float) -> void: _apply(v / 100.0))
	box.add_child(slider)
	if "--capture" in OS.get_cmdline_user_args():
		panel.visible = false


# ---------- liberation state ----------

func _apply(t: float) -> void:
	liberation = t
	var dawn := t >= 0.5
	env.sky.sky_material = sky_dawn if dawn else sky_night
	env.background_energy_multiplier = lerp(0.25, 0.55, t)
	env.ambient_light_energy = lerp(0.35, 0.8, t)
	env.fog_light_color = Color(0.3, 0.34, 0.4).lerp(Color(0.6, 0.5, 0.42), t)
	env.fog_density = lerp(0.024, 0.01, t)
	moon.light_color = Color(0.6, 0.7, 0.9).lerp(Color(1.0, 0.82, 0.65), t)
	moon.light_energy = lerp(0.25, 0.9, t)
	road_mat.roughness = lerp(0.12, 0.55, t)
	var lamp_c := Color(0.85, 0.9, 1.0).lerp(Color(1.0, 0.72, 0.42), t)
	for l in lamps:
		l.light_color = lamp_c
	for b in lamp_bulbs:
		b.emission = lamp_c
	var lit_fraction := 0.1 + 0.38 * t
	for w in windows:
		var mi: MeshInstance3D = w[0]
		var th: float = w[1]
		if th < lit_fraction:
			mi.material_override = mat_window_warm if th < 0.6 * t + 0.03 else mat_window_cold
		else:
			mi.material_override = mat_window_off
	for n in regime_nodes:
		n.visible = t < 0.5
	for n in liberated_nodes:
		n.visible = t >= 0.5
	rain.emitting = t < 0.75
	rain.amount_ratio = clamp(1.0 - t * 1.2, 0.0, 1.0)
	grade_mat.set_shader_parameter("liberation", t)
	grade_mat.set_shader_parameter("grain_seed", rng.randf() * 100.0)
	if state_label:
		state_label.text = "District 7, the Rail Yards  ·  %s" % _state_name(t)
	if slider and not is_equal_approx(slider.value, t * 100.0):
		slider.set_value_no_signal(t * 100.0)


func _state_name(t: float) -> String:
	if t < 0.2:
		return "Regime-held"
	if t < 0.45:
		return "Wary"
	if t < 0.7:
		return "Sympathetic"
	if t < 0.95:
		return "Ready to turn"
	return "Liberated"


# ---------- screenshots ----------

func _capture() -> void:
	for pair in [[0.0, "regime"], [0.55, "contested"], [1.0, "liberated"]]:
		_apply(pair[0])
		for i in range(40):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://docs/renders/frontline_%s.png" % pair[1])
		print("saved ", pair[1])
	# Close-ups to judge the characters
	var face_dir := duff.global_transform.basis.z.normalized()
	for shot in [[1.0, "closeup_duff", duff.global_position + face_dir * 1.3 + Vector3(0.3, 1.62, 0), duff.global_position + Vector3(0, 1.58, 0)],
			[1.0, "duff_body", duff.global_position + face_dir * 3.2 + Vector3(0.0, 1.1, 0), duff.global_position + Vector3(0, 0.95, 0)],
			[1.0, "duff_side", duff.global_position + face_dir.rotated(Vector3.UP, 1.2) * 1.2 + Vector3(0, 1.62, 0), duff.global_position + Vector3(0, 1.58, 0)],
			[0.0, "closeup_police", Vector3(1.9, 1.65, -4.6), Vector3(0.5, 1.45, -6.7)]]:
		_apply(shot[0])
		cam.fov = 35
		cam.position = shot[2]
		cam.look_at(shot[3])
		for i in range(30):
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://docs/renders/frontline_%s.png" % shot[1])
		print("saved ", shot[1])
	get_tree().quit()
