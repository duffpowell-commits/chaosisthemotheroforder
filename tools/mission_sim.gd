extends SceneTree
## Signal Box balance check (M5). Two simple player policies against the guard AI:
##   quiet: sneak, take guards down by hand, talk the Wavering one over, shoot only once spotted
##   loud:  walk in and shoot anything worth shooting
## godot --headless --path . --script tools/mission_sim.gd -- [missions] [focus]
## "focus" runs only the cases that decide the jam's difficulty (3 or 5 vs 4).
##
## Tension (does it feel close, not just who wins):
##   close   share of missions that came down to the wire: aired after someone
##           went down, or failed after the upload had started
##   flips   coin-flip shots per mission (35-65% hit chance), the rolls that
##           make you hold your breath
## Target for the jam: close 40-70%, flips 2+ per mission.
##
## Diversion tools (J1.5, spec §4): both bots use them. Lights out early (the
## squad member nearest the junction box), Radio from the box before the
## upload, Smoke on the run home once spotted, Flash when 2+ guards bunch.
## `-- 300 focus notools` runs the bots without them, for before/after.
## White Flag (Nov 26): guards break (surrender or run); `nowf` turns it off for before/after.

static var use_tools := true
static var white_flag := true

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
	var focus := "focus" in args
	use_tools = not "notools" in args
	white_flag = not "nowf" in args
	for size in [3, 5]:
		for guards in ([4] if focus else [2, 4, 6]):
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
	var prisoners := 0
	var fled := 0
	var close := 0
	var flips := 0
	var tools_used := {"smoke": 0, "lights": 0, "radio": 0, "flash": 0}
	for i in range(n):
		var b = play({"guards": guards, "legitimacy": 1, "squad": SQUAD.slice(0, size), "seed": i + 1}, loud)
		var r: Dictionary = b.mission_result()
		prisoners += int(r.prisoners)
		fled += int(r.fled)
		if r.aired:
			aired += 1
			if r.kills == 0:
				clean += 1
		if r.out.is_empty():
			wiped += 1
		if b.alarm:
			alarms += 1
		kills += r.kills
		for line in b.log:
			if "smoke flare" in line: tools_used.smoke += 1
			elif "floodlight dies" in line: tools_used.lights += 1
			elif "answers the call" in line or "stranger on their channel" in line: tools_used.radio += 1
			elif "throws a flashbang" in line: tools_used.flash += 1
		dead += r.dead.size()
		defections += r.defections
		turns += b.turn
		var hurt_any := false
		for u in b.units:
			if u.side == Battle.US and not u.defected and (u.hp < Battle.MAX_HP or u.dead):
				hurt_any = true
		if (r.aired and hurt_any) or (not r.aired and b.upload >= 1):
			close += 1
		for line in b.log:
			var m := _chance_re().search(line)
			if m != null and (" hit" in line or " miss" in line):
				var c := int(m.get_string(1))
				if c >= 35 and c <= 65:
					flips += 1
	print("squad %d v %d guards, %s: aired %d%% (clean %d%%), nobody out %d%%, alarm %d%%, kills %.1f, our dead %.2f, defections %.2f, turns %.1f | close %d%%, flips %.1f" % [
		size, guards, "loud " if loud else "quiet", 100 * aired / n, 100 * clean / n, 100 * wiped / n,
		100 * alarms / n, float(kills) / n, float(dead) / n, float(defections) / n, float(turns) / n,
		100 * close / n, float(flips) / n])
	if white_flag:
		print("    white flag per mission: surrendered %.2f, fled %.2f" % [float(prisoners) / n, float(fled) / n])
	if use_tools:
		print("    tools used per 100 missions: smoke %d, lights %d, radio %d (calls), flash %d" % [
			100 * tools_used.smoke / n, 100 * tools_used.lights / n, 100 * tools_used.radio / n / 2, 100 * tools_used.flash / n])


static var _re: RegEx
static func _chance_re() -> RegEx:
	if _re == null:
		_re = RegEx.create_from_string("\\((\\d+)%\\)")
	return _re


static func play(params: Dictionary, loud: bool) -> RefCounted:
	var b = Battle.create_mission(params)
	b.white_flag = white_flag
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
		if use_tools and _use_tool(b, u):
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


## Diversion tools, spec §4. Returns true if a tool was used (or the unit
## walked toward the junction box), so act() loops.
static func _use_tool(b, u) -> bool:
	# Flash: 2+ guards bunched within the defector's reach.
	if u.flash > 0:
		var best := Vector2i(-1, -1)
		var most := 1
		for g in b.alive_units(Battle.REGIME):
			for p in Battle.area3(g.pos):
				var n: int = b.flash_targets(p).filter(func(x): return x.stun == 0).size()
				if n > most and b.can_flash(u, p):
					best = p
					most = n
		if best.x >= 0:
			return b.flashbang(u, best)
	# Smoke: on the run home, once a guard can see us, cloud ourselves.
	if (b.upload >= Battle.UPLOAD_TURNS or u.defected) and _spotted(b, u) and b.can_smoke(u, u.pos):
		return b.smoke(u, u.pos)
	# Radio: You at the box before the upload, guards within 6.
	if b.can_radio(u) and b.upload == 0 and b.radio_chance() > 0:
		var near: bool = b.alive_units(Battle.REGIME).any(func(g): return Battle._cheb(g.pos, u.pos) <= 6)
		if near:
			b.radio(u)
			return true
	# Lights out: early, by the squad member nearest the junction box (not You).
	if not b.lights_used and b.turn <= 4 and not u.is_you and b.upload == 0 and _lights_runner(b) == u:
		if b.lights_out(u):
			return true
		var ring := []
		for p in Battle.area3(Battle.JUNCTION_POS):
			if p != Battle.JUNCTION_POS and b.standable(p):
				ring.append(p)
		if u.ap >= 1 and _step_toward(b, u, ring, false):
			return true
	return false


static func _lights_runner(b):
	var best = null
	for m in b.alive_units(Battle.US):
		if m.is_you or m.defected:
			continue
		if best == null or Battle._manhattan(m.pos, Battle.JUNCTION_POS) < Battle._manhattan(best.pos, Battle.JUNCTION_POS):
			best = m
	return best


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
