extends SceneTree
## Sound check (standards item 6, step 1, Nov 26): each event in the fight and on the run screens
## plays its clip, the beds swap between desk and yard, and buttons click.
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
		if mode == "lights":
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
				if b.standable(b.JUNCTION_POS + d) and b.unit_at(b.JUNCTION_POS + d) == null:
					you.pos = b.JUNCTION_POS + d
					break
		t._confirm_tool()
		var want: String = {"smoke": "smoke", "flash": "flash", "lights": "lights", "radio": "static"}[mode]
		print("     %s -> %s" % [mode, str(a.heard.slice(n))])
		expect(_heard(a, want, n), "%s plays %s" % [mode, want])
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
