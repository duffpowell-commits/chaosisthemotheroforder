extends SceneTree
## Sound check (standards item 6, step 1, Nov 26): each event in the fight and on the run screens
## plays its clip, the beds swap between desk and yard, and buttons click.
## Feel (step 2): shake, hit-stop, flashes, alarm pulse and the SHAKE setting.
## godot --headless --path . --script tools/sound_check.gd  -> last line SOUND PASS

var ok := true
var done := false


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func expect(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	ok = ok and cond


func _heard(a: Node, clip: String, since: int) -> bool:
	return a.heard.slice(since).has(clip)


func _run() -> void:
	var a: Node = root.get_node_or_null("Audio")
	expect(a != null, "Audio autoload is there")
	if a == null:
		_finish()
		return
	Engine.set_meta("mission", {"params": {"guards": 5, "legitimacy": 1, "seed": 4, "squad": [
		{"name": "You", "op": 0, "is_you": true}, {"name": "Mara", "op": 1, "is_you": false}]}})
	change_scene_to_file("res://scenes/tactical.tscn")
	await _frames(8)
	var t = current_scene
	expect(a.now_playing() == ["music_fight", "rain_loop"], "fight: cold music + rain (%s)" % str(a.now_playing()))
	var b = t.battle
	# A step per tile walked.
	var n: int = a.heard.size()
	var you = t.selected
	var dest := Vector2i(-1, -1)
	var reach: Dictionary = b.reachable(you, 1)
	for p in reach:
		if p != you.pos and b.path_to(you, p).size() >= 2:
			dest = p
			break
	await t._move_selected(dest, false)
	expect(a.heard.slice(n).count("step") >= 1, "walking plays boots on gravel")
	# A shot (ours) and a hit grunt.
	n = a.heard.size()
	var g = b.alive_units("regime")[0] if b.alive_units("regime").size() > 0 else null
	t._flash(you, g, true)
	await create_timer(0.3).timeout
	expect(_heard(a, "shot", n) and _heard(a, "hurt", n), "our shot + a grunt on a hit")
	n = a.heard.size()
	t._flash(g, you, false)
	expect(_heard(a, "guard_shot", n) and not _heard(a, "hurt", n), "their rifle; no grunt on a miss")
	# The alarm sounds once, when it trips.
	n = a.heard.size()
	b.alarm = true
	t._refresh()
	t._refresh()
	expect(a.heard.slice(n).count("alarm") == 1, "alarm sounds once when it trips")
	# Tools.
	for mode in ["smoke", "flash", "lights", "radio"]:
		n = a.heard.size()
		t.tool_mode = mode
		t.tool_at = you.pos
		b.smoke_left = 2
		you.ap = 2
		you.flash = 1
		if mode == "lights" or mode == "radio":  # beside the junction box / the signal box
			var at: Vector2i = b.JUNCTION_POS if mode == "lights" else b.box
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				if b.standable(at + d) and b.unit_at(at + d) == null:
					you.pos = at + d
					break
		t._confirm_tool()
		var want: String = {"smoke": "smoke", "flash": "flash", "lights": "lights", "radio": "static"}[mode]
		print("     %s -> %s" % [mode, str(a.heard.slice(n))])
		expect(_heard(a, want, n), "%s plays %s" % [mode, want])
	# Feel (step 2): a hit shakes and stops time for a beat, then time comes back.
	var f = t.feel
	f.trauma = 0.0
	t._flash(g, you, true)
	expect(f.trauma > 0.0 and Engine.time_scale < 0.5, "a hit shakes the camera and stops time (trauma %.2f, scale %.2f)" % [f.trauma, Engine.time_scale])
	await create_timer(0.5, true, false, true).timeout
	expect(Engine.time_scale == 1.0, "time comes back after the hit-stop")
	var st: Node = root.get_node("Settings")
	st.set_value("shake", false)
	f.trauma = 0.0
	t._flash(you, g, true)
	expect(f.trauma == 0.0, "SHAKE off: no shake")
	f._flash.color.a = 0.0   # the tool loop's flashbang may still be fading
	f.screen_flash(Color(1, 1, 1, 0.7), 0.5)
	expect(f._flash.color.a == 0.0, "SHAKE off: no screen flash")
	await create_timer(1.6, true, false, true).timeout   # the earlier alarm's pulse plays out
	(f._edge.material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	f.alarm_pulse()
	await create_timer(0.2, true, false, true).timeout
	expect(float((f._edge.material as ShaderMaterial).get_shader_parameter("amount")) == 0.0, "SHAKE off: no alarm pulse")
	st.set_value("shake", true)
	f.screen_flash(Color(1, 1, 1, 0.7), 0.5)
	expect(f._flash.color.a > 0.5, "flashbang whites the screen")
	f.alarm_pulse()
	await create_timer(0.15, true, false, true).timeout
	expect(float((f._edge.material as ShaderMaterial).get_shader_parameter("amount")) > 0.1, "alarm pulses the screen edge red")
	await create_timer(1.8, true, false, true).timeout
	# Buttons click; End turn types.
	await create_timer(0.1).timeout
	n = a.heard.size()
	t.end_btn.pressed.emit()
	await _frames(2)
	expect(_heard(a, "click", n) and _heard(a, "type", n), "End turn: click + typewriter key")
	await create_timer(1.5).timeout
	# The desk: dossier music, rain stops, paper on a new screen.
	Engine.remove_meta("mission")
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(5)
	await create_timer(1.0).timeout
	var gm = current_scene
	expect(a.now_playing() == ["music_dossier", ""], "desk: dossier music, no rain (%s)" % str(a.now_playing()))
	gm._new_run()
	n = a.heard.size()
	gm.show_district()
	expect(_heard(a, "paper", n), "a new screen turns paper")
	done = true
	_finish()


func _finish() -> void:
	expect(done, "sound checks ran to the end (a script error stops them early)")
	print("SOUND PASS" if ok else "SOUND FAIL")
	quit(0 if ok else 1)
