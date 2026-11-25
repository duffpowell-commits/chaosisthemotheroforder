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

const SAVE_PATH := "user://run.save"
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
	"seize": "res_heat",
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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_clear()
	var box := _vbox(18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(box)
	box.add_child(_label("CHAOS IS THE MOTHER OF ORDER", 44, C_FG))
	box.add_child(_label("The Rail Yards  ·  District 7, Port Varga", 22, C_MUTED))
	box.add_child(_spacer(12))
	box.add_child(_label("Six weeks. One district. The Continuity Government is watching.", 20, C_FG, true))
	box.add_child(_spacer(12))
	var row := _hbox(14)
	box.add_child(row)
	# Playable in 10 s (standards/08): one tap drops you into the Signal Box fight. A run's
	# weeks come after, from New run.
	var fight := _button("Fight now", _fight_now, 260)
	fight.add_theme_color_override("font_color", C_ACCENT)
	row.add_child(fight)
	if FileAccess.file_exists(SAVE_PATH):
		row.add_child(_button("Continue", _continue_run, 220))
	row.add_child(_button("New run", _new_run, 220))
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
	_clear()
	_set_backdrop(_liberation())
	var col := _vbox(12)
	screen.add_child(col)
	col.add_child(_top_bar())
	var body := _hbox(16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	# Left: the two zones (propaganda-layer paper cards).
	var zones := _vbox(12)
	zones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zones.size_flags_stretch_ratio = 1.0
	body.add_child(zones)
	for zone in Rules.ZONES:
		zones.add_child(_zone_card(zone))
	zones.add_child(_teodor_line())
	# Right: this week's plan.
	var right := _panel(C_PANEL)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.15
	body.add_child(right)
	var pcol := _vbox(10)
	right.add_child(pcol)
	pcol.add_child(_label("THIS WEEK", 16, C_MUTED))
	pcol.add_child(_label("Give up to 3 operatives a job. Everyone else rests.", 17, C_FG, true))
	var used := plan.size()
	for i in s.ready_operatives():
		pcol.add_child(_operative_row(i, used))
	for i in range(s.operatives.size()):
		var o: Dictionary = s.operatives[i]
		if not o.dead and o.out_weeks > 0:
			pcol.add_child(_label("%s — out for %d more week%s" % [o.name, o.out_weeks, "" if o.out_weeks == 1 else "s"], 16, C_MUTED))
	message = _label("", 17, C_ACCENT, true)
	pcol.add_child(message)
	var end := _button("End week %d" % s.week, _end_week, 0)
	end.size_flags_vertical = Control.SIZE_SHRINK_END
	pcol.add_child(end)


func show_report() -> void:
	_clear()
	_set_backdrop(_liberation())
	var col := _vbox(14)
	screen.add_child(col)
	col.add_child(_label("WEEK %d REPORT" % (s.week - (0 if s.is_over() else 1)), 16, C_MUTED))
	var row := _hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	# State TV: the woodcut propaganda layer.
	var tv := _panel(C_PAPER, C_INK, 3)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tv)
	var tvc := _vbox(10)
	tv.add_child(tvc)
	var slug := _panel(C_RED)
	slug.add_child(_label("CONTINUITY NEWS 24", 20, C_PAPER))
	tvc.add_child(slug)
	for line in Text.regime_bulletin(s):
		tvc.add_child(_label(line, 18, C_INK, true))
	# Pirate radio: what actually happened.
	var radio := _panel(Color("0a0703"), C_ACCENT, 2)
	radio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(radio)
	var rc := _vbox(10)
	radio.add_child(rc)
	rc.add_child(_label("UNBROKEN RADIO · what really happened", 18, C_ACCENT))
	if s.report.is_empty():
		rc.add_child(_label("A quiet week. Nobody moved.", 18, C_FG, true))
	for line in s.report:
		rc.add_child(_label("— " + line, 18, C_FG, true))
	col.add_child(_button("See the ending" if s.is_over() else "Plan week %d" % s.week,
		show_ending if s.is_over() else _start_planning, 0))


## A dialogue scene (docs/slice-spec.md §11.4): portrait, speaker, line, then
## either Continue or the choices. Calls on_done(vars) when the scene ends.
func show_dialogue(node: String, on_done: Callable) -> void:
	dlg_runner = Dialogue.Runner.new(Story.load_nodes(), Story.context(s))
	dlg_runner.start(node)
	dlg_done = on_done
	dlg_portrait = ""
	_dialogue_step()


func _dialogue_step() -> void:
	var ev: Dictionary = dlg_runner.next()
	if ev.type == "end":
		dlg_done.call(dlg_runner.vars)
		return
	_clear()
	_set_backdrop(_liberation())
	var col := _vbox(14)
	screen.add_child(col)
	var speaker: String = ev.get("speaker", "")
	if Story.PORTRAITS.has(speaker):
		dlg_portrait = Story.PORTRAITS[speaker]
	var row := _hbox(18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	if dlg_portrait != "" and ResourceLoader.exists(dlg_portrait):
		var frame := _panel(C_PANEL, C_LINE, 2)
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var pic := TextureRect.new()
		pic.texture = load(dlg_portrait)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.custom_minimum_size = Vector2(300, 300)
		frame.add_child(pic)
		row.add_child(frame)
	var talk := _panel(C_PANEL, C_LINE, 2)
	talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	talk.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(talk)
	var tc := _vbox(12)
	talk.add_child(tc)
	if ev.type == "line":
		if speaker == "":
			tc.add_child(_label(ev.text, 22, C_MUTED, true))
		else:
			tc.add_child(_label(Text.SPEAKERS.get(speaker, speaker.capitalize()), 18, C_ACCENT))
			tc.add_child(_label(ev.text, 24, C_FG, true))
		var go := _button("Continue", _dialogue_step, 0)
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(go)
	else:
		tc.add_child(_label("What do you say?", 18, C_ACCENT))
		for o in ev.options:
			var b := _button(o.text, func():
				dlg_runner.choose(o.index)
				_dialogue_step(), 0)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.custom_minimum_size = Vector2(0, 64)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tc.add_child(b)


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
	_clear()
	var e: Dictionary = Text.ENDINGS[s.ending]
	_set_backdrop(e.grade)
	var box := _vbox(16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	screen.add_child(box)
	box.add_child(_label(e.title.to_upper(), 46, C_FG))
	box.add_child(_label(e.text, 21, C_FG, true))
	box.add_child(_spacer(6))
	box.add_child(_label("Week %d  ·  Legitimacy %d  ·  Kills %d  ·  Broadcast %s  ·  Teodor: %s" % [
		mini(s.week, RunState.MAX_WEEKS), s.legitimacy, s.kills, "aired" if s.broadcast_aired else "never aired",
		_teodor_status()], 17, C_MUTED, true))
	box.add_child(_button("New run", _new_run, 240))
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------- flow ----------

func _new_run() -> void:
	s = RunState.create(int(Time.get_unix_time_from_system()) % 1000000)
	Rules.start_week(s)
	plan.clear()
	_save()
	show_district()


func _continue_run() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if d == null:
		_new_run()
		return
	s = RunState.from_dict(_fix_ints(d))
	plan.clear()
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
	var head := _hbox(16)
	list.add_child(head)
	head.add_child(_stamp("WEEK %d · ORDERS" % s.week, C_STAMP, 30, -3.0))
	var for_lbl := _label("for " + ("you" if who.is_you else who.name), 24, C_INK)
	for_lbl.add_theme_font_override("font", TYPE_FONT)
	for_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(for_lbl)
	var cancel := _button("✕  Cancel", _close_overlay, 0)
	cancel.custom_minimum_size = Vector2(170, 64)
	head.add_child(cancel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	list.add_child(grid)
	var story: Array[String] = []
	for a in Rules.available_actions(s):
		if a in STORY_ACTIONS:
			story.append(a)
		else:
			grid.add_child(_action_tile(a, op, planned.get(a, 0), cash_left, sup_left))
	# Story beats look different from chores: a full-width card with the face.
	for a in story:
		list.add_child(_action_tile(a, op, planned.get(a, 0), cash_left, sup_left, true))


## One action on the ledger: woodcut icon (or Teodor's face), typewriter title,
## a short line, effect chips, and stamps for RISK / PLANNED / can't afford.
func _action_tile(a: String, op: int, n_planned: int, cash_left: int, sup_left: int, story := false) -> Button:
	var info: Dictionary = Text.ACTIONS[a]
	var card: Dictionary = Text.ACTION_CARDS.get(a, {"line": info.desc, "fx": []})
	var cost: Dictionary = Rules.ACTIONS[a]
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 112 if story else 104)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := Color("e2c9a0") if story else C_PAPER_DARK
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.darkened(0.12) if st == "pressed" else bg
		sb.border_color = C_STAMP if st in ["hover", "focus"] or story else C_INK
		sb.set_border_width_all(3 if story else 2)
		sb.set_corner_radius_all(3)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func(): _after_action(op, a))
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	b.add_child(pad)
	var row := _hbox(12)
	pad.add_child(row)
	var pic := TextureRect.new()
	pic.texture = load(TEODOR_FACE if story else ACTION_ICON % ACTION_ICONS.get(a, "res_people"))
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if story else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(96, 96) if story else Vector2(84, 84)
	pic.clip_contents = true
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
	var chips := _hbox(6)
	for fx in card.fx:
		chips.add_child(_chip(fx[0], fx[1]))
	if chips.get_child_count() > 0:
		col.add_child(chips)
	_mouse_through(pad)
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
	var bgc: Color = {"good": Color("2f5a2c"), "heat": C_STAMP, "cost": C_INK}.get(kind, Color(0, 0, 0, 0))
	var fg: Color = C_PAPER if kind in ["good", "heat", "cost"] else (C_STAMP if kind == "bad" else C_INK)
	if kind == "heat":
		icon = "res_heat"
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bgc
	sb.border_color = fg if kind in ["bad", "info"] else bgc
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 8 if icon == "" else 3
	sb.content_margin_right = 10
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	var h := _hbox(5)
	p.add_child(h)
	if icon != "":
		var t := TextureRect.new()
		t.texture = load(ACTION_ICON % icon)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(24, 24)
		h.add_child(t)
	h.add_child(_label(text, 20, fg))
	return p


## A rubber stamp: typewriter caps in a rough box, tilted. Wrapped in a plain
## Control because containers reset their children's rotation.
func _stamp(text: String, col: Color, size: int, tilt: float) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TYPE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.08)
	sb.border_color = Color(col, 0.85)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 0
	l.add_theme_stylebox_override("normal", sb)
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
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var vp := get_viewport_rect().size
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PAPER
	sb.border_color = C_INK
	sb.set_border_width_all(3)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	p.add_theme_stylebox_override("panel", sb)
	p.position = Vector2(12, 10)
	p.size = vp - Vector2(24, 20)
	overlay.add_child(p)
	var v := _vbox(0)
	p.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var box := _vbox(8)
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
	var bar := _panel(C_PANEL)
	var row := _hbox(26)
	bar.add_child(row)
	row.add_child(_stat("WEEK", "%d / %d" % [s.week, RunState.MAX_WEEKS]))
	var heat_col := C_GOOD if s.heat < 3 else (C_ACCENT if s.heat < 7 else C_RED)
	row.add_child(_stat("HEAT", "%d · %s" % [s.heat, Text.heat_label(s.heat)], heat_col))
	row.add_child(_stat("CASH", str(s.cash)))
	row.add_child(_stat("SUPPLIES", str(s.supplies)))
	row.add_child(_stat("PARTS", str(s.parts)))
	row.add_child(_stat("LEGITIMACY", str(s.legitimacy)))
	return bar


func _zone_card(zone: String) -> Control:
	var r := Rules.reading(s, zone)
	var card := _panel(C_PAPER, C_INK, 3)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := _vbox(6)
	card.add_child(col)
	col.add_child(_label(Text.ZONE_NAMES[zone].to_upper(), 22, C_INK))
	col.add_child(_label("Mood: %s" % r.label, 20, C_INK))
	var cert := _label("Intel: %s" % r.certainty, 16, C_RED if r.certainty == "Rumor" else C_INK)
	col.add_child(cert)
	var eyes := "unknown (Listen to find out)" if int(r.attention) < 0 else ("●".repeat(int(r.attention)) if int(r.attention) > 0 else "none")
	col.add_child(_label("Regime eyes: %s" % eyes, 16, C_INK))
	return card


func _teodor_line() -> Control:
	return _label("Teodor, dock foreman: %s" % _teodor_status(), 17, C_MUTED, true)


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
	var row := _hbox(10)
	var name_lbl := _label(o.name, 19, C_FG)
	name_lbl.custom_minimum_size = Vector2(110, 0)
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
		row.add_child(b)
		row.add_child(_button("✕", func(): plan.erase(i); show_district(), 56))
	else:
		var b := _button("Assign a job" if used < 3 else "Resting", func(): _pick_action(i), 0)
		b.disabled = used >= 3
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b


func _label(text: String, font_size: int, col: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", maxi(font_size, MIN_TEXT))
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
