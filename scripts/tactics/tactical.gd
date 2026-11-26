extends "res://scripts/render_test.gd"
## Tactical map: the Rail Yards street with a grid on it, driven by
## scripts/tactics/battle.gd. Two modes:
## - Skirmish (M4, the title's Skirmish button): kill or rout the guards.
## - Signal Box mission (M5): launched by game.gd with Engine meta "mission".
##   Upload the footage at the box, get out the south edge, and the result goes
##   back to the run.
## Tap a squad member (or their button), tap a blue tile to move, tap a guard to
## aim. Actions sit in the column on the right.
## `res://scenes/tactical.tscn -- --capture-tactical` saves skirmish renders,
## `-- --capture-mission` saves mission renders, both to docs/renders/.

const Battle = preload("res://scripts/tactics/battle.gd")
const SettingsSheet = preload("res://scripts/ui/settings_sheet.gd")
const FightSave = preload("res://scripts/fight_save.gd")
const Sfx = preload("res://scripts/audio.gd")
const Feel = preload("res://scripts/tactics/feel.gd")
const PlayStats = preload("res://scripts/stats.gd")

const C_FG := Color("e7e3da")
const C_MUTED := Color("9b988f")
const C_ACCENT := Color("e2713b")
const C_PANEL := Color("171a1f")
const C_RED := Color("e05a46")
const C_GOOD := Color("7fbf7a")
const C_MOVE := Color(0.3, 0.62, 1.0, 0.32)
const C_SNEAK := Color(0.62, 0.42, 1.0, 0.36)
const C_EXIT := Color(0.45, 0.85, 0.45, 0.30)
# J1 readability. Team colours live in the 2D overlay (above the grade, which
# drains 3D colour to 7%): red rings for the movement, cold blue for the regime.
const C_RING_US := Color(0.93, 0.33, 0.24)
const C_RING_REGIME := Color(0.42, 0.68, 1.0)
const C_RING_WAVER := Color(1.0, 0.85, 0.4)
const C_THREAT_MOVE := Color(0.88, 0.35, 0.27, 0.30)  # map red: danger, not accent orange
const C_THREAT_SHOOT := Color(0.88, 0.35, 0.27, 0.08)
const C_SMOKE := Color(0.82, 0.83, 0.85)
const C_DARK := Color(0.0, 0.0, 0.0, 0.45)  # near-black: blue is taken by move range and the regime
const C_TOOL := Color(0.92, 0.92, 0.88)  # tool targeting: neutral, not team or danger
const TAG_SIZE := 19
const GRADE_GRAIN := 0.2  # the tactical map keeps the Frontline grade, lighter
const GRADE_CRUSH := 0.45
const GRADE_SAT := 0.6       # colour kept on the tactical map (street grade is 0.07)
const FRAME_GUARD_RANGE := 4  # guards this close to the selected unit stay in frame
const FRAME_ALLY_RANGE := 3   # squad mates this close to it too (was: whole squad + guards within 6)

const TOP_H := 56
const BOTTOM_H := 148
const COLUMN_W := 210

var battle
var seed_value := 1
var mission_meta := {}  # set when the run launched the Signal Box
var unit_nodes := {}    # Battle.Unit -> Node3D
var unit_tags := {}     # Battle.Unit -> [text, colour], drawn in 2D (or absent = hidden)
var threat := {}        # {"move", "shoot"} for the tapped guard, or empty
## Diversion tools (J1.5): two steps, like every action that costs noise.
## Press a tool to preview it (area, affected guards, noise, chance), then
## Confirm. Smoke and Flash also need a target tile tapped in between.
var tool_mode := ""     # "", "smoke", "flash", "lights", "radio"
var tool_at := Vector2i(-1, -1)
var lamp_energy := {}   # OmniLight3D -> lit energy, for lights out
## Grid highlights are drawn in 2D above the colour grade, so the grade
## can't wash out the move range and the target.
var overlay: Node2D
var top_overlay: Node2D  # tags and odds, drawn above the cutout characters
var rig_root: Node2D     # cutout characters: above rings and grid, below tags
var rigs := {}           # unit -> CutoutRig (HD-2D cutouts; Duff's call Nov 11)
var rig_clips := {}      # unit -> Node2D that clips its rig behind walls
var rig_seen := {}       # unit -> [last 3D position, last hp]
var rig_ghosts := {}     # unit -> silhouette rig shown where walls hide the real one
var ghost_clips := {}    # unit -> Node2D that limits the silhouette to the walls in front
var tile_fill := {}     # Vector2i -> Color for this frame
var selected = null
var aimed = null
var sneaking := false
var busy := false
var feel: Feel   # shake, hit-stop, buzz, flashes (scripts/tactics/feel.gd)
var alarm_heard := true   # the alarm sounds once, when it trips (a resumed alarmed fight stays quiet)
var world_root: Node3D
## Camera follow (J1 review): the fight drifts north and ended up tiny at the
## top of the screen. The camera keeps its angle but slides to the squad and
## the guards near them, and moves in when they're bunched.
const CAM_HOME := Vector3(0.6, 0.0, 0.2)
var cam_offset := Vector3.ZERO
var cam_goal := Vector3.INF
var cam_tween: Tween

var top_label: Label
var meter_label: Label
var log_label: Label
var squad_row: HBoxContainer
var column: VBoxContainer
var end_btn: Button
var result_panel: PanelContainer
var result_label: Label
var result_buttons: VBoxContainer
var goal_btn: Button
var hud_layer: CanvasLayer
var brief_panel: PanelContainer   # 8.5 pass: what the mission wants, before turn 1 and on "Goal"
var regime_panel: PanelContainer  # 8.5 pass: what the regime just did, one line per event
var tip_label: Label              # 8.5 pass: one-time tips (?, Wavering, ALARM, nerve)


func _ready() -> void:
	rng.seed = 7
	_build_environment()
	_build_street()
	_build_buildings()
	_build_lamps()
	_build_rain()
	_build_tactical_camera()
	_build_grade_only()
	_build_hud()
	feel = Feel.new()
	add_child(feel)
	feel.setup(cam, self)
	_apply(0.0)
	env.fog_density = 0.012  # keep the far end of the grid readable
	grade_mat.set_shader_parameter("grain_mul", GRADE_GRAIN)
	grade_mat.set_shader_parameter("crush_mul", GRADE_CRUSH)
	grade_mat.set_shader_parameter("regime_sat", GRADE_SAT)
	# Key light on the cast only (light layer UNIT_LAYER): dark clothes vanished into the night
	# yard once the pale mannequins became real models. Lights bodies, never the street.
	var key := DirectionalLight3D.new()
	key.light_cull_mask = UNIT_LAYER
	key.light_energy = UNIT_KEY
	# Warm and from the side (Nov 25): a cold light from the camera flattened the cast into pale
	# grey shapes; side light gives form, warmth keeps skin and the movement red alive.
	key.light_color = Color(1.0, 0.88, 0.74)
	key.rotation = cam.rotation + Vector3(0, deg_to_rad(UNIT_KEY_YAW), 0)
	add_child(key)
	apply_graphics()
	var st := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
	if st:
		st.changed.connect(func(k: String):
			if k == "low_graphics":
				apply_graphics())
	var args := OS.get_cmdline_user_args()
	if ("--capture-mission" in args or "--autoplay" in args or "--capture-tools" in args or "--capture-rig" in args or "--capture-white-flag" in args or "--capture-8-5" in args or "--capture-fox" in args) and not Engine.has_meta("mission"):
		Engine.set_meta("mission", {"params": {"guards": 5, "legitimacy": 1, "seed": 4, "squad": [
			{"name": "You", "op": 0, "is_you": true}, {"name": "Mara", "op": 1, "is_you": false},
			{"name": "Kesh", "op": 2, "is_you": false}, {"name": "Teodor", "op": 3, "is_you": false}]}})
	if Engine.has_meta("mission"):
		mission_meta = Engine.get_meta("mission")
	_new_battle(seed_value)
	alarm_heard = battle.alarm
	Sfx.music("music_fight")
	Sfx.bed("rain_loop")
	_save_fight()  # first checkpoint: leaving now resumes here, not a replayed week
	var plain := true
	for a in args:
		if a.begins_with("--capture") or a == "--autoplay" or a == "--shots":
			plain = false
	if plain and battle.mission and battle.turn == 1 and battle.upload == 0:
		_show_brief.call_deferred()
	# The web canvas can settle its size after the first frame: frame the squad again once it has
	# (first-timer: units started under the bottom bar).
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(self) and battle != null:
			cam_goal = Vector3.INF
			_frame_camera())
	if "--capture-tactical" in args:
		_capture_tactical()
	elif "--capture-mission" in args:
		_capture_mission()
	elif "--capture-tools" in args:
		_capture_tools()
	elif "--capture-white-flag" in args:
		_capture_white_flag()
	elif "--capture-8-5" in args:
		_capture_8_5()
	elif "--capture-fox" in args:
		_capture_fox()
	elif "--capture-rig" in args:
		_capture_rig(_arg_after(args, "--out", "/tmp/rig"))
	elif "--capture-sprite-sizes" in args:
		_capture_sprite_sizes()
	elif "--autoplay" in args:
		_autoplay("--loud" in args, _arg_after(args, "--out", "/tmp/autoplay"))


# ---------- coordinates ----------

static func to_world(p: Vector2i) -> Vector3:
	return Vector3(p.x - 6.5, 0.0, p.y - 9.0)


static func to_tile(w: Vector3) -> Vector2i:
	return Vector2i(floori(w.x + 7.0), floori(w.z + 9.5))


func _ground(p: Vector2i) -> float:
	return 0.9 if battle.tile(p) == Battle.HIGH else 0.0


# ---------- build ----------

## Framed so the whole 14x14 grid sits between the top bar, the bottom panel
## and the action column (M4's camera put the squad's start row under the HUD).
func _build_tactical_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 55  # J1: a touch wider so the squad's start row clears the bottom panel
	add_child(cam)
	cam.position = Vector3(3.6, 13.6, 9.9)
	cam.look_at(CAM_HOME)
	cam_offset = cam.position - CAM_HOME
	cam.current = true


func _build_grade_only() -> void:
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


func _new_battle(s: int) -> void:
	seed_value = s
	if world_root:
		world_root.queue_free()
	world_root = Node3D.new()
	add_child(world_root)
	if mission_meta.is_empty():
		battle = Battle.create_skirmish(s)
		PlayStats.log_event("fight_start", {"kind": "skirmish"})
	elif mission_meta.has("resume"):
		# Continue from the title: the fight as it stood at the last save (QoL step 4).
		battle = Battle.from_dict(mission_meta.resume)
		mission_meta.erase("resume")
		resumed_over = battle.is_over()  # its fight_end is logged already; no fight_start for a resume either
	else:
		battle = Battle.create_mission(mission_meta.params)
		# Mascot cameo: rare (Battle.FOX_CHANCE), but a player's first ever mission fight always has the fox.
		# Marked in coach.cfg as soon as it is forced, so it is forced once, found or not. Renders/autoplay skip it.
		if battle.fox.x < 0 and not _fox_forced_before() and not _scripted_run():
			battle.place_fox(FOX_FIRST_WALL)
			var cfg := ConfigFile.new()
			cfg.load(COACH_FILE)
			cfg.set_value("tips", "fox_forced", true)
			cfg.save(COACH_FILE)
		PlayStats.log_event("fight_start", {"kind": "run" if mission_meta.has("state") else "fight now",
			"guards": int(mission_meta.params.get("guards", 0)), "squad": mission_meta.params.get("squad", []).size()})
	unit_nodes.clear()
	unit_tags.clear()
	for c in rig_clips.values():
		c.queue_free()
	for g in ghost_clips.values():
		g.queue_free()
	ghost_clips.clear()
	rigs.clear()
	rig_ghosts.clear()
	rig_clips.clear()
	rig_seen.clear()
	cam_goal = Vector3.INF
	# A resumed fight can already be over (saved on the result screen): nobody to select,
	# and _refresh then puts the result panel up so "Back to the week" still works.
	var ours: Array = battle.alive_units(Battle.US)
	selected = ours[0] if not ours.is_empty() else null
	aimed = null
	sneaking = false
	tool_mode = ""
	busy = false
	_build_cover()
	result_panel.visible = false
	_refresh()


