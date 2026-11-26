extends Control
## The playable slice (M2-M3): title, district map + week planner, dialogue
## scenes, weekly report, ending. Built in code from the M1 rules; phone-first (big touch targets,
## nothing on hover). Run with `-- --shots` to save screenshots of each screen.

const Config = preload("res://scripts/config.gd")
const RunState = preload("res://scripts/sim/run_state.gd")
const Rules = preload("res://scripts/sim/rules.gd")
const Policies = preload("res://scripts/sim/policies.gd")
const Text = preload("res://scripts/ui/text.gd")
const Dialogue = preload("res://scripts/dialogue/dialogue.gd")
const Story = preload("res://scripts/dialogue/story.gd")
const FightSave = preload("res://scripts/fight_save.gd")
const Sfx = preload("res://scripts/audio.gd")
const SettingsSheet = preload("res://scripts/ui/settings_sheet.gd")
const PlayStats = preload("res://scripts/stats.gd")

const SAVE_PATH := "user://run.save"
## The week's half-made plan, saved when the app loses focus or the back button leaves
## the run (QoL step 1, Nov 25). Only kept while its week is still the run's week.
const PLAN_PATH := "user://plan.save"
## Smallest text on a phone screen (1280x720 canvas on a ~6" phone).
const MIN_TEXT := 20

# Palette: dark field-dossier UI, woodcut paper for the propaganda layer.
const C_BG := Color("0e1013")
const C_PANEL := Color("171a1f")
const C_LINE := Color("2c3139")
const C_FG := Color("e7e3da")
const C_MUTED := Color("9b988f")
const C_ACCENT := Color("e2713b")
const C_PAPER := Color("e9e0cc")
const C_INK := Color("1b1714")
const C_RED := Color("c8372d")
const C_GOOD := Color("6fa36b")
# Ledger action picker (Nov 25): darker paper for tiles, stamp red = movement red.
const C_PAPER_DARK := Color("ddd2b8")
const C_INK_SOFT := Color("4a423a")
const C_STAMP := Color("9e1a14")
const TYPE_FONT := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const SYMBOLS_FONT := preload("res://assets/fonts/symbols_dejavu.ttf")
const ACTION_ICON := "res://assets/ui/woodcut/icons/display/%s.png"  # 128 px copies
const ACTION_ICONS := {
	"aid": "action_aid", "expose": "action_expose", "recruit": "action_recruit",
	"scavenge": "action_scavenge", "listen": "action_listen", "lay_low": "action_lay_low",
	"diversion": "action_diversion", "signal_box": "tool_radio_call", "rally": "res_legitimacy",
	"seize": "res_heat", "see_teodor": "action_see_teodor", "strike": "action_see_teodor",
	"confess": "action_see_teodor",
}
const DOSSIER := "res://assets/ui/dossier/%s.png"
const INK_SHADER := preload("res://shaders/ui_ink_stamp.gdshader")
const ROUND_SHADER := preload("res://shaders/ui_round_icon.gdshader")
const OP_FACES := {
	"You": "res://assets/portraits/duff_neutral_warm.png",
	"Mara": "res://assets/portraits/mara_calm_warm.png",
	"Kesh": "res://assets/portraits/kesh_suspicious_warm.png",
	"Teodor": "res://assets/portraits/teodor_guarded_warm.png",
}
const TEODOR_FACE := "res://assets/portraits/teodor_guarded_warm.png"
const STORY_ACTIONS := ["see_teodor", "strike", "confess"]
const RISKY_ACTIONS := ["scavenge", "diversion", "signal_box", "rally", "seize"]

var s: RunState
var plan := {}  # operative index -> plan entry
var screen: Control
var backdrop_regime: TextureRect
var backdrop_free: TextureRect
var overlay: Control
var message: Label
# The dialogue scene on screen (M3): its runner, what to call when it ends,
# and the portrait to keep showing through narration.
var dlg_runner
var dlg_done: Callable
var dlg_portrait := ""
var dlg_log: Array = []  # lines so far in this scene, shown as a running transcript
var on_title := false
var where := ""  # which screen is up, for bug reports
var left_from := ""  # the run screen the player backed out of to reach the title


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.music("music_dossier")
	Sfx.bed("")  # the fight's rain stops at the desk
	var tf: FontFile = TYPE_FONT  # typewriter has no ▼ ✕: borrow the symbols font
	if not tf.fallbacks.has(SYMBOLS_FONT):
		tf.fallbacks = [SYMBOLS_FONT]
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# The Rail Yards street behind everything: regime render fading into the liberated one.
	backdrop_regime = _backdrop("res://assets/ui/backdrop_regime.png")
	backdrop_free = _backdrop("res://assets/ui/backdrop_liberated.png")
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.035, 0.045, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	screen = MarginContainer.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		screen.add_theme_constant_override("margin_" + side, 20)
	add_child(screen)
	_set_backdrop(0.0)
	if "--shots" in OS.get_cmdline_user_args():
		_take_shots.call_deferred()
	elif Engine.has_meta("mission") and Engine.get_meta("mission").has("result"):
		var m: Dictionary = Engine.get_meta("mission")
		Engine.remove_meta("mission")
		_after_mission.call_deferred(m)
	else:
		show_title()


# ---------- screens ----------

