extends "res://scripts/render_test.gd"
## Tactical map (M4): the Rail Yards street with a grid on it, driven by
## scripts/tactics/battle.gd. Tap a squad member (or their button), tap a
## blue tile to move, tap a guard to aim, then Shoot. End turn hands over to
## the regime.
## Run `res://scenes/tactical.tscn -- --capture-tactical` to save renders
## to docs/renders/tactical_*.png.

const Battle = preload("res://scripts/tactics/battle.gd")

const C_FG := Color("e7e3da")
const C_MUTED := Color("9b988f")
const C_ACCENT := Color("e2713b")
const C_PANEL := Color("171a1f")

var battle
var seed_value := 1
var unit_nodes := {}   # Battle.Unit -> Node3D
var unit_tags := {}    # Battle.Unit -> Label3D
## Grid highlights are drawn in 2D above the colour grade, so the grade
## can't wash out the move range and the target.
var overlay: Node2D
var tile_fill := {}    # Vector2i -> Color for this frame
var selected = null
var aimed = null
var busy := false
var world_root: Node3D

var top_label: Label
var log_label: Label
var squad_row: HBoxContainer
var shoot_btn: Button
var end_btn: Button
var result_panel: PanelContainer
var result_label: Label


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
	_new_battle(seed_value)
	if "--capture-tactical" in OS.get_cmdline_user_args():
		_capture_tactical()


# ---------- coordinates ----------

static func to_world(p: Vector2i) -> Vector3:
	return Vector3(p.x - 6.5, 0.0, p.y - 9.0)


static func to_tile(w: Vector3) -> Vector2i:
	return Vector2i(floori(w.x + 7.0), floori(w.z + 9.5))


func _ground(p: Vector2i) -> float:
	return 0.9 if battle.tile(p) == Battle.HIGH else 0.0


# ---------- build ----------