func _build_cover() -> void:
	var steel := [_flat(Color(0.16, 0.24, 0.24), 0.55), _flat(Color(0.33, 0.15, 0.1), 0.55), _flat(Color(0.2, 0.21, 0.24), 0.5)]
	var rib := _flat(Color(0.08, 0.08, 0.09), 0.6)
	var deck := _flat(Color(0.2, 0.2, 0.21), 0.45)
	var rail := _flat(Color(0.55, 0.42, 0.12), 0.5)
	var n := 0
	for y in range(Battle.H):
		for x in range(Battle.W):
			var p := Vector2i(x, y)
			var w := to_world(p)
			match battle.tile(p):
				Battle.FULL:
					# Shipping containers: colour by 2x2 block so neighbours read as one box.
					var m: Material = steel[(x / 2 + y / 2) % steel.size()]
					_box(Vector3(1.0, 2.5, 1.0), w + Vector3(0, 1.25, 0), m, world_root)
					_box(Vector3(1.02, 0.06, 1.02), w + Vector3(0, 2.5, 0), rib, world_root)
				Battle.HALF:
					n += 1
					if n % 2 == 0:
						_model("concrete_road_barrier", w, 90 if (x + y) % 2 == 0 else 0, 1.0, world_root)
					else:
						_model("barrel_03", w + Vector3(-0.2, 0, 0.1), 0, 1.0, world_root)
						_model("barrel_03", w + Vector3(0.22, 0, -0.15), 40, 1.0, world_root)
				Battle.HIGH:
					_box(Vector3(1.0, 0.12, 1.0), w + Vector3(0, 0.84, 0), deck, world_root)
					for c in [Vector3(-0.45, 0.42, -0.45), Vector3(0.45, 0.42, 0.45)]:
						_box(Vector3(0.08, 0.84, 0.08), w + c, rib, world_root)
					_box(Vector3(1.0, 0.05, 0.05), w + Vector3(0, 1.85, -0.48), rail, world_root)
				Battle.BOX:
					_build_signal_box(w)
				Battle.JUNCTION:
					_build_junction(w)
	_build_fox()


## The studio fox (docs/MASCOT.md), sprayed on the south face of a 2-wide container block.
## The texture is the paint cut out of the wall (alpha), so the white stencil shows on dark steel too.
const FOX_FIRST_WALL := 1    # Battle.FOX_WALLS index forced on a player's first fight: mid-yard, in view
const FOX_SIZE := Vector2(1.45, 2.15)

func _fox_forced_before() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(COACH_FILE)
	return cfg.get_value("tips", "fox_forced", false) or cfg.get_value("tips", "fox", false)


## Captures and autoplay keep the dice-rolled fox only, so older renders stay reproducible.
func _scripted_run() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture") or a == "--autoplay" or a == "--shots":
			return true
	return false


func _build_fox() -> void:
	if battle == null or battle.fox.x < 0:
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/props/fox_graffiti.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.8
	var q := MeshInstance3D.new()
	var pm := QuadMesh.new()
	pm.size = FOX_SIZE
	q.mesh = pm
	q.material_override = m
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.position = to_world(battle.fox) + Vector3(0.5, 1.2, 0.515)
	q.name = "FoxGraffiti"
	world_root.add_child(q)


## The signal box: a grey relay cabinet with a lit screen facing the yard and
## a cable mast. The light is the only warm thing in the depot.
func _build_signal_box(w: Vector3) -> void:
	_box(Vector3(0.9, 1.9, 0.8), w + Vector3(0, 0.95, 0), _flat(Color(0.3, 0.31, 0.3), 0.5), world_root)
	_box(Vector3(0.95, 0.08, 0.85), w + Vector3(0, 1.94, 0), _flat(Color(0.1, 0.1, 0.11), 0.6), world_root)
	_box(Vector3(0.62, 0.42, 0.03), w + Vector3(0, 1.3, 0.42), _flat(Color(0.1, 0.12, 0.1), 0.3, Color(0.95, 0.6, 0.25), 2.2), world_root)
	_box(Vector3(0.06, 1.6, 0.06), w + Vector3(0.38, 2.7, -0.3), _flat(Color(0.08, 0.08, 0.09), 0.6), world_root)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.62, 0.3)
	glow.light_energy = 1.6
	glow.omni_range = 3.2
	glow.position = w + Vector3(0, 1.3, 0.9)
	world_root.add_child(glow)


## The floodlight's junction box: a grey cabinet on the yard's west wall with
## a small status lamp that goes out with the lights.
var junction_lamp: StandardMaterial3D

func _build_junction(w: Vector3) -> void:
	_box(Vector3(0.45, 1.3, 0.7), w + Vector3(-0.25, 0.9, 0), _flat(Color(0.27, 0.28, 0.27), 0.6), world_root)
	_box(Vector3(0.06, 1.8, 0.06), w + Vector3(-0.42, 1.9, 0.25), _flat(Color(0.08, 0.08, 0.09), 0.6), world_root)
	junction_lamp = _flat(Color(0.2, 0.2, 0.2), 0.4, Color(0.4, 1.0, 0.45), 2.5)
	_box(Vector3(0.04, 0.1, 0.1), w + Vector3(-0.01, 1.35, 0.2), junction_lamp, world_root)


func _spawn_unit(u) -> void:
	var p: Vector3 = to_world(u.pos) + Vector3(0, _ground(u.pos), 0)
	unit_nodes[u] = _meshy_person(_cast_model(u), p, 180 if u.side == Battle.US else 0, world_root)
	# No fresnel rim on the Meshy cast: on bodies this small it washed them out to pale ghosts;
	# the unit-only key light (UNIT_KEY) does the separating now.


## Which Meshy model plays a unit (Nov 25: real 3D cast replaces mannequins + cutouts).
## Recruits without their own model borrow a squad body until they get one.
func _cast_model(u) -> String:
	if u.side == Battle.REGIME:
		return "guard"
	match u.name:
		"You":
			return "duff"
		"Mara":
			return "mara"
		"Kesh":
			return "kesh"
		"Teodor":
			return "teodor"
	return "kesh" if u.name.length() % 2 == 0 else "teodor"


## A cool fresnel rim on every surface of a unit (units only, not the street),
## so a body separates from crates and barrels in the dark. Added as a
## next_pass on a per-unit copy of each material, so shared assets stay clean.
var _rim_mat: ShaderMaterial

func _add_rim(n: Node3D) -> void:
	if _rim_mat == null:
		_rim_mat = ShaderMaterial.new()
		_rim_mat.shader = load("res://shaders/unit_rim.gdshader")
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var m: Material = mi.get_active_material(i)
			if m == null or m.next_pass != null:
				continue
			var c: Material = m.duplicate()
			c.next_pass = _rim_mat
			mi.set_surface_override_material(i, c)


func _build_hud() -> void:
	var grid_layer := CanvasLayer.new()
	grid_layer.layer = 2
	add_child(grid_layer)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	grid_layer.add_child(overlay)
	rig_root = Node2D.new()
	grid_layer.add_child(rig_root)
	top_overlay = Node2D.new()
	top_overlay.draw.connect(_draw_top)
	grid_layer.add_child(top_overlay)
	var ui := CanvasLayer.new()
	ui.layer = 3
	add_child(ui)
	hud_layer = ui

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, TOP_H)
	top.add_theme_stylebox_override("panel", _panel_style())
	ui.add_child(top)
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 24)
	top.add_child(tb)
	top_label = _hud_label("", 24, C_FG)
	top_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tb.add_child(top_label)
	meter_label = _hud_label("", 22, C_FG)
	meter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	tb.add_child(meter_label)
	goal_btn = _hud_button("Goal", _show_brief)
	goal_btn.custom_minimum_size = Vector2(96, 40)
	goal_btn.add_theme_font_size_override("font_size", _fs(20))
	tb.add_child(goal_btn)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOTTOM_H
	bottom.add_theme_stylebox_override("panel", _panel_style())
	ui.add_child(bottom)
	var col := VBoxContainer.new()
	bottom.add_child(col)
	log_label = _hud_label("", 18, C_MUTED)
	log_label.custom_minimum_size = Vector2(0, 50)
	col.add_child(log_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	squad_row = HBoxContainer.new()
	squad_row.add_theme_constant_override("separation", 8)
	squad_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(squad_row)
	end_btn = _hud_button("End turn", _on_end_turn)
	end_btn.custom_minimum_size = Vector2(COLUMN_W - 20, 56)
	row.add_child(end_btn)

	# Actions for the selected unit, stacked on the right above the bottom panel.
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.anchor_left = 1.0
	column.anchor_right = 1.0
	column.anchor_bottom = 1.0
	column.offset_left = -COLUMN_W
	column.offset_right = -10
	column.offset_top = TOP_H + 10
	column.offset_bottom = -BOTTOM_H - 10
	column.alignment = BoxContainer.ALIGNMENT_END
	ui.add_child(column)

	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	result_panel.add_theme_stylebox_override("panel", _panel_style())
	ui.add_child(result_panel)
	_build_coach(ui)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 14)
	result_panel.add_child(rc)
	result_label = _hud_label("", 28, C_FG)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.custom_minimum_size = Vector2(560, 0)
	rc.add_child(result_label)
	result_buttons = VBoxContainer.new()
	result_buttons.add_theme_constant_override("separation", 10)
	rc.add_child(result_buttons)
	result_panel.visible = false


func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(C_PANEL, 0.88)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _hud_label(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", _fs(size))
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _hud_button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, 64)
	b.add_theme_font_size_override("font_size", _fs(24))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # phone text size: long labels wrap, never clip
	b.pressed.connect(cb)
	return b


# ---------- state -> screen ----------

func _refresh() -> void:
	if battle and battle.alarm and not alarm_heard:
		alarm_heard = true
		Sfx.fx("alarm")
		feel.alarm_pulse()
		feel.shake(0.45)
		feel.buzz(180)
	var over: bool = battle.is_over()
	var who := "Your move" if battle.side == Battle.US else "Regime move"
	if battle.mission:
		top_label.text = "Turn %d  ·  %s  ·  The Signal Box" % [battle.turn, who]
		var up := "Upload %d/%d" % [battle.upload, Battle.UPLOAD_TURNS] if battle.upload < Battle.UPLOAD_TURNS else "AIRED: get out south"
		var alarm := ""
		if battle.alarm:
			alarm = "  ·  ALARM" + (": %d more in %d" % [Battle.REINFORCEMENTS, battle.reinforce_in] if battle.reinforce_in > 0 else "")
		meter_label.text = "Noise %d/%d  ·  %s%s" % [battle.noise, Battle.NOISE_MAX, up, alarm]
		meter_label.add_theme_color_override("font_color", C_RED if battle.alarm else (C_GOOD if battle.upload >= Battle.UPLOAD_TURNS else C_FG))
	else:
		top_label.text = "Turn %d  ·  %s  ·  Guards left: %d" % [battle.turn, who, battle.alive_units(Battle.REGIME).size()]
		meter_label.text = ""
	log_label.text = "\n".join(battle.log.slice(maxi(0, battle.log.size() - 2)))
	goal_btn.visible = battle.mission
	_tips()
	if selected != null and not selected.alive():
		selected = null
	if aimed != null and (not aimed.alive() or aimed.side == Battle.US):
		aimed = null
	_refresh_squad()
	_frame_camera()
	_refresh_units()
	_refresh_tiles()
	_refresh_column()
	end_btn.disabled = busy or over
	if over and not result_panel.visible:
		_show_result()
	if over and coach != null and is_instance_valid(coach):
		coach.visible = false  # no "Tap a blue tile" over a result (e.g. a resumed, finished fight)


func _refresh_squad() -> void:
	for c in squad_row.get_children():
		c.queue_free()
	var ours: Array = battle.units.filter(func(u): return u.side == Battle.US)
	var w := 188 if ours.size() <= 4 else 150
	for u in ours:
		var state := "%s  %s" % [_hearts(u.hp), _pips(u.ap, "●")]
		if u.escaped:
			state = "out"
		elif u.dead:
			state = "dead"
		elif u.downed():
			state = "stable" if u.stabilized else "bleeding %d" % u.bleed
		var b := _hud_button("%s  %s" % [u.name, state], func(): _select(u))
		b.custom_minimum_size = Vector2(w, 56)
		b.add_theme_font_size_override("font_size", 20 if ours.size() <= 4 else 17)
		b.disabled = not u.alive() or busy
		if u == selected:
			b.add_theme_color_override("font_color", C_ACCENT)
		elif u.downed() and not u.stabilized:
			b.add_theme_color_override("font_color_disabled", C_RED)
		squad_row.add_child(b)


func _refresh_units() -> void:
	for u in battle.units:
		if not unit_nodes.has(u):
			_spawn_unit(u)  # reinforcements
		var n: Node3D = unit_nodes[u]
		unit_tags.erase(u)
		if u.escaped:
			n.visible = false
			continue
		if not u.alive():
			if not n.has_meta("anim"):
				n.rotation.x = deg_to_rad(-88)  # downed (the Meshy cast plays its death clip instead)
			if u.side == Battle.US and u.downed():
				unit_tags[u] = ["%s %s" % [u.name, "stable" if u.stabilized else "bleeding"], C_FG if u.stabilized else C_RED, "%s +" % u.name.left(1)]
			elif u.surrendered:
				unit_tags[u] = ["⚐ hands up", C_FG, "⚐"]  # White Flag: a prisoner, not a body
			continue
		var text := ""
		var col := C_FG
		if u.side == Battle.US:
			text = "%s %s" % [u.name, _hearts(u.hp)]
			col = C_ACCENT if u == selected else C_FG
			if u.hidden:
				text += " (hidden)"
			if u.overwatch:
				text += " ◎"
			if u.flash > 0:
				text += " ✦"
		else:
			text = _hearts(u.hp)
			if u.wavering:
				text = "Wavering " + text
			if battle.white_flag and battle.mission:
				text += " " + _nerve_pips(u)
			if u.nerve <= 0:
				text += " running"
			elif u.stun > 0:
				text += " stunned"
			elif u.busy > 0:
				text += " on a fake call"
			elif battle.stunned > 0:
				text += " watching"
			elif u.state == Battle.PATROL:
				text += " ?"
			col = C_RING_WAVER if u.wavering else C_RING_REGIME.lightened(0.35)
		unit_tags[u] = [text, col, _short_tag(u)]
		_face(u)