func show_title() -> void:
	if where != "" and where != "title":
		left_from = where  # Settings (and REPORT A BUG) only open from the title
	where = "title"
	_clear()
	on_title = true
	var box := _vbox(18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(box)
	box.add_child(_typed("CHAOS IS THE MOTHER OF ORDER", 48, C_FG))
	box.add_child(_label("The Rail Yards  ·  District 7, Port Varga", 22, C_MUTED))
	box.add_child(_spacer(12))
	box.add_child(_label("Six weeks. One district. The Continuity Government is watching.", 20, C_FG, true))
	box.add_child(_spacer(12))
	var row := _hbox(14)
	box.add_child(row)
	# Playable in 10 s (standards/08): one tap drops you into the Signal Box fight. A run's
	# weeks come after, from New run.
	var fight := _ink_button("FIGHT NOW  ▶", _fight_now, true)
	fight.custom_minimum_size.x = 280
	row.add_child(fight)
	for pair in ([["CONTINUE FIGHT" if FightSave.exists() else "CONTINUE", _continue_run]] if FileAccess.file_exists(SAVE_PATH) else []) + [["NEW RUN", _new_run]]:
		var b := _ink_button(pair[0], pair[1], false)
		b.custom_minimum_size.x = 270 if pair[0] == "CONTINUE FIGHT" else 220
		b.add_theme_color_override("font_color", C_PAPER)
		row.add_child(b)
	var gear := _ink_button("SETTINGS", func(): SettingsSheet.open(self, show_title), false)
	gear.custom_minimum_size.x = 220
	gear.add_theme_color_override("font_color", C_PAPER)
	row.add_child(gear)
	box.add_child(_spacer(8))
	box.add_child(_label(Config.version_label(), 18, C_MUTED))


## Quick launch: the Signal Box with the core four and no run behind it (the result screen
## then returns here). Same squad the captures and autoplay use.
func _fight_now() -> void:
	Engine.set_meta("mission", {"params": {"guards": 5, "legitimacy": 1, "seed": randi() % 1000, "squad": [
		{"name": "You", "op": 0, "is_you": true}, {"name": "Mara", "op": 1, "is_you": false},
		{"name": "Kesh", "op": 2, "is_you": false}, {"name": "Teodor", "op": 3, "is_you": false}]}})
	get_tree().change_scene_to_file("res://scenes/tactical.tscn")


func show_district() -> void:
	where = "district"
	Sfx.fx("paper")
	_clear()
	_set_backdrop(_liberation())
	var col := _page()
	col.add_child(_top_bar())
	var body := _hbox(22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	# Left: the two zones as case-file cards, and Teodor's tag.
	var zones := _vbox(14)
	zones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zones.size_flags_stretch_ratio = 1.0
	body.add_child(zones)
	for zone in Rules.ZONES:
		zones.add_child(_on_desk(_zone_card(zone), zone, true))
	zones.add_child(_on_desk(_teodor_line(), "teodor_tag"))
	# Right: this week's assignments.
	var pcol := _vbox(10)
	pcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pcol.size_flags_stretch_ratio = 1.15
	body.add_child(pcol)
	var head := _hbox(12)
	pcol.add_child(head)
	head.add_child(_stamp("ASSIGNMENTS", C_INK, 24, -2.0))
	var hint := _typed("Up to 3 jobs. Everyone else rests.", 20, C_INK_SOFT, true)
	head.add_child(hint)
	var used := plan.size()
	# A big cell scrolls its rows and drops the street photo, so END WEEK always shows.
	var rows_n := s.ready_operatives().size()
	for o in s.operatives:
		if not o.dead and o.out_weeks > 0:
			rows_n += 1
	var big := rows_n > 3
	var rows := _vbox(10)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if big:
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.add_child(rows)
		pcol.add_child(sc)
	else:
		pcol.add_child(rows)
	for i in s.ready_operatives():
		rows.add_child(_operative_row(i, used))
	for i in range(s.operatives.size()):
		var o: Dictionary = s.operatives[i]
		if not o.dead and o.out_weeks > 0:
			rows.add_child(_typed("%s: out for %d more week%s" % [o.name, o.out_weeks, "" if o.out_weeks == 1 else "s"], 20, C_INK_SOFT))
	message = _typed("", 20, C_STAMP)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pcol.add_child(message)
	if not big:
		pcol.add_child(_on_desk(_street_photo(), "street_photo", true, 1.2))
	pcol.add_child(_ink_button("END WEEK %d  ▶" % s.week, _end_week, true))


func show_report() -> void:
	where = "report"
	Sfx.fx("paper")
	_clear()
	_set_backdrop(_liberation())
	var col := _page()
	var head := _hbox(16)
	col.add_child(head)
	head.add_child(_stamp("WEEK %d · REPORT" % (s.week - (0 if s.is_over() else 1)), C_STAMP, 30, -2.0))
	head.add_child(_typed("FILE 07 · RAIL YARDS CELL · WHAT THEY SAY / WHAT HAPPENED", 20, C_INK_SOFT))
	# A busy week's report scrolls; the button forward stays on screen.
	var rsc := ScrollContainer.new()
	rsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(rsc)
	var row := _hbox(26)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rsc.add_child(row)
	# State TV: a torn clipping, regime red masthead.
	var tv := _paper_panel("card")
	var tvc := _vbox(10)
	tv.add_child(tvc)
	var slug := _panel(C_STAMP)
	slug.add_child(_label("CONTINUITY NEWS 24", 22, C_PAPER))
	tvc.add_child(slug)
	var bulletin := Text.regime_bulletin(s)
	# The lead story goes on the studio screen of the woodcut TV set.
	# The woodcut TV set, live from the studio; the bulletin reads out under it.
	var live := CenterContainer.new()
	live.add_child(_stamp("● LIVE · DISTRICT 7", C_STAMP, 22, -3.0))
	tvc.add_child(_framed("res://assets/ui/woodcut/report_frame_cn24.png", Rect2(0.205, 0.30, 0.59, 0.45), live))
	for line in bulletin:
		tvc.add_child(_label(line, 20, C_INK, true))
	row.add_child(_on_desk(tv, "report_tv", true))
	# Pirate radio: what actually happened, typed on a manila sheet.
	var radio := _paper_panel("manila")
	var rc := _vbox(10)
	radio.add_child(rc)
	rc.add_child(_stamp("UNBROKEN RADIO", C_STAMP, 24, -3.0))
	var onair := CenterContainer.new()
	onair.add_child(_stamp("● ON AIR", C_STAMP, 22, -4.0))
	rc.add_child(_framed("res://assets/ui/woodcut/report_frame_unbroken.png", Rect2(0.334, 0.276, 0.36, 0.42), onair))
	rc.add_child(_typed("what really happened", 20, C_INK_SOFT))
	if s.report.is_empty():
		rc.add_child(_typed("A quiet week. Nobody moved.", 22, C_INK, true))
	for line in s.report:
		rc.add_child(_typed("— " + line, 22, C_INK, true))
	row.add_child(_on_desk(radio, "report_radio", true))
	col.add_child(_ink_button("SEE THE ENDING  ▶" if s.is_over() else "PLAN WEEK %d  ▶" % s.week,
		show_ending if s.is_over() else _start_planning, true))
## A dialogue scene (docs/slice-spec.md §11.4): portrait, speaker, line, then
## either Continue or the choices. Calls on_done(vars) when the scene ends.
func show_dialogue(node: String, on_done: Callable) -> void:
	where = "dialogue " + node
	dlg_runner = Dialogue.Runner.new(Story.load_nodes(), Story.context(s))
	dlg_runner.start(node)
	dlg_done = on_done
	dlg_portrait = ""
	dlg_log.clear()
	_dialogue_step()


func _dialogue_step() -> void:
	var ev: Dictionary = dlg_runner.next()
	if ev.type == "end":
		dlg_done.call(dlg_runner.vars)
		return
	_clear()
	_set_backdrop(_liberation())
	var col := _page()
	var speaker: String = ev.get("speaker", "")
	if Story.PORTRAITS.has(speaker):
		dlg_portrait = _portrait_for(speaker)
	var row := _hbox(26)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	# Left: the subject's photo taped to the file, name typed under it.
	if dlg_portrait != "" and ResourceLoader.exists(dlg_portrait):
		var left := _vbox(6)
		left.add_child(_polaroid(load(dlg_portrait), Vector2(270, 270), -2.5))
		var who := dlg_portrait.get_file().get_slice("_", 0).to_upper()
		left.add_child(_typed("SUBJECT: " + who, 20, C_INK_SOFT))
		left.add_child(_spacer(10))
		var me := _hbox(10)
		me.add_child(_polaroid(load(OP_FACES["You"]), Vector2(110, 110), 3.0))
		me.add_child(_typed("AGENT:\nYOU", 20, C_INK_SOFT))
		left.add_child(me)
		row.add_child(left)
	# Right: the transcript card.
	var talk := _paper_panel("card")
	talk.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tc := _vbox(12)
	talk.add_child(tc)
	row.add_child(_on_desk(talk, "transcript", true))
	tc.add_child(_typed("TRANSCRIPT · WEEK %d" % s.week, 20, C_INK_SOFT))
	# Earlier lines of the scene stay on the card, faded, newest last.
	var keep := 4 if ev.type == "line" else 2
	for old in dlg_log.slice(maxi(0, dlg_log.size() - keep)):
		var who_old: String = old.speaker
		var t_old: String = old.text if who_old == "" else Text.SPEAKERS.get(who_old, who_old.capitalize()).to_upper() + ": " + old.text
		var lo := _typed(t_old, 20, Color(C_INK_SOFT, 0.75), true)
		tc.add_child(lo)
	if ev.type == "line":
		dlg_log.append({"speaker": speaker, "text": ev.text})
		if speaker == "":
			tc.add_child(_typed(ev.text, 22, C_INK, true))
		else:
			tc.add_child(_typed(Text.SPEAKERS.get(speaker, speaker.capitalize()).to_upper() + ":", 22, C_STAMP))
			tc.add_child(_label(ev.text, 26, C_INK, true))
		var go := _ink_button("CONTINUE  ▶", _dialogue_step, true)
		go.size_flags_horizontal = Control.SIZE_SHRINK_END
		go.custom_minimum_size = Vector2(300, 72)
		col.add_child(go)
	else:
		tc.add_child(_typed("WHAT DO YOU SAY?", 22, C_STAMP))
		for o in ev.options:
			var b := _button("▶  " + o.text, func():
				dlg_runner.choose(o.index)
				_dialogue_step(), 0)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 64)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_paper_button(b, "manila")
			tc.add_child(b)


## The painted portrait that fits the moment: Teodor's face follows where he
## stands with you; cold (regime) light while the district is cold, warm once it turns.
func _portrait_for(speaker: String) -> String:
	var tone := "warm" if _liberation() >= 0.35 else "cold"
	var mood := ""
	match speaker:
		"TEODOR":
			var t: Dictionary = s.teodor
			mood = "betrayed" if t.state == "gone" else ("resolved" if t.state == "ally" and t.path == "trust" else "guarded")
		"MARA":
			mood = "worried" if s.heat >= 5 else "calm"
		"KESH":
			mood = "scared" if s.heat >= 5 else "suspicious"
	var path := "res://assets/portraits/%s_%s_%s.png" % [speaker.to_lower(), mood, tone]
	return path if ResourceLoader.exists(path) else Story.PORTRAITS[speaker]
## Skips to the end of the scenes on screen, taking the first choice each time (screenshots only).
func _dialogue_finish_fast() -> void:
	while dlg_runner != null:
		var r = dlg_runner
		var ev: Dictionary = r.next()
		if ev.type == "choices":
			r.choose(ev.options[0].index)
		elif ev.type == "end":
			dlg_runner = null
			dlg_done.call(r.vars)  # may start the next scene and set dlg_runner again
			if dlg_runner == r:
				dlg_runner = null


func show_ending() -> void:
	where = "ending"
	Sfx.fx("paper")
	_clear()
	var e: Dictionary = Text.ENDINGS[s.ending]
	_set_backdrop(e.grade)
	var box := _vbox(16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(box)
	box.add_child(_stamp("CASE CLOSED", C_STAMP, 26, -4.0))
	box.add_child(_typed(e.title.to_upper(), 48, C_FG))
	box.add_child(_label(e.text, 21, C_FG, true))
	box.add_child(_spacer(6))
	box.add_child(_label("Week %d  ·  Legitimacy %d  ·  Kills %d  ·  Broadcast %s  ·  Teodor: %s" % [
		mini(s.week, RunState.MAX_WEEKS), s.legitimacy, s.kills, "aired" if s.broadcast_aired else "never aired",
		_teodor_status()], 17, C_MUTED, true))
	var again := _ink_button("NEW RUN  ▶", _new_run, true)
	again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again.custom_minimum_size.x = 280
	box.add_child(again)
	if FileAccess.file_exists(SAVE_PATH):   # first time this ending shows (the save goes now)
		PlayStats.log_event("run_end", {"ending": s.ending, "week": s.week, "legitimacy": s.legitimacy, "kills": s.kills})
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------- flow ----------

func _new_run() -> void:
	s = RunState.create(int(Time.get_unix_time_from_system()) % 1000000)
	Rules.start_week(s)
	plan.clear()
	FightSave.clear()
	_save()
	PlayStats.log_event("run_start", {"seed": s.run_seed})
	show_district()


func _continue_run() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d == null:
		_new_run()
		return
	s = RunState.from_dict(_fix_ints(d))
	# Left mid-fight: straight back into the Signal Box at the saved turn (QoL step 4).
	var fight := FightSave.load_for(s.run_seed, s.week)
	if not fight.is_empty() and not s.is_over():
		var at = RunState.from_dict(_fix_ints(fight.run))
		Engine.set_meta("mission", {"state": at, "entries": fight.entries,
			"teodor_before": fight.teodor_before, "params": fight.params, "resume": fight.battle})
		get_tree().change_scene_to_file("res://scenes/tactical.tscn")
		return
	_load_plan()
	if s.is_over():
		show_ending()
	else:
		show_district()


func _start_planning() -> void:
	plan.clear()
	show_district()


func _end_week() -> void:
	var entries := plan.values()
	var err := Rules.validate(s, entries)
	if err != "":
		message.text = err
		return
	# Teodor's scenes play first: what you say in them decides the plan's choice.
	_play_scenes(Story.pre_scenes(s, entries), entries, func(): _resolve(entries))


func _resolve(entries: Array) -> void:
	var before: Dictionary = s.teodor.duplicate(true)
	if entries.any(func(e): return e.action == "signal_box"):
		# M5: pay and run diversions, play the mission, finish the week after.
		Rules.begin_resolve(s, entries)
		if not s.is_over():
			Engine.set_meta("mission", {"state": s, "entries": entries, "teodor_before": before,
				"params": Rules.mission_params(s, entries)})
			_save_plan()  # "Quit and replan the week" brings this plan back, not an older half of it
			get_tree().change_scene_to_file("res://scenes/tactical.tscn")
			return
	else:
		Rules.resolve_week(s, entries)
	_after_resolve(entries, before)


## Back from the Signal Box with its result: finish the week it interrupted.
func _after_mission(m: Dictionary) -> void:
	s = m.state
	Rules.finish_resolve(s, m.entries, m.result)
	_after_resolve(m.entries, m.teodor_before)


func _after_resolve(entries: Array, before: Dictionary) -> void:
	plan.clear()
	_save()
	PlayStats.log_event("week_done", {"week": s.week - 1, "heat": s.heat, "cash": s.cash,
		"legitimacy": s.legitimacy, "ops": s.operatives.size(), "actions": entries.map(func(e): return e.action)})
	var beats := Story.post_beats(before, s.teodor, entries).map(func(n): return {"node": n})
	_play_scenes(beats, [], show_report)


## Plays scenes one after another, then calls `done`. A scene tied to a plan
## entry writes its `choice` into that entry.
func _play_scenes(scenes: Array, entries: Array, done: Callable) -> void:
	if scenes.is_empty():
		done.call()
		return
	var scene: Dictionary = scenes.pop_front()
	show_dialogue(scene.node, func(vars: Dictionary):
		if scene.has("entry") and vars.has("choice"):
			entries[scene.entry].choice = str(vars.choice)
		_play_scenes(scenes, entries, done))


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s.to_dict()))
	_save_plan()


