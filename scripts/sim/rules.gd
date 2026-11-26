extends RefCounted
## The rules of the Rail Yards slice (docs/slice-spec.md).
## Pure functions over a run state: no scenes, no UI, fully deterministic for
## a given seed, so the simulator and tests can drive them headless.
##
## A plan is an Array of entries: {"action", "op", "zone", "choice"}.
## Flow per week: start_week() -> player plans -> resolve_week().

const RunState = preload("res://scripts/sim/run_state.gd")

const ZONES := ["dorms", "depot"]
const READY_AT := 61
const MAX_OPERATIVES := 8

## What each action costs and whether it needs a zone or a choice.
const ACTIONS := {
	"aid":        {"cash": 0, "supplies": 2, "zone": true},
	"expose":     {"cash": 1, "supplies": 0, "zone": true},
	"recruit":    {"cash": 0, "supplies": 0, "zone": true},
	"scavenge":   {"cash": 0, "supplies": 0, "zone": false},
	"listen":     {"cash": 0, "supplies": 0, "zone": true},
	"lay_low":    {"cash": 0, "supplies": 0, "zone": false},
	"see_teodor": {"cash": 0, "supplies": 0, "zone": false},
	"diversion":  {"cash": 1, "supplies": 0, "zone": true},
	"strike":     {"cash": 0, "supplies": 0, "zone": false},
	"signal_box": {"cash": 0, "supplies": 0, "zone": false},
	"confess":    {"cash": 0, "supplies": 0, "zone": false},
	"rally":      {"cash": 0, "supplies": 0, "zone": false},
	"seize":      {"cash": 0, "supplies": 0, "zone": false},
}

const ENDINGS := {
	"district_turns": "The district turns",
	"yards_silent": "The yards go silent",
	"occupiers": "Occupiers",
	"captured": "Captured",
	"window_closes": "The window closes",
}


# ---------- reading the state ----------

static func sentiment_state(value: int) -> String:
	if value <= 15:
		return "Hostile"
	if value <= 35:
		return "Wary"
	if value < READY_AT:
		return "Sympathetic"
	return "Ready"


## What the player is allowed to see of a zone (docs/slice-spec.md §6).
static func reading(s: RunState, zone: String) -> Dictionary:
	var z: Dictionary = s.zones[zone]
	var states := ["Hostile", "Wary", "Sympathetic", "Ready"]
	var true_idx := states.find(sentiment_state(z.sentiment))
	match int(z.certainty):
		2:
			return {"certainty": "Confirmed", "label": states[true_idx], "attention": z.attention}
		1:
			# Likely: a deterministic 20% chance (per zone and week) of being off by one.
			var h := hash("%d:%s:%d" % [s.run_seed, zone, s.week]) % 100
			var idx := true_idx
			if h < 20:
				idx = clampi(true_idx + (1 if h % 2 == 0 else -1), 0, 3)
			return {"certainty": "Likely", "label": states[idx], "attention": -1}
		_:
			var lo := clampi(true_idx - 1 if hash("%d:%s" % [s.run_seed, zone]) % 2 == 0 else true_idx, 0, 2)
			return {"certainty": "Rumor", "label": "%s or %s" % [states[lo], states[lo + 1]], "attention": -1}


static func available_actions(s: RunState) -> Array[String]:
	var out: Array[String] = ["aid", "expose", "recruit", "scavenge", "listen", "lay_low", "diversion"]
	var t: Dictionary = s.teodor
	if t.state in ["unmet", "met"]:
		out.append("see_teodor")
	if t.state == "ally" and t.loyalty == "high" and not t.strike_used:
		out.append("strike")
	if t.state == "ally" and t.lied and not t.confessed:
		out.append("confess")
	if s.week >= 2 and not s.broadcast_aired:
		out.append("signal_box")
	if _both_ready(s):
		out.append("rally")
	if s.week >= 3 and s.ready_operatives().size() >= 4:
		out.append("seize")
	return out


