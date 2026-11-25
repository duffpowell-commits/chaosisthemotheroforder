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
}

var values := DEFAULTS.duplicate()
var _gamma_layer: CanvasLayer
var _gamma_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	_make_gamma_layer()
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
	for k in DEFAULTS:
		values[k] = cfg.get_value("settings", k, DEFAULTS[k])


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
