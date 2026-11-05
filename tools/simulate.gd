extends SceneTree
## Balance simulator (docs/slice-spec.md §12).
## godot --headless --path . --script tools/simulate.gd -- [runs]

const RunState = preload("res://scripts/sim/run_state.gd")
const Rules = preload("res://scripts/sim/rules.gd")
const Policies = preload("res://scripts/sim/policies.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 1000
	for policy in ["random", "careful", "violent"]:
		var counts := {}
		var weeks := 0
		for i in range(runs):
			var s = RunState.create(i + 1)
			Rules.start_week(s)
			while not s.is_over():
				var plan: Array = Policies.random_plan(s) if policy == "random" else Policies.careful_plan(s, policy == "violent")
				Rules.resolve_week(s, plan)
			counts[s.ending] = counts.get(s.ending, 0) + 1
			weeks += s.week
		print("== %s policy, %d runs, avg end week %.1f" % [policy, runs, float(weeks) / runs])
		var keys := counts.keys()
		keys.sort_custom(func(a, b): return counts[a] > counts[b])
		for k in keys:
			print("  %-16s %5.1f%%" % [k, 100.0 * counts[k] / runs])
	quit()