## Returns "" if the plan is legal, otherwise the reason it isn't.
static func validate(s: RunState, plan: Array) -> String:
	if plan.size() > 3:
		return "At most 3 actions a week."
	var allowed := available_actions(s)
	var ready := s.ready_operatives()
	var used_ops := {}
	var cash := 0
	var supplies := 0
	for p in plan:
		if not p.action in allowed:
			return "%s isn't available right now." % p.action
		if not p.op in ready:
			return "That operative isn't available."
		if used_ops.has(p.op):
			return "One action per operative."
		used_ops[p.op] = true
		if ACTIONS[p.action].zone and not p.get("zone", "") in ZONES:
			return "%s needs a zone." % p.action
		cash += ACTIONS[p.action].cash
		supplies += ACTIONS[p.action].supplies
	if cash > s.cash:
		return "Not enough cash."
	if supplies > s.supplies:
		return "Not enough supplies."
	return ""


# ---------- the week ----------

## Regime moves first so the player plans against it (as a Rumor unless they Listen).
static func start_week(s: RunState) -> void:
	s.diversion_zone = ""
	s.heat_gained = 0
	for zone in ZONES:
		var z: Dictionary = s.zones[zone]
		z.certainty = maxi(0, int(z.certainty) - 1)
		z.attention = 0
	if s.teodor.state == "ally":
		s.zones.depot.certainty = maxi(1, int(s.zones.depot.certainty))
	var points := 3 - (1 if s.strike_weeks > 0 else 0)
	for i in range(points):
		var wd := float(s.zones.dorms.sentiment) + 20.0
		var wp := float(s.zones.depot.sentiment) + 20.0
		var zone := "dorms" if s.rng.randf() * (wd + wp) < wd else "depot"
		s.zones[zone].attention += 1
	if s.week == 5 and s.teodor.lied and not s.teodor.confessed and s.teodor.state == "ally":
		s.report.append("Teodor has been asking the night shift about Kell Prison.")


## `mission` is the Signal Box result from the tactical scene (Battle.mission_result()).
## Empty = auto-resolve it, which the simulator and tests rely on.
static func resolve_week(s: RunState, plan: Array, mission := {}) -> void:
	begin_resolve(s, plan)
	if not s.is_over():
		finish_resolve(s, plan, mission)


## First half: pay for everything and resolve diversions, which move the
## regime's eyes for everything else. The game plays the mission after this.
static func begin_resolve(s: RunState, plan: Array) -> void:
	assert(validate(s, plan) == "", validate(s, plan))
	s.report.clear()
	for p in plan:
		s.cash -= ACTIONS[p.action].cash
		s.supplies -= ACTIONS[p.action].supplies
	for p in plan:
		if p.action == "diversion":
			_do_action(s, p)
			if s.is_over():
				return


static func finish_resolve(s: RunState, plan: Array, mission := {}) -> void:
	for p in plan:
		if p.action == "diversion":
			continue
		if p.action == "signal_box" and not mission.is_empty():
			apply_mission(s, p, mission)
		else:
			_do_action(s, p)
		if s.is_over():
			return
	_regime_response(s)
	if s.is_over():
		return
	s.week += 1
	if s.week > RunState.MAX_WEEKS:
		s.ending = "window_closes"
		s.report.append("Week six ends. The regime fills the yards with soldiers. The window closes.")
		return
	start_week(s)


# ---------- actions ----------

static func _success_chance(s: RunState, zone: String) -> float:
	var p := 0.9
	if zone != "":
		p -= 0.10 * int(s.zones[zone].attention)
	if s.heat >= 3:
		p -= 0.05
	return clampf(p, 0.2, 0.95)


static func _shift(s: RunState, zone: String, amount: int) -> void:
	s.zones[zone].sentiment = clampi(int(s.zones[zone].sentiment) + amount, 0, 100)


static func _heat(s: RunState, amount: int) -> void:
	s.heat = maxi(0, s.heat + amount)
	if amount > 0:
		s.heat_gained += amount