## Keeps the half-made plan for this week (empty plan = no file).
func _save_plan() -> void:
	if plan.is_empty() or s == null:
		if FileAccess.file_exists(PLAN_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PLAN_PATH))
		return
	var f := FileAccess.open(PLAN_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"week": s.week, "plan": plan}))


func _load_plan() -> void:
	plan.clear()
	if not FileAccess.file_exists(PLAN_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PLAN_PATH))
	if d is Dictionary and int(d.get("week", -1)) == s.week and d.get("plan") is Dictionary:
		var ready: Array = s.ready_operatives()
		for k in d.plan:
			var e = _fix_ints(d.plan[k])
			if e is Dictionary and Text.ACTIONS.has(e.get("action", "")) and int(k) in ready:
				plan[int(k)] = e


## Phone lifecycle (standards: focus-out saves, back button goes back, deferred).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if s != null and not s.is_over():
				_save()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_go_back.call_deferred()


## For REPORT A BUG: where the run is, so a report needs no questions back.
func bug_state() -> String:
	var out := "screen %s" % where
	if where == "title" and left_from != "":
		out += " (came from %s)" % left_from
	if overlay:
		out += " + picker"
	if s != null:
		out += " | week %d, heat %d, cash %d, supplies %d, parts %d, legit %d, ops %d, planned %d" % [
			s.week, s.heat, s.cash, s.supplies, s.parts, s.legitimacy, s.operatives.size(), plan.size()]
		if s.ending != "":
			out += ", ending " + s.ending
	return out


