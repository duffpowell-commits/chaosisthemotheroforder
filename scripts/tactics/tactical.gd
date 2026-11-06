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

const C_FG := Color("e7e3da")
const C_MUTED := Color("9b988f")
const C_ACCENT := Color("e2713b")
const C_PANEL := Color("171a1f")
const C_RED := Color("e05a46")
const C_GOOD := Color("7fbf7a")
const C_MOVE := Color(0.3, 0.62, 1.0, 0.32)
const C_SNEAK := Color(0.62, 0.42, 1.0, 0.36)
const C_EXIT := Color(0.45, 0.85, 0.45, 0.30)

const TOP_H := 56
const BOTTOM_H := 148
const COLUMN_W := 210

var battle
var seed_value := 1
var mission_meta := {}  # set when the run launched the Signal Box
var unit_nodes := {}    # Battle.Unit -> Node3D
var unit_tags := {}     # Battle.Unit -> Label3D
## Grid highlights are drawn in 2D above the colour grade, so the grade
## can't wash out the move range and the target.
var overlay: Node2D
var tile_fill := {}     # Vector2i -> Color for this frame
var selected = null
var aimed = null
var sneaking := false
var busy := false
var world_root: Node3D

var top_label: Label
var meter_label: Label
var log_label: Label
var squad_row: HBoxContainer
var column: VBoxContainer
var end_btn: Button
var result_panel: PanelContainer
var result_label: Label
var result_buttons: VBoxContainer


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
	_apply(0.0)
	env.fog_density = 0.012  # keep the far end of the grid readable
	var args := OS.get_cmdline_user_args()
	if ("--capture-mission" in args or "--autoplay" in args) and not Engine.has_meta("mission"):
		Engine.set_meta("mission", {"params": {"guards": 5, "legitimacy": 1, "seed": 4, "squad": [
			{"name": "You", "op": 0, "is_you": true}, {"name": "Mara", "op": 1, "is_you": false},
			{"name": "Kesh", "op": 2, "is_you": false}, {"name": "Teodor", "op": 3, "is_you": false}]}})
	if Engine.has_meta("mission"):
		mission_meta = Engine.get_meta("mission")
	_new_battle(seed_value)
	if "--capture-tactical" in args:
		_capture_tactical()
	elif "--capture-mission" in args:
		_capture_mission()
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
	cam.fov = 52
	add_child(cam)
	cam.position = Vector3(3.6, 13.6, 9.4)
	cam.look_at(Vector3(0.6, 0.0, -0.4))
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
	else:
		battle = Battle.create_mission(mission_meta.params)
	unit_nodes.clear()
	unit_tags.clear()
	selected = battle.alive_units(Battle.US)[0]
	aimed = null
	sneaking = false
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


func _spawn_unit(u) -> void:
	var p: Vector3 = to_world(u.pos) + Vector3(0, _ground(u.pos), 0)
	var n: Node3D
	match u.name:
		"You":
			n = _person("duff", p, 180, world_root, false, {
				"shirt": Color(0.09, 0.09, 0.1), "pants": Color(0.16, 0.19, 0.27),
				"boot": Color(0.22, 0.18, 0.15), "hair": Color(0.74, 0.52, 0.33)})
		"Mara":
			n = _person("civilian_woman", p, 180, world_root, false, {"shirt": Color(0.32, 0.12, 0.1), "pants": Color(0.1, 0.1, 0.12), "hair": Color(0.1, 0.08, 0.07)})
		"Kesh":
			n = _person("riot_police", p, 180, world_root, false, {"shirt": Color(0.12, 0.2, 0.16), "pants": Color(0.2, 0.17, 0.13), "hair": Color(0.05, 0.05, 0.05)})
		_:
			if u.side == Battle.US:
				# Teodor and new recruits: work clothes until they get their own models.
				n = _person("civilian_woman" if u.name.length() % 2 == 0 else "riot_police", p, 180, world_root, false,
					{"shirt": Color(0.24, 0.2, 0.12), "pants": Color(0.12, 0.13, 0.16), "hair": Color(0.2, 0.18, 0.16)})
			else:
				n = _person("riot_police", p, 0, world_root, true, {}, "weight_shift")
	unit_nodes[u] = n
	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 56
	tag.pixel_size = 0.006
	tag.outline_size = 12
	tag.position = Vector3(0, 2.15, 0)
	n.add_child(tag)
	unit_tags[u] = tag