static func _do_action(s: RunState, p: Dictionary) -> void:
	var zone: String = p.get("zone", "")
	var choice: String = p.get("choice", "")
	var op: Dictionary = s.operatives[p.op]
	match p.action:
		"aid":
			if s.rng.randf() < _success_chance(s, zone):
				_shift(s, zone, 10)
				s.zones[zone].aid_runs += 1
				s.report.append("%s ran food and medicine into the %s." % [op.name, zone])
			else:
				_heat(s, 1)
				s.report.append("Police turned back the aid run in the %s." % zone)
		"expose":
			_heat(s, 1)
			if s.rng.randf() < _success_chance(s, zone):
				_shift(s, zone, 8)
				s.legitimacy += 1
				s.report.append("Posters went up overnight in the %s. People are reading them." % zone)
			else:
				s.report.append("Crews scraped the posters off the %s walls by dawn." % zone)
		"recruit":
			_heat(s, 1)
			if s.rng.randf() < _success_chance(s, zone):
				var n := 2 if sentiment_state(s.zones[zone].sentiment) in ["Sympathetic", "Ready"] else 1
				for i in range(n):
					_add_operative(s)
				s.report.append("%d new %s joined in the %s." % [n, "faces" if n > 1 else "face", zone])
			else:
				s.report.append("Nobody in the %s would talk to %s." % [zone, op.name])
		"scavenge":
			var roll := s.rng.randi() % 3
			if roll == 0:
				s.parts += 1
			elif roll == 1:
				s.cash += 2
			else:
				s.supplies += 3
			s.report.append("%s came back from the scrapyards with %s." % [op.name, ["parts", "cash", "supplies"][roll]])
			if s.rng.randf() < 0.15:
				op.out_weeks = 2
				_heat(s, 1)
				s.report.append("%s stopped on the way back and held." % _who(op, "was"))
		"listen":
			s.zones[zone].certainty = 2
			s.zones[zone].listens += 1
			if zone == "depot" and s.zones.depot.listens >= 2 and not s.teodor.knows_skim:
				s.teodor.knows_skim = true
				s.report.append("The depot talks: Teodor's night shift skims cargo for the smugglers.")
			else:
				s.report.append("%s spent the week listening in the %s." % [op.name, zone])
		"lay_low":
			_heat(s, -3)
			s.report.append("%s kept the cell quiet. The streets cooled a little." % op.name)
		"see_teodor":
			_see_teodor(s, choice)
		"diversion":
			_heat(s, 1)
			var p_ok := clampf(0.7 - 0.1 * maxi(0, s.heat - 3), 0.1, 0.9)
			if s.rng.randf() < p_ok:
				var other := "depot" if zone == "dorms" else "dorms"
				var moved := mini(2, int(s.zones[other].attention))
				s.zones[other].attention -= moved
				s.zones[zone].attention += moved
				s.diversion_zone = zone
				s.report.append("The Signal Fire worked. Patrols poured into the %s." % zone)
			else:
				_heat(s, 1)
				op.out_weeks = 2
				s.report.append("The decoy protest was a trap. %s arrested." % _who(op, "was"))
		"strike":
			_heat(s, 2)
			_shift(s, "depot", 20)
			s.strike_weeks = 2
			s.teodor.strike_used = true
			s.report.append("The cranes stopped. The whole east dock walked out with Teodor.")
		"signal_box":
			_signal_box(s, p, choice)
		"confess":
			var p_ok := clampf(0.5 + 0.1 * s.legitimacy, 0.1, 0.95)
			if s.rng.randf() < p_ok:
				s.teodor.confessed = true
				s.teodor.path = "trust"
				s.report.append("You told Teodor the truth about Kell. He didn't speak for a long time. He stayed.")
			else:
				_lose_teodor(s, "Teodor heard the truth from you, and it was too late. He's gone.")
		"rally":
			_rally(s)
		"seize":
			s.kills += 2
			if _both_ready(s) and s.legitimacy >= 3 and s.kills < 3:
				s.ending = "district_turns"
			else:
				s.ending = "occupiers"
			s.report.append("Your people took the Rail Yards by force.")


## "You were" / "Mara was": the player is an operative too.
static func _who(op: Dictionary, verb: String) -> String:
	if op.is_you:
		return "You " + {"was": "were", "is": "are"}.get(verb, verb)
	return "%s %s" % [op.name, verb]


static func _add_operative(s: RunState) -> void:
	if s.operatives.size() >= MAX_OPERATIVES:
		return
	var names := ["Ilse", "Dov", "Renata", "Sami", "Oren", "Lida", "Pell", "Yusra"]
	var name: String = names[(s.operatives.size() - 3) % names.size()]
	s.operatives.append({"name": name, "is_you": false, "is_teodor": false, "out_weeks": 0, "dead": false})


