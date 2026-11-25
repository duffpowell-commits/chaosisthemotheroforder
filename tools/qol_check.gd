extends SceneTree
## QoL step 1 check (Nov 25): focus-out saves the run and the half-made plan, Continue
## brings the plan back, back closes the picker then leaves to the title, and the fight
## pauses behind a menu on back / focus-out. Saves a render of the pause menu.
## xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/qol_check.gd

const RunState = preload("res://scripts/sim/run_state.gd")
const Rules = preload("res://scripts/sim/rules.gd")

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
	g._new_run()
	await _frames(2)
	var op: int = g.s.ready_operatives()[0]
	g.plan[op] = {"action": "lay_low", "op": op, "zone": "", "choice": ""}
	g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	expect(FileAccess.file_exists(g.PLAN_PATH), "focus-out saves the half-made plan")
	# Back: picker open -> closes it; on the district -> title; on the title -> (would quit).
	g._pick_action(op)
	await _frames(2)
	g._go_back()
	await _frames(2)
	expect(g.overlay == null and not g.on_title, "back closes the action picker")
	g._go_back()
	await _frames(2)
	expect(g.on_title, "back from the district goes to the title")
	# Fresh scene, Continue: the plan comes back.
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(5)
	g = current_scene
	g._continue_run()
	await _frames(2)
	expect(g.plan.has(op) and g.plan[op].action == "lay_low", "Continue restores the plan")
	# A new run drops the old plan.
	g._new_run()
	expect(not FileAccess.file_exists(g.PLAN_PATH) and g.plan.is_empty(), "new run clears the old plan")
	# The fight pauses on back, resumes on back, and pauses on focus-out.
	g._fight_now()
	await _frames(20)
	var t = current_scene
	t._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	expect(paused and t.pause_layer != null, "back pauses the fight")
	await _frames(3)
	if DisplayServer.get_name() != "headless":  # CI runs headless: no pixels to save
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://docs/renders/ui/7_paused.png"))
	t._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	expect(not paused and t.pause_layer == null, "back again resumes")
	t._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _frames(3)
	expect(paused, "leaving the app pauses the fight")
	t._quit_fight()
	await _frames(6)
	expect(not paused and current_scene.scene_file_path.ends_with("game.tscn") and current_scene.on_title, "quit goes to the title")
	print("QOL PASS" if ok else "QOL FAIL")
	quit(0 if ok else 1)
