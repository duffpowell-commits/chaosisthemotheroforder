extends Node
## Game feel for the fight (standards item 6, step 2, Nov 26): camera shake, hit-stop, phone buzz,
## screen flashes, the alarm's red edge pulse and muzzle smoke. tactical.gd owns one of these
## (`feel`) and calls it on shots, hits, tools and the alarm. Sound lives in scripts/audio.gd.
## Settings: SHAKE (shake + screen flashes, off for players it makes sick) and BUZZ (haptics).

## Camera shake: offset in metres at full trauma; trauma decays per second. Shake is trauma²,
## so small knocks stay small and a downed squad member really lands.
const SHAKE_MAX := 0.35
const SHAKE_DECAY := 2.4
const SHAKE_HZ := 22.0
## Hit-stop: the world nearly freezes for a beat when a shot lands.
const STOP_SCALE := 0.05
const STOP_HIT := 0.06
const STOP_DOWN := 0.14
## Alarm edge pulse: three red beats round the screen edge, ~2 a second (under the 3 Hz
## photosensitivity line), and only with SHAKE on, like every other screen flash.
const ALARM_BEATS := 3
const ALARM_BEAT := 0.5
const ALARM_ALPHA := 0.55

var cam: Camera3D
var trauma := 0.0
var _t := 0.0
var _stop_id := 0
var _flash: ColorRect
var _edge: ColorRect


func setup(camera: Camera3D, ui_parent: Node) -> void:
	cam = camera
	var layer := CanvasLayer.new()
	layer.layer = 2   # with the grid (added after it, so over it), under the HUD (layer 3)
	ui_parent.add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)
	_edge = ColorRect.new()
	_edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.85, 0.08, 0.05, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float e = smoothstep(0.62, 1.0, max(d.x, d.y));
	COLOR = vec4(tint.rgb, tint.a * e * amount);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_edge.material = mat
	layer.add_child(_edge)


## Pause: the camera settles instead of freezing mid-shake.
func settle() -> void:
	trauma = 0.0
	if cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0   # never leave the game in slow motion


func _setting(key: String) -> bool:
	var st := get_tree().root.get_node_or_null("Settings")
	return st == null or bool(st.get_value(key))


func shake(amount: float) -> void:
	if _setting("shake"):
		trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if cam == null:
		return
	var dt := delta / maxf(Engine.time_scale, 0.01)   # shake keeps time during a hit-stop
	_t += dt
	trauma = maxf(trauma - SHAKE_DECAY * dt, 0.0)
	var s := trauma * trauma * SHAKE_MAX
	cam.h_offset = s * sin(_t * SHAKE_HZ * TAU * 0.5 + 1.3) * cos(_t * 7.1)
	cam.v_offset = s * sin(_t * SHAKE_HZ * TAU * 0.43)


## A beat where the world almost stops: makes a hit land. Real time, so it can't stretch itself.
func hit_stop(sec: float) -> void:
	_stop_id += 1
	var id := _stop_id
	Engine.time_scale = STOP_SCALE
	await get_tree().create_timer(sec, true, false, true).timeout
	if id == _stop_id:
		Engine.time_scale = 1.0


func buzz(ms: int) -> void:
	if _setting("haptics"):
		Input.vibrate_handheld(ms)


## Whole-screen flash that fades (white for the flashbang, black for lights out).
func screen_flash(col: Color, dur: float) -> void:
	if _flash == null or not _setting("shake"):
		return
	_flash.color = col
	var tw := create_tween().set_ignore_time_scale()
	tw.tween_property(_flash, "color:a", 0.0, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func alarm_pulse() -> void:
	if _edge == null or not _setting("shake"):
		return
	var mat := _edge.material as ShaderMaterial
	var tw := create_tween().set_ignore_time_scale()
	for i in ALARM_BEATS:
		tw.tween_method(func(v): mat.set_shader_parameter("amount", v), 0.0, ALARM_ALPHA, ALARM_BEAT * 0.35)
		tw.tween_method(func(v): mat.set_shader_parameter("amount", v), ALARM_ALPHA, 0.0, ALARM_BEAT * 0.65)


## A puff of grey gunsmoke at the muzzle, drifting up and off. Cheap CPU particles (Compatibility-safe).
func muzzle_smoke(parent: Node3D, at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 14
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 35.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, 0.25, 0)
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.5
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.8, 0.78, 0.75, 0.8))
	ramp.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	p.color_ramp = ramp
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.55, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	mat.albedo_texture = tex
	mesh.material = mat
	p.mesh = mesh
	p.position = at
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)
