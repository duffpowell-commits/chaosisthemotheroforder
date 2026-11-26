extends Node
## Autoload "Stats" (standards item 7, step 2, Nov 26; from godot-game-starter's Telemetry): play
## stats, offline and private. Events go to user://events.jsonl on the phone (last 500). Nothing
## leaves the phone: there's no collector yet (ENDPOINT stays empty until Duff picks one). The
## summary rides along on REPORT A BUG, so a tester's report says how far they got and where they
## left. No login, no ids beyond a random install id, nothing personal.
##   Stats.log_event("fight_end", {"aired": true})       (static helpers below; --script runs don't register autoloads)
## Where players leave: every focus-out / close logs "left" with the screen they were on
## (title, district, report, dialogue <node>, ending, fight turn N). A launch after a run that didn't
## close cleanly logs "crash_suspected" with the last screen.

const EVENTS := "user://events.jsonl"
const RUN_FLAG := "user://running.flag"
const MAX_LINES := 500

var crashed_last_run := false
var install_id := ""
var _where := ""
var _poll := 0.0


static func log_event(name: String, props: Dictionary = {}) -> void:
	var st := _me()
	if st != null:
		st.event(name, props)


static func _me() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Stats") if tree != null else null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	install_id = _install_id()
	if FileAccess.file_exists(RUN_FLAG):
		crashed_last_run = true
		event("crash_suspected", {"last": FileAccess.get_file_as_string(RUN_FLAG)})
	event("session_start", {})
	_mark_running("boot")


## The screen the player is on now: the scene's `where` (game.gd) or the fight's turn.
func where_now() -> String:
	var cs := get_tree().current_scene
	if cs == null:
		return "boot"
	if "where" in cs:
		return str(cs.where)
	if "battle" in cs and cs.battle != null:
		return "fight turn %d" % cs.battle.turn
	return cs.name


func _process(dt: float) -> void:
	_poll -= dt
	if _poll > 0.0:
		return
	_poll = 1.0
	var w := where_now()
	if w != _where:
		_where = w
		_mark_running(w)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_left()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_mark_running(where_now())


## A clean quit (back on the title, get_tree().quit()) sends none of the leave notifications, but
## autoloads leave the tree: without this the next launch would count it as a crash.
func _exit_tree() -> void:
	_left()


## Once per leave (focus-out and pause both fire): log where, and drop the crash flag.
func _left() -> void:
	if FileAccess.file_exists(RUN_FLAG):
		event("left", {"at": where_now() if is_inside_tree() else _where})
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_FLAG))


func event(name: String, props: Dictionary = {}) -> void:
	var line := JSON.stringify({"e": name, "t": int(Time.get_unix_time_from_system()),
		"build": _build(), "id": install_id, "p": props})
	var lines: PackedStringArray = []
	if FileAccess.file_exists(EVENTS):
		lines = FileAccess.get_file_as_string(EVENTS).split("\n", false)
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines = lines.slice(lines.size() - MAX_LINES)
	var f := FileAccess.open(EVENTS, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")


func events() -> Array:
	var out := []
	if FileAccess.file_exists(EVENTS):
		for l in FileAccess.get_file_as_string(EVENTS).split("\n", false):
			var v = JSON.parse_string(l)
			if v is Dictionary:
				out.append(v)
	return out


## One line for REPORT A BUG: how far this player has got and where they leave.
func summary() -> String:
	var n := {}
	var aired := 0
	var got_out := 0
	var endings := []
	var lefts := {}
	var best_week := 0
	for ev in events():
		var e: String = ev.get("e", "")
		var p: Dictionary = ev.get("p", {}) if ev.get("p") is Dictionary else {}
		n[e] = int(n.get(e, 0)) + 1
		match e:
			"fight_end":
				aired += 1 if p.get("aired", false) else 0
				got_out += 1 if int(p.get("out", 0)) > 0 else 0
			"week_done":
				best_week = maxi(best_week, int(p.get("week", 0)))
			"run_end":
				endings.append(str(p.get("ending", "?")))
			"left":
				var at := str(p.get("at", "?")).split(" turn")[0]   # fight turn 3 -> fight
				lefts[at] = int(lefts.get(at, 0)) + 1
	var top := []
	for k in lefts:
		top.append([lefts[k], k])
	top.sort_custom(func(a, b): return a[0] > b[0])
	var left_txt := ", ".join(top.slice(0, 3).map(func(x): return "%s x%d" % [x[1], x[0]]))
	return "sessions %d, runs %d, best week %d, fights %d (aired %d, got out %d), endings %s, crashes %d, left at: %s" % [
		n.get("session_start", 0), n.get("run_start", 0), best_week, n.get("fight_end", 0), aired, got_out,
		"/".join(endings) if not endings.is_empty() else "none", n.get("crash_suspected", 0),
		left_txt if left_txt != "" else "nowhere yet"]


func _mark_running(where: String) -> void:
	var f := FileAccess.open(RUN_FLAG, FileAccess.WRITE)
	if f != null:
		f.store_string("%s %s" % [where, _build()])


func _build() -> String:
	return preload("res://scripts/config.gd").version_label()


func _install_id() -> String:
	var cfg := ConfigFile.new()
	cfg.load("user://install.cfg")
	var id: String = cfg.get_value("install", "id", "")
	if id == "":
		id = Crypto.new().generate_random_bytes(8).hex_encode()
		cfg.set_value("install", "id", id)
		cfg.save("user://install.cfg")
	return id
