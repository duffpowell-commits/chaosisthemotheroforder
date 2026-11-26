extends Node
## Audio (autoload): one-shots on the SFX bus, a music bed and an ambience bed on the Music bus.
## Clips are real CC0 recordings cut by tools/real_audio.py into assets/audio/ (SOURCES.md lists each).
## A name plays any of its takes: "shot" picks shot_0..shot_2, never the same take twice running.
## Every button in the game clicks on press (hooked as buttons enter the tree), so UI code stays silent.
## Scripts call the static helpers (Sfx.fx / Sfx.music / Sfx.bed through a preload), because
## `--script` runs (tests, tools) don't register autoload names.

const DIR := "res://assets/audio/"
const POOL := 12
const NAMES := ["shot", "guard_shot", "step", "hurt", "alarm", "static", "flash", "smoke", "lights",
	"click", "type", "paper", "rain_loop", "music_fight", "music_dossier"]
const BEDS := ["rain_loop", "music_fight", "music_dossier"]
const FADE := 1.2

var _pool: Array[AudioStreamPlayer] = []
var _takes := {}       # name -> Array[AudioStream]
var _last_take := {}   # name -> index played last
var _last_ms := {}     # name -> Time ms (same sound twice inside 40 ms plays once)
var _music: AudioStreamPlayer
var _bed: AudioStreamPlayer
var _tweens := {}
var heard: Array[String] = []   # last clips played, newest last (tools/sound_check.gd reads it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the pause menu clicks too; beds keep going under it
	for i in POOL:
		_pool.append(_player("SFX"))
	_music = _player("Music")
	_bed = _player("Music")
	get_tree().node_added.connect(_on_node_added)


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("silent"):
		(n as BaseButton).pressed.connect(func(): play("click"))


## Every take of a clip, loaded once. Beds loop.
func takes(clip: String) -> Array:
	if _takes.has(clip):
		return _takes[clip]
	var out: Array = []
	if ResourceLoader.exists(DIR + clip + ".ogg"):
		out.append(load(DIR + clip + ".ogg"))
	else:
		var i := 0
		while ResourceLoader.exists(DIR + "%s_%d.ogg" % [clip, i]):
			out.append(load(DIR + "%s_%d.ogg" % [clip, i]))
			i += 1
	if clip in BEDS:
		for s in out:
			if s is AudioStreamOggVorbis:
				s.loop = true
	_takes[clip] = out
	return out


func play(clip: String, db := 0.0, pitch_jitter := 0.05) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(clip, -1000)) < 40:
		return
	_last_ms[clip] = now
	var all := takes(clip)
	if all.is_empty():
		return
	var i := randi() % all.size()
	if all.size() > 1 and i == int(_last_take.get(clip, -1)):
		i = (i + 1) % all.size()
	_last_take[clip] = i
	heard.append(clip)
	if heard.size() > 64:
		heard.pop_front()
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null:
		p = _pool[0]
		_pool.push_back(_pool.pop_front())  # steal the oldest
	p.stream = all[i]
	p.volume_db = db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


## Cross to another bed on a player ("" fades it out). Same clip already playing: nothing.
func _swap(p: AudioStreamPlayer, clip: String, db: float) -> void:
	var cur := str(p.get_meta("clip", ""))
	if cur == clip:
		return
	p.set_meta("clip", clip)
	if _tweens.has(p) and _tweens[p].is_valid():
		_tweens[p].kill()
	var tw := create_tween()
	_tweens[p] = tw
	if p.playing:
		tw.tween_property(p, "volume_db", -40.0, FADE * 0.5)
	tw.tween_callback(func():
		p.stop()
		var all := takes(clip) if clip != "" else []
		if not all.is_empty():
			p.stream = all[0]
			p.volume_db = -40.0
			p.play())
	if clip != "":
		tw.tween_property(p, "volume_db", db, FADE)


func set_music(clip: String) -> void:
	_swap(_music, clip, 0.0)


func set_bed(clip: String) -> void:
	_swap(_bed, clip, -2.0)


func now_playing() -> Array:
	return [str(_music.get_meta("clip", "")), str(_bed.get_meta("clip", ""))]


# ---- static helpers: safe when the autoload isn't there (tests, tools) ----

static func _me() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Audio") if tree else null


static func fx(clip: String, db := 0.0) -> void:
	var a := _me()
	if a:
		a.play(clip, db)


static func music(clip: String) -> void:
	var a := _me()
	if a:
		a.set_music(clip)


static func bed(clip: String) -> void:
	var a := _me()
	if a:
		a.set_bed(clip)