## Back: closes the action picker, else leaves the run for the title (saved), else quits.
func _go_back() -> void:
	if SettingsSheet.close_open(self):
		return
	if overlay:
		_close_overlay()
	elif on_title:
		get_tree().quit()
	else:
		if s != null and not s.is_over():
			_save()
		show_title()


## JSON turns every number into a float; the rules expect ints.
func _fix_ints(v):
	if v is Dictionary:
		var out := {}
		for k in v:
			out[k] = _fix_ints(v[k])
		return out
	if v is Array:
		return v.map(func(x): return _fix_ints(x))
	if v is float and v == floor(v):
		return int(v)
	return v


# ---------- picking an action ----------

func _pick_action(op: int) -> void:
	var who: Dictionary = s.operatives[op]
	var list := _ledger_box()
	# What the other operatives already use this week: their actions get a
	# PLANNED stamp and their costs come off what's left to spend.
	var planned := {}
	var cash_left: int = s.cash
	var sup_left: int = s.supplies
	for k in plan:
		if k == op:
			continue
		var pa: String = plan[k].action
		planned[pa] = planned.get(pa, 0) + 1
		cash_left -= int(Rules.ACTIONS[pa].cash)
		sup_left -= int(Rules.ACTIONS[pa].supplies)
	# Header: the red week stamp, who it's for, and Cancel (no row lost at the bottom).
	# Case-file header: the operative's photo taped on, the week stamp, a typed
	# file line, a faded CONFIDENTIAL stamp, and CLOSE.
	var head := _hbox(16)
	list.add_child(head)
	var face: String = OP_FACES.get(who.name, "")
	if face != "":
		head.add_child(_polaroid(load(face), Vector2(62, 62), -4.0))
	var titles := _vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(_stamp("WEEK %d · ORDERS" % s.week, C_STAMP, 30, -2.0))
	var for_lbl := _label("FILE 07 · RAIL YARDS CELL · FOR: " + ("YOU" if who.is_you else who.name.to_upper()), 20, C_INK_SOFT)
	for_lbl.add_theme_font_override("font", TYPE_FONT)
	titles.add_child(for_lbl)
	var conf := _stamp("CONFIDENTIAL", C_STAMP, 24, 6.0)
	conf.modulate = Color(1, 1, 1, 0.55)
	head.add_child(conf)
	# Cancel as a red ink "close file" stamp you tap.
	var cancel := _ink_button("✕  CLOSE", _close_overlay, false)
	cancel.custom_minimum_size = Vector2(170, 64)
	cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cancel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 11)
	list.add_child(grid)
	var story: Array[String] = []
	for a in Rules.available_actions(s):
		if a in STORY_ACTIONS:
			story.append(a)
		else:
			grid.add_child(_on_desk(_action_tile(a, op, planned.get(a, 0), cash_left, sup_left), a))
	# Story beats look different from chores: a full-width card with the face.
	for a in story:
		list.add_child(_on_desk(_action_tile(a, op, planned.get(a, 0), cash_left, sup_left, true), a))