static func _see_teodor(s: RunState, choice: String) -> void:
	var t: Dictionary = s.teodor
	if t.state == "unmet":
		t.state = "met"
		s.report.append("You met Teodor at the container yard. Quiet got his brother six years.")
		return
	match choice:
		"honest":
			if int(s.zones.depot.aid_runs) >= 2:
				_teodor_joins(s, "trust", "high")
				s.report.append("Teodor watched your aid reach his people twice. He's in.")
			else:
				s.report.append("Teodor listened. \"Show me, don't tell me.\" He wants to see aid reach the depot.")
		"blackmail":
			if t.knows_skim:
				_teodor_joins(s, "leverage", "low")
				s.report.append("Teodor joined. He looked at you the way he looks at the police.")
			else:
				s.report.append("You had nothing on him. Teodor walked away.")
		"lie":
			_teodor_joins(s, "lie", "high")
			t.lied = true
			s.report.append("You promised to get his brother out of Kell. Teodor believed you.")
		_:
			s.report.append("You and Teodor talked around things for an hour.")


static func _teodor_joins(s: RunState, path: String, loyalty: String) -> void:
	s.teodor.state = "ally"
	s.teodor.path = path
	s.teodor.loyalty = loyalty
	s.operatives.append({"name": "Teodor", "is_you": false, "is_teodor": true, "out_weeks": 0, "dead": false})


static func _lose_teodor(s: RunState, line: String) -> void:
	s.teodor.state = "lost"
	for o in s.operatives:
		if o.is_teodor:
			o.dead = true  # gone from the roster (not dead in fiction)
	s.report.append(line)


## How many guards hold the depot this week (spec §9): 4, +1 per Attention on
## the Depot, -2 if the diversion pulled patrols into the Dormitories.
static func signal_box_guards(s: RunState) -> int:
	return clampi(4 + int(s.zones.depot.attention) - (2 if s.diversion_zone == "dorms" else 0), 1, 8)


## Everything the tactical mission needs. Squad: the operative on the op, plus
## everyone ready who isn't doing something else this week (max 6, you first).
static func mission_params(s: RunState, plan: Array) -> Dictionary:
	var busy := {}
	var lead := -1
	for p in plan:
		busy[p.op] = true
		if p.action == "signal_box":
			lead = p.op
	var squad := []
	for i in s.ready_operatives():
		if i == lead or not busy.has(i):
			var o: Dictionary = s.operatives[i]
			squad.append({"name": o.name, "op": i, "is_you": o.is_you})
	squad.sort_custom(func(a, b): return a.is_you and not b.is_you)
	return {"guards": signal_box_guards(s), "legitimacy": s.legitimacy,
		"squad": squad.slice(0, 6), "seed": s.rng.randi()}


## Feed a played Signal Box mission back into the run (spec §9 outcomes).
static func apply_mission(s: RunState, p: Dictionary, r: Dictionary) -> void:
	var kills := int(r.get("kills", 0))
	var defections := int(r.get("defections", 0))
	s.kills += kills
	s.legitimacy += defections - kills
	if kills > 0:
		_heat(s, kills)
	if r.get("aired", false):
		s.broadcast_aired = true
		_shift(s, "dorms", 20)
		_shift(s, "depot", 20)
		if kills == 0:
			s.legitimacy += 2
			_heat(s, 1)
		s.report.append("The footage of the dormitory raid played on every screen in the district.")
	else:
		_heat(s, 1)
		s.report.append("The signal box op failed. The screens stayed on the regime's channel.")
	if defections > 0:
		s.report.append("A depot guard came over to you. He won't be the last.")
	var gave_up := int(r.get("prisoners", 0))
	if gave_up > 0:
		s.prisoners += gave_up
		s.surrenders += gave_up
	if s.prisoners > 0:
		s.report.append("Prisoners: %d held%s." % [s.prisoners,
			" (%d gave up at the depot this week)" % gave_up if gave_up > 0 else ""])
	for o in s.operatives:
		if o.dead:
			continue
		if o.name in r.get("dead", []):
			o.dead = true
			if o.is_you:
				s.ending = "captured"
				s.report.append("You didn't come back from the depot.")
			else:
				s.report.append("%s didn't come back from the depot." % o.name)
		elif o.name in r.get("hurt", []):
			o.out_weeks = 2
			s.report.append("%s was carried out and needs two weeks." % o.name)


