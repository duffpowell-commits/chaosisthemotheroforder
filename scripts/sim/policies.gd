extends RefCounted
## Automated players for the balance simulator and tests.

const Rules = preload("res://scripts/sim/rules.gd")


## Picks random legal actions. Used for the spec's balance target.
static func random_plan(s) -> Array:
	var ready: Array = s.ready_operatives()
	ready.shuffle()
	var count: int = s.rng.randi_range(0, mini(3, ready.size()))
	var plan := []
	var tries := 0
	while plan.size() < count and tries < 30:
		tries += 1
		var acts: Array = Rules.available_actions(s)
		var a: String = acts[s.rng.randi() % acts.size()]
		var entry := {"action": a, "op": ready[plan.size()],
			"zone": Rules.ZONES[s.rng.randi() % 2],
			"choice": ["honest", "blackmail", "lie", "quiet", "loud"][s.rng.randi() % 5]}
		var trial := plan.duplicate()
		trial.append(entry)
		if Rules.validate(s, trial) == "":
			plan = trial
	return plan


## A sensible, non-violent player: earns Teodor's trust, diverts, broadcasts quietly.
## With violent = true it goes in loud and seizes the district when it can.
static func careful_plan(s, violent := false) -> Array:
	var ready: Array = s.ready_operatives()
	var acts: Array = Rules.available_actions(s)
	var wants := []
	if violent and "seize" in acts:
		wants.append({"action": "seize"})
	if "rally" in acts:
		wants.append({"action": "rally"})
	if s.heat >= 6:
		wants.append({"action": "lay_low"})
	if "strike" in acts:
		wants.append({"action": "strike"})
	if "signal_box" in acts and s.week >= 3:
		wants.append({"action": "diversion", "zone": "dorms"})
		wants.append({"action": "signal_box", "choice": "loud" if violent else "quiet"})
	if s.teodor.state == "unmet":
		wants.append({"action": "see_teodor"})
	elif s.teodor.state == "met" and int(s.zones.depot.aid_runs) >= 2:
		wants.append({"action": "see_teodor", "choice": "honest"})
	if int(s.zones.depot.aid_runs) < 2:
		wants.append({"action": "aid", "zone": "depot"})
	var weaker := "dorms" if int(s.zones.dorms.sentiment) <= int(s.zones.depot.sentiment) else "depot"
	wants.append({"action": "aid", "zone": weaker})
	wants.append({"action": "expose", "zone": weaker})
	wants.append({"action": "scavenge"})
	wants.append({"action": "recruit", "zone": weaker})
	var plan := []
	for w in wants:
		if plan.size() >= mini(3, ready.size()):
			break
		var entry: Dictionary = w.duplicate()
		entry["op"] = ready[plan.size()]
		var trial := plan.duplicate()
		trial.append(entry)
		if Rules.validate(s, trial) == "":
			plan = trial
	return plan