## One action on the ledger: woodcut icon (or Teodor's face), typewriter title,
## a short line, effect chips, and stamps for RISK / PLANNED / can't afford.
func _action_tile(a: String, op: int, n_planned: int, cash_left: int, sup_left: int, story := false) -> Button:
	var info: Dictionary = Text.ACTIONS[a]
	var card: Dictionary = Text.ACTION_CARDS.get(a, {"line": info.desc, "fx": []})
	var cost: Dictionary = Rules.ACTIONS[a]
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 108 if story else 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# An index card (a manila folder card for story beats) on the desk.
	var paper_tex: Texture2D = load(DOSSIER % ("manila" if story else "card"))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxTexture.new()
		sb.texture = paper_tex
		sb.set_texture_margin_all(26)
		sb.set_content_margin_all(0)
		sb.modulate_color = Color(0.86, 0.84, 0.8) if st == "pressed" else (Color(1, 0.97, 0.93) if st in ["hover", "focus"] else Color.WHITE)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func(): _after_action(op, a))
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	b.add_child(pad)
	var row := _hbox(12)
	pad.add_child(row)
	if story:
		row.add_child(_polaroid(load(TEODOR_FACE), Vector2(78, 78), -3.0))
	else:
		var pic := TextureRect.new()
		pic.texture = load(ACTION_ICON % ACTION_ICONS.get(a, "res_people"))
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(80, 80)
		pic.material = _round_mat()
		row.add_child(pic)
	var col := _vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	# Title row: typewriter title, then what it costs (ink tag with the resource icon).
	var title_row := _hbox(10)
	col.add_child(title_row)
	var title := _label(info.title, 26, C_INK)
	title.add_theme_font_override("font", TYPE_FONT)
	title_row.add_child(title)
	if cost.cash > 0:
		title_row.add_child(_chip("%d cash" % cost.cash, "cost", "res_cash"))
	if cost.supplies > 0:
		title_row.add_child(_chip("%d supplies" % cost.supplies, "cost", "res_supplies"))
	var line := _label(card.line, 20, C_INK_SOFT)
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.clip_text = true
	col.add_child(line)
	# Chips wrap onto a second line when text is LARGE/HUGE (Settings) instead of running off.
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for fx in card.fx:
		chips.add_child(_chip(fx[0], fx[1]))
	if chips.get_child_count() > 0:
		col.add_child(chips)
	_mouse_through(pad)
	# The card grows with its text (big TEXT SIZE), never clips the heat/fail chips.
	var base_h: float = b.custom_minimum_size.y
	var fit := func(): b.custom_minimum_size.y = maxf(base_h, pad.get_combined_minimum_size().y)
	pad.minimum_size_changed.connect(fit)
	fit.call_deferred()
	# Stamps in the top-right corner, stacked.
	var stamps: Array = []
	if a in RISKY_ACTIONS:
		stamps.append(["RISK", C_STAMP])
	if n_planned > 0:
		stamps.append(["PLANNED" + (" ×%d" % n_planned if n_planned > 1 else ""), C_INK])
	var broke := ""
	if int(cost.cash) > cash_left:
		broke = "NO CASH"
	elif int(cost.supplies) > sup_left:
		broke = "NO SUPPLIES"
	if broke != "":
		stamps.append([broke, C_INK])
		b.disabled = true
		pad.modulate = Color(1, 1, 1, 0.45)
	for i in stamps.size():
		var st := _stamp(stamps[i][0], stamps[i][1], 20, -7.0 + 4.0 * i)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.anchor_left = 1.0
		st.anchor_right = 1.0
		st.offset_left = -st.custom_minimum_size.x - 10
		st.offset_right = -10
		st.offset_top = 6 + 40 * i
		st.offset_bottom = st.offset_top + st.custom_minimum_size.y
		b.add_child(st)
	return b


## Effect chip: green +good, red heat with the flame icon, red-outlined bad,
## ink cost tag with the resource icon, ink-outlined info. Colour is never the
## only cue (icon or outline style too; standards colour rule).
func _chip(text: String, kind: String, icon := "") -> PanelContainer:
	if kind == "heat":
		icon = "res_heat"
	var p := PanelContainer.new()
	var fg: Color
	if kind in ["good", "heat", "cost"]:
		# Label-maker tape: tinted strip, raised pale letters.
		var tb := StyleBoxTexture.new()
		tb.texture = load(DOSSIER % "tape_label")
		tb.texture_margin_left = 6
		tb.texture_margin_right = 6
		tb.texture_margin_top = 4
		tb.texture_margin_bottom = 4
		tb.modulate_color = {"good": Color("2e6a34"), "heat": Color("a8261d"), "cost": Color("2a2622")}[kind]
		tb.content_margin_left = 10 if icon == "" else 5
		tb.content_margin_right = 11
		tb.content_margin_top = 1
		tb.content_margin_bottom = 1
		p.add_theme_stylebox_override("panel", tb)
		fg = Color("f3efe4")
	else:
		# Typed note boxed in pen: red for a downside, ink for plain info.
		fg = C_STAMP if kind == "bad" else C_INK
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(fg, 0.8)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		p.add_theme_stylebox_override("panel", sb)
	var h := _hbox(5)
	p.add_child(h)
	if icon != "":
		var t := TextureRect.new()
		t.texture = load(ACTION_ICON % icon)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(24, 24)
		t.material = _round_mat()
		h.add_child(t)
	var l := _label(text, 20, fg)
	if kind in ["good", "heat", "cost"]:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
	else:
		l.add_theme_font_override("font", TYPE_FONT)
	h.add_child(l)
	return p


## A photo in a white instant-print frame, tilted, with tape across the top.
## Returns a plain holder so containers keep the tilt.
func _polaroid(tex: Texture2D, pic_size: Vector2, tilt: float) -> Control:
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f4f1ea")
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(2, 3)
	frame.add_theme_stylebox_override("panel", sb)
	var fsize := pic_size + Vector2(10, 22)
	frame.size = fsize
	frame.position = Vector2(4, 6)
	frame.pivot_offset = fsize / 2.0
	frame.rotation_degrees = tilt
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = tex
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.clip_contents = true
	pic.position = Vector2(5, 5)
	pic.size = pic_size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	var tape := _fastener("tape")
	tape.position = Vector2(fsize.x / 2.0 - 26, -9)
	frame.add_child(tape)
	var holder := Control.new()
	holder.custom_minimum_size = fsize + Vector2(8, 10)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)
	return holder


