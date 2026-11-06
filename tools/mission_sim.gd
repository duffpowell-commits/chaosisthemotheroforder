extends SceneTree
## Signal Box balance check (M5). Two simple player policies against the guard AI:
##   quiet: sneak, take guards down by hand, talk the Wavering one over, shoot only once spotted
##   loud:  walk in and shoot anything worth shooting
## godot --headless --path . --script tools/mission_sim.gd -- [missions]

const Battle = preload("res://scripts/tactics/battle.gd")

const SQUAD := [
	{"name": "You", "op": 0, "is_you": true},
	{"name": "Mara", "op": 1, "is_you": false},
	{"name": "Kesh", "op": 2, "is_you": false},
	{"name": "Teodor", "op": 3, "is_you": false},
	{"name": "Ana", "op": 4, "is_you": false},
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 500
	for size in [3, 5]:
		for guards in [2, 4, 6]:
			for loud in [false, true]:
				_report(guards, size, loud, n)
	quit()


func _report(guards: int, size: int, loud: bool, n: int) -> void:
	var aired := 0
	var clean := 0
	var wiped := 0
	var alarms := 0
	var kills := 0
	var dead := 0
	var defections := 0
	var turns := 0
	for i in range(n):
		var b = play({"guards": guards, "legitimacy": 1, "squad": SQUAD.slice(0, size), "seed": i + 1}, loud)
		var r: Dictionary = b.mission_result()
		if r.aired:
			aired += 1
			if r.kills == 0:
				clean += 1
		if r.out.is_empty():
			wiped += 1
		if b.alarm:
			alarms += 1
		kills += r.kills
		dead += r.dead.size()
		defections += r.defections
		turns += b.turn
	print("squad %d v %d guards, %s: aired %d%% (clean %d%%), nobody out %d%%, alarm %d%%, kills %.1f, our dead %.2f, defections %.2f, turns %.1f" % [
		size, guards, "loud " if loud else "quiet", 100 * aired / n, 100 * clean / n, 100 * wiped / n,
		100 * alarms / n, float(kills) / n, float(dead) / n, float(defections) / n, float(turns) / n])


static func play(params: Dictionary, loud: bool) -> RefCounted:
	var b = Battle.create_mission(params)
	while not b.is_over():
		for u in b.alive_units(Battle.US):
			act(b, u, loud)
		if b.is_over():
			break
		b.end_turn()
	return b


static func act(b, u, loud: bool) -> void:
	for _step in range(4):
		if not u.alive() or u.ap <= 0:
			return
		if b.stabilize(u):
			continue
		if b.upload >= Battle.UPLOAD_TURNS or u.defected:
			if b.leave(u):
				return
			if _spotted(b, u):
				var t0 = b._best_target(u)
				if t0 != null and b.chance(u, t0) >= 50 and b.shoot(u, t0):
					continue
			if not _step_toward(b, u, _south_row(), loud):
				return
			continue
		var adj = _adjacent_enemy(b, u)
		if adj != null and b.subdue(u, adj):
			continue
		if _ambush(b, u):
			continue
		var w = _wavering(b, u)
		if w != null and b.persuade(u, w):
			continue
		if b.do_upload(u):
			continue
		if loud and _any_alert(b):
			b.act_unit(u)  # the M4 fight policy: best covered tile, then shoot
			return
		if loud or _spotted(b, u):
			var t = b._best_target(u)
			if t != null and b.chance(u, t) >= 50 and b.shoot(u, t):
				continue
		if b.can_upload(u) == false and b.box != Vector2i(-1, -1) and Battle._cheb(u.pos, b.box) == 1:
			b.overwatch(u)  # waiting on the second upload turn
			return
		if not _step_toward(b, u, _box_ring(b), loud):
			if loud:
				b.overwatch(u)
			return


## Close in and take a guard down by hand in the same turn: one move to a tile
## next to him, then Subdue.
static func _ambush(b, u) -> bool:
	if u.ap < Battle.AP_PER_TURN:
		return false
	var r: Dictionary = b.reachable(u, 1)
	for g in b.alive_units(Battle.REGIME):
		for p in r:
			if Battle._cheb(p, g.pos) == 1 and (b.turn > 3 or not _watched(b, p, g)):
				b.move(u, p)
				return b.subdue(u, g)
	return false


## Would any other patrolling guard see a unit standing on `p`?
static func _watched(b, p: Vector2i, except) -> bool:
	for g in b.alive_units(Battle.REGIME):
		if g != except and g.state == Battle.PATROL and Battle._cheb(g.pos, p) <= b.sight and b.line_of_sight(g.pos, p):
			return true
	return false


## Tiles a patrol will pass close enough to spot a sneaking unit.
static func _danger(b) -> Dictionary:
	var out := {}
	for g in b.alive_units(Battle.REGIME):
		if g.state != Battle.PATROL or g.route.is_empty():
			continue
		var pts: Array = [g.pos]
		for w in g.route:
			var a: Vector2i = pts[pts.size() - 1]
			while a != w:
				a += Vector2i(signi(w.x - a.x), signi(w.y - a.y))
				pts.append(a)
		for c in pts:
			for dx in range(-Battle.HIDDEN_SIGHT, Battle.HIDDEN_SIGHT + 1):
				for dy in range(-Battle.HIDDEN_SIGHT, Battle.HIDDEN_SIGHT + 1):
					out[c + Vector2i(dx, dy)] = true
	return out


static func _any_alert(b) -> bool:
	return b.alive_units(Battle.REGIME).any(func(g): return g.state != Battle.PATROL)


static func _spotted(b, u) -> bool:
	for g in b.alive_units(Battle.REGIME):
		if g.state != Battle.PATROL and b.chance(g, u) > 0:
			return true
	return false


static func _adjacent_enemy(b, u):
	for g in b.alive_units(Battle.REGIME):
		if b.can_subdue(u, g):
			return g
	return null


static func _wavering(b, u):
	for g in b.alive_units(Battle.REGIME):
		if b.can_persuade(u, g):
			return g
	return null


static func _box_ring(b) -> Array:
	var out := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var p: Vector2i = b.box + Vector2i(dx, dy)
			if p != b.box and Battle.in_bounds(p) and (b.tile(p) == Battle.FLOOR or b.tile(p) == Battle.HIGH):
				out.append(p)
	return out


static func _south_row() -> Array:
	var out := []
	for x in range(Battle.W):
		out.append(Vector2i(x, Battle.H - 1))
	return out


## Walking distance to the nearest goal tile, ignoring units.
static func _field(b, goals: Array) -> Dictionary:
	var dist := {}
	var queue: Array = []
	for g in goals:
		dist[g] = 0
		queue.append(g)
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var q: Vector2i = p + d
			if dist.has(q) or not Battle.in_bounds(q):
				continue
			if b.tile(q) != Battle.FLOOR and b.tile(q) != Battle.HIGH:
				continue
			dist[q] = dist[p] + 1
			queue.append(q)
	return dist


## Sneak if nobody's onto us yet and we have the full turn, else a normal move.
static func _step_toward(b, u, goals: Array, loud: bool) -> bool:
	var field := _field(b, goals)
	var here: int = field.get(u.pos, 999)
	if here == 0:
		return false
	var quiet: bool = not loud and not b.alarm and u.ap >= Battle.AP_PER_TURN and not _spotted(b, u)
	var danger := _danger(b) if quiet and b.turn <= 3 else {}
	var best: Vector2i = u.pos
	var best_d := here + (6 if danger.has(u.pos) else 0)
	for p in b.reachable(u, 1):
		var d: int = field.get(p, 999) + (6 if danger.has(p) else 0)
		if d < best_d or (d == best_d and best != u.pos and b._exposure(u, p) < b._exposure(u, best)):
			best = p
			best_d = d
	if best == u.pos:
		return false
	return b.sneak(u, best) if quiet else b.move(u, best)
