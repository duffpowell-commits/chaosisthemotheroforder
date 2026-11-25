extends SceneTree
## QoL step 1 check (Nov 25): focus-out saves the run and the half-made plan, Continue
## brings the plan back, back closes the picker then leaves to the title, and the fight
## pauses behind a menu on back / focus-out. Saves a render of the pause menu.
## xvfb-run -a godot --path . --rendering-driver opengl3 --script tools/qol_check.gd

const RunState = preload("res://scripts/sim/run_state.gd")
const Rules = preload("res://scripts/sim/rules.gd")

var ok := true


var settings_done := false
var bug_done := false
var fight_done := false


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
	expect(settings_done, "settings checks ran to the end (a script error stops them early)")
	await _bug_checks()
	expect(bug_done, "bug report checks ran to the end")
	await _fight_save_checks()
	expect(fight_done, "mid-fight save checks ran to the end")
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
	t.SettingsSheet.open(t)
	await _frames(2)
	t._back()
	await _frames(2)
	expect(paused and t.pause_layer != null and not _sheet_open(t), "back in the fight closes the sheet, stays paused")
	t._quit_fight()
	await _frames(6)
	g = current_scene
	g.show_title()
	g.SettingsSheet.open(g, g.show_title)
	await _frames(2)
	g._go_back()
	await _frames(2)
	expect(g.on_title and not _sheet_open(g), "back on the title closes the sheet, doesn't quit")
	# A corrupt settings file falls back to safe values (gamma 0 would black the screen).
	var bad := ConfigFile.new()
	bad.set_value("settings", "gamma", "oops")
	bad.set_value("settings", "music", [1, 2])
	bad.set_value("settings", "low_graphics", "false")
	bad.set_value("settings", "text_size", 9)
	bad.save(st.PATH)
	st.load_settings()
	expect(st.get_value("gamma") == 1.0 and st.get_value("music") == 0.8 and st.get_value("low_graphics") == false and st.get_value("text_size") == 2, "corrupt settings file falls back safely")
	st.values = st.DEFAULTS.duplicate()
	st.save_settings()
	settings_done = true


func _sheet_open(n: Node) -> bool:
	for c in n.get_children():
		if c is CanvasLayer and c.has_meta("sheet_close") and not c.is_queued_for_deletion():
			return true
	return false


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
	expect(BugReport.issue_url(BugReport.report_text("é ".repeat(5000), self)).length() < 8000, "a huge note still makes a working link")
	g._go_back()
	await _frames(2)
	expect(not is_instance_valid(bug) or bug.is_queued_for_deletion(), "back closes the bug report first")
	expect(_sheet_open(g), "settings sheet is still under it")
	g._go_back()
	await _frames(2)
	expect(not _sheet_open(g) and is_instance_valid(g), "back again closes settings")
	expect(BugReport.report_text("", self).contains("came from district"), "from the title, the report says which run screen you left")
	g._fight_now()
	await _frames(20)
	var ftxt: String = BugReport.report_text("", self)
	expect(ftxt.contains("fight turn 1") and ftxt.contains("hp"), "fight reports carry turn and units")
	current_scene._quit_fight()
	await _frames(6)
	bug_done = true


## QoL step 4: a run's fight saves at each of your turns and on quit; Continue drops you back
## into it at that turn; finishing the fight or starting a new run clears it.
func _fight_save_checks() -> void:
	var FightSave = load("res://scripts/fight_save.gd")
	var g = current_scene
	g._new_run()
	await _frames(2)
	expect(not FightSave.exists(), "a new run has no saved fight")
	var seed_now: int = g.s.run_seed
	Engine.set_meta("mission", {"state": g.s, "entries": [], "teodor_before": g.s.teodor.duplicate(true),
		"params": {"guards": 5, "legitimacy": 1, "seed": 4, "squad": [
			{"name": "You", "op": 0, "is_you": true}, {"name": "Mara", "op": 1, "is_you": false}]}})
	change_scene_to_file("res://scenes/tactical.tscn")
	await _frames(20)
	var t = current_scene
	expect(FightSave.exists(), "the fight saves as it starts")
	t._on_end_turn()
	await _frames(90)
	t.battle.units[0].hp = 1
	var want := var_to_str(t.battle.to_dict())
	expect(t.battle.turn == 2, "played into turn 2")
	t._set_paused(true)
	await _frames(2)
	expect(t.pause_layer.find_child("*", true, false) != null, "pause menu builds")
	t._quit_fight()
	await _frames(6)
	g = current_scene
	expect(g.on_title and _has_button(g, "CONTINUE FIGHT"), "the title offers CONTINUE FIGHT")
	await _shot("11_title_continue_fight.png")
	g._continue_run()
	await _frames(30)
	t = current_scene
	expect(t.scene_file_path.ends_with("tactical.tscn") and var_to_str(t.battle.to_dict()) == want, "Continue resumes the fight at the saved turn, hurt unit and all")
	await _shot("11_fight_resumed.png")
	# A stale save (another run's) is ignored and removed.
	expect(FightSave.load_for(seed_now + 1, 1).is_empty() and not FightSave.exists(), "another run's fight save is dropped")
	# A fight saved after it ended (squad down on the regime's turn, then the app was killed on
	# the result screen) resumes to its result panel, and Back to the week still works.
	for u in t.battle.units:
		if u.side == "us":
			u.hp = 0
			u.dead = true
	t._on_end_turn()
	await _frames(90)
	expect(t.battle.is_over() and t.result_panel.visible and FightSave.exists(), "an ended fight is saved with its result up")
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(5)
	current_scene._continue_run()
	await _frames(30)
	t = current_scene
	expect(t.scene_file_path.ends_with("tactical.tscn") and t.battle.is_over() and t.result_panel.visible, "resuming an ended fight shows its result, not an empty street")
	t._return_to_run(t.battle.mission_result())
	await _frames(10)
	expect(not FightSave.exists(), "finishing the fight clears the save")
	current_scene.get_tree().paused = false
	# Fight now (no run behind it) must never touch a run's saved fight.
	var RS = load("res://scripts/sim/run_state.gd")
	var keep = RS.create(5)
	Engine.set_meta("mission", {"params": {"guards": 5, "legitimacy": 1, "seed": 4, "squad": [
		{"name": "You", "op": 0, "is_you": true}]}})
	change_scene_to_file("res://scenes/tactical.tscn")
	await _frames(20)
	t = current_scene
	FightSave.save({"state": keep, "entries": [], "teodor_before": {}, "params": {}}, t.battle)
	t._return_to_run(t.battle.mission_result())
	await _frames(10)
	expect(FightSave.exists(), "finishing Fight now keeps the run's saved fight")
	FightSave.clear()
	change_scene_to_file("res://scenes/game.tscn")
	await _frames(5)
	fight_done = true


func _has_button(n: Node, text: String) -> bool:
	for b in n.find_children("*", "Button", true, false):
		if b.text == text:
			return true
	return false