func _refresh_tiles() -> void:
	tile_fill.clear()
	var ours: bool = battle.side == Battle.US and not busy and not battle.is_over()
	if battle.mission and battle.upload >= Battle.UPLOAD_TURNS:
		for x in range(Battle.W):
			tile_fill[Vector2i(x, Battle.H - 1)] = C_EXIT
	threat = {}
	_apply_dark()
	if battle.mission and battle.dark > 0:
		for y in range(Battle.DARK_ROWS + 1):
			for x in range(Battle.W):
				tile_fill[Vector2i(x, y)] = C_DARK
	if tool_mode != "" and ours:
		_tool_tiles()
	elif aimed != null and ours:
		threat = battle.threat(aimed)
		for p in threat.shoot:
			tile_fill[p] = C_THREAT_SHOOT
		for p in threat.move:
			tile_fill[p] = C_THREAT_MOVE
	elif selected != null and ours:
		if sneaking:
			for p in battle.reachable(selected, 1):
				tile_fill[p] = C_SNEAK
		else:
			for p in battle.reachable(selected, selected.ap):
				tile_fill[p] = C_MOVE
	if selected != null and threat.is_empty():
		tile_fill[selected.pos] = Color(1.0, 0.75, 0.25, 0.5)
	if aimed != null:
		tile_fill[aimed.pos] = Color(1.0, 0.25, 0.15, 0.55)
	overlay.queue_redraw()


## Only actions that make sense right now; a phone has no room for greyed-out walls.
func _refresh_column() -> void:
	for c in column.get_children():
		c.queue_free()
	if busy or battle.is_over() or battle.side != Battle.US or selected == null:
		return
	var u = selected
	if battle.mission and tool_mode != "":
		_tool_column(u)
		return
	if battle.mission:
		if battle.smoke_left > 0 and u.ap >= 1:
			column.add_child(_hud_button("Smoke (%d)" % battle.smoke_left, func(): _start_tool("smoke")))
		if battle.can_lights_out(u):
			column.add_child(_hud_button("Lights out", func(): _start_tool("lights")))
		if battle.can_radio(u):
			column.add_child(_hud_button("Radio %d%%" % battle.radio_chance(), func(): _start_tool("radio")))
		if u.flash > 0 and u.ap >= 1:
			column.add_child(_hud_button("Flashbang (%d)" % u.flash, func(): _start_tool("flash")))
		if u.ap >= Battle.AP_PER_TURN:
			var sb := _hud_button("Sneak: on" if sneaking else "Sneak", _on_sneak_toggle)
			if sneaking:
				sb.add_theme_color_override("font_color", C_ACCENT)
			column.add_child(sb)
		if battle.can_upload(u):
			column.add_child(_hud_button("Upload %d/%d" % [battle.upload + 1, Battle.UPLOAD_TURNS], _on_upload))
		var hurt = battle.stabilize_target(u)
		if hurt != null:
			column.add_child(_hud_button("Stabilize %s" % hurt.name, _on_stabilize))
		if battle.can_leave(u):
			column.add_child(_hud_button("Leave", _on_leave))
		if battle.can_persuade(u, aimed):
			column.add_child(_hud_button("Persuade %d%%" % battle.persuade_chance(), _on_persuade))
		elif aimed != null and aimed.wavering and aimed.alive():
			# Talk-down is the point of a wavering guard: show it, and what it needs (8.5 pass).
			var pb := _hud_button("Persuade: %s within %d" % ["You" if not u.is_you else "get", Battle.PERSUADE_RANGE], _on_persuade)
			pb.disabled = true
			column.add_child(pb)
		if battle.can_subdue(u, aimed):
			column.add_child(_hud_button("Subdue", _on_subdue))
		if u.ap >= 1:
			column.add_child(_hud_button("Overwatch", _on_overwatch))
	var c := 0
	var label := "Shoot"
	var loud_warn := false
	if aimed != null:
		var pv: Dictionary = battle.shot_preview(u, aimed)
		c = pv.chance
		if c > 0:
			label = "Shoot %d%%\n%s" % [c, "downs him" if pv.result == "down" else "wounds him"]
			var breaks: int = battle.breaks_on_hit(aimed)
			if breaks > 0:
				label += " · he breaks" if pv.result != "down" else " · %d break%s" % [breaks, "" if breaks == 1 else "s"]
			if pv.noise > 0 and not battle.alarm:
				label += " · ALARM" if battle.trips_alarm(pv.noise) else " · +%d noise" % pv.noise
			var ours: int = battle.alive_units(Battle.US).size()
			var theirs: int = battle.alive_units(Battle.REGIME).size()
			if battle.goes_loud() and ours < theirs:
				label += "\nGOES LOUD · %d vs %d" % [ours, theirs]
				loud_warn = true
		else:
			label = "No line of sight"
	if u.ap < 1:
		label = "Shoot (no AP left)"
		loud_warn = false
	elif aimed == null:
		label = "Shoot: tap a guard"
	var shoot := _hud_button(label, _on_shoot)
	shoot.disabled = c <= 0 or u.ap < 1
	column.add_child(shoot)
	for b in column.get_children():
		b.custom_minimum_size = Vector2(COLUMN_W - 10, 64)
	if c > 0:
		shoot.add_theme_font_size_override("font_size", 18)
		shoot.custom_minimum_size = Vector2(COLUMN_W - 10, 96 if loud_warn else 70)
		if loud_warn:
			shoot.add_theme_color_override("font_color", C_RED)


## Tool targeting overlay: valid targets faint, the chosen 3x3 strong; lights
## out previews the zone that will go dark.
func _tool_tiles() -> void:
	match tool_mode:
		"smoke", "flash":
			for y in range(Battle.H):
				for x in range(Battle.W):
					var p := Vector2i(x, y)
					var ok: bool = battle.can_smoke(selected, p) if tool_mode == "smoke" else battle.can_flash(selected, p)
					if ok:
						tile_fill[p] = Color(C_TOOL, 0.22)
			if tool_at.x >= 0:
				for p in Battle.area3(tool_at):
					tile_fill[p] = Color(C_TOOL, 0.42)
		"lights":
			for y in range(Battle.DARK_ROWS + 1):
				for x in range(Battle.W):
					tile_fill[Vector2i(x, y)] = C_DARK


## Guards the pending tool would hit, for the white preview outline.
func _tool_affected() -> Array:
	if selected == null:
		return []
	match tool_mode:
		"flash":
			return battle.flash_targets(tool_at) if tool_at.x >= 0 else []
		"radio":
			return battle.radio_targets(selected)
		"lights":
			var near = battle.lights_checker()
			return [near] if near != null else []
		"smoke":
			if tool_at.x < 0:
				return []
			return battle.alive_units(Battle.REGIME).filter(func(g): return g.state == Battle.PATROL \
				and Battle._cheb(g.pos, tool_at) <= battle.sight and battle.line_of_sight(g.pos, tool_at))
	return []


func _apply_dark() -> void:
	if lamp_energy.is_empty():
		for l in lamps:
			lamp_energy[l] = l.light_energy
	var off: bool = battle.mission and battle.dark > 0
	for l in lamps:
		l.light_energy = lamp_energy[l] * (0.08 if off and l.position.z < -2.0 else 1.0)
	if junction_lamp:
		junction_lamp.emission_energy_multiplier = 0.0 if off or battle.lights_used else 2.5


func _frame_camera() -> void:
	var ours: Array = battle.alive_units(Battle.US)
	if ours.is_empty() or cam_offset == Vector3.ZERO:
		return
	# Phone readability (Nov 25): frame the unit you're moving plus who's near it, not the
	# whole squad, so the camera can get close enough that bodies read on a phone.
	var focus = selected if selected != null and selected.alive() else ours[0]
	var pts: Array[Vector2i] = [focus.pos]
	for u in ours:
		if u != focus and Battle._cheb(u.pos, focus.pos) <= FRAME_ALLY_RANGE:
			pts.append(u.pos)
	for g in battle.alive_units(Battle.REGIME):
		if Battle._cheb(g.pos, focus.pos) <= FRAME_GUARD_RANGE:
			pts.append(g.pos)
	var lo := Vector2(pts[0])
	var hi := Vector2(pts[0])
	for p in pts:
		lo = lo.min(Vector2(p))
		hi = hi.max(Vector2(p))
	var mid := (lo + hi) / 2.0
	var c := to_world(Vector2i(roundi(mid.x), roundi(mid.y)))
	# Lean toward the board centre so the camera never chases one straggler off the map.
	var target := CAM_HOME.lerp(Vector3(c.x, 0, c.z) + Vector3(0.3, 0, 0.6), 0.75)
	target.x = clampf(target.x, -2.0, 3.0)
	target.z = clampf(target.z, -5.0, 1.0)
	# Closest zoom that keeps every relevant unit inside the play area (between the
	# HUD bars, left of the action column). If none fits, the home framing.
	var goal := CAM_HOME + cam_offset
	var keep := cam.global_transform
	for zoom in [0.5, 0.58, 0.66, 0.74, 0.82, 0.9, 1.0]:
		var g: Vector3 = target + cam_offset * zoom
		if _fits(g, target, pts):
			goal = g
			break
	cam.global_transform = keep
	if goal == CAM_HOME + cam_offset:
		target = CAM_HOME
	if cam_goal != Vector3.INF and goal.distance_to(cam_goal) < 0.3:
		return
	var first := cam_goal == Vector3.INF
	cam_goal = goal
	if cam_tween:
		cam_tween.kill()
	var look := Transform3D(Basis(), goal).looking_at(target).basis
	if first:
		cam.position = goal
		cam.basis = look
		return
	cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	cam_tween.tween_property(cam, "position", goal, 0.45)
	cam_tween.tween_property(cam, "quaternion", look.get_rotation_quaternion(), 0.45)


## Would a camera at `at` looking at `target` show all `pts` (feet and heads)
## inside the safe area? Moves the camera; the caller restores it.
func _fits(at: Vector3, target: Vector3, pts: Array[Vector2i]) -> bool:
	cam.global_transform = Transform3D(Basis(), at).looking_at(target)
	var vp := get_viewport().get_visible_rect().size
	var safe := Rect2(24, TOP_H + 34, vp.x - COLUMN_W - 40, vp.y - BOTTOM_H - TOP_H - 70)
	for p in pts:
		var w := to_world(p) + Vector3(0, _ground(p), 0)
		for y in [0.0, 1.9]:
			var q := w + Vector3(0, y, 0)
			if cam.is_position_behind(q) or not safe.has_point(cam.unproject_position(q)):
				return false
	return true


## While a tool is pending the column is just its preview + Confirm / Cancel.
func _tool_column(u) -> void:
	var info := ""
	var ready := true
	var cost := 0
	match tool_mode:
		"smoke":
			ready = tool_at.x >= 0
			cost = Battle.NOISE_SMOKE
			info = "3x3, 2 turns: blocks sight\nedge -30 to hit\n" + _noise_note(cost) if ready else "Tap a tile\nwithin %d" % Battle.SMOKE_RANGE
		"flash":
			ready = tool_at.x >= 0
			cost = Battle.NOISE_FLASH
			var n: int = battle.flash_targets(tool_at).size() if ready else 0
			info = "Stuns %d for 1 turn\n" % n + _noise_note(cost) if ready else "Tap a tile\nwithin %d" % Battle.FLASH_RANGE
		"lights":
			cost = Battle.NOISE_LIGHTS
			info = "North yard dark %d turns\nwhite ring comes to look\n" % Battle.DARK_TURNS + _noise_note(cost)
		"radio":
			cost = Battle.NOISE_RADIO_FAIL
			info = "%d%%: 2 ringed guards leave\nfail: all alert, " % battle.radio_chance() + _noise_note(cost)
	var l := _hud_label(info, 17, C_RED if ready and battle.trips_alarm(cost) else C_FG)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(l)
	var ok := _hud_button("Confirm", _confirm_tool)
	ok.disabled = not ready
	column.add_child(ok)
	column.add_child(_hud_button("Cancel", func(): _start_tool("")))
	for b in column.get_children():
		if b is Button:
			b.custom_minimum_size = Vector2(COLUMN_W - 10, 64)


## "+4 noise", or "+4 noise: ALARM, 3 riot police in 2" when it would trip it.
func _noise_note(n: int) -> String:
	if battle.trips_alarm(n):
		return "+%d noise: ALARM\n%d riot police in %d" % [n, Battle.REINFORCEMENTS, Battle.REINFORCE_DELAY]
	return "+%d noise (%d/%d)" % [n, mini(Battle.NOISE_MAX, battle.noise + n), Battle.NOISE_MAX]


func _start_tool(mode: String) -> void:
	_coach_done()
	tool_mode = mode
	tool_at = Vector2i(-1, -1)
	aimed = null
	sneaking = false
	_refresh()