func _build_tactical_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 50
	add_child(cam)
	cam.position = Vector3(4.5, 12.5, 8.5)
	cam.look_at(Vector3(0.0, 0.0, -3.2))
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
	battle = Battle.create_skirmish(s)
	unit_nodes.clear()
	unit_tags.clear()
	selected = null
	aimed = null
	busy = false
	_build_cover()
	for u in battle.units:
		_spawn_unit(u)
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
			n = _person("riot_police", p, 0, world_root, true, {}, "weight_shift")
	unit_nodes[u] = n
	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 44
	tag.pixel_size = 0.006
	tag.outline_size = 10
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
	top.add_theme_stylebox_override("panel", _panel_style())
	ui.add_child(top)
	var tb := HBoxContainer.new()
	top.add_child(tb)
	top_label = _hud_label("", 24, C_FG)
	top_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_child(top_label)

	var bottom := PanelContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -150
	bottom.add_theme_stylebox_override("panel", _panel_style())
	ui.add_child(bottom)
	var col := VBoxContainer.new()
	bottom.add_child(col)
	log_label = _hud_label("", 18, C_MUTED)
	log_label.custom_minimum_size = Vector2(0, 52)
	col.add_child(log_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	squad_row = HBoxContainer.new()
	squad_row.add_theme_constant_override("separation", 10)
	squad_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(squad_row)
	shoot_btn = _hud_button("Shoot", _on_shoot)
	row.add_child(shoot_btn)
	end_btn = _hud_button("End turn", _on_end_turn)
	row.add_child(end_btn)

	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.add_theme_stylebox_override("panel", _panel_style())
	ui.add_child(result_panel)
	var rc := VBoxContainer.new()
	rc.add_theme_constant_override("separation", 14)
	result_panel.add_child(rc)
	result_label = _hud_label("", 30, C_FG)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rc.add_child(result_label)
	rc.add_child(_hud_button("Fight again", func(): _new_battle(seed_value + 1)))
	rc.add_child(_hud_button("Back to the run", func(): get_tree().change_scene_to_file("res://scenes/game.tscn")))
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
	var w: String = battle.winner()
	top_label.text = "Turn %d  ·  %s  ·  Guards left: %d" % [battle.turn,
		"Your move" if battle.side == Battle.US else "Regime move", battle.alive_units(Battle.REGIME).size()]
	log_label.text = "\n".join(battle.log.slice(maxi(0, battle.log.size() - 2)))
	for c in squad_row.get_children():
		c.queue_free()
	for u in battle.units:
		if u.side != Battle.US:
			continue
		var b := _hud_button("%s  %s  %s" % [u.name, _pips(u.hp, "♥"), _pips(u.ap, "●")], func(): _select(u))
		b.custom_minimum_size = Vector2(190, 56)
		b.disabled = not u.alive() or busy
		if u == selected:
			b.add_theme_color_override("font_color", C_ACCENT)
		squad_row.add_child(b)
	for u in battle.units:
		var n: Node3D = unit_nodes[u]
		var tag: Label3D = unit_tags[u]
		if not u.alive():
			tag.visible = false
			if u.escaped:
				n.visible = false
			else:
				n.rotation.x = deg_to_rad(-88)  # downed
			continue
		tag.text = "%s %s" % [u.name if u.side == Battle.US else "", _pips(u.hp, "♥")]
		tag.modulate = C_FG if u.side == Battle.US else Color(1.0, 0.55, 0.45)
		if u.side == Battle.REGIME and u.state == Battle.PATROL:
			tag.text += " ?"
		_face(u)
	# Tiles
	tile_fill.clear()
	if selected != null and selected.alive() and battle.side == Battle.US and not busy:
		for p in battle.reachable(selected, selected.ap):
			tile_fill[p] = Color(0.3, 0.62, 1.0, 0.32)
	if selected != null and selected.alive():
		tile_fill[selected.pos] = Color(1.0, 0.75, 0.25, 0.5)
	if aimed != null and aimed.alive():
		tile_fill[aimed.pos] = Color(1.0, 0.25, 0.15, 0.55)
	overlay.queue_redraw()
	var c := 0
	if selected != null and aimed != null:
		c = battle.chance(selected, aimed)
	shoot_btn.text = "Shoot %d%%" % c if c > 0 else "Shoot"
	shoot_btn.disabled = busy or c <= 0 or selected == null or selected.ap < 1
	end_btn.disabled = busy or w != ""
	if w != "":
		result_label.text = "The yard is ours." if w == Battle.US else "The squad is down."
		result_panel.visible = true


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
			if t == Battle.HALF or t == Battle.FULL:
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
	if not pressed or busy or battle.winner() != "" or battle.side != Battle.US:
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
	if selected != null and battle.reachable(selected, selected.ap).has(p):
		_move_selected(p)


func _select(u) -> void:
	if not u.alive():
		return
	selected = u
	_refresh()


func _move_selected(p: Vector2i) -> void:
	var path: Array[Vector2i] = battle.path_to(selected, p)
	if not battle.move(selected, p):
		return
	busy = true
	_refresh()
	var n: Node3D = unit_nodes[selected]
	var tw := create_tween()
	for step in path:
		tw.tween_property(n, "position", to_world(step) + Vector3(0, _ground(step), 0), 0.12)
	await tw.finished
	busy = false
	_refresh()


func _on_shoot() -> void:
	if selected == null or aimed == null:
		return
	var target = aimed
	var hit: bool = battle.shoot(selected, target)
	_flash(selected, target, hit)
	if not target.alive():
		aimed = null
	_refresh()


func _flash(from, to, hit: bool) -> void:
	var a := to_world(from.pos) + Vector3(0, _ground(from.pos) + 1.35, 0)
	var b := to_world(to.pos) + Vector3(0, _ground(to.pos) + 1.2, 0)
	var light := OmniLight3D.new()
	light.position = a
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 6.0
	light.omni_range = 5.0
	world_root.add_child(light)
	var pop := Label3D.new()
	pop.text = "HIT" if hit else "MISS"
	pop.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pop.no_depth_test = true
	pop.font_size = 64
	pop.pixel_size = 0.007
	pop.outline_size = 12
	pop.modulate = Color(1.0, 0.4, 0.3) if hit else C_MUTED
	pop.position = b + Vector3(0, 1.1, 0)
	world_root.add_child(pop)
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.25)
	tw.parallel().tween_property(pop, "position:y", pop.position.y + 0.6, 0.9)
	tw.tween_callback(light.queue_free)
	tw.tween_callback(pop.queue_free)


func _on_end_turn() -> void:
	busy = true
	aimed = null
	var before := {}
	for u in battle.units:
		before[u] = u.pos
	var log_start: int = battle.log.size()
	battle.end_turn()
	_refresh()
	var tw := create_tween().set_parallel(true)
	for u in battle.units:
		if u.side == Battle.REGIME and before[u] != u.pos:
			tw.tween_property(unit_nodes[u], "position", to_world(u.pos) + Vector3(0, _ground(u.pos), 0), 0.5)
	tw.tween_interval(0.5)
	await tw.finished
	for line in battle.log.slice(log_start):
		if " hits " in line or " misses " in line:
			_flash_from_line(line)
	busy = false
	if selected != null and not selected.alive():
		selected = null
	_refresh()


func _flash_from_line(line: String) -> void:
	var shooter = null
	var target = null
	for u in battle.units:
		if line.begins_with(u.name + " "):
			shooter = u
		elif (" " + u.name + " ") in line:
			target = u
	if shooter != null and target != null:
		_flash(shooter, target, " hits " in line)


# ---------- renders ----------

func _wait(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(30)
	get_viewport().get_texture().get_image().save_png("res://docs/renders/tactical_%s.png" % name)
	print("saved tactical_", name)


func _capture_tactical() -> void:
	await _shot("start")
	_select(battle.units[1])
	await _shot("move_range")
	await _move_selected(Vector2i(6, 9))
	var g = battle.units[5]  # the depot-yard patrol
	aimed = g
	_refresh()
	await _shot("aim")
	_on_end_turn()
	await _wait(50)
	await _shot("regime_turn")
	get_tree().quit()
