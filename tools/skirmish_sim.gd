extends SceneTree
## Skirmish balance check (M4). Both sides on the simple policy.
## godot --headless --path . --script tools/skirmish_sim.gd -- [fights]

const Battle = preload("res://scripts/tactics/battle.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 500
	var res := {Battle.US: 0, Battle.REGIME: 0, "": 0}
	var turns := 0
	var ours_left := 0
	var escaped := 0
	for i in range(n):
		var b = Battle.play_auto(i + 1)
		res[b.winner()] += 1
		turns += b.turn
		ours_left += b.alive_units(Battle.US).size()
		for u in b.units:
			if u.escaped:
				escaped += 1
	print("%d fights: won %.0f%%, lost %.0f%%, stalled %.0f%%" % [n, 100.0 * res[Battle.US] / n, 100.0 * res[Battle.REGIME] / n, 100.0 * res[""] / n])
	print("avg turns %.1f, avg squad left %.2f, guards escaped/fight %.2f" % [float(turns) / n, float(ours_left) / n, float(escaped) / n])
	quit()