func _confirm_tool() -> void:
	var u = selected
	var at := tool_at
	var mode := tool_mode
	tool_mode = ""
	match mode:
		"smoke":
			if battle.smoke(u, at):
				Sfx.fx("smoke")
				feel.shake(0.2)
				_pop_at(at, "SMOKE", C_SMOKE)
		"flash":
			var hit: Array = battle.flash_targets(at)
			if battle.flashbang(u, at):
				Sfx.fx("flash")
				feel.screen_flash(Color(1, 1, 0.95, 0.7), 0.5)
				feel.shake(0.6)
				feel.buzz(90)
				_pop_at(at, "FLASH", Color(1, 1, 0.85))
				for g in hit:
					_pop(g, "STUNNED", C_FG)
		"lights":
			if battle.lights_out(u):
				Sfx.fx("lights")
				feel.screen_flash(Color(0, 0, 0, 0.55), 0.7)
				_pop(u, "LIGHTS OUT", C_FG)
		"radio":
			var tried: bool = battle.can_radio(u)
			var ok: bool = battle.radio(u)
			if tried:
				Sfx.fx("static", -4.0)
			_pop(u, "THEY BUY IT" if ok else "BLOWN", C_GOOD if ok else C_RED)
	_refresh()


func _pop_at(p: Vector2i, text: String, col: Color) -> void:
	var dummy := Battle.Unit.new()
	dummy.pos = p
	_pop(dummy, text, col)


func _tile_poly(p: Vector2i, inset: float) -> PackedVector2Array:
	var c := to_world(p) + Vector3(0, _ground(p) + 0.02, 0)
	var h := 0.5 - inset
	var out := PackedVector2Array()
	for o in [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]:
		out.append(cam.unproject_position(c + o))
	return out


func _draw_overlay() -> void:
	if battle == null:
		return
	var bodies := _body_rects()
	for y in range(Battle.H):
		for x in range(Battle.W):
			var p := Vector2i(x, y)
			var t: int = battle.tile(p)
			if t != Battle.FLOOR and t != Battle.HIGH:
				continue
			var poly := _tile_poly(p, 0.04)
			if tile_fill.has(p):
				var fill: Color = tile_fill[p]
				# The grid is 2D, drawn over the 3D cast: thin the fill where a body stands so the
				# tiles don't paint over people (Nov 25, real 3D cast).
				var r := Rect2(poly[0], Vector2.ZERO)
				for q in poly:
					r = r.expand(q)
				for b: Rect2 in bodies:
					if b.intersects(r):
						fill.a *= TILE_UNDER_BODY
						break
				overlay.draw_colored_polygon(poly, fill)
			var line := poly.duplicate()
			line.append(poly[0])
			overlay.draw_polyline(line, Color(0.9, 0.9, 0.85, 0.13), 1.0, true)
	_draw_cover_marks()
	_draw_smoke()
	_draw_map_labels()
	_draw_checker_path()
	_draw_rings()


const TILE_UNDER_BODY := 0.2

## Screen boxes of the standing cast (feet to head), for _draw_overlay.
func _body_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var up := Vector3(0, 1.8, 0)
	for u in battle.units:
		if not unit_nodes.has(u) or not unit_nodes[u].visible or not u.alive():
			continue
		var feet: Vector3 = unit_nodes[u].global_position
		var a := cam.unproject_position(feet)
		var b := cam.unproject_position(feet + up)
		var h := a.distance_to(b)
		out.append(Rect2(Vector2(minf(a.x, b.x) - h * 0.22, b.y), Vector2(absf(a.x - b.x) + h * 0.44, h * 0.92)))
	return out


func _draw_top() -> void:
	if battle == null:
		return
	_draw_threat_odds()
	_draw_tags()


## Slide a tag rect up (dir -1) or down (dir 1) until it clears every placed tag.
static func _place_tag(r: Rect2, placed: Array[Rect2], dir: int) -> Rect2:
	var moved := true
	var tries := 0
	while moved and tries < 16:
		moved = false
		tries += 1
		for q in placed:
			if r.intersects(q):
				r.position.y = q.position.y - r.size.y - 1.0 if dir < 0 else q.end.y + 1.0
				moved = true
	return r


func _process(delta: float) -> void:
	super(delta)
	if overlay:
		overlay.queue_redraw()  # rings and tags follow units while they tween
		top_overlay.queue_redraw()
	_update_rigs()
	_update_bodies()


func _feet(u) -> Vector3:
	return unit_nodes[u].global_position + Vector3(0, 0.03, 0)


## Lights out preview: the guard who'll come to check the box, and his walk, in
## danger red. He's the cost you have to plan around (spec §2.2).
func _draw_checker_path() -> void:
	if tool_mode != "lights":
		return
	var g = battle.lights_checker()
	if g == null:
		return
	var dest := Vector2i(-1, -1)
	for p in Battle.area3(Battle.JUNCTION_POS):
		if battle.standable(p) and (dest.x < 0 or Battle._manhattan(p, g.pos) < Battle._manhattan(dest, g.pos)):
			dest = p
	if dest.x < 0:
		return
	var pts := PackedVector2Array([cam.unproject_position(to_world(g.pos) + Vector3(0, 0.05, 0))])
	for p in battle.path_to(g, dest):
		pts.append(cam.unproject_position(to_world(p) + Vector3(0, _ground(p) + 0.05, 0)))
	if pts.size() > 1:
		overlay.draw_polyline(pts, Color(C_RING_US, 0.9), 3.0, true)
		overlay.draw_circle(pts[pts.size() - 1], 6.0, C_RING_US)


## Points of interest the player should know exist (no hidden map features):
## the floodlight junction box until it's been used.
func _draw_map_labels() -> void:
	if not battle.mission:
		return
	_draw_goal_markers()
	if battle.lights_used or battle.tile(Battle.JUNCTION_POS) != Battle.JUNCTION:
		return
	var font := ThemeDB.fallback_font
	var at := cam.unproject_position(to_world(Battle.JUNCTION_POS) + Vector3(0, 1.7, 0))
	var t := "⚡ Floodlight"
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	overlay.draw_rect(Rect2(at.x - 4, at.y - 17, w + 8, 21), Color(0.05, 0.06, 0.07, 0.6))
	overlay.draw_string(font, at + Vector2(0, -1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, C_MUTED)


## The mission's goal on the map (8.5 pass): where to upload, where to get out.
func _draw_goal_markers() -> void:
	var font := ThemeDB.fallback_font
	var aired: bool = battle.upload >= Battle.UPLOAD_TURNS
	if not aired and battle.box.x >= 0:
		var at := cam.unproject_position(to_world(battle.box) + Vector3(0, 2.4, 0))
		_marker(font, at, "▣ UPLOAD HERE %d/%d" % [battle.upload, Battle.UPLOAD_TURNS], Color(1.0, 0.7, 0.35))
	var mid := cam.unproject_position(to_world(Vector2i(Battle.W / 2, Battle.H - 1)) + Vector3(0, 0.05, 0.6))
	_marker(font, mid, "▼ EXIT" + ("" if aired else " (after the upload)"), C_GOOD if aired else C_MUTED)
	if not aired:
		for x in range(Battle.W):
			var poly := _tile_poly(Vector2i(x, Battle.H - 1), 0.04)
			var line := poly.duplicate()
			line.append(poly[0])
			overlay.draw_polyline(line, Color(C_GOOD, 0.35), 1.5, true)


func _marker(font: Font, at: Vector2, t: String, col: Color) -> void:
	# Off the play area (the camera follows the squad): pin it to the nearest edge with an arrow.
	var vp := get_viewport().get_visible_rect().size
	if at.y < TOP_H + 26:
		t = "▲ " + t.trim_prefix("▣ ")
	elif at.y > vp.y - BOTTOM_H - 8:
		t = t if t.begins_with("▼") else "▼ " + t
	at.y = clampf(at.y, TOP_H + 26, vp.y - BOTTOM_H - 8)
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	at.x = clampf(at.x, w / 2 + 8, vp.x - COLUMN_W - w / 2 - 12)
	var x := at.x - w / 2
	overlay.draw_rect(Rect2(x - 5, at.y - 18, w + 10, 23), Color(0.05, 0.06, 0.07, 0.72))
	overlay.draw_string(font, Vector2(x, at.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)


## Cover on the move range (8.5 pass, veteran: "no cover markers"): a bar on each tile edge that
## faces cover. Thin = half cover (barrels, barriers), thick = full (containers, the box).
func _draw_cover_marks() -> void:
	if selected == null or busy or battle.side != Battle.US or tool_mode != "":
		return
	for p in tile_fill:
		if tile_fill[p] != C_MOVE and tile_fill[p] != C_SNEAK and p != selected.pos:
			continue
		for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
			var t: int = battle.tile(p + d) if Battle.in_bounds(p + d) else Battle.FLOOR
			if t != Battle.HALF and t != Battle.FULL and t != Battle.BOX:
				continue
			var c := to_world(p) + Vector3(0, _ground(p) + 0.03, 0)
			var e := Vector3(d.x, 0, d.y) * 0.42
			var side := Vector3(d.y, 0, -d.x) * 0.3
			var a := cam.unproject_position(c + e - side)
			var b := cam.unproject_position(c + e + side)
			overlay.draw_line(a, b, Color(0.95, 0.95, 0.9, 0.9), 5.0 if t != Battle.HALF else 2.5, true)


## Smoke: soft grey puffs over each cloud's 3x3, drawn above the grid.
func _draw_smoke() -> void:
	if not battle.mission:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for sm in battle.smokes:
		for p in Battle.area3(sm[0]):
			var c := to_world(p) + Vector3(0, _ground(p) + 0.5, 0)
			for k in range(3):
				var o := Vector3(sin(t * 0.7 + k * 2.1 + p.x) * 0.25, 0.2 * k, cos(t * 0.5 + k * 1.7 + p.y) * 0.25)
				var a := cam.unproject_position(c + o)
				var b := cam.unproject_position(c + o + Vector3(0.55, 0, 0))
				overlay.draw_circle(a, a.distance_to(b), Color(C_SMOKE, 0.16))


## Team ring under every standing unit. The near half is drawn solid and the
## far half faint, so the ring reads as lying on the ground behind the legs.
func _draw_rings() -> void:
	var hit := _tool_affected() if tool_mode != "" else []
	for u in battle.units:
		if not unit_nodes.has(u) or not u.alive():
			continue
		var col: Color = C_RING_US if u.side == Battle.US else (C_RING_WAVER if u.wavering else C_RING_REGIME)
		var c := _feet(u)
		var pts := PackedVector2Array()
		for i in range(25):
			var a := TAU * i / 24.0
			pts.append(cam.unproject_position(c + Vector3(cos(a), 0, sin(a)) * 0.4))
		overlay.draw_colored_polygon(pts.slice(0, 24), Color(col, 0.32))
		var near := pts.slice(0, 13)   # +z half faces the camera
		var far := pts.slice(12, 25)
		overlay.draw_polyline(far, Color(col, 0.55), 2.5, true)
		overlay.draw_polyline(near, col, 4.5 if u == selected else 3.5, true)
		if hit.has(u):
			# Tool preview: a white outer ring on every guard the tool would affect.
			var outer := PackedVector2Array()
			for i in range(25):
				var a := TAU * i / 24.0
				outer.append(cam.unproject_position(c + Vector3(cos(a), 0, sin(a)) * 0.58))
			overlay.draw_polyline(outer, C_TOOL, 2.5, true)


## With a guard tapped: his best hit chance on each of ours standing in his reach.
func _draw_threat_odds() -> void:
	if threat.is_empty():
		return
	var font := ThemeDB.fallback_font
	for u in battle.alive_units(Battle.US):
		if threat.shoot.has(u.pos):
			# Beside the ring, not under it, so the bottom row never pushes it under the HUD.
			var at := cam.unproject_position(_feet(u)) + Vector2(24, 7)
			var t := "%d%%" % threat.shoot[u.pos]
			top_overlay.draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, 6, Color.BLACK)
			top_overlay.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, Color(1.0, 0.5, 0.42))


