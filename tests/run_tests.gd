extends SceneTree
## Headless rule tests. Run before every push:
##   godot --headless --path . --script tests/run_tests.gd
## Exits with code 1 if any test fails.

const RunState = preload("res://scripts/sim/run_state.gd")
const Rules = preload("res://scripts/sim/rules.gd")
const Policies = preload("res://scripts/sim/policies.gd")

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
