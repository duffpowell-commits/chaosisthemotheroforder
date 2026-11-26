extends Node
## Autoload "Settings" (QoL step 2, Nov 25; trimmed from godot-game-starter's): player options
## saved in user://settings.cfg. Settings.get_value("music"), Settings.set_value("music", 0.5)
## saves, applies and emits `changed`.

signal changed(key: String)

const PATH := "user://settings.cfg"
## No SMALL: phone text never goes under 20 px (game.gd MIN_TEXT).
const TEXT_SCALES := [1.0, 1.15, 1.3]
const TEXT_NAMES := ["NORMAL", "LARGE", "HUGE"]

const DEFAULTS := {
	"music": 0.8,          # 0..1 linear, Music bus (sound arrives with standards item 6)
	"sfx": 0.9,            # 0..1 linear, SFX bus
	"gamma": 1.0,          # 0.6 (darker) .. 1.6 (brighter); 1.0 = off, costs nothing
	"text_size": 0,        # index into TEXT_SCALES
	"low_graphics": false, # fight: no shadows, glow, reflections; less rain; 75% 3D resolution
	"shake": true,         # fight: camera shake + screen flashes (off if it makes you sick)
	"haptics": true,       # fight: phone buzz on hits and the alarm
	"show_fps": false,     # a small FPS counter top-left on every screen (item 7: Duff reads it on his phone)
}

var values := DEFAULTS.duplicate()
var _gamma_layer: CanvasLayer
var _fps_layer: CanvasLayer
var _fps_label: Label
var _fps_t := 0.0
var _gamma_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	_make_gamma_layer()
	_make_fps_layer()
	apply_all()


func get_value(key: String):
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, v) -> void:
	values[key] = v
	save_settings()
	apply_all()
	changed.emit(key)


func text_scale() -> float:
	return TEXT_SCALES[clampi(int(get_value("text_size")), 0, TEXT_SCALES.size() - 1)]


func text_name() -> String:
	return TEXT_NAMES[clampi(int(get_value("text_size")), 0, TEXT_NAMES.size() - 1)]


## A font size scaled by the TEXT SIZE setting.
func fs(size: int) -> int:
	return int(round(size * text_scale()))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	# A hand-edited or corrupt file falls back per key: wrong type -> default, numbers clamped
	# (gamma 0 would black the screen).
	for k in DEFAULTS:
		var v = cfg.get_value("settings", k, DEFAULTS[k])
		var d = DEFAULTS[k]
		if typeof(d) == TYPE_BOOL:
			values[k] = v if v is bool else d
		elif typeof(d) == TYPE_INT:
			values[k] = clampi(int(v), 0, TEXT_SCALES.size() - 1) if (v is int or v is float) else d
		else:
			values[k] = float(v) if (v is int or v is float) else d
	values["music"] = clampf(values["music"], 0.0, 1.0)
	values["sfx"] = clampf(values["sfx"], 0.0, 1.0)
	values["gamma"] = clampf(values["gamma"], 0.6, 1.6)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


func apply_all() -> void:
	_set_bus("Music", float(get_value("music")))
	_set_bus("SFX", float(get_value("sfx")))
	var g := float(get_value("gamma"))
	if _gamma_layer != null:
		_gamma_layer.visible = absf(g - 1.0) > 0.01
		(_gamma_rect.material as ShaderMaterial).set_shader_parameter("gamma", g)
	if _fps_layer != null:
		_fps_layer.visible = bool(get_value("show_fps"))


func _set_bus(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001)))


## Brightness: a full-screen pass over the finished frame. Hidden at 1.0 so it costs nothing.
func _make_gamma_layer() -> void:
	_gamma_layer = CanvasLayer.new()
	_gamma_layer.layer = 127
	add_child(_gamma_layer)
	_gamma_rect = ColorRect.new()
	_gamma_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gamma_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float gamma = 1.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(pow(c, vec3(1.0 / gamma)), 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_gamma_rect.material = m
	_gamma_layer.add_child(_gamma_rect)


## FPS counter (item 7, step 1): off by default; SHOW FPS in Settings. Top-left, under the top bar's
## text line, on every screen; updates twice a second so it costs nothing.
func _make_fps_layer() -> void:
	_fps_layer = CanvasLayer.new()
	_fps_layer.layer = 126
	add_child(_fps_layer)
	_fps_label = Label.new()
	_fps_label.name = "fps"
	_fps_label.position = Vector2(8, 74)
	_fps_label.add_theme_font_size_override("font_size", 20)
	_fps_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fps_label.add_theme_constant_override("outline_size", 6)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_layer.add_child(_fps_label)
	_fps_layer.visible = bool(get_value("show_fps"))


func _process(delta: float) -> void:
	if _fps_layer == null or not _fps_layer.visible:
		return
	_fps_t += delta
	if _fps_t >= 0.5:
		_fps_t = 0.0
		var fps := Engine.get_frames_per_second()
		_fps_label.text = "%d FPS" % fps
		_fps_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55) if fps >= 55 else (Color(1.0, 0.85, 0.3) if fps >= 30 else Color(1.0, 0.4, 0.35)))