## Name/HP tags at a fixed screen size. Bunched units used to stack their tags
## into one unreadable blob: now nearer units keep their spot and the rest get
## pushed up, with a thin leader line back to the unit.
func _draw_tags() -> void:
	var font := ThemeDB.fallback_font
	var entries := []
	for u in unit_tags:
		if not unit_nodes.has(u) or not unit_nodes[u].visible:
			continue
		var head_up := Vector3(0, 1.95, 0)
		if rigs.has(u):  # cutouts stand up the camera's axis; a downed one lies low
			head_up = cam.global_transform.basis.y * (0.7 if not u.alive() else 2.0)
		var anchor := cam.unproject_position(unit_nodes[u].global_position + head_up)
		entries.append([u, anchor])
	# The selected unit gets first pick, then nearer units (lower on screen).
	entries.sort_custom(func(a, b):
		if (a[0] == selected) != (b[0] == selected):
			return a[0] == selected
		return a[1].y > b[1].y)
	var placed: Array[Rect2] = []
	var h := TAG_SIZE + 4.0
	for e in entries:
		var u = e[0]
		var anchor: Vector2 = e[1]
		var text: String = unit_tags[u][0]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x + 8.0
		var r := Rect2(anchor.x - w / 2, maxf(anchor.y - h, TOP_H + 2.0), w, h)
		if _hits(r, placed):
			# Bunched: collapse to initial + hearts, then slide up (or down near the top bar).
			text = unit_tags[u][2]
			w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE).x + 8.0
			r = Rect2(anchor.x - w / 2, maxf(anchor.y - h, TOP_H + 2.0), w, h)
			if _hits(r, placed):
				r = _place_tag(r, placed, -1)
				if r.position.y < TOP_H + 2.0:
					r = _place_tag(Rect2(anchor.x - w / 2, maxf(anchor.y - h, TOP_H + 2.0), w, h), placed, 1)
		var vw := get_viewport().get_visible_rect().size.x
		r.position.x = clampf(r.position.x, 4.0, vw - COLUMN_W - r.size.x - 6.0)  # never clipped by the edge or the column
		r.position.y = minf(r.position.y, get_viewport().get_visible_rect().size.y - BOTTOM_H - r.size.y - 4.0)  # nor hidden under the bottom bar
		placed.append(r)
		var ring: Color = C_RING_US if u.side == Battle.US else (C_RING_WAVER if u.wavering else C_RING_REGIME)
		if r.end.y < anchor.y - 4.0 or r.position.y > anchor.y:
			var feet := cam.unproject_position(_feet(u))
			var edge := r.end.y if r.end.y < anchor.y else r.position.y
			top_overlay.draw_line(Vector2(clampf(feet.x, r.position.x + 4, r.end.x - 4), edge), feet, Color(ring, 0.85), 2.0, true)
		top_overlay.draw_rect(r, Color(0.05, 0.06, 0.07, 0.62))
		top_overlay.draw_rect(Rect2(r.position, Vector2(3, r.size.y)), ring)  # team chip
		var base := Vector2(r.position.x + 5, r.end.y - 5)
		top_overlay.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, 5, Color.BLACK)
		top_overlay.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, unit_tags[u][1])


static func _hits(r: Rect2, placed: Array[Rect2]) -> bool:
	for q in placed:
		if r.intersects(q):
			return true
	return false


## Collapsed tag for bunched units: initial + hearts ("K ♥"), guards just hearts.
func _short_tag(u) -> String:
	if u.side != Battle.US:
		return ("W " if u.wavering else "") + _hearts(u.hp)
	var t: String = ("You" if u.is_you or u.name == "You" else u.name.left(1)) + " " + _hearts(u.hp)
	return t + (" ◎" if u.overwatch else "")


## White Flag nerve: filled diamonds left of NERVE ("◆◆◇" = one drained). Breaks at none.
static func _nerve_pips(u) -> String:
	return "◆".repeat(maxi(u.nerve, 0)) + "◇".repeat(maxi(Battle.NERVE - maxi(u.nerve, 0), 0))


## Hearts left and lost ("♥♡" = one hit from going down), so a wounded unit reads as wounded.
static func _hearts(hp: int) -> String:
	return "♥".repeat(maxi(hp, 0)) + "♡".repeat(maxi(Battle.MAX_HP - maxi(hp, 0), 0))


static func _pips(n: int, ch: String) -> String:
	return ch.repeat(maxi(n, 0))


func _face(u) -> void:
	var foes: Array = battle.enemies_of(u)
	if foes.is_empty():
		return
	var best = foes[0]
	for f in foes:
		if (f.pos - u.pos).length_squared() < (best.pos - u.pos).length_squared():
			best = f
	var d := to_world(best.pos) - to_world(u.pos)
	unit_nodes[u].rotation.y = atan2(d.x, d.z) + PI


# ---------- the end ----------

var resumed_over := false


func _show_result() -> void:
	for c in result_buttons.get_children():
		c.queue_free()
	if not battle.mission:
		var w: String = battle.winner()
		PlayStats.log_event("fight_end", {"kind": "skirmish", "won": w == Battle.US, "turns": battle.turn})
		result_label.text = "The yard is ours." if w == Battle.US else "The squad is down."
		result_buttons.add_child(_hud_button("Fight again", func(): _new_battle(seed_value + 1)))
		result_buttons.add_child(_hud_button("Back to the run", func(): get_tree().change_scene_to_file("res://scenes/game.tscn")))
		result_panel.visible = true
		return
	var r: Dictionary = battle.mission_result()
	if not resumed_over:
		PlayStats.log_event("fight_end", {"kind": "run" if mission_meta.has("state") else "fight now", "aired": r.aired,
			"out": r.out.size(), "hurt": r.hurt.size(), "dead": r.dead.size(), "kills": r.kills, "turns": battle.turn,
			"noise": battle.noise, "alarm": battle.alarm, "surrendered": r.prisoners, "fled": r.fled})
	var lines: Array[String] = []
	lines.append("The footage aired." if r.aired else "The screens stayed on the regime's channel.")
	if not r.out.is_empty():
		lines.append("Got out: %s." % ", ".join(r.out))
	if not r.hurt.is_empty():
		lines.append("Carried out: %s." % ", ".join(r.hurt))
	if not r.dead.is_empty():
		lines.append("Didn't make it: %s." % ", ".join(r.dead))
	var counts := []
	if r.kills > 0:
		counts.append("%d killed" % r.kills)
	if r.subdued > 0:
		counts.append("%d subdued" % r.subdued)
	if r.defections > 0:
		counts.append("%d came over" % r.defections)
	if r.prisoners > 0:
		counts.append("%d surrendered" % r.prisoners)
	if r.fled > 0:
		counts.append("%d ran" % r.fled)
	if not counts.is_empty():
		lines.append(", ".join(counts) + ".")
	result_label.text = "\n".join(lines)
	result_buttons.add_child(_hud_button("Back to the week" if mission_meta.has("state") else "Back to the title", func(): _return_to_run(r)))
	result_panel.visible = true


func _return_to_run(r: Dictionary) -> void:
	if mission_meta.has("state"):
		FightSave.clear()  # the week finishes now; the run save takes over (never on Fight now)
		mission_meta["result"] = r
		Engine.set_meta("mission", mission_meta)
	else:
		Engine.remove_meta("mission")  # a test launch with no run behind it
	get_tree().change_scene_to_file("res://scenes/game.tscn")


# ---------- pause (QoL step 1, Nov 25) ----------
# Leaving the app or pressing back pauses the fight behind a menu. "Save and quit" drops back
# to the title; CONTINUE FIGHT resumes at the saved turn (QoL step 4, scripts/fight_save.gd).

var pause_layer: CanvasLayer


## For REPORT A BUG: the fight's state in one line.
func bug_state() -> String:
	if battle == null:
		return "fight not built"
	var out := "fight turn %d, side %s, mission %s, noise %d, alarm %s, upload %d" % [
		battle.turn, battle.side, str(battle.mission), battle.noise, str(battle.alarm), battle.upload]
	var us := []
	for u in battle.units:
		us.append("%s %s hp%d @%s%s" % [u.side, u.name, u.hp, str(u.pos), " dead" if u.dead else ""])
	return out + " | " + "; ".join(us)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_save_fight()  # now, not deferred: Android may kill the app right after
			_set_paused.call_deferred(true)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_back.call_deferred()


## Back: closes the settings sheet first (the fight stays paused), else toggles pause.
func _back() -> void:
	if SettingsSheet.close_open(self):
		return
	_set_paused(pause_layer == null)


## Mid-fight save (scripts/fight_save.gd). Only fights a run launched; never under autoplay.
func _save_fight() -> void:
	if "--autoplay" in OS.get_cmdline_user_args() or battle == null:
		return
	FightSave.save(mission_meta, battle)


func _set_paused(on: bool) -> void:
	if "--autoplay" in OS.get_cmdline_user_args() or not is_inside_tree():
		return
	if on and (pause_layer != null or (result_panel and result_panel.visible)):
		return
	if not on:
		if pause_layer:
			pause_layer.queue_free()
			pause_layer = null
		get_tree().paused = false
		return
	get_tree().paused = true
	if feel:
		feel.settle()
	_save_fight()
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var t := _hud_label("PAUSED", 40, C_FG)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var resume := _hud_button("Resume", func(): _set_paused(false))
	resume.custom_minimum_size = Vector2(360, 72)
	box.add_child(resume)
	var settings := _hud_button("Settings", func(): SettingsSheet.open(self))
	settings.custom_minimum_size = Vector2(360, 72)
	box.add_child(settings)
	var run := mission_meta.has("state")
	var quit := _hud_button("Save and quit to title" if run else "Quit to title", _quit_fight)
	quit.custom_minimum_size = Vector2(360, 72)
	box.add_child(quit)
	if run:
		# Duff's pick (Nov 26): keep the old way out too. Drops the saved fight; Continue then
		# replays the week from its plan (the run save is from before the week resolved).
		var replan := _hud_button("Quit and replan the week", _replan_week)
		replan.name = "replan"
		replan.custom_minimum_size = Vector2(360, 72)
		box.add_child(replan)
	resume.grab_focus.call_deferred()


func _quit_fight() -> void:
	_save_fight()  # Continue on the title picks the fight up at this turn
	get_tree().paused = false
	Engine.remove_meta("mission")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _replan_week() -> void:
	FightSave.clear()
	get_tree().paused = false
	Engine.remove_meta("mission")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	var at := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		at = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		at = event.position
	if not pressed or busy or battle.is_over() or battle.side != Battle.US:
		return
	if (brief_panel != null and brief_panel.visible) or (regime_panel != null and regime_panel.visible):
		_close_card()   # a tap on the map closes the card; it doesn't also move someone
		return
	_coach_done_soft()
	var o := cam.project_ray_origin(at)
	var d := cam.project_ray_normal(at)
	if absf(d.y) < 0.001:
		return
	var hit := o + d * ((0.3 - o.y) / d.y)
	tap_tile(to_tile(hit))


func tap_tile(p: Vector2i) -> void:
	if not Battle.in_bounds(p):
		return
	if tool_mode == "smoke" or tool_mode == "flash":
		var ok: bool = battle.can_smoke(selected, p) if tool_mode == "smoke" else battle.can_flash(selected, p)
		if ok:
			tool_at = p
			_refresh()
		return
	if tool_mode != "":
		return
	var u = battle.unit_at(p)
	if u != null and u.side == Battle.US:
		_select(u)
		return
	if u != null and u.side == Battle.REGIME:
		aimed = u
		_refresh()
		return
	if aimed != null:
		aimed = null  # first tap away dismisses the threat view (Advance Wars style)
		_refresh()
		return
	if selected == null:
		return
	if sneaking and battle.reachable(selected, 1).has(p):
		_move_selected(p, true)
	elif not sneaking and battle.reachable(selected, selected.ap).has(p):
		_move_selected(p, false)


func _select(u) -> void:
	if not u.alive():
		return
	if u != selected:
		sneaking = false
		tool_mode = ""
	selected = u
	_refresh()


func _move_selected(p: Vector2i, sneak: bool) -> void:
	var path: Array[Vector2i] = battle.path_to(selected, p)
	var ok: bool = battle.sneak(selected, p) if sneak else battle.move(selected, p)
	if not ok:
		return
	if battle.fox_found and not _tip_seen("fox") and "--autoplay" not in OS.get_cmdline_user_args():
		_show_tip("fox")
	_coach_done()
	sneak_walk = sneak
	sneaking = false
	busy = true
	_refresh()
	var n: Node3D = unit_nodes[selected]
	var tw := create_tween()
	for step in path:
		tw.tween_callback(Sfx.fx.bind("step", -9.0 if sneak else 0.0))  # sneaking is quieter
		tw.tween_property(n, "position", to_world(step) + Vector3(0, _ground(step), 0), 0.2 if sneak else 0.12)
	await tw.finished
	busy = false
	_refresh()


func _on_sneak_toggle() -> void:
	_coach_done()
	sneaking = not sneaking
	_refresh()


func _on_shoot() -> void:
	_coach_done()
	if selected == null or aimed == null:
		return
	var target = aimed
	var hit: bool = battle.shoot(selected, target)
	_flash(selected, target, hit)
	_refresh()


func _on_subdue() -> void:
	if battle.subdue(selected, aimed):
		_pop(aimed, "SUBDUED", C_FG)
	_refresh()


func _on_persuade() -> void:
	var target = aimed
	var ok: bool = battle.persuade(selected, target)
	_pop(target, "JOINS YOU" if ok else "REFUSES", C_GOOD if ok else C_MUTED)
	_refresh()


func _on_overwatch() -> void:
	battle.overwatch(selected)
	_refresh()


func _on_upload() -> void:
	if battle.do_upload(selected):
		Sfx.fx("static")
	_refresh()


func _on_stabilize() -> void:
	battle.stabilize(selected)
	_refresh()


func _on_leave() -> void:
	var left_behind: Array = battle.units.filter(func(o): return o.side == Battle.US and o.downed())
	var others: Array = battle.alive_units(Battle.US).filter(func(o): return o != selected)
	if not left_behind.is_empty() and others.is_empty() and not "--autoplay" in OS.get_cmdline_user_args():
		_confirm_leave(left_behind)
		return
	_do_leave()