func _build_hud() -> void:
	var grid_layer := CanvasLayer.new()
	grid_layer.layer = 2
	add_child(grid_layer)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	grid_layer.add_child(overlay)
	var ui := CanvasLayer.new()
	ui.layer = 3
	add_child(ui)

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
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _hud_button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(150, 56)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b


# ---------- state -> screen ----------

func _refresh() -> void:
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
	if selected != null and not selected.alive():
		selected = null
	if aimed != null and (not aimed.alive() or aimed.side == Battle.US):
		aimed = null
	_refresh_squad()
	_refresh_units()
	_refresh_tiles()
	_refresh_column()
	end_btn.disabled = busy or over
	if over and not result_panel.visible:
		_show_result()


func _refresh_squad() -> void:
	for c in squad_row.get_children():
		c.queue_free()
	var ours: Array = battle.units.filter(func(u): return u.side == Battle.US)
	var w := 188 if ours.size() <= 4 else 150
	for u in ours:
		var state := "%s  %s" % [_pips(u.hp, "♥"), _pips(u.ap, "●")]
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
		var tag: Label3D = unit_tags[u]
		if u.escaped:
			n.visible = false
			continue
		if not u.alive():
			n.rotation.x = deg_to_rad(-88)  # downed
			tag.visible = u.side == Battle.US and u.downed()
			tag.text = "%s %s" % [u.name, "stable" if u.stabilized else "bleeding"]
			tag.modulate = C_FG if u.stabilized else C_RED
			continue
		tag.visible = true
		if u.side == Battle.US:
			tag.text = "%s %s" % [u.name, _pips(u.hp, "♥")]
			tag.modulate = C_ACCENT if u == selected else C_FG
			if u.hidden:
				tag.text += " (hidden)"
			if u.overwatch:
				tag.text += " ◎"
		else:
			tag.text = _pips(u.hp, "♥")
			if u.wavering:
				tag.text = "Wavering " + tag.text
			if u.state == Battle.PATROL:
				tag.text += " ?"
			tag.modulate = Color(1.0, 0.85, 0.45) if u.wavering else Color(1.0, 0.55, 0.45)
		_face(u)


func _refresh_tiles() -> void:
	tile_fill.clear()
	var ours: bool = battle.side == Battle.US and not busy and not battle.is_over()
	if battle.mission and battle.upload >= Battle.UPLOAD_TURNS:
		for x in range(Battle.W):
			tile_fill[Vector2i(x, Battle.H - 1)] = C_EXIT
	if selected != null and ours:
		if sneaking:
			for p in battle.reachable(selected, 1):
				tile_fill[p] = C_SNEAK
		else:
			for p in battle.reachable(selected, selected.ap):
				tile_fill[p] = C_MOVE
	if selected != null:
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
	if battle.mission:
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
		if battle.can_subdue(u, aimed):
			column.add_child(_hud_button("Subdue", _on_subdue))
		if u.ap >= 1:
			column.add_child(_hud_button("Overwatch", _on_overwatch))
	var c := 0
	if aimed != null:
		c = battle.chance(u, aimed)
	var shoot := _hud_button("Shoot %d%%" % c if c > 0 else "Shoot", _on_shoot)
	shoot.disabled = c <= 0 or u.ap < 1
	column.add_child(shoot)
	for b in column.get_children():
		b.custom_minimum_size = Vector2(COLUMN_W - 10, 54)


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
	for y in range(Battle.H):
		for x in range(Battle.W):
			var p := Vector2i(x, y)
			var t: int = battle.tile(p)
			if t != Battle.FLOOR and t != Battle.HIGH:
				continue
			var poly := _tile_poly(p, 0.04)
			if tile_fill.has(p):
				overlay.draw_colored_polygon(poly, tile_fill[p])
			var line := poly.duplicate()
			line.append(poly[0])
			overlay.draw_polyline(line, Color(0.9, 0.9, 0.85, 0.13), 1.0, true)


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