## What holds a card to the page: a paper clip, a strip of masking tape or a staple.
func _fastener(kind: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(DOSSIER % {"clip": "clip", "tape": "tape_mask", "staple": "staple"}[kind])
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size = {"clip": Vector2(16, 42), "tape": Vector2(54, 18), "staple": Vector2(34, 10)}[kind]
	return t


## A rubber stamp: typewriter caps in a rough box, tilted. Wrapped in a plain
## Control because containers reset their children's rotation.
func _stamp(text: String, col: Color, size: int, tilt: float) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TYPE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.0)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", sb)
	var m := ShaderMaterial.new()
	m.shader = INK_SHADER
	m.set_shader_parameter("ink", load(DOSSIER % "ink_noise"))
	l.material = m
	# Measure with the font itself: a Label outside the tree reports a stale minimum size.
	var tf: Font = TYPE_FONT
	var sz := Vector2(tf.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 20,
		tf.get_height(size) + 2)
	var holder := Control.new()
	holder.custom_minimum_size = sz + Vector2(6, 8)
	holder.add_child(l)
	l.size = sz
	l.position = Vector2(3, 4)
	l.pivot_offset = sz / 2.0
	l.rotation_degrees = tilt
	return holder


func _mouse_through(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_mouse_through(c)


## The action picker's sheet: a full-screen ledger page on paper. Scrolls only
## if a late week has more actions than fit, with a "more" hint at the bottom.
func _ledger_box() -> VBoxContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	# The graffiti wall, then the carried stack of pages on it.
	_wall_and_sheets(overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 58)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 18)
	overlay.add_child(margin)
	var v := _vbox(0)
	margin.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var box := _vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var more := _label("▼  more below  ▼", 20, C_STAMP)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.visible = false
	v.add_child(more)
	var bar := scroll.get_v_scroll_bar()
	var upd := func(): more.visible = bar.max_value - bar.page > bar.value + 4.0
	bar.changed.connect(upd)
	bar.value_changed.connect(func(_v): upd.call())
	return box


## Lays a card on the desk: a soft shadow under it, a paper clip on top, and a
## small crooked tilt that's the same every time for the same action. The holder
## takes the grid slot because containers reset a child's rotation.
func _on_desk(card: Control, key: String, fill_v := false, max_tilt := 3.5) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = card.get_combined_minimum_size()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if fill_v:
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Panels size from their content: keep the slot as big as the card wants.
	card.minimum_size_changed.connect(func(): holder.custom_minimum_size = card.get_combined_minimum_size())
	var tilt := (float(absi(key.hash()) % 100) / 100.0 - 0.5) * 2.0 * max_tilt
	var shadow := Panel.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.1, 0.07, 0.04, 0.32)
	ssb.set_corner_radius_all(4)
	shadow.add_theme_stylebox_override("panel", ssb)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Control in [shadow, card]:
		holder.add_child(c)
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.rotation_degrees = tilt
	# Scatter: nudge each card off the grid a few pixels, same every time.
	var jx := float((absi(key.hash()) / 7) % 13 - 6)
	var jy := float((absi(key.hash()) / 13) % 7 - 3)
	for side in ["offset_left", "offset_right"]:
		card.set(side, card.get(side) + jx)
	for side in ["offset_top", "offset_bottom"]:
		card.set(side, card.get(side) + jy)
	shadow.offset_left = 3 + jx
	shadow.offset_top = 5 + jy
	shadow.offset_right = 4 + jx
	shadow.offset_bottom = 6 + jy
	holder.resized.connect(func():
		card.pivot_offset = card.size / 2.0
		shadow.pivot_offset = shadow.size / 2.0)
	var hsh := absi(key.hash())
	var kind: String = ["clip", "tape", "staple"][hsh % 3]
	var f := _fastener(kind)
	match kind:
		"clip":
			f.position = Vector2(16 + hsh % 24, -9)
			f.rotation_degrees = -6.0
		"tape":
			f.pivot_offset = f.size / 2.0
			f.position = Vector2(4, 6) - f.size / 2.0
			f.rotation_degrees = -40.0 + float(hsh % 10)
		"staple":
			f.position = Vector2(12, 8)
			f.rotation_degrees = -20.0 + float(hsh % 12)
	# On the holder, not the card: a container card would stretch it to fill.
	holder.add_child(f)
	return holder



## Behind every dossier page: the graffiti wall, then a dog-eared stack of carried
## sheets, each a little crooked (Duff, Nov 25: "too boring", "more worn ... often carried").
func _wall_and_sheets(parent: Control) -> void:
	var wall := TextureRect.new()
	wall.texture = load(DOSSIER % ("wall" if ResourceLoader.exists(DOSSIER % "wall") else "desk"))
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.modulate = Color(0.7, 0.68, 0.66)
	parent.add_child(wall)
	# [inset x, inset y, tilt, shade]: the back sheets peek out under the top one.
	for sh in [[54.0, 24.0, 2.4, 0.72], [48.0, 18.0, -1.8, 0.84], [42.0, 12.0, -0.6, 1.0]]:
		var sheet := TextureRect.new()
		sheet.texture = load(DOSSIER % "sheet")
		sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sheet.stretch_mode = TextureRect.STRETCH_SCALE
		sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
		sheet.offset_left = sh[0]
		sheet.offset_top = sh[1]
		sheet.offset_right = -sh[0]
		sheet.offset_bottom = -sh[1]
		sheet.rotation_degrees = sh[2]
		sheet.modulate = Color(sh[3], sh[3] * 0.98, sh[3] * 0.94)
		sheet.flip_h = sh[2] > 0.0
		sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.resized.connect(func(): sheet.pivot_offset = sheet.size / 2.0)
		parent.add_child(sheet)

## A full-screen dossier page: the desk, the torn sheet, and a column inside it.
## Used by the planner, report and dialogue screens (Duff, Nov 25: "Dossier look everywhere").
func _page() -> VBoxContainer:
	for side in ["left", "right", "top", "bottom"]:
		screen.add_theme_constant_override("margin_" + side, 0)
	var page := Control.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(page)
	_wall_and_sheets(page)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 58)
	margin.add_theme_constant_override("margin_right", 58)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	page.add_child(margin)
	var col := _vbox(14)
	margin.add_child(col)
	return col


## A surveillance print of the Rail Yards pinned to the file: the street render,
## regime fading into liberated as the district turns (the old full-screen backdrop).
func _street_photo() -> Control:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f4f1ea")
	sb.set_content_margin_all(7)
	sb.content_margin_bottom = 4
	frame.add_theme_stylebox_override("panel", sb)
	var v := _vbox(2)
	frame.add_child(v)
	var photo := Control.new()
	photo.custom_minimum_size = Vector2(0, 110)
	photo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	photo.clip_contents = true
	v.add_child(photo)
	var lib := _liberation()
	for pair in [["res://assets/ui/backdrop_regime.png", 1.0], ["res://assets/ui/backdrop_liberated.png", lib]]:
		var t := TextureRect.new()
		t.texture = load(pair[0])
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.modulate.a = pair[1]
		photo.add_child(t)
	v.add_child(_typed("RAIL YARDS · SURVEILLANCE · WK %d" % s.week, 20, C_INK_SOFT))
	return frame


