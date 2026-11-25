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
	await _settings_checks()
	await _bug_checks()
	print("QOL PASS" if ok else "QOL FAIL")
	quit(0 if ok else 1)


func _shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await _frames(4)
		root.get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://docs/renders/ui/" + name))


## QoL step 2: the settings sheet opens from the title, TEXT SIZE scales the run's text,
## LOW GRAPHICS cuts the fight's 3D cost, and the choices persist.
func _settings_checks() -> void:
	var st = root.get_node_or_null("Settings")
	expect(st != null, "Settings autoload is loaded")
	if st == null:
		return
	st.values = st.DEFAULTS.duplicate()
	var g = current_scene
	g.show_title()
	await _frames(2)
	var sheet = g.SettingsSheet.open(g, g.show_title)
	await _frames(2)
	expect(sheet.find_child("music", true, false) != null and sheet.find_child("done", true, false) != null, "settings sheet opens from the title")
	await _shot("8_settings.png")
	var tb: Button = sheet.find_child("text_size", true, false)
	tb.pressed.emit()
	tb.pressed.emit()
	await _frames(2)
	expect(int(st.get_value("text_size")) == 2, "TEXT SIZE steps to HUGE")
	expect(g._label("x", 20, Color.WHITE).get_theme_font_size("font_size") == 26, "HUGE text scales a 20 px label to 26")
	for c in g.get_children():
		if c is CanvasLayer and c.layer == 30:
			c.queue_free()
	g._new_run()
	await _frames(3)
	await _shot("9_district_huge_text.png")
	st.set_value("text_size", 0)
	var cfg := ConfigFile.new()
	expect(cfg.load(st.PATH) == OK and int(cfg.get_value("settings", "text_size", -1)) == 0, "settings are saved to disk")
	st.set_value("low_graphics", true)
	g._fight_now()
	await _frames(20)
	var t = current_scene
	expect(is_equal_approx(t.get_viewport().scaling_3d_scale, 0.75) and not t.moon.shadow_enabled and t.rain.amount == 500, "LOW GRAPHICS: 75% 3D, no shadows, less rain")
	st.set_value("low_graphics", false)
	await _frames(2)
	expect(is_equal_approx(t.get_viewport().scaling_3d_scale, 1.0) and t.moon.shadow_enabled, "HIGH GRAPHICS comes back live")
	t._set_paused(true)
	await _frames(2)
	expect(t.pause_layer.find_child("*", true, false) != null, "pause menu still builds")
	t._quit_fight()
	await _frames(6)


## QoL step 3: REPORT A BUG from the settings sheet; the report carries the version and
## the scene's state (district and fight) without the tester typing it.
func _bug_checks() -> void:
	var g = current_scene
	g._new_run()
	await _frames(2)
	var sheet = g.SettingsSheet.open(g, g.show_title)
	await _frames(2)
	var rb: Button = sheet.find_child("report_bug", true, false)
	expect(rb != null, "settings sheet has REPORT A BUG")
	if rb == null:
		return
	rb.pressed.emit()
	await _frames(2)
	var bug: CanvasLayer = null
	for c in g.get_children():
		if c is CanvasLayer and c.layer == 31:
			bug = c
	expect(bug != null and bug.find_child("note", true, false) != null and bug.find_child("send", true, false) != null and bug.find_child("copy", true, false) != null, "bug report opens with note, send, copy")
	if bug == null:
		return
	(bug.find_child("note", true, false) as TextEdit).text = "Shoot button did nothing"
	await _shot("10_bug_report.png")
	var BugReport = load("res://scripts/ui/bug_report.gd")
	var txt: String = BugReport.report_text("Shoot button did nothing", self)
	var Config = load("res://scripts/config.gd")
	expect(txt.begins_with("Shoot button did nothing") and txt.contains(Config.version_label()) and txt.contains("week 1") and txt.contains("screen district"), "report has the note, version and run state")
	var url: String = BugReport.issue_url(txt)
	expect(url.contains("/issues/new?labels=bug") and not url.contains(" "), "SEND makes an encoded GitHub issue link")
	bug.queue_free()
	for c in g.get_children():
		if c is CanvasLayer and c.layer == 30:
			c.queue_free()
	g._fight_now()
	await _frames(20)
	var ftxt: String = BugReport.report_text("", self)
	expect(ftxt.contains("fight turn 1") and ftxt.contains("hp"), "fight reports carry turn and units")
	current_scene._quit_fight()
	await _frames(6)
