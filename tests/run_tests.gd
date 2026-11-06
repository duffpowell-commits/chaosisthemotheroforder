extends SceneTree
## Headless rule tests. Run before every push:
##   godot --headless --path . --script tests/run_tests.gd
## Exits with code 1 if any test fails.

const RunState = preload("res://scripts/sim/run_state.gd")
const Rules = preload("res://scripts/sim/rules.gd")
const Policies = preload("res://scripts/sim/policies.gd")
const Dialogue = preload("res://scripts/dialogue/dialogue.gd")
const Story = preload("res://scripts/dialogue/story.gd")
const Battle = preload("res://scripts/tactics/battle.gd")

var failures := 0
var passed := 0


func _init() -> void:
	for m in get_method_list():
		if m.name.begins_with("test_"):
			var before := failures
			call(m.name)
			if failures == before:
				passed += 1
			else:
				print("FAIL ", m.name)
	print("%d passed, %d failed" % [passed, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  assertion failed: ", msg)


func fresh(seed_value := 1) -> RunState:
	var s := RunState.create(seed_value)
	Rules.start_week(s)
	return s


func act(action: String, op: int, zone := "", choice := "") -> Dictionary:
	return {"action": action, "op": op, "zone": zone, "choice": choice}


# ---------- tests ----------

func test_sentiment_bands() -> void:
	check(Rules.sentiment_state(15) == "Hostile", "15 is Hostile")
	check(Rules.sentiment_state(16) == "Wary", "16 is Wary")
	check(Rules.sentiment_state(35) == "Wary", "35 is Wary")
	check(Rules.sentiment_state(36) == "Sympathetic", "36 is Sympathetic")
	check(Rules.sentiment_state(60) == "Sympathetic", "60 is Sympathetic")
	check(Rules.sentiment_state(61) == "Ready", "61 is Ready")


func test_validate_limits() -> void:
	var s := fresh()
	check(Rules.validate(s, []) == "", "empty plan is legal")
	s.operatives.append({"name": "X", "is_you": false, "is_teodor": false, "out_weeks": 0, "dead": false})
	var four := [act("listen", 0, "dorms"), act("listen", 1, "depot"), act("lay_low", 2), act("scavenge", 3)]
	check(Rules.validate(s, four) != "", "4 actions rejected")
	check(Rules.validate(s, [act("listen", 0, "dorms"), act("lay_low", 0)]) != "", "same operative twice rejected")
	check(Rules.validate(s, [act("aid", 0)]) != "", "aid without zone rejected")
	s.supplies = 1
	check(Rules.validate(s, [act("aid", 0, "dorms")]) != "", "aid without supplies rejected")
	check(Rules.validate(s, [act("signal_box", 0)]) != "", "signal box locked in week 1")


func test_costs_paid() -> void:
	var s := fresh()
	var cash: int = s.cash
	var supplies: int = s.supplies
	Rules.resolve_week(s, [act("aid", 0, "dorms"), act("expose", 1, "depot")])
	check(s.supplies == supplies - 2, "aid costs 2 supplies")
	check(s.cash <= cash - 1, "expose costs 1 cash")


func test_listen_confirms_intel() -> void:
	var s := fresh()
	check(Rules.reading(s, "dorms").certainty == "Rumor", "starts as rumor")
	Rules.resolve_week(s, [act("listen", 0, "dorms")])
	# Certainty decays by one at the start of the next week: confirmed becomes likely.
	check(Rules.reading(s, "dorms").certainty == "Likely", "listened zone is still likely next week")
	check(Rules.reading(s, "depot").certainty == "Rumor", "other zone stays rumor")


func test_determinism_and_save_roundtrip() -> void:
	var a := fresh(42)
	var b := fresh(42)
	for i in range(3):
		var plan := Policies.careful_plan(a)
		Rules.resolve_week(a, plan.duplicate(true))
		Rules.resolve_week(b, plan.duplicate(true))
	check(a.to_dict() == b.to_dict(), "same seed and plans give the same state")
	var c := RunState.from_dict(a.to_dict())
	check(c.to_dict() == a.to_dict(), "save and load round-trips")
	var plan2 := Policies.careful_plan(a)
	Rules.resolve_week(a, plan2.duplicate(true))
	Rules.resolve_week(c, plan2.duplicate(true))
	check(a.to_dict() == c.to_dict(), "a loaded run continues identically")


func test_capture_at_heat_nine() -> void:
	var s := fresh()
	s.heat = 9
	Rules.resolve_week(s, [])
	check(s.ending == "captured", "heat 9 ends in capture")


func test_window_closes_after_week_six() -> void:
	var s := fresh()
	s.week = 6
	s.heat = 0
	Rules.resolve_week(s, [])
	check(s.ending == "window_closes", "week 6 ending without a win closes the window")


func test_teodor_lie_path_and_reveal() -> void:
	var s := fresh()
	Rules.resolve_week(s, [act("see_teodor", 0)])
	check(s.teodor.state == "met", "first visit meets him")
	s.heat = 0
	Rules.resolve_week(s, [act("see_teodor", 0, "", "lie")])
	check(s.teodor.state == "ally" and s.teodor.lied, "the lie recruits him")
	check("strike" in Rules.available_actions(s), "lie path unlocks the strike")
	s.week = 5
	s.heat = 0
	Rules.resolve_week(s, [])
	check(s.teodor.state == "lost", "unconfessed lie is found out in week 5")


func test_teodor_blackmail_needs_dirt() -> void:
	var s := fresh()
	Rules.resolve_week(s, [act("see_teodor", 0)])
	s.heat = 0
	Rules.resolve_week(s, [act("see_teodor", 0, "", "blackmail")])
	check(s.teodor.state == "met", "blackmail fails without knowing about the skimming")
	s.teodor.knows_skim = true
	s.heat = 0
	Rules.resolve_week(s, [act("see_teodor", 0, "", "blackmail")])
	check(s.teodor.state == "ally" and s.teodor.loyalty == "low", "blackmail recruits him with low loyalty")


func test_teodor_trust_needs_aid() -> void:
	var s := fresh()
	Rules.resolve_week(s, [act("see_teodor", 0)])
	s.heat = 0
	Rules.resolve_week(s, [act("see_teodor", 0, "", "honest")])
	check(s.teodor.state == "met", "honesty alone isn't enough")
	s.zones.depot.aid_runs = 2
	s.heat = 0
	Rules.resolve_week(s, [act("see_teodor", 0, "", "honest")])
	check(s.teodor.state == "ally" and s.teodor.path == "trust", "aid plus honesty earns his trust")


func test_rally_endings() -> void:
	var s := fresh()
	s.zones.dorms.sentiment = 70
	s.zones.depot.sentiment = 70
	s.broadcast_aired = true
	s.legitimacy = 3
	Rules.resolve_week(s, [act("rally", 0)])
	check(s.ending == "district_turns", "broadcast + legitimacy turns the district")
	var v := fresh()
	v.zones.dorms.sentiment = 70
	v.zones.depot.sentiment = 70
	v.kills = 3
	Rules.resolve_week(v, [act("rally", 0)])
	check(v.ending == "occupiers", "3+ kills makes you occupiers")
	var w := fresh()
	w.zones.dorms.sentiment = 70
	w.zones.depot.sentiment = 70
	Rules.resolve_week(w, [act("rally", 0)])
	check(w.ending == "" and w.zones.dorms.sentiment < 70, "a rally without proof gets crushed")


func test_diversion_moves_attention() -> void:
	var moved := 0
	for seed_value in range(1, 40):
		var s := fresh(seed_value)
		s.zones.depot.attention = 2
		s.zones.dorms.attention = 1
		Rules.resolve_week(s, [act("diversion", 0, "dorms")])
		if s.report[0].begins_with("The Signal Fire worked"):
			moved += 1
	check(moved > 15 and moved < 39, "diversion usually works but not always (%d/39)" % moved)


# ---------- dialogue (M3) ----------

const SAMPLE := """
# A comment.
== start
TEODOR: You again.
> He doesn't look up.
if knows -> knows
* Tell him straight. -> straight
* [if knows] Mention the cargo. -> cargo
== straight
set choice = "honest"
YOU: Straight, then.
-> END
== cargo
set choice = "blackmail"
-> END
== knows
TEODOR: You've been asking around.
-> start_menu
== start_menu
* Mention the cargo. -> cargo
"""


## Plays a node, picking choices by their text prefix. Returns [lines, vars].
func play(nodes: Dictionary, node: String, ctx: Dictionary, picks: Array = []) -> Array:
	var r := Dialogue.Runner.new(nodes, ctx)
	r.start(node)
	var lines := []
	var guard := 0
	while guard < 200:
		guard += 1
		var ev: Dictionary = r.next()
		if ev.type == "end":
			break
		if ev.type == "line":
			lines.append("%s|%s" % [ev.speaker, ev.text])
		elif ev.type == "choices":
			var want: String = picks.pop_front() if not picks.is_empty() else ""
			var idx := 0
			for o in ev.options:
				if want != "" and o.text.begins_with(want):
					idx = o.index
			r.choose(idx)
	return [lines, r.vars]


func test_dialogue_parse_and_lines() -> void:
	var nodes := Dialogue.parse(SAMPLE)
	check(Dialogue.lint(nodes).is_empty(), "sample lints clean: %s" % [Dialogue.lint(nodes)])
	var out := play(nodes, "start", {"knows": false}, ["Tell"])
	check(out[0][0] == "TEODOR|You again.", "speaker line parsed")
	check(out[0][1] == "|He doesn't look up.", "narration has no speaker")
	check(out[0][2] == "YOU|Straight, then.", "choice jumps to its node")
	check(out[1].get("choice") == "honest", "set stores a value")


func test_dialogue_conditions_hide_choices() -> void:
	var nodes := Dialogue.parse(SAMPLE)
	var r := Dialogue.Runner.new(nodes, {"knows": false})
	r.start("start")
	r.next()
	r.next()
	var ev: Dictionary = r.next()
	check(ev.type == "choices" and ev.options.size() == 1, "conditional choice hidden when false")
	var out := play(nodes, "start", {"knows": true}, ["Mention"])
	check(out[0][2] == "TEODOR|You've been asking around.", "if-jump taken when true")
	check(out[1].get("choice") == "blackmail", "jumped branch reaches its choice")


func test_dialogue_lint_catches_bad_targets() -> void:
	var nodes := Dialogue.parse("== a\n-> nowhere\n")
	check(not Dialogue.lint(nodes).is_empty(), "missing target reported")


func test_teodor_script_lints() -> void:
	var nodes := Story.load_nodes()
	var problems := Dialogue.lint(nodes, Story.context_keys())
	check(problems.is_empty(), "teodor.dlg lints clean: %s" % [problems])
	for n in Story.ALL_NODES:
		check(nodes.has(n), "teodor.dlg has node " + n)


## Plays a week the way the UI does: pre-scenes fill the choices, then resolve, then beats.
func story_week(s: RunState, plan: Array, picks: Array = []) -> Array:
	var nodes := Story.load_nodes()
	for scene in Story.pre_scenes(s, plan):
		var out := play(nodes, scene.node, Story.context(s), picks)
		plan[scene.entry].choice = out[1].get("choice", plan[scene.entry].choice)
	var before: Dictionary = s.teodor.duplicate(true)
	Rules.resolve_week(s, plan)
	return Story.post_beats(before, s.teodor, plan)


func test_story_trust_path() -> void:
	var s := fresh()
	story_week(s, [act("see_teodor", 0)])
	check(s.teodor.state == "met", "meeting scene meets him")
	s.zones.depot.aid_runs = 2
	s.heat = 0
	story_week(s, [act("see_teodor", 0)], ["Tell him"])
	check(s.teodor.state == "ally" and s.teodor.path == "trust", "honest talk after aid earns trust")
	check("strike" in Rules.available_actions(s), "trust unlocks the strike")


func test_story_leverage_path_and_betrayal() -> void:
	var s := fresh()
	story_week(s, [act("see_teodor", 0)])
	var r := Dialogue.Runner.new(Story.load_nodes(), Story.context(s))
	r.start(Story.pre_scenes(s, [act("see_teodor", 0)])[0].node)
	var shown := []
	while true:
		var ev: Dictionary = r.next()
		if ev.type != "line":
			if ev.type == "choices":
				for o in ev.options:
					shown.append(o.text)
			break
	check(not shown.any(func(t): return t.begins_with("You know about the cargo")), "no blackmail option without the dirt")
	s.teodor.knows_skim = true
	s.heat = 0
	story_week(s, [act("see_teodor", 0)], ["You know about the cargo"])
	check(s.teodor.state == "ally" and s.teodor.loyalty == "low", "blackmail recruits him, low loyalty")
	var betrayed := false
	for seed_value in range(1, 30):
		var t := fresh(seed_value)
		t.teodor = s.teodor.duplicate(true)
		t.operatives.append({"name": "Teodor", "is_you": false, "is_teodor": true, "out_weeks": 0, "dead": false})
		t.heat = 8  # a quiet week cools it to 7 before the raid check
		var beats := story_week(t, [])
		if t.teodor.betrayed:
			betrayed = true
			check(beats.has("betrayal"), "betrayal plays its scene")
			break
	check(betrayed, "low loyalty at Heat 7 can betray you")


func test_story_lie_found_out() -> void:
	var s := fresh()
	story_week(s, [act("see_teodor", 0)])
	s.heat = 0
	story_week(s, [act("see_teodor", 0)], ["I can get your brother out"])
	check(s.teodor.state == "ally" and s.teodor.lied, "the lie recruits him")
	s.week = 5
	s.heat = 0
	var beats := story_week(s, [])
	check(s.teodor.state == "lost", "unconfessed lie found out in week 5")
	check(beats.has("found_out"), "found-out scene plays")


func test_story_lie_confession() -> void:
	var stayed := 0
	var left := 0
	for seed_value in range(1, 40):
		var s := fresh(seed_value)
		story_week(s, [act("see_teodor", 0)])
		s.heat = 0
		story_week(s, [act("see_teodor", 0)], ["I can get your brother out"])
		s.heat = 0
		var beats := story_week(s, [act("confess", 0)])
		if s.teodor.state == "ally":
			stayed += 1
			check(beats.has("confess_stayed"), "stayed scene plays")
		else:
			left += 1
			check(beats.has("confess_left"), "left scene plays")
	check(stayed > 0 and left > 0, "confession can go either way (%d stayed, %d left)" % [stayed, left])


# ---------- tactics (M4) ----------

## A bare 14x14 yard with the given cover tiles: {Vector2i: Battle.HALF/FULL/HIGH}.
func yard(cover := {}) -> Battle:
	var b := Battle.new()
	b.setup_empty(1)
	for p in cover:
		b.set_tile(p, cover[p])
	return b


func test_tactics_hit_table() -> void:
	var b := yard({Vector2i(5, 6): Battle.HALF, Vector2i(8, 6): Battle.FULL})
	# Open ground, straight shot.
	check(b.chance_from(Vector2i(5, 12), Vector2i(2, 2)) == 65, "open shot is 65%")
	# Target at (5,5) hides behind a crate at (5,6) from a shooter to the south.
	check(b.chance_from(Vector2i(5, 12), Vector2i(5, 5)) == 45, "half cover is -20")
	check(b.chance_from(Vector2i(8, 12), Vector2i(8, 5)) == 25, "full cover is -40")
	# Same target, shooter due east: the crate faces south, so it's flanked.
	check(b.chance_from(Vector2i(12, 5), Vector2i(5, 5)) == 85, "flanked cover is +20")
	b.set_tile(Vector2i(5, 12), Battle.HIGH)
	check(b.chance_from(Vector2i(5, 12), Vector2i(5, 5)) == 55, "high ground is +10")
	check(Battle.clamp_chance(140) == 95 and Battle.clamp_chance(-30) == 5, "clamped to 5-95")


func test_tactics_los() -> void:
	var b := yard({Vector2i(5, 5): Battle.FULL, Vector2i(9, 5): Battle.HALF})
	check(not b.line_of_sight(Vector2i(5, 2), Vector2i(5, 8)), "a container blocks sight")
	check(b.line_of_sight(Vector2i(9, 2), Vector2i(9, 8)), "a crate doesn't block sight")
	check(b.chance_from(Vector2i(5, 2), Vector2i(5, 8)) == 0, "no sight, no shot")
	check(b.line_of_sight(Vector2i(0, 13), Vector2i(13, 0)), "open diagonal is clear")


func test_tactics_move_range() -> void:
	var b := yard({Vector2i(6, 5): Battle.FULL})
	var u := b.add_unit("You", Battle.US, Vector2i(5, 5))
	var one := b.reachable(u, 1)
	check(one.has(Vector2i(9, 5)) == false, "a container blocks the straight path")
	check(one.has(Vector2i(5, 1)), "4 tiles per AP")
	check(not one.has(Vector2i(5, 0)), "not 5 tiles on 1 AP")
	check(b.reachable(u, 2).has(Vector2i(5, 13)), "8 tiles on 2 AP")
	check(not one.has(Vector2i(6, 5)), "can't stand on a container")
	b.add_unit("G", Battle.REGIME, Vector2i(5, 4))
	check(not b.reachable(u, 1).has(Vector2i(5, 4)), "can't stand on a unit")
	check(b.move(u, Vector2i(5, 7)) and u.ap == 1 and u.pos == Vector2i(5, 7), "move costs 1 AP")
	check(not b.move(u, Vector2i(13, 13)), "too far is refused")


func test_tactics_shoot_and_down() -> void:
	var b := yard()
	var me := b.add_unit("You", Battle.US, Vector2i(5, 12))
	var g := b.add_unit("G", Battle.REGIME, Vector2i(5, 2))
	var hits := 0
	for i in range(200):
		g.hp = 2
		me.ap = 2
		if b.shoot(me, g):
			hits += 1
	check(hits > 100 and hits < 160, "65%% shots land about 65%% of the time (%d/200)" % hits)
	g.hp = 1
	me.ap = 2
	b.rng.seed = 3
	while g.hp > 0:
		me.ap = 2
		b.shoot(me, g)
	check(not g.alive(), "0 HP is down")
	check(b.winner() == Battle.US, "no guards left is a win")


func test_tactics_ai_patrol_then_alert() -> void:
	var b := yard({Vector2i(4, 4): Battle.FULL, Vector2i(5, 4): Battle.FULL, Vector2i(6, 4): Battle.FULL})
	var me := b.add_unit("You", Battle.US, Vector2i(5, 12))
	var g := b.add_unit("G", Battle.REGIME, Vector2i(5, 1))
	g.route = [Vector2i(5, 1), Vector2i(12, 1)]
	b.end_turn()  # regime acts: it can't see you behind the containers
	check(g.state == Battle.PATROL, "unseen, the guard patrols")
	check(g.pos != Vector2i(5, 1), "the patrol moves")
	check(me.hp == 2, "no shots while patrolling")
	b.alert_all("test")
	check(g.state == Battle.ALERT, "a shot or a sighting alerts every guard")


func test_tactics_ai_takes_cover_and_retreats() -> void:
	var b := yard({Vector2i(9, 7): Battle.HALF})
	b.add_unit("You", Battle.US, Vector2i(9, 13)).hp = 99  # survives the test
	var g := b.add_unit("G", Battle.REGIME, Vector2i(11, 5))
	b.alert_all("test")
	b.rng.seed = 7
	b.end_turn()
	check(g.pos == Vector2i(9, 6) or b.cover_against(g.pos, Vector2i(9, 13)) > 0, "alerted guard moves into cover (at %s)" % g.pos)
	b.add_unit("Mara", Battle.US, Vector2i(1, 13)).hp = 99  # 2 v 2: outnumbered enough to run
	var w := b.add_unit("W", Battle.REGIME, Vector2i(3, 6))
	w.hp = 1
	w.state = Battle.ALERT
	b.end_turn()
	b.end_turn()
	check(w.state == Battle.RETREAT, "a wounded guard retreats when not outnumbering you")
	check(w.pos.y < 6 or w.escaped, "retreat runs for the north edge")


func test_tactics_skirmish_deterministic_and_both_outcomes() -> void:
	var a = Battle.play_auto(11)
	var b = Battle.play_auto(11)
	check(a.winner() == b.winner() and a.turn == b.turn, "same seed, same fight")
	var wins := 0
	var losses := 0
	for i in range(60):
		var r: String = Battle.play_auto(i + 1).winner()
		if r == Battle.US:
			wins += 1
		elif r == Battle.REGIME:
			losses += 1
	check(wins > 0 and losses > 0, "skirmish is winnable and losable (%d won, %d lost)" % [wins, losses])


func test_tactics_wounded_guard_holds_when_ahead() -> void:
	var b := yard()
	b.add_unit("You", Battle.US, Vector2i(9, 13))
	b.add_unit("G1", Battle.REGIME, Vector2i(2, 2))
	var w := b.add_unit("W", Battle.REGIME, Vector2i(11, 2))
	w.hp = 1
	b.alert_all("test")
	b.end_turn()
	check(w.state == Battle.ALERT, "2 v 1: the wounded guard keeps fighting")


# ---------- the Signal Box mission (M5) ----------

## Every script the game needs compiles. A parse error otherwise shows up as
## "Nil" errors while the count still says everything passed.
func test_scripts_compile() -> void:
	for path in ["res://scripts/tactics/battle.gd", "res://scripts/sim/rules.gd",
			"res://scripts/sim/run_state.gd", "res://scripts/tactics/tactical.gd",
			"res://scripts/ui/game.gd", "res://scripts/dialogue/dialogue.gd"]:
		var sc: GDScript = load(path)
		check(sc != null and sc.can_instantiate(), "%s compiles" % path)


## A bare mission yard: the box at its spot, one squad member, no guards.
func mission_yard(legit := 0) -> Battle:
	var b := yard({Battle.BOX_POS: Battle.BOX})
	b.mission = true
	b.sight = Battle.MISSION_SIGHT
	b.box = Battle.BOX_POS
	b.legitimacy = legit
	return b


func test_mission_setup() -> void:
	var b = Battle.create_mission({"guards": 6, "legitimacy": 2, "seed": 3,
		"squad": [{"name": "You", "op": 0, "is_you": true}, {"name": "Mara", "op": 1, "is_you": false}]})
	check(b.alive_units(Battle.US).size() == 2, "two of ours")
	check(b.alive_units(Battle.REGIME).size() == 6, "six guards")
	check(b.units.filter(func(u): return u.wavering).size() == 1, "exactly one Wavering guard")
	check(b.tile(Battle.BOX_POS) == Battle.BOX, "the box is on the map")
	for u in b.alive_units(Battle.US):
		check(u.pos.y == Battle.H - 1, "squad starts on the south edge")
	check(b.winner() == "" and not b.is_over(), "mission doesn't end on its own")


func test_mission_noise_alarm_reinforcements() -> void:
	var b := mission_yard()
	var you := b.add_unit("You", Battle.US, Vector2i(7, 12))
	var g := b.add_unit("G", Battle.REGIME, Vector2i(7, 4))
	g.state = Battle.ALERT
	b.add_noise(3, you.pos)
	b.add_noise(3, you.pos)
	b.add_noise(3, you.pos)
	check(b.noise == 9 and not b.alarm, "9 noise, no alarm yet")
	b.add_noise(3, you.pos)
	check(b.noise == 10 and b.alarm, "noise caps at 10 and the alarm sounds")
	var before := b.units.size()
	b.end_turn()
	check(b.units.size() == before, "reinforcements not there after one turn")
	b.end_turn()
	check(b.units.size() == before + Battle.REINFORCEMENTS, "3 reinforcements after two turns")


func test_mission_noise_wakes_nearby_patrols() -> void:
	var b := mission_yard()
	var you := b.add_unit("You", Battle.US, Vector2i(7, 12))
	var near := b.add_unit("Near", Battle.REGIME, Vector2i(7, 10))
	var far := b.add_unit("Far", Battle.REGIME, Vector2i(7, 3))
	b.add_noise(Battle.NOISE_SUBDUE, you.pos)
	check(near.state == Battle.ALERT, "a guard 2 tiles away hears a takedown")
	check(far.state == Battle.PATROL, "a guard 9 tiles away doesn't")
	var shooter := b.add_unit("Kesh", Battle.US, Vector2i(2, 12))
	shooter.ap = 2
	b.shoot(shooter, near)
	check(b.noise == Battle.NOISE_SUBDUE + Battle.NOISE_SHOT, "a shot adds 3 noise")


func test_mission_sneak_is_hard_to_spot() -> void:
	var b := mission_yard()
	var you := b.add_unit("You", Battle.US, Vector2i(7, 12))
	var g := b.add_unit("G", Battle.REGIME, Vector2i(7, 4))
	g.route = [Vector2i(7, 4), Vector2i(7, 4)]
	check(not b.sneak(you, Vector2i(7, 5)), "can't sneak further than one move")
	check(b.sneak(you, Vector2i(7, 8)), "sneak 4 tiles")
	check(you.ap == 0 and you.hidden, "sneak costs both AP and hides you")
	b.end_turn()
	check(g.state == Battle.PATROL, "a patrol 4 tiles away misses a sneaking unit")
	b.move(you, Vector2i(6, 8))
	b.end_turn()
	check(g.state == Battle.ALERT, "a normal move in sight gets spotted")


func test_mission_subdue() -> void:
	var b := mission_yard()
	var you := b.add_unit("You", Battle.US, Vector2i(7, 12))
	var g := b.add_unit("G", Battle.REGIME, Vector2i(9, 12))
	check(not b.subdue(you, g), "can't subdue from 2 tiles")
	b.move(you, Vector2i(8, 12))
	check(b.subdue(you, g), "subdue from next to them")
	check(not g.alive() and g.subdued and b.kills == 0, "down, not dead")
	check(b.noise == Battle.NOISE_SUBDUE, "a takedown makes 1 noise")


func test_mission_overwatch() -> void:
	var b := mission_yard()
	b.rng.seed = 2
	var you := b.add_unit("You", Battle.US, Vector2i(7, 12))
	var g := b.add_unit("G", Battle.REGIME, Vector2i(7, 5))
	g.state = Battle.ALERT
	check(b.overwatch(you) and you.ap == 0, "overwatch spends the turn")
	b.move(g, Vector2i(7, 7))
	check(not you.overwatch, "the reaction shot is used up")
	check(b.log.any(func(l): return l.begins_with("You reacts")), "you fire at the moving guard")


func test_mission_upload_takes_two_turns_and_trips_alarm() -> void:
	var b := mission_yard()
	var you := b.add_unit("You", Battle.US, Battle.BOX_POS + Vector2i(0, 1))
	check(b.do_upload(you), "start the upload next to the box")
	check(not b.do_upload(you), "only one upload per turn")
	check(b.upload == 1 and not b.alarm, "half done, quiet")
	b.end_turn()
	check(b.do_upload(you) and b.upload == 2, "second turn finishes it")
	check(b.alarm, "the broadcast trips the alarm")
	var far := b.add_unit("Kesh", Battle.US, Vector2i(2, 12))
	check(not b.can_upload(far), "can't upload from across the yard")


func test_mission_persuade() -> void:
	var b := mission_yard(6)
	var you := b.add_unit("You", Battle.US, Vector2i(7, 12))
	you.is_you = true
	var mara := b.add_unit("Mara", Battle.US, Vector2i(6, 12))
	var g := b.add_unit("G", Battle.REGIME, Vector2i(7, 10))
	g.wavering = true
	var plain := b.add_unit("P", Battle.REGIME, Vector2i(9, 11))
	check(b.persuade_chance() == 95, "40 + 10 x 6 clamps to 95")
	check(not b.can_persuade(mara, g), "only you can persuade")
	check(not b.can_persuade(you, plain), "only a Wavering guard")
	g.pos = Vector2i(7, 8)
	check(not b.can_persuade(you, g), "not from 4 tiles")
	g.pos = Vector2i(7, 9)
	var ok := false
	for seed_value in range(1, 6):  # 95%: at least one of these rolls lands
		b.rng.seed = seed_value
		if b.rng.randi_range(1, 100) <= 95:
			b.rng.seed = seed_value
			ok = b.persuade(you, g)
			break
	check(ok, "persuaded at 95%")
	check(g.side == Battle.US and g.defected and b.defections == 1, "he's on your side now")
	check(not g.wavering, "one try per guard")
	var b2 := mission_yard(-10)
	var you2 := b2.add_unit("You", Battle.US, Vector2i(7, 12))
	you2.is_you = true
	var g2 := b2.add_unit("G", Battle.REGIME, Vector2i(7, 10))
	g2.wavering = true
	check(b2.persuade_chance() == 5, "floor of 5%")


func test_mission_bleed_out_and_stabilize() -> void:
	var b := mission_yard()
	var you := b.add_unit("You", Battle.US, Vector2i(7, 13))
	you.is_you = true
	var mara := b.add_unit("Mara", Battle.US, Vector2i(3, 13))
	var kesh := b.add_unit("Kesh", Battle.US, Vector2i(11, 13))
	for u in [mara, kesh]:
		u.hp = 0
		u.bleed = Battle.BLEED_TURNS
	b.end_turn()
	check(mara.downed() and kesh.downed(), "still alive after one of your turns")
	b.move(you, Vector2i(4, 13))
	check(b.stabilize(you) and mara.stabilized, "stabilize next to Mara")
	b.end_turn()
	check(kesh.dead and not mara.dead, "Kesh bleeds out on the second turn; Mara holds")
	check(b.leave(you), "leave from the south edge")
	check(b.is_over(), "nobody left on the map")
	var r: Dictionary = b.mission_result()
	check(r.dead == ["Kesh"] and r.hurt == ["Mara"] and r.out == ["You"], "result: %s" % r)
	check(not r.aired and not r.you_dead, "no broadcast, you made it")


func test_mission_left_behind_dies() -> void:
	var b := mission_yard()
	var you := b.add_unit("You", Battle.US, Vector2i(7, 13))
	you.is_you = true
	var mara := b.add_unit("Mara", Battle.US, Vector2i(3, 12))
	mara.hp = 0
	mara.bleed = 2
	mara.stabilized = true
	you.hp = 0
	you.bleed = 2
	check(b.is_over(), "everyone down")
	var r: Dictionary = b.mission_result()
	check(r.you_dead and r.dead.size() == 2, "nobody got out to carry them")


func test_mission_params_from_run() -> void:
	var s := fresh()
	s.week = 3
	s.zones.depot.attention = 2
	var plan := [act("signal_box", 1), act("scavenge", 2)]
	var m := Rules.mission_params(s, plan)
	check(m.guards == 6, "4 + 2 depot attention")
	var names: Array = m.squad.map(func(x): return x.name)
	check(names == ["You", "Mara"], "the op lead plus everyone not busy, you first: %s" % [names])
	s.diversion_zone = "dorms"
	check(Rules.signal_box_guards(s) == 4, "diversion to the dorms pulls 2 off")


func test_mission_result_feeds_the_run() -> void:
	var s := fresh()
	var l0 := s.legitimacy
	var h0 := s.heat
	var d0: int = s.zones.dorms.sentiment
	Rules.apply_mission(s, act("signal_box", 0), {"aired": true, "kills": 0, "defections": 1,
		"dead": ["Mara"], "hurt": ["Kesh"], "out": ["You"]})
	check(s.broadcast_aired, "broadcast aired")
	check(s.zones.dorms.sentiment == d0 + 20, "sentiment up")
	check(s.legitimacy == l0 + 3, "clean (+2) and a defector (+1)")
	check(s.heat == h0 + 1, "a clean op still adds 1 heat")
	check(s.operatives[1].dead and s.operatives[2].out_weeks == 2, "Mara's gone, Kesh is out 2 weeks")
	var s2 := fresh()
	Rules.apply_mission(s2, act("signal_box", 0), {"aired": false, "kills": 2, "defections": 0,
		"dead": [], "hurt": [], "out": ["You"]})
	check(not s2.broadcast_aired and s2.kills == 2, "failed, 2 kills on the books")
	check(s2.legitimacy == -2 and s2.heat == h0 + 3, "kills cost Legitimacy and heat")
	var s3 := fresh()
	Rules.apply_mission(s3, act("signal_box", 0), {"aired": true, "dead": ["You"]})
	check(s3.ending == "captured", "dying in the depot ends the run")


func test_mission_split_resolve_matches_auto() -> void:
	# Same seed, same plan: resolve_week and begin+finish land in the same place.
	var plan := [act("scavenge", 0), act("aid", 1, "dorms")]
	var a := fresh(9)
	a.supplies = 4
	var b := fresh(9)
	b.supplies = 4
	Rules.resolve_week(a, plan)
	Rules.begin_resolve(b, plan)
	Rules.finish_resolve(b, plan)
	check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "split resolve is identical")