## Auto-resolved when there's no played mission (the simulator). "quiet" or "loud".
static func _signal_box(s: RunState, p: Dictionary, choice: String) -> void:
	var guards := signal_box_guards(s)
	var loud := choice == "loud"
	var p_ok := clampf((1.05 if loud else 0.95) - (0.07 if loud else 0.08) * guards, 0.1, 0.95)
	var op: Dictionary = s.operatives[p.op]
	if s.rng.randf() < p_ok:
		var killed := s.rng.randi_range(1, 3) if loud else 0
		s.kills += killed
		s.broadcast_aired = true
		_shift(s, "dorms", 20)
		_shift(s, "depot", 20)
		if killed == 0:
			s.legitimacy += 2
			_heat(s, 1)
		else:
			s.legitimacy -= killed
			_heat(s, killed)
		s.report.append("The footage of the dormitory raid played on every screen in the district.")
	else:
		_heat(s, 1)
		if s.rng.randf() < (0.2 if loud else 0.3) and not op.is_you:
			op.dead = true
			s.report.append("The signal box op failed. %s didn't come back." % op.name)
		else:
			op.out_weeks = 2
			s.report.append("The signal box op failed. %s hurt and lying low." % _who(op, "is"))


static func _rally(s: RunState) -> void:
	if s.kills >= 3:
		s.ending = "occupiers"
	elif s.teodor.strike_used and s.broadcast_aired:
		s.ending = "yards_silent"
	elif s.broadcast_aired and s.legitimacy >= 3:
		s.ending = "district_turns"
	else:
		_heat(s, 2)
		_shift(s, "dorms", -10)
		_shift(s, "depot", -10)
		s.report.append("The rally was broken up with gas. Without proof, people went home.")
		return
	s.report.append("Thousands filled the Rail Yards.")


static func _both_ready(s: RunState) -> bool:
	return int(s.zones.dorms.sentiment) >= READY_AT and int(s.zones.depot.sentiment) >= READY_AT


# ---------- the regime answers ----------

static func _regime_response(s: RunState) -> void:
	# From week 3 the regime escalates no matter what. Heat 9 means you're found;
	# only below that does a quiet week let the streets cool.
	if s.week >= 3:
		_heat(s, 1)
	if s.heat >= 9:
		s.ending = "captured"
		s.report.append("They came at four in the morning. You were taken.")
		return
	if s.heat_gained == 0:
		_heat(s, -1)
	if s.heat >= 5:
		var pools := []
		for r in ["cash", "supplies", "parts"]:
			if int(s.get(r)) > 0:
				pools.append(r)
		if not pools.is_empty():
			var r: String = pools[s.rng.randi() % pools.size()]
			s.set(r, int(s.get(r)) - 1)
			s.report.append("A checkpoint raid cost you %s." % r)
	if s.heat >= 7:
		var targets := s.ready_operatives().filter(func(i): return not s.operatives[i].is_you)
		if not targets.is_empty():
			var o: Dictionary = s.operatives[targets[s.rng.randi() % targets.size()]]
			o.out_weeks = 2
			s.report.append("A targeted raid took %s." % o.name)
		var t: Dictionary = s.teodor
		if t.state == "ally" and t.path == "leverage" and not t.betrayed and s.rng.randf() < 0.5:
			t.betrayed = true
			_heat(s, 2)
			_lose_teodor(s, "Teodor sold your safehouse to the police to save himself.")
	if s.week == 5 and s.teodor.state == "ally" and s.teodor.lied and not s.teodor.confessed:
		_lose_teodor(s, "Teodor learned there was never a plan for Kell. He's gone, and he took the dock with him.")
	for o in s.operatives:
		if o.out_weeks > 0:
			o.out_weeks -= 1
	if s.strike_weeks > 0:
		s.strike_weeks -= 1
