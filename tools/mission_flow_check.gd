extends SceneTree
## End-to-end check of the M5 hook: a planned Signal Box op switches to the
## mission, and its result finishes the week back in the run.
## xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/mission_flow_check.gd

const RunState = preload("res://scripts/sim/run_state.gd")
const Rules = preload("res://scripts/sim/rules.gd")
const Battle = preload("res://scripts/tactics/battle.gd")

var ok := true


func _init() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func expect(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	ok = ok and cond


func _run() -> void:
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(5)
	var g = current_scene
	g.s = RunState.create(11)
	Rules.start_week(g.s)
	g.s.week = 2
	var cash0: int = g.s.cash
	g.plan = {0: {"action": "signal_box", "op": 0, "zone": "", "choice": ""},
		1: {"action": "scavenge", "op": 1, "zone": "", "choice": ""}}
	g._resolve(g.plan.values())
	await _frames(10)
	var t = current_scene
	expect(t.scene_file_path.ends_with("tactical.tscn") and t.battle != null and t.battle.mission, "planned op opens the mission")
	var names: Array = t.battle.alive_units(Battle.US).map(func(u): return u.name)
	expect(names == ["You", "Kesh"], "squad = you + the free operative (Mara is scavenging): %s" % [names])
	# Play it out: upload twice, then everyone walks off the south edge.
	var b = t.battle
	b.upload = Battle.UPLOAD_TURNS
	b.kills = 1
	for u in b.alive_units(Battle.US):
		u.escaped = true
	t._refresh()
	expect(t.result_panel.visible, "result screen shows")
	t._return_to_run(b.mission_result())
	await _frames(10)
	var g2 = current_scene
	expect(g2.s != null and g2.s.broadcast_aired, "the broadcast is in the run")
	expect(g2.s.kills == 1 and g2.s.legitimacy == -1, "the kill counts (kills %d, legitimacy %d)" % [g2.s.kills, g2.s.legitimacy])
	expect(g2.s.week == 3, "the week finished (week %d)" % g2.s.week)
	expect(not Engine.has_meta("mission"), "mission handoff cleared")
	print("ALL OK" if ok else "FAILED")
	quit(0 if ok else 1)
