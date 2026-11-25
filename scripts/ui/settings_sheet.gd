extends RefCounted
## The SETTINGS sheet (QoL step 2, Nov 25): a manila card over a dimmed screen, from the
## title and the fight's pause menu. SettingsSheet.open(parent, on_close).
## Works while the tree is paused. TEXT SIZE reopens the sheet so the new size shows at once;
## on_close lets the caller rebuild its own screen at the new size.

const Config = preload("res://scripts/config.gd")
const TYPE_FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const C_INK := Color("1b1714")
const C_INK_SOFT := Color("4a423a")
const C_STAMP := Color("9e1a14")
const C_PAPER := Color("e9e0cc")


## Back button: closes an open sheet the way DONE does. True if there was one.
static func close_open(parent: Node) -> bool:
	for c in parent.get_children():
		if c is CanvasLayer and c.has_meta("sheet_close") and not c.is_queued_for_deletion():
			(c.get_meta("sheet_close") as Callable).call()
			return true
	return false


static func open(parent: Node, on_close := Callable()) -> CanvasLayer:
	var st: Node = parent.get_node("/root/Settings")
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/dossier/manila.png")
	sb.set_texture_margin_all(26)
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(760, 0)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var title := _text("SETTINGS", 34, C_STAMP)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_text(Config.version_label(), 20, C_INK_SOFT))
	var close := func():
		layer.queue_free()
		if on_close.is_valid():
			on_close.call()
	layer.set_meta("sheet_close", close)
	_slider(col, st, "MUSIC", "music", 0.0, 1.0)
	_slider(col, st, "SOUND EFFECTS", "sfx", 0.0, 1.0)
	_slider(col, st, "BRIGHTNESS", "gamma", 0.6, 1.6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var text_b := _button("TEXT SIZE: " + st.text_name(), func():
		st.set_value("text_size", (int(st.get_value("text_size")) + 1) % st.TEXT_SCALES.size())
		layer.queue_free()
		open(parent, on_close))
	text_b.name = "text_size"
	row.add_child(text_b)
	var gfx_b := _button("", Callable())
	gfx_b.name = "low_graphics"
	var gfx_text := func(): gfx_b.text = "GRAPHICS: " + ("LOW" if st.get_value("low_graphics") else "HIGH")
	gfx_text.call()
	gfx_b.pressed.connect(func():
		st.set_value("low_graphics", not st.get_value("low_graphics"))
		gfx_text.call())
	row.add_child(gfx_b)
	var done := _button("DONE", close)
	done.name = "done"
	var sbd := StyleBoxFlat.new()
	sbd.bg_color = C_STAMP
	sbd.set_corner_radius_all(4)
	for s in ["normal", "hover", "pressed", "focus"]:
		done.add_theme_stylebox_override(s, sbd)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		done.add_theme_color_override(k, C_PAPER)
	col.add_child(done)
	return layer


static func _text(t: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", TYPE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	return l


static func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override("font", TYPE_FONT)
	b.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = C_INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	var sp := sb.duplicate()
	sp.bg_color = Color(0, 0, 0, 0.12)
	for s in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_stylebox_override("pressed", sp)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, C_INK)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func _slider(col: Control, st: Node, title: String, key: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	var l := _text(title, 24, C_INK)
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	var sl := HSlider.new()
	sl.name = key
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = float(st.get_value(key))
	sl.custom_minimum_size = Vector2(0, 64)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	# A thick ink rail and a big grabber, so a thumb can drag it.
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(C_INK, 0.35)
	rail.content_margin_top = 6
	rail.content_margin_bottom = 6
	rail.set_corner_radius_all(4)
	var fill := rail.duplicate()
	fill.bg_color = C_STAMP
	sl.add_theme_stylebox_override("slider", rail)
	sl.add_theme_stylebox_override("grabber_area", fill)
	sl.add_theme_stylebox_override("grabber_area_highlight", fill)
	var g := _grabber()
	sl.add_theme_icon_override("grabber", g)
	sl.add_theme_icon_override("grabber_highlight", g)
	sl.value_changed.connect(func(v: float): st.set_value(key, v))
	row.add_child(sl)


static func _grabber() -> Texture2D:
	var img := Image.create(36, 36, false, Image.FORMAT_RGBA8)
	for y in 36:
		for x in 36:
			var d := Vector2(x - 17.5, y - 17.5).length()
			if d < 17.0:
				img.set_pixel(x, y, Color("1b1714") if d > 13.0 else Color("e9e0cc"))
	return ImageTexture.create_from_image(img)