func _show_result() -> void:
	for c in result_buttons.get_children():
		c.queue_free()
	if not battle.mission:
		var w: String = battle.winner()
		result_label.text = "The yard is ours." if w == Battle.US else "The squad is down."
		result_buttons.add_child(_hud_button("Fight again", func(): _new_battle(seed_value + 1)))
		result_buttons.add_child(_hud_button("Back to the run", func(): get_tree().change_scene_to_file("res://scenes/game.tscn")))
		result_panel.visible = true
		return
	var r: Dictionary = battle.mission_result()
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
	if not counts.is_empty():
		lines.append(", ".join(counts) + ".")
	result_label.text = "\n".join(lines)
	result_buttons.add_child(_hud_button("Back to the week", func(): _return_to_run(r)))
	result_panel.visible = true


func _return_to_run(r: Dictionary) -> void:
	if mission_meta.has("state"):
		mission_meta["result"] = r
		Engine.set_meta("mission", mission_meta)
	else:
		Engine.remove_meta("mission")  # a test launch with no run behind it
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
	var o := cam.project_ray_origin(at)
	var d := cam.project_ray_normal(at)
	if absf(d.y) < 0.001:
		return
	var hit := o + d * ((0.3 - o.y) / d.y)
	tap_tile(to_tile(hit))


func tap_tile(p: Vector2i) -> void:
	if not Battle.in_bounds(p):
		return
	var u = battle.unit_at(p)
	if u != null and u.side == Battle.US:
		_select(u)
		return
	if u != null and u.side == Battle.REGIME:
		aimed = u
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
	selected = u
	_refresh()


func _move_selected(p: Vector2i, sneak: bool) -> void:
	var path: Array[Vector2i] = battle.path_to(selected, p)
	var ok: bool = battle.sneak(selected, p) if sneak else battle.move(selected, p)
	if not ok:
		return
	sneaking = false
	busy = true
	_refresh()
	var n: Node3D = unit_nodes[selected]
	var tw := create_tween()
	for step in path:
		tw.tween_property(n, "position", to_world(step) + Vector3(0, _ground(step), 0), 0.2 if sneak else 0.12)
	await tw.finished
	busy = false
	_refresh()


func _on_sneak_toggle() -> void:
	sneaking = not sneaking
	_refresh()


func _on_shoot() -> void:
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
	battle.do_upload(selected)
	_refresh()


func _on_stabilize() -> void:
	battle.stabilize(selected)
	_refresh()


func _on_leave() -> void:
	battle.leave(selected)
	selected = null
	var left: Array = battle.alive_units(Battle.US)
	if not left.is_empty():
		selected = left[0]
	_refresh()


func _flash(from, to, hit: bool) -> void:
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
	busy = true
	aimed = null
	sneaking = false
	var before := {}
	for u in battle.units:
		before[u] = u.pos
	var log_start: int = battle.log.size()
	battle.end_turn()
	_refresh()
	var tw := create_tween().set_parallel(true)
	for u in battle.units:
		if u.side == Battle.REGIME and before.has(u) and before[u] != u.pos:
			tw.tween_property(unit_nodes[u], "position", to_world(u.pos) + Vector3(0, _ground(u.pos), 0), 0.5)
	tw.tween_interval(0.5)
	await tw.finished
	for line in battle.log.slice(log_start):
		if _shot_line(line):
			_flash_from_line(line)
	busy = false
	if selected == null or not selected.alive():
		var left: Array = battle.alive_units(Battle.US)
		selected = left[0] if not left.is_empty() else null
	_refresh()


func _flash_from_line(line: String) -> void:
	var shooter = null
	var target = null
	for u in battle.units:
		if line.begins_with(u.name + " "):
			shooter = u
		elif (" " + u.name + " ") in line or line.contains(" " + u.name + " ("):
			target = u
	if shooter != null and target != null:
		_flash(shooter, target, " hits " in line or " hit " in line)


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


# ---------- autoplay (-- --autoplay [--loud] [--out DIR]) ----------
# Plays a whole Signal Box mission through the real scene with the balance
# sim's player policy, saving a frame after every unit's turn. Lets Claude
# "watch" a run: frames -> GIF with tools/make_gif.py, log -> log.txt.
# Fails loudly (exit 1) if the mission stalls past MAX_AUTO_TURNS.

const MissionSim = preload("res://tools/mission_sim.gd")
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
			MissionSim.act(battle, u, loud)
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