## 8.5 pass: the last one standing leaving ends the fight and abandons whoever is down. Ask first.
func _confirm_leave(downed: Array) -> void:
	_show_card("LEAVE THEM?", "%s %s down and will be left behind. Leaving now ends the fight." % [
		", ".join(downed.map(func(o): return o.name)), "is" if downed.size() == 1 else "are"],
		[["Stay", func(): _close_card()], ["Leave anyway", func(): _close_card(); _do_leave()]])


func _do_leave() -> void:
	battle.leave(selected)
	selected = null
	var left: Array = battle.alive_units(Battle.US)
	if not left.is_empty():
		selected = left[0]
	_refresh()


func _flash(from, to, hit: bool, last_on_target := true) -> void:
	_rig_play(from, "shoot", to)
	Sfx.fx("guard_shot" if from.side == Battle.REGIME else "shot")
	if hit:
		get_tree().create_timer(0.18, false).timeout.connect(Sfx.fx.bind("hurt"))
	# Feel: a hit lands (hit-stop, shake, buzz); losing one of ours lands hardest.
	feel.muzzle_smoke(world_root, to_world(from.pos) + Vector3(0, _ground(from.pos) + 1.35, 0))
	if hit:
		var down: bool = not to.alive() and last_on_target   # replayed turns: only the shot that downed them
		var ours: bool = to.side == Battle.US
		feel.hit_stop(Feel.STOP_DOWN if down else Feel.STOP_HIT)
		feel.shake((0.75 if down else 0.45) if ours else (0.5 if down else 0.3))
		feel.buzz((160 if down else 70) if ours else 30)
	else:
		feel.shake(0.12)
	_body_shoot(from, to)
	var a := to_world(from.pos) + Vector3(0, _ground(from.pos) + 1.35, 0)
	var light := OmniLight3D.new()
	light.position = a
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 6.0
	light.omni_range = 5.0
	world_root.add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.25)
	tw.tween_callback(light.queue_free)
	_pop(to, "HIT" if hit else "MISS", Color(1.0, 0.4, 0.3) if hit else C_MUTED)


func _pop(at, text: String, col: Color) -> void:
	var b := to_world(at.pos) + Vector3(0, _ground(at.pos) + 1.2, 0)
	var pop := Label3D.new()
	pop.text = text
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.font_size = 64
	pop.pixel_size = 0.007
	pop.outline_size = 12
	pop.modulate = col
	pop.position = b + Vector3(0, 1.1, 0)
	world_root.add_child(pop)
	var tw := create_tween()
	tw.tween_property(pop, "position:y", pop.position.y + 0.6, 0.9)
	tw.tween_callback(pop.queue_free)


func _on_end_turn() -> void:
	Sfx.fx("type")
	busy = true
	aimed = null
	sneaking = false
	tool_mode = ""
	var before := {}
	for u in battle.units:
		before[u] = u.pos
	var log_start: int = battle.log.size()
	_coach_done()
	battle.end_turn()
	_refresh()
	# 8.5 pass (first-timer: "the enemy turn takes your squad apart and you can't see how"): one
	# guard at a time, then each shot on its own beat, then a card listing what happened.
	var tw := create_tween()
	var moved := 0
	for u in battle.units:
		if u.side == Battle.REGIME and before.has(u) and before[u] != u.pos and unit_nodes.has(u):
			tw.tween_callback(Sfx.fx.bind("step", -6.0))  # their boots on the gravel, as they set off
			tw.tween_property(unit_nodes[u], "position", to_world(u.pos) + Vector3(0, _ground(u.pos), 0), ENEMY_STEP)
			moved += 1
	tw.tween_interval(0.25)
	await tw.finished
	var shots: Array = battle.log.slice(log_start).filter(func(l): return _shot_line(l))
	for i in shots.size():
		_flash_from_line(shots[i], shots.slice(i + 1))
		await get_tree().create_timer(ENEMY_SHOT_GAP, false, false, true).timeout
	busy = false
	var lines: Array = battle.log.slice(log_start)
	if not lines.is_empty() and not battle.is_over() and not "--autoplay" in OS.get_cmdline_user_args():
		_show_regime_turn(lines)
	if selected == null or not selected.alive():
		var left: Array = battle.alive_units(Battle.US)
		selected = left[0] if not left.is_empty() else null
	_refresh()
	_save_fight()  # checkpoint at the start of each of your turns


func _flash_from_line(line: String, later: Array = []) -> void:
	var shooter = null
	var target = null
	for u in battle.units:
		if line.begins_with(u.name + " "):
			shooter = u
		elif (" " + u.name + " ") in line or line.contains(" " + u.name + " ("):
			target = u
	if shooter != null and target != null:
		var again := later.any(func(l): return (" " + target.name + " ") in l or l.contains(" " + target.name + " ("))
		_flash(shooter, target, " hits " in line or " hit " in line, not again)


static func _shot_line(line: String) -> bool:
	for w in [" hits ", " hit ", " misses ", " miss "]:
		if w in line:
			return true
	return false


# ---------- renders ----------

func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(30)
	get_viewport().get_texture().get_image().save_png("res://docs/renders/%s.png" % name)
	print("saved ", name)


func _capture_tactical() -> void:
	await _shot("tactical_start")
	_select(battle.units[1])
	await _shot("tactical_move_range")
	await _move_selected(Vector2i(6, 9), false)
	var g = battle.units[5]  # the depot-yard patrol
	aimed = g
	_refresh()
	await _shot("tactical_aim")
	_on_end_turn()
	await _wait(50)
	await _shot("tactical_regime_turn")
	get_tree().quit()


## Scripted beats of one Signal Box run (seeded), saved as mission_*.png.
func _capture_mission() -> void:
	await _shot("mission_start")
	sneaking = true
	_refresh()
	await _shot("mission_sneak")
	await _move_selected(Vector2i(3, 9), true)
	# Fast-forward a scripted approach so the box and the Wavering guard are in frame.
	var you = battle.units[0]
	sneaking = false
	you.pos = Vector2i(6, 2)
	battle.units[1].pos = Vector2i(8, 2)
	for u in battle.alive_units(Battle.US):
		unit_nodes[u].position = to_world(u.pos) + Vector3(0, _ground(u.pos), 0)
	for g in battle.alive_units(Battle.REGIME):
		if g.wavering:
			g.pos = Vector2i(4, 2)
			unit_nodes[g].position = to_world(g.pos)
			aimed = g
	you.ap = 2
	selected = you
	_refresh()
	await _shot("mission_persuade")
	battle.do_upload(you)
	battle.noise = 7
	battle.alarm = true
	battle.reinforce_in = 1
	_refresh()
	await _shot("mission_upload")
	battle.upload = Battle.UPLOAD_TURNS
	for u in battle.alive_units(Battle.US):
		u.escaped = true
	_refresh()
	await _shot("mission_result")
	get_tree().quit()


## Each diversion tool, previewed and then fired: tools_*.png (J1.5).
func _capture_tools() -> void:
	var you = battle.units[0]
	var mara = battle.units[1]
	var kesh = battle.units[2]
	var guards: Array = battle.alive_units(Battle.REGIME)
	# Lights out: Kesh at the junction box.
	_place(kesh, Battle.JUNCTION_POS + Vector2i(1, 0))
	_place(mara, Vector2i(4, 10))
	_place(you, Vector2i(6, 10))
	_select(kesh)
	_start_tool("lights")
	await _shot("tools_lights_preview")
	_confirm_tool()
	await _shot("tools_lights_dark")
	# Smoke: Mara clouds the gap in front of her.
	_select(mara)
	_start_tool("smoke")
	tap_tile(Vector2i(4, 7))
	await _shot("tools_smoke_preview")
	_confirm_tool()
	await _shot("tools_smoke")
	# Radio: You at the box. Seeded so the call works and "on a fake call" shows.
	_place(you, battle.box + Vector2i(-1, 0))
	you.ap = 2
	battle.legitimacy = 3
	battle.rng.seed = 3
	_select(you)
	_start_tool("radio")
	await _shot("tools_radio_preview")
	_confirm_tool()
	await _shot("tools_radio")
	# Flashbang: the Wavering guard has come over; two guards bunched near him.
	var w = null
	for g in guards:
		if g.wavering:
			w = g
	w.wavering = false
	w.side = Battle.US
	w.defected = true
	w.flash = 1
	w.ap = 2
	_place(w, Vector2i(9, 7))
	var others := guards.filter(func(g): return g != w and g.busy == 0)
	_place(others[0], Vector2i(10, 4))
	_place(others[1], Vector2i(11, 4))
	battle.noise = 6  # so the preview has to warn that this one trips the alarm
	_select(w)
	_start_tool("flash")
	tap_tile(Vector2i(10, 4))
	await _shot("tools_flash_preview")
	_confirm_tool()
	await _shot("tools_flash")
	get_tree().quit()


## White Flag step 1 (Nov 26): nerve pips, the "he breaks" preview, a surrender and a guard
## running. Saved as docs/renders/white_flag/*.png.
func _capture_white_flag() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/renders/white_flag"))
	var you = battle.units[0]
	var mara = battle.units[1]
	var guards: Array = battle.alive_units(Battle.REGIME)
	var g = guards[1]
	await _shot("white_flag/1_nerve_pips")
	# Shaken: his partner went down, then a flashbang. One more hit and he breaks.
	g.nerve = 1
	var spot: Vector2i = g.pos + Vector2i(0, 3)
	for dy in range(1, 4):
		battle.set_tile(g.pos + Vector2i(0, dy), Battle.FLOOR)
	_place(you, spot)
	_place(mara, spot + Vector2i(-2, 0))
	you.ap = 2
	_select(you)
	aimed = g
	_refresh()
	await _shot("white_flag/2_breaks_preview")
	# He breaks with You right there: hands up. Another guard, shaken and alone, runs.
	aimed = null
	battle._shake(g, 1)
	var h = guards[3]
	h.nerve = 1
	battle._shake(h, 1)
	_refresh()
	await _shot("white_flag/3_surrender")
	get_tree().quit()


func _place(u, p: Vector2i) -> void:
	u.pos = p
	unit_nodes[u].position = to_world(p) + Vector3(0, _ground(p), 0)


# ---------- autoplay (-- --autoplay [--loud] [--out DIR]) ----------
# Plays a whole Signal Box mission through the real scene with the balance
# sim's player policy, saving a frame after every unit's turn. Lets Claude
# "watch" a run: frames -> GIF with tools/make_gif.py, log -> log.txt.
# Fails loudly (exit 1) if the mission stalls past MAX_AUTO_TURNS.

## Loaded only when autoplay runs: tools/ is excluded from the Android export, and a const
## preload of it broke this whole scene on the phone (Nov 25 fresh-eyes review).
const MISSION_SIM_PATH := "res://tools/mission_sim.gd"
const MAX_AUTO_TURNS := 30


static func _arg_after(args: PackedStringArray, flag: String, fallback: String) -> String:
	var i := args.find(flag)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback


func _autoplay(loud: bool, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var n := 0
	await _wait(20)
	n = await _auto_frame(out, n)
	while not battle.is_over() and battle.turn <= MAX_AUTO_TURNS:
		for u in battle.alive_units(Battle.US):
			if battle.is_over():
				break
			selected = u
			load(MISSION_SIM_PATH).act(battle, u, loud)
			await _sync_nodes()
			n = await _auto_frame(out, n)
		if battle.is_over():
			break
		await _on_end_turn()
		n = await _auto_frame(out, n)
	_refresh()
	await _wait(20)
	n = await _auto_frame(out, n)
	var stalled: bool = not battle.is_over()
	var f := FileAccess.open(out.path_join("log.txt"), FileAccess.WRITE)
	f.store_line("policy: %s, turns: %d, frames: %d, stalled: %s" % ["loud" if loud else "quiet", battle.turn, n, stalled])
	f.store_line(str(battle.mission_result()) if battle.mission else "winner: " + battle.winner())
	for line in battle.log:
		f.store_line(line)
	f.close()
	print("autoplay: %d frames, %d turns, stalled=%s -> %s" % [n, battle.turn, stalled, out])
	get_tree().quit(1 if stalled else 0)


func _sync_nodes() -> void:
	var tw := create_tween().set_parallel(true)
	for u in battle.units:
		if unit_nodes.has(u):
			tw.tween_property(unit_nodes[u], "position", to_world(u.pos) + Vector3(0, _ground(u.pos), 0), 0.25)
	tw.tween_interval(0.25)
	await tw.finished
	_refresh()


func _auto_frame(out: String, n: int) -> int:
	await _wait(6)
	get_viewport().get_texture().get_image().save_png(out.path_join("f%03d.png" % n))
	return n + 1


# ---------- HD-2D sprite size test (Nov 11, art direction) ----------

const SIZE_TEST_DIR := "res://docs/renders/sprites/size_test"
const SIZE_TEST_HEIGHTS := [64, 96, 128]
const PERSON_HEIGHT := 1.8  # metres, same as the rigs

## Duff's Canva sprite at 64/96/128 px source height, standing on the map at
## the same world height. Two shots: drawn in the 3D world (under the street
## grade) and drawn in 2D above the grade. Saves sprite_size_*.png.
func _capture_sprite_sizes() -> void:
	var us: Array = battle.alive_units(Battle.US)
	var tiles: Array[Vector2i] = []
	for x in range(3, 13):
		var p := Vector2i(x, 10)
		if battle.tile(p) != Battle.HIGH and tiles.size() < 3 and (tiles.is_empty() or x - tiles[-1].x >= 2):
			tiles.append(p)
	var texs: Array[ImageTexture] = []
	for h in SIZE_TEST_HEIGHTS:
		var img := Image.load_from_file(ProjectSettings.globalize_path("%s/duff_%d.png" % [SIZE_TEST_DIR, h]))
		texs.append(ImageTexture.create_from_image(img))
	for i in range(us.size()):
		var u = us[i]
		unit_nodes[u].visible = false
		if i < 3:
			u.pos = tiles[i]
			u.name = "%d px" % SIZE_TEST_HEIGHTS[i]
		else:
			u.pos = Vector2i(1 + i, 13)
		unit_nodes[u].position = to_world(u.pos) + Vector3(0, _ground(u.pos), 0)
	selected = null
	_refresh()
	# 1) In the world, under the grade.
	var world_sprites: Array[Sprite3D] = []
	for i in range(3):
		var sp := Sprite3D.new()
		sp.texture = texs[i]
		sp.pixel_size = PERSON_HEIGHT / float(SIZE_TEST_HEIGHTS[i])
		# Full billboard: the tactical camera looks down steeply, so an upright
		# (Y-only) sprite gets squashed. HD-2D tilts sprites to face the camera.
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED

		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sp.shaded = false
		# Centre the camera-facing quad half a body up the camera's own up axis,
		# so its bottom edge lands on the feet on screen.
		sp.position = to_world(tiles[i]) + cam.global_transform.basis.y * PERSON_HEIGHT * 0.5
		world_root.add_child(sp)
		world_sprites.append(sp)
	await _shot("sprite_size_world")
	# 2) Above the grade (full colour), drawn in 2D at the same screen size.
	for sp in world_sprites:
		sp.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	for i in range(3):
		var feet := cam.unproject_position(to_world(tiles[i]))
		var head := cam.unproject_position(to_world(tiles[i]) + Vector3(0, PERSON_HEIGHT, 0))
		var s := (feet.y - head.y) / float(SIZE_TEST_HEIGHTS[i])
		var sp := Sprite2D.new()
		sp.texture = texs[i]
		sp.centered = false
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2(s, s)
		sp.position = feet - Vector2(texs[i].get_width() * s * 0.5, SIZE_TEST_HEIGHTS[i] * s)
		layer.add_child(sp)
	await _shot("sprite_size_overlay")
	print("tiles ", tiles)
	get_tree().quit()


# ---------- HD-2D cutout characters ----------

## Off since Nov 25: the standards want real 3D on a humanoid skeleton, and the Meshy cast does that
## (_update_bodies). The cutout code stays for now in case Duff wants the HD-2D look back.
const USE_CUTOUTS := false

## Units without calibrated sprite joints still use their 3D models.
func _rig_spec(u) -> Dictionary:
	if not USE_CUTOUTS:
		return {}
	if u.defected:
		return CutoutRig.DEFECTOR
	if u.side == Battle.REGIME:
		return CutoutRig.GUARD
	if u.is_you or u.name == "You":
		return CutoutRig.DUFF
	if u.name == "Mara":
		return CutoutRig.MARA
	return {}


func _authored_rear_spec(front_spec: Dictionary) -> Dictionary:
	if front_spec == CutoutRig.DUFF:
		return CutoutRig.DUFF_BACK
	if front_spec == CutoutRig.MARA:
		return CutoutRig.MARA_BACK
	return {}


## Keep every cutout on its unit: placed at the feet, sized to a 1.8 m body at
## the camera, facing the nearest foe, walking while its 3D node moves, hit
## when it loses hp, down when it falls, and clipped behind walls.
func _update_rigs() -> void:
	if battle == null or rig_root == null:
		return
	var cam_up := cam.global_transform.basis.y
	_hulls_frame = -1  # wall outlines are rebuilt once, on first use this frame
	for u in battle.units:
		var spec := _rig_spec(u)
		if not unit_nodes.has(u) or spec.is_empty():
			continue
		var n: Node3D = unit_nodes[u]
		var feet := n.global_position
		var seen: Array = rig_seen.get(u, [feet, u.hp])
		var movement: Vector3 = feet - seen[0]
		var moving := movement.length_squared() > 0.0005 * 0.0005
		var rear_spec := _authored_rear_spec(spec)
		if not rear_spec.is_empty() and rigs.has(u):
			var current: CutoutRig = rigs[u]
			var front_spec := spec
			spec = current.spec
			if moving and u.alive() and u.hp >= seen[1] and current.state in ["idle", "walk"]:
				var depth := movement.dot(cam.global_transform.basis.z)
				if absf(depth) > movement.length() * 0.15:
					spec = rear_spec if depth < 0.0 else front_spec
		if rigs.has(u) and rigs[u].spec.texture != spec.texture:
			rig_root.remove_child(rig_clips[u])
			rig_root.remove_child(ghost_clips[u])
			rig_clips[u].queue_free()
			ghost_clips[u].queue_free()
			rigs.erase(u)
		if not rigs.has(u):
			_attach_rig(u, n, spec)
		var rig: CutoutRig = rigs[u]
		var clip: Node2D = rig_clips[u]
		var ghost: CutoutRig = rig_ghosts[u]
		clip.visible = n.visible
		ghost_clips[u].visible = n.visible
		ghost.visible = n.visible  # downed bodies behind cover still show as a silhouette
		if not n.visible:
			continue
		var a := cam.unproject_position(feet)
		var b := cam.unproject_position(feet + cam_up * 1.8)
		var k := a.distance_to(b) / rig.height_px()
		rig.position = a
		rig.scale = Vector2(-k if rig.scale.x < 0 else k, k)
		if not u.alive():
			rig.play("down")
		elif u.hp < seen[1]:
			rig.play("hit")
		elif moving and rig.state != "shoot":
			rig.play("walk")
			var dx := a.x - cam.unproject_position(seen[0]).x
			if absf(dx) > 0.5:
				rig.face(dx > 0.0)
		elif rig.state == "walk":
			rig.play("idle")
		if not moving and rig.state == "idle":
			_rig_face_foe(u, rig)
		rig_seen[u] = [feet, u.hp]
		ghost.position = rig.position
		ghost.scale = rig.scale
		ghost_clips[u].set_meta("unit", u)
		ghost_clips[u].queue_redraw()
		clip.set_meta("unit", u)
		clip.queue_redraw()
	var ordered := rigs.keys()
	ordered.sort_custom(func(a, b):
		return cam.to_local(unit_nodes[a].global_position).z < cam.to_local(unit_nodes[b].global_position).z)
	for index in ordered.size():
		var u = ordered[index]
		rig_root.move_child(ghost_clips[u], index * 2)
		rig_root.move_child(rig_clips[u], index * 2 + 1)


func _attach_rig(u, n: Node3D, spec: Dictionary) -> void:
	# The 3D node stays (tweens, tags and rings follow it); only its meshes hide.
	for vi: VisualInstance3D in n.find_children("*", "VisualInstance3D", true, false):
		vi.visible = false
	var rig := CutoutRig.create(spec)
	var ghost := CutoutRig.silhouette(rig, Color(C_RING_US if u.side == Battle.US else C_RING_REGIME, 0.5))
	var gclip := Node2D.new()
	gclip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	gclip.draw.connect(_draw_ghost_clip.bind(gclip))
	rig_root.add_child(gclip)
	gclip.add_child(ghost)
	rig_ghosts[u] = ghost
	ghost_clips[u] = gclip
	var clip := Node2D.new()
	clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	clip.draw.connect(_draw_rig_clip.bind(clip))
	rig_root.add_child(clip)
	clip.add_child(rig)
	rigs[u] = rig
	rig_clips[u] = clip


func _rig_face_foe(u, rig: CutoutRig) -> void:
	var foes: Array = battle.enemies_of(u)
	if foes.is_empty():
		return
	var best = foes[0]
	for f in foes:
		if (f.pos - u.pos).length_squared() < (best.pos - u.pos).length_squared():
			best = f
	_rig_face_point(u, rig, to_world(best.pos))


func _rig_face_point(u, rig: CutoutRig, p: Vector3) -> void:
	var dx := cam.unproject_position(p).x - cam.unproject_position(unit_nodes[u].global_position).x
	if absf(dx) > 2.0:
		rig.face(dx > 0.0)


func _rig_play(u, anim: String, target = null) -> void:
	if not rigs.has(u):
		return
	if target != null:
		_rig_face_point(u, rigs[u], to_world(target.pos))
	rigs[u].play(anim)


## The clip mask: the rig's screen box minus every wall, container or barrier
## standing between it and the camera. clip_children shows the rig only where
## this draws, so a body behind a container is cut off at the container's edge.
func _draw_rig_clip(clip: Node2D) -> void:
	if not clip.has_meta("unit"):
		return
	var u = clip.get_meta("unit")
	var rig: CutoutRig = rigs.get(u)
	if rig == null:
		return
	var hw := rig.height_px() * absf(rig.scale.y) * 0.9
	var box := PackedVector2Array([rig.position + Vector2(-hw, -hw * 1.2), rig.position + Vector2(hw, -hw * 1.2),
		rig.position + Vector2(hw, hw * 0.35), rig.position + Vector2(-hw, hw * 0.35)])
	clip.draw_rect(Rect2(-10, -10, 1, 1), Color.WHITE)
	var visible_parts: Array = [box]
	var uz: float = unit_nodes[u].global_position.z
	var box_rect := Rect2(box[0], box[2] - box[0])
	for hull in _occluder_hulls(uz, box_rect):
		var next: Array = []
		for part in visible_parts:
			next.append_array(_clip_no_holes(part, hull))
		visible_parts = next
	for part in visible_parts:
		if part.size() >= 3:
			clip.draw_colored_polygon(part, Color.WHITE)


## The silhouette shows only on the walls in front of the unit.
func _draw_ghost_clip(gclip: Node2D) -> void:
	if not gclip.has_meta("unit"):
		return
	var u = gclip.get_meta("unit")
	# A parent that draws nothing doesn't clip at all, so always draw a speck off-screen.
	gclip.draw_rect(Rect2(-10, -10, 1, 1), Color.WHITE)
	var rig: CutoutRig = rigs.get(u)
	if rig == null:
		return
	var hw := rig.height_px() * absf(rig.scale.y) * 0.9
	var near := Rect2(rig.position - Vector2(hw, hw * 1.2), Vector2(hw * 2.0, hw * 1.55))
	for hull in _occluder_hulls(unit_nodes[u].global_position.z, near):
		if hull.size() >= 3:
			gclip.draw_colored_polygon(hull, Color.WHITE)


## Screen outlines of the blocking geometry nearer the camera than depth z that
## overlap `near` (a screen rect). All outlines are built once per frame and
## shared by every rig and silhouette, then filtered here.
var _hulls: Array = []   # [world z of the tile's near face, hull, screen rect]
var _hulls_frame := -1

func _occluder_hulls(z: float, near := Rect2()) -> Array:
	var frame := Engine.get_process_frames()
	if _hulls_frame != frame:
		_hulls_frame = frame
		_hulls.clear()
		for y in range(Battle.H):
			for x in range(Battle.W):
				var p := Vector2i(x, y)
				var top := 0.0
				match battle.tile(p):
					Battle.FULL: top = 2.5
					Battle.BOX: top = 2.2
					Battle.HALF: top = 0.95
					_: continue
				var w := to_world(p)
				var pts := PackedVector2Array()
				for cx in [-0.5, 0.5]:
					for cz in [-0.5, 0.5]:
						for cy in [0.0, top]:
							pts.append(cam.unproject_position(w + Vector3(cx, cy, cz)))
				var hull := Geometry2D.convex_hull(pts)
				var r := Rect2(hull[0], Vector2.ZERO)
				for v in hull:
					r = r.expand(v)
				_hulls.append([w.z + 0.45, hull, r])
	var out := []
	for h in _hulls:
		if h[0] > z and (near.size == Vector2.ZERO or near.intersects(h[2])):
			out.append(h[1])
	return out


## a minus b, with no holes: if b sits inside a, split a down b's middle first.
static func _clip_no_holes(a: PackedVector2Array, b: PackedVector2Array) -> Array:
	var res := Geometry2D.clip_polygons(a, b)
	var has_hole := false
	for r in res:
		if Geometry2D.is_polygon_clockwise(r) != Geometry2D.is_polygon_clockwise(a):
			has_hole = true
	if not has_hole:
		return res
	var cx := 0.0
	for v in b:
		cx += v.x
	cx /= b.size()
	var out := []
	for half in [PackedVector2Array([Vector2(-1e5, -1e5), Vector2(cx, -1e5), Vector2(cx, 1e5), Vector2(-1e5, 1e5)]),
			PackedVector2Array([Vector2(cx, -1e5), Vector2(1e5, -1e5), Vector2(1e5, 1e5), Vector2(cx, 1e5)])]:
		for piece in Geometry2D.intersect_polygons(a, half):
			out.append_array(Geometry2D.clip_polygons(piece, b))
	return out


## Cutout check (-- --capture-rig [--out DIR]): the Signal Box start, You tucked
## behind a container (occlusion), and frozen poses for a sheet. Map shots go
## to docs/renders/rig_*.png, pose frames + You's screen spot to DIR.
func _capture_rig(out_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var you = battle.units[0]
	await _shot("rig_start")
	# Frozen poses where You starts (in the open, in frame).
	var rig: CutoutRig = rigs[you]
	rig.set_process(false)
	var poses := [["idle", 0.0, 0.0], ["walk", 0.0, 0.13], ["walk", 0.0, 0.26], ["walk", 0.0, 0.39],
		["shoot", 0.24, 0.0], ["hit", 0.17, 0.0], ["down", 0.6, 0.0]]
	var i := 0
	var at := Vector2.ZERO
	for ps in poses:
		rig.state = ps[0]
		rig.state_t = ps[1]
		rig.t = ps[2]
		rig._hit_flash = 0.0
		rig._pose(ps[0], ps[1])
		rig.body_root.modulate = Color(0.7, 0.62, 0.62) if ps[0] == "down" else Color.WHITE
		await _wait(6)
		at = rig.position
		get_viewport().get_texture().get_image().save_png("%s/pose_%d_%s.png" % [out_dir, i, ps[0]])
		i += 1
	var f := FileAccess.open(out_dir + "/you.txt", FileAccess.WRITE)
	f.store_string("%d %d %f" % [int(at.x), int(at.y), absf(rig.scale.y)])
	f.close()
	rig.state = "idle"
	rig.set_process(true)
	# Occlusion: behind a container, where the hidden part shows as a silhouette.
	for kind in [[Battle.FULL, "rig_behind_container"]]:
		var spot := Vector2i(-1, -1)
		for y in range(Battle.H - 1, 0, -1):
			for x in range(Battle.W):
				var q := Vector2i(x, y)
				var behind := q + Vector2i(0, -1)
				if spot.x < 0 and battle.tile(q) == kind[0] and battle.tile(behind) == Battle.FLOOR and battle.unit_at(behind) == null:
					spot = behind
		you.pos = spot
		unit_nodes[you].position = to_world(you.pos) + Vector3(0, _ground(you.pos), 0)
		_refresh()
		await _shot(kind[1])
	print("rig poses saved")
	get_tree().quit()


# ---------- 3D cast animation (Meshy clips) ----------

var body_seen := {}      # unit -> [feet position, hp] last frame
var body_shot_until := {} # unit -> msec when the shoot pose ends

## Pick each body's clip from what the unit is doing: walking (sneaking crouches, 1 hp limps),
## shooting, hit when it loses hp, the death clip when it goes down, idle otherwise.
func _update_bodies() -> void:
	if battle == null:
		return
	var now := Time.get_ticks_msec()
	for u in battle.units:
		if not unit_nodes.has(u) or not unit_nodes[u].has_meta("anim"):
			continue
		var n: Node3D = unit_nodes[u]
		var ap: AnimationPlayer = n.get_meta("anim")
		var feet := n.global_position
		var seen: Array = body_seen.get(u, [feet, u.hp])
		var moving: bool = (feet - seen[0]).length_squared() > 0.0005 * 0.0005
		var body: Node3D = n.get_node("Body")
		var want := "c/idle"
		if u.surrendered:
			want = "c/crouch_walk"   # White Flag: kneels, hands down (no hands-up clip yet)
		elif not u.alive():
			want = "c/death"
		elif u.hp < seen[1]:
			want = "c/hit"
		elif body_shot_until.get(u, 0) > now:
			want = "c/shoot"
		elif moving:
			want = "c/sneak" if sneak_walk and u == selected else ("c/run" if u.nerve <= 0 else ("c/injured_walk" if u.hp <= 1 else "c/walk"))
			var d: Vector3 = feet - seen[0]
			n.rotation.y = atan2(d.x, d.z) + PI
		elif ap.current_animation in ["c/hit"] and ap.is_playing():
			want = "c/hit"
		if want != "c/shoot":
			body.rotation.y = PI
		# One-shot clips (death, shoot) end with current_animation == "": compare the assigned
		# clip too, or a dead body gets up and falls again every clip length (fresh-eyes, Nov 25).
		var once := want == "c/death" or want == "c/shoot"
		if ap.current_animation != want and not (once and ap.assigned_animation == want):
			ap.play(want, 0.15)
			if want == "c/shoot":
				ap.seek(SHOOT_FROM, true)
		body_seen[u] = [feet, u.hp]


## The shoot clip draws, turns side-on and fires with the right arm out. Show its firing
## stretch, turned so that arm points at the target.
const SHOOT_FROM := 1.8
const SHOOT_FOR_MS := 1100

func _body_shoot(from, to) -> void:
	if not unit_nodes.has(from) or not unit_nodes[from].has_meta("anim"):
		return
	var n: Node3D = unit_nodes[from]
	var d: Vector3 = to_world(to.pos) - to_world(from.pos)
	n.rotation.y = atan2(d.x, d.z) + PI
	(n.get_node("Body") as Node3D).rotation.y = PI + PI / 2.0
	body_shot_until[from] = Time.get_ticks_msec() + SHOOT_FOR_MS


# ---------- first-minute coach (standards/08: teach by doing, 4 words, once) ----------

const ENEMY_STEP := 0.32      # seconds per guard's move on the regime turn (one at a time)
const ENEMY_SHOT_GAP := 0.4    # seconds between their shots
const COACH_FILE := "user://coach.cfg"
var coach: Label
var sneak_walk := false   # the move now playing was a sneak (sneaking resets as it starts)

func _build_coach(ui: CanvasLayer) -> void:
	var cfg := ConfigFile.new()
	cfg.load(COACH_FILE)
	if cfg.get_value("seen", "move", false) or "--autoplay" in OS.get_cmdline_user_args():
		return
	coach = _hud_label("Tap a blue tile", 30, C_FG)
	coach.autowrap_mode = TextServer.AUTOWRAP_OFF
	coach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coach.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	coach.grow_horizontal = Control.GROW_DIRECTION_BOTH
	coach.position.y -= BOTTOM_H + 64
	coach.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	coach.add_theme_constant_override("outline_size", 10)
	ui.add_child(coach)
	var tw := create_tween().set_loops()
	tw.tween_property(coach, "modulate:a", 0.45, 0.7)
	tw.tween_property(coach, "modulate:a", 1.0, 0.7)


## The first move teaches it: the hint goes, for good.
func _coach_done() -> void:
	if coach == null:
		return
	coach.queue_free()
	coach = null
	var cfg := ConfigFile.new()
	cfg.load(COACH_FILE)
	cfg.set_value("seen", "move", true)
	cfg.save(COACH_FILE)


## Any tap on the map after the first turn retires the hint too (first-timer: it never went away).
func _coach_done_soft() -> void:
	if coach != null and battle != null and battle.turn > 1:
		_coach_done()


# ---------- cards: mission brief, regime turn, leave check (8.5 pass, Nov 26) ----------

func _show_card(title: String, body: String, buttons: Array, wide := 640) -> PanelContainer:
	_close_card()
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := _panel_style()
	sb.bg_color = Color(C_PANEL, 0.95)
	sb.border_color = C_ACCENT
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	hud_layer.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var t := _hud_label(title, 28, C_ACCENT)
	v.add_child(t)
	var b := _hud_label(body, 21, C_FG)
	b.custom_minimum_size = Vector2(wide, 0)
	v.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	for bt in buttons:
		var btn := _hud_button(bt[0], bt[1])
		btn.custom_minimum_size = Vector2(200, 64)
		row.add_child(btn)
	brief_panel = p
	return p


func _close_card() -> void:
	for p in [brief_panel, regime_panel]:
		if p != null and is_instance_valid(p):
			p.queue_free()
	brief_panel = null
	regime_panel = null


## What the Signal Box wants, in plain words (first-timer: the goal was never stated in the fight).
func _show_brief() -> void:
	if battle == null or not battle.mission:
		return
	var body := "1. Get one of yours next to the signal box (UPLOAD HERE) and Upload. Two uploads, one per turn, air the footage.\n" \
		+ "2. Then get out: anyone on the south edge (EXIT) can Leave.\n\n" \
		+ "Guards marked ? are on patrol and haven't seen you. Sneak and they only spot you from %d tiles. " % Battle.HIDDEN_SIGHT \
		+ "A guard who spots you shouts, and shoots next turn. Shots make noise; at %d the alarm brings %d more." % [Battle.NOISE_MAX, Battle.REINFORCEMENTS]
	_show_card("THE SIGNAL BOX", body, [["Go", func(): _close_card(); cam_goal = Vector3.INF; _frame_camera()]], 700)


## The regime's turn, written down: who moved, who saw whom, who shot whom.
func _show_regime_turn(lines: Array) -> void:
	var keep: Array = lines.slice(maxi(0, lines.size() - 8))
	var p := _show_card("REGIME TURN", "\n".join(keep), [["Your move", func(): _close_card()]], 640)
	brief_panel = null
	regime_panel = p


# ---------- one-time tips (8.5 pass): ?, Wavering, ALARM, nerve ----------

const TIPS := {
	"patrol": "? = on patrol: he hasn't seen you. Sneaking, he only spots you from 2 tiles.",
	"waver": "Wavering: he's close to switching sides. Get You within 3 and Persuade.",
	"alarm": "ALARM: more guards are coming. Finish the upload or get out.",
	"nerve": "◆ = nerve. Hits and fallen partners drain it; at none he runs or gives up.",
	"fox": "A three-eyed fox, sprayed on the steel. Somebody in this yard is on your side.",
}
var tip_seen := {}
var tip_until := 0


func _tips() -> void:
	if battle == null or not battle.mission or "--autoplay" in OS.get_cmdline_user_args():
		return
	var key := ""
	if battle.alarm:
		key = "alarm"
	if key == "" or _tip_seen(key):
		key = ""
		if aimed != null and aimed.wavering:
			key = "waver"
		elif aimed != null and aimed.state == Battle.PATROL:
			key = "patrol"
		elif aimed != null and battle.white_flag:
			key = "nerve"
	if key != "" and not _tip_seen(key):
		_show_tip(key)


func _tip_seen(key: String) -> bool:
	if tip_seen.is_empty():
		var cfg := ConfigFile.new()
		cfg.load(COACH_FILE)
		for k in TIPS:
			tip_seen[k] = cfg.get_value("tips", k, false)
	return tip_seen.get(key, false)


func _show_tip(key: String) -> void:
	tip_seen[key] = true
	var cfg := ConfigFile.new()
	cfg.load(COACH_FILE)
	cfg.set_value("tips", key, true)
	cfg.save(COACH_FILE)
	if tip_label == null or not is_instance_valid(tip_label):
		tip_label = _hud_label("", 21, C_FG)
		tip_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		tip_label.offset_top = TOP_H + 8
		tip_label.offset_left = 24
		tip_label.offset_right = -COLUMN_W - 20
		tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		tip_label.add_theme_constant_override("outline_size", 10)
		tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_layer.add_child(tip_label)
	tip_label.text = TIPS[key]
	tip_label.visible = true
	tip_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(7.0)
	tw.tween_property(tip_label, "modulate:a", 0.0, 0.6)


## 8.5 pass renders: docs/renders/8_5/ (brief, cover marks + goal markers, regime turn card, a tip).
func _capture_8_5() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/renders/8_5")
	await _wait(20)
	_show_brief()
	await _shot("8_5/1_brief")
	_close_card()
	await _wait(5)
	await _shot("8_5/2_cover_and_goal")
	aimed = battle.alive_units(Battle.REGIME)[0]
	tip_seen = {"patrol": false, "waver": true, "alarm": true, "nerve": true}
	_show_tip("patrol")
	_refresh()
	await _shot("8_5/3_tip_patrol")
	aimed = null
	_show_regime_turn(["Guard 2 spots Mara (4 tiles, in the open) and shouts", "Guard 3 hears something",
		"Guard 2 takes aim but holds fire", "Guard 3 is alerted: the shout"])
	await _shot("8_5/4_regime_turn")
	get_tree().quit()


## Mascot cameo render: docs/renders/fox/ (the fox on its wall, then You finding it + the tip).
func _capture_fox() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs/renders/fox")
	var old := world_root.get_node_or_null("FoxGraffiti")
	if old:
		old.free()
	battle.place_fox(FOX_FIRST_WALL)
	_build_fox()
	await _wait(20)
	var you = battle.alive_units(Battle.US)[0]
	you.pos = battle.fox + Vector2i(0, 2)
	unit_nodes[you].position = to_world(you.pos) + Vector3(0, _ground(you.pos), 0)
	selected = you
	cam_goal = Vector3.INF
	_frame_camera()
	_refresh()
	await _wait(30)
	await _shot("fox/1_fox_on_the_wall")
	you.pos = battle.fox + Vector2i(1, 1)
	unit_nodes[you].position = to_world(you.pos) + Vector3(0, _ground(you.pos), 0)
	battle.check_fox(you)
	tip_seen = {"fox": false}
	_show_tip("fox")
	_refresh()
	await _wait(10)
	await _shot("fox/2_found_tip")
	get_tree().quit()