## A woodcut frame with something written into its blank screen (the TV studio or
## the phone in the report). `screen` is the blank area as fractions of the image.
func _framed(tex_path: String, screen: Rect2, inner: Control) -> AspectRatioContainer:
	var tex: Texture2D = load(tex_path)
	var arc := AspectRatioContainer.new()
	arc.ratio = float(tex.get_width()) / tex.get_height()
	arc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arc.custom_minimum_size = Vector2(0, 250)
	var box := Control.new()
	arc.add_child(box)
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(t)
	var m := MarginContainer.new()
	m.anchor_left = screen.position.x
	m.anchor_top = screen.position.y
	m.anchor_right = screen.end.x
	m.anchor_bottom = screen.end.y
	m.clip_contents = true
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 6)
	box.add_child(m)
	m.add_child(inner)
	return arc


## Typewriter text (Special Elite), never under MIN_TEXT.
func _typed(text: String, size: int, col: Color, wrap := false) -> Label:
	var l := _label(text, size, col, wrap)
	l.add_theme_font_override("font", TYPE_FONT)
	return l


## A sheet of card or manila paper to put content on (pair with _on_desk for the tilt).
func _paper_panel(kind: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxTexture.new()
	sb.texture = load(DOSSIER % kind)
	sb.set_texture_margin_all(26)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	return p


## Restyles a Button as paper (card or manila) with ink text.
func _paper_button(b: Button, kind: String) -> void:
	var tex: Texture2D = load(DOSSIER % kind)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.modulate_color = Color(0.86, 0.84, 0.8) if st == "pressed" else (Color(0.8, 0.78, 0.74, 0.7) if st == "disabled" else (Color(1, 0.97, 0.93) if st in ["hover", "focus"] else Color.WHITE))
		b.add_theme_stylebox_override(st, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, C_INK)
	b.add_theme_color_override("font_disabled_color", C_INK_SOFT)
	b.add_theme_font_override("font", TYPE_FONT)


## An ink-stamp button in typewriter caps: outlined red (filled = red ink pad with
## paper letters, for the screen's main action).
func _ink_button(text: String, cb: Callable, filled: bool) -> Button:
	var b := _button(text, cb, 0)
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_override("font", TYPE_FONT)
	b.add_theme_font_size_override("font_size", 28 if filled else 26)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var a := 1.0 if filled else 0.0
		if st == "pressed":
			a = 0.8 if filled else 0.18
		sb.bg_color = Color(C_STAMP, a)
		sb.border_color = C_STAMP.darkened(0.2) if filled else C_STAMP
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(st, sb)
	var fg := C_PAPER if filled else C_STAMP
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	if not filled:  # blotchy ink only on outline stamps; a filled pad stays readable
		var m := ShaderMaterial.new()
		m.shader = INK_SHADER
		m.set_shader_parameter("ink", load(DOSSIER % "ink_noise"))
		b.material = m
	return b


func _round_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROUND_SHADER
	return m


func _after_action(op: int, a: String) -> void:
	_close_overlay()
	var entry := {"action": a, "op": op, "zone": "", "choice": ""}
	if Rules.ACTIONS[a].zone:
		var box := _overlay_box(Text.ACTIONS[a].get("zone", "Where?"))
		for zone in Rules.ZONES:
			var r := Rules.reading(s, zone)
			box.add_child(_card_button(Text.ZONE_NAMES[zone], "%s (%s)" % [r.label, r.certainty],
				func(): _after_zone(entry, zone)))
		box.add_child(_button("Cancel", _close_overlay, 0))
		return
	_after_zone(entry, "")


func _after_zone(entry: Dictionary, zone: String) -> void:
	_close_overlay()
	entry.zone = zone
	var needs_choice: bool = Text.CHOICES.has(entry.action)
	if needs_choice:
		var box := _overlay_box("How?")
		for c in Text.CHOICES[entry.action]:
			box.add_child(_card_button(c.title, c.desc, func(): _commit(entry, c.id)))
		box.add_child(_button("Cancel", _close_overlay, 0))
		return
	_commit(entry, "")


func _commit(entry: Dictionary, choice: String) -> void:
	_close_overlay()
	entry.choice = choice
	var trial := plan.duplicate()
	trial[entry.op] = entry
	var err := Rules.validate(s, trial.values())
	if err != "":
		show_district()
		message.text = err
		return
	plan = trial
	show_district()


# ---------- widgets ----------

func _top_bar() -> Control:
	# Case-file header: week stamp + file line, then the cell's resources as
	# typed tags with their woodcut icons; heat on label-maker tape.
	var row := _hbox(18)
	row.add_child(_stamp("WEEK %d / %d" % [s.week, RunState.MAX_WEEKS], C_STAMP, 30, -2.0))
	var file := _typed("FILE 07", 20, C_INK_SOFT)
	file.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(file)
	var heat_kind := "good" if s.heat < 3 else "heat"
	row.add_child(_chip("HEAT %d · %s" % [s.heat, Text.heat_label(s.heat)], heat_kind, "res_heat"))
	for st in [["res_cash", "CASH", s.cash], ["res_supplies", "SUPPLIES", s.supplies],
			["res_parts", "PARTS", s.parts], ["res_legitimacy", "LEGIT.", s.legitimacy]]:
		var h := _hbox(5)
		var ic := TextureRect.new()
		ic.texture = load(ACTION_ICON % st[0])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(30, 30)
		ic.material = _round_mat()
		h.add_child(ic)
		var v := _typed("%s %d" % [st[1], st[2]], 20, C_INK)
		v.add_theme_font_size_override("font_size", 20)  # the strip stays one line at any TEXT SIZE
		h.add_child(v)
		row.add_child(h)
	file.add_theme_font_size_override("font_size", 20)
	return row


func _zone_card(zone: String) -> Control:
	var r := Rules.reading(s, zone)
	var card := _paper_panel("card")
	var col := _vbox(4)
	card.add_child(col)
	var top := _hbox(10)
	col.add_child(top)
	var name_l := _typed(Text.ZONE_NAMES[zone].to_upper(), 26, C_INK)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	top.add_child(_stamp(r.certainty.to_upper(), C_STAMP if r.certainty == "Rumor" else C_INK, 20, 4.0))
	col.add_child(_label("Mood: %s" % r.label, 22, C_INK))
	var eyes := "unknown (Listen to find out)" if int(r.attention) < 0 else ("●".repeat(int(r.attention)) if int(r.attention) > 0 else "none")
	col.add_child(_label("Regime eyes: %s" % eyes, 20, C_INK_SOFT))
	return card


func _teodor_line() -> Control:
	var tag := _paper_panel("manila")
	var h := _hbox(12)
	tag.add_child(h)
	var face := TextureRect.new()
	face.texture = load(_portrait_for("TEODOR"))
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.custom_minimum_size = Vector2(52, 52)
	h.add_child(face)
	var l := _typed("TEODOR, dock foreman: %s" % _teodor_status(), 20, C_INK, true)
	h.add_child(l)
	return tag


func _teodor_status() -> String:
	var t: Dictionary = s.teodor
	match t.state:
		"unmet":
			return "you haven't met"
		"met":
			return "met, not with you yet" + (" (you know about the skimming)" if t.knows_skim else "")
		"ally":
			return "with you (%s)" % {"trust": "trusts you", "leverage": "blackmailed", "lie": "believes your promise"}[t.path]
		_:
			return "gone"


func _operative_row(i: int, used: int) -> Control:
	var o: Dictionary = s.operatives[i]
	var row := _hbox(12)
	var face: String = OP_FACES.get(o.name, "")
	var pic := TextureRect.new()
	pic.texture = load(face if face != "" else ACTION_ICON % "res_people")
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = Vector2(56, 56)
	if face == "":
		pic.material = _round_mat()
	row.add_child(pic)
	var name_lbl := _typed(o.name.to_upper(), 22, C_INK)
	name_lbl.custom_minimum_size = Vector2(96, 0)
	row.add_child(name_lbl)
	if plan.has(i):
		var e: Dictionary = plan[i]
		var txt: String = Text.ACTIONS[e.action].title
		if e.get("zone", "") != "":
			txt += " · " + Text.ZONE_NAMES[e.zone]
		if e.get("choice", "") != "":
			for c in Text.CHOICES.get(e.action, []):
				if c.id == e.choice:
					txt += " · " + c.title
		var b := _button(txt, func(): _pick_action(i), 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_paper_button(b, "card")
		var ic: String = ACTION_ICONS.get(e.action, "")
		if ic != "":
			b.icon = load(ACTION_ICON % ic)
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 40)
		row.add_child(b)
		var x := _ink_button("✕", func(): plan.erase(i); show_district(), false)
		x.custom_minimum_size = Vector2(64, 64)
		row.add_child(x)
	else:
		var b := _button("Assign a job  ▶" if used < 3 else "Resting", func(): _pick_action(i), 0)
		b.disabled = used >= 3
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_paper_button(b, "manila")
		row.add_child(b)
	return row


func _stat(title: String, value: String, col := C_FG) -> Control:
	var v := _vbox(0)
	v.add_child(_label(title, 13, C_MUTED))
	v.add_child(_label(value, 21, col))
	return v


func _overlay_box(title: String) -> VBoxContainer:
	_close_overlay()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var p := _panel(C_PANEL, C_LINE, 2)
	p.custom_minimum_size = Vector2(min(get_viewport_rect().size.x - 40, 980), 0)
	center.add_child(p)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, min(get_viewport_rect().size.y - 60, 640))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var box := _vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	box.add_child(_label(title, 24, C_FG, true))
	return box


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _card_button(title: String, desc: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = title + "\n" + desc
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(440, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _button(text: String, cb: Callable, min_w: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 72)   # thumb-sized on a phone (standards/06)
	b.add_theme_font_size_override("font_size", _fs(24))
	b.pressed.connect(cb)
	return b


## A font size scaled by the TEXT SIZE setting (plain size when Settings isn't loaded, e.g. tests).
func _fs(size: int) -> int:
	var st := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
	return st.fs(size) if st else size


func _label(text: String, font_size: int, col: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", _fs(maxi(font_size, MIN_TEXT)))
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _panel(bg: Color, border := Color(0, 0, 0, 0), width := 0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _vbox(sep: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func _hbox(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _clear() -> void:
	_close_overlay()
	on_title = false
	for side in ["left", "right", "top", "bottom"]:
		screen.add_theme_constant_override("margin_" + side, 20)
	for c in screen.get_children():
		screen.remove_child(c)
		c.queue_free()


func _backdrop(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(t)
	return t


## How liberated the district feels: drives the street behind the UI.
func _liberation() -> float:
	var avg := (int(s.zones.dorms.sentiment) + int(s.zones.depot.sentiment)) / 2.0
	return clampf((avg - 25.0) / 40.0, 0.0, 1.0)


func _set_backdrop(t: float) -> void:
	backdrop_free.modulate.a = t


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 22
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("232830")
	normal.border_color = C_LINE
	normal.set_border_width_all(1)
	normal.set_content_margin_all(12)
	var hover := normal.duplicate()
	hover.bg_color = Color("2e343e")
	var pressed := normal.duplicate()
	pressed.bg_color = C_ACCENT.darkened(0.4)
	var disabled := normal.duplicate()
	disabled.bg_color = Color("16191d")
	for st in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["focus", hover]]:
		th.set_stylebox(st[0], "Button", st[1])
	th.set_color("font_color", "Button", C_FG)
	th.set_color("font_disabled_color", "Button", C_MUTED.darkened(0.3))
	th.set_font_size("font_size", "Button", 22)
	return th


# ---------- screenshots for review (-- --shots) ----------

func _take_shots() -> void:
	var dir := "res://docs/renders/ui"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	show_title()
	await _snap(dir + "/1_title.png")
	s = RunState.create(11)
	Rules.start_week(s)
	plan.clear()
	for e in Policies.careful_plan(s):
		plan[e.op] = e
	show_district()
	await _snap(dir + "/2_district.png")
	_pick_action(s.ready_operatives()[0])
	await _snap(dir + "/3_pick_action.png")
	_close_overlay()
	_end_week()
	if dlg_runner != null:
		_dialogue_step()  # past Teodor's first line, onto the scene proper
	await _snap(dir + "/4_dialogue.png")
	_dialogue_finish_fast()
	await _snap(dir + "/5_report.png")
	while not s.is_over():
		Rules.resolve_week(s, Policies.careful_plan(s))
	show_ending()
	await _snap(dir + "/6_ending.png")
	get_tree().quit()


func _snap(path: String) -> void:
	for i in range(4):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
