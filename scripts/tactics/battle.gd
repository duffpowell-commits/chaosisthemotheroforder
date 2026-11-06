extends RefCounted
## Tactical core (docs/slice-spec.md §9, M4): a turn-based skirmish as plain
## data. No scenes: the tactical scene reads and drives this, tests run it headless.
##
## Grid: W x H tiles. Crates are half cover, containers full cover; neither can
## be stood on. Gantry tiles are high ground and walkable.
## Each unit: 2 AP, 2 HP. Move = 1 AP per 4 tiles. Shoot = 1 AP, a hit does 1.
## Hit chance: 65 base, half cover -20, full -40, high ground +10, flanking +20,
## clamped 5-95. Cover only counts on the side facing the shooter.

const W := 14
const H := 14

const FLOOR := 0
const HALF := 1
const FULL := 2
const HIGH := 3

const US := "us"
const REGIME := "regime"

const PATROL := "patrol"
const ALERT := "alert"
const RETREAT := "retreat"

const AP_PER_TURN := 2
const MAX_HP := 2
const TILES_PER_AP := 4
const BASE_HIT := 65
const SIGHT := 9  # Chebyshev tiles a patrolling guard can spot you from
const TURN_LIMIT := 40


class Unit:
	var name := ""
	var side := ""
	var pos := Vector2i.ZERO
	var hp := MAX_HP
	var ap := AP_PER_TURN
	var state := ALERT
	var route: Array = []
	var route_i := 0
	var escaped := false

	func alive() -> bool:
		return hp > 0 and not escaped


var tiles := PackedInt32Array()
var units: Array = []
var rng := RandomNumberGenerator.new()
var side := US
var turn := 1
var log: Array[String] = []


# ---------- setup ----------

func setup_empty(seed_value: int) -> void:
	rng.seed = seed_value
	tiles.resize(W * H)
	tiles.fill(FLOOR)
	units.clear()
	side = US
	turn = 1


## The Rail Yards skirmish: the street from the render test plus the depot
## yard. '.' floor, 'h' crate, 'F' container, 'G' gantry. North (row 0) is
## the regime's way out; the squad comes in from the south.
const STREET := [
	"..............",
	"..FF......FF..",
	"..........h...",
	"....h.........",
	".FF.....GGG...",
	"......h.......",
	"...h.....FF...",
	".........FF...",
	"..FF...h......",
	"..FF..........",
	"......GG...h..",
	".h............",
	"......FF....h.",
	"..............",
]


static func create_skirmish(seed_value: int) -> RefCounted:
	var b = load("res://scripts/tactics/battle.gd").new()
	b.setup_empty(seed_value)
	for y in range(H):
		for x in range(W):
			var c: String = STREET[y][x]
			b.set_tile(Vector2i(x, y), {"h": HALF, "F": FULL, "G": HIGH}.get(c, FLOOR))
	b.add_unit("You", US, Vector2i(3, 13))
	b.add_unit("Mara", US, Vector2i(7, 13))
	b.add_unit("Kesh", US, Vector2i(11, 13))
	var routes := [
		[Vector2i(1, 2), Vector2i(7, 2)],
		[Vector2i(12, 3), Vector2i(12, 7)],
		[Vector2i(5, 6), Vector2i(8, 6)],
		[Vector2i(9, 0), Vector2i(4, 0)],
	]
	for i in range(routes.size()):
		var g = b.add_unit("Guard %d" % (i + 1), REGIME, routes[i][0])
		g.route = routes[i]
	return b


## A whole skirmish with both sides on the simple policy. For tests and the sim.
static func play_auto(seed_value: int) -> RefCounted:
	var b = create_skirmish(seed_value)
	while b.winner() == "" and b.turn <= TURN_LIMIT:
		for u in b.alive_units(US):
			b.act_unit(u)
		b.end_turn()
	return b


func set_tile(p: Vector2i, kind: int) -> void:
	tiles[p.y * W + p.x] = kind


func tile(p: Vector2i) -> int:
	return tiles[p.y * W + p.x]


func add_unit(unit_name: String, unit_side: String, p: Vector2i) -> Unit:
	var u := Unit.new()
	u.name = unit_name
	u.side = unit_side
	u.pos = p
	u.state = PATROL if unit_side == REGIME else ALERT
	units.append(u)
	return u


# ---------- queries ----------

static func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H


static func clamp_chance(c: int) -> int:
	return clampi(c, 5, 95)


func unit_at(p: Vector2i) -> Unit:
	for u in units:
		if u.alive() and u.pos == p:
			return u
	return null


func alive_units(which: String) -> Array:
	return units.filter(func(u): return u.side == which and u.alive())


func enemies_of(u: Unit) -> Array:
	return alive_units(REGIME if u.side == US else US)


func standable(p: Vector2i) -> bool:
	return in_bounds(p) and tile(p) != HALF and tile(p) != FULL and unit_at(p) == null


## Tiles reachable with `ap` action points: {Vector2i: steps}. 4-way steps,
## cover and units block. Excludes the unit's own tile.
func reachable(u: Unit, ap: int) -> Dictionary:
	var limit := TILES_PER_AP * mini(ap, u.ap)
	var dist := {u.pos: 0}
	var queue: Array[Vector2i] = [u.pos]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if dist[p] >= limit:
			continue
		for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var n: Vector2i = p + d
			if dist.has(n) or not standable(n):
				continue
			dist[n] = dist[p] + 1
			queue.append(n)
	dist.erase(u.pos)
	return dist


## Step-by-step path to `dest` (for the scene to animate). Empty if unreachable.
func path_to(u: Unit, dest: Vector2i) -> Array[Vector2i]:
	var parent := {u.pos: u.pos}
	var queue: Array[Vector2i] = [u.pos]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p == dest:
			break
		for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var n: Vector2i = p + d
			if not parent.has(n) and standable(n):
				parent[n] = p
				queue.append(n)
	var out: Array[Vector2i] = []
	if not parent.has(dest):
		return out
	var at := dest
	while at != u.pos:
		out.push_front(at)
		at = parent[at]
	return out


## Containers block sight; crates don't. Cover right next to either end
## doesn't block (you lean out from it, and you shoot at what's behind it).
func line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var p := a
	while p != b:
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
		if p == b:
			break
		if _cheb(p, a) <= 1 or _cheb(p, b) <= 1:
			continue
		if tile(p) == FULL:
			return false
	return true


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Best cover at `target` on the side facing `shooter`: FLOOR (none), HALF or FULL.
func cover_against(target: Vector2i, shooter: Vector2i) -> int:
	var best := FLOOR
	var sx := signi(shooter.x - target.x)
	var sy := signi(shooter.y - target.y)
	for n in [Vector2i(target.x + sx, target.y), Vector2i(target.x, target.y + sy)]:
		if n == target or not in_bounds(n):
			continue
		var t := tile(n)
		if t == FULL:
			best = FULL
		elif t == HALF and best != FULL:
			best = HALF
	return best


func _has_any_cover(p: Vector2i) -> bool:
	for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var n: Vector2i = p + d
		if in_bounds(n) and (tile(n) == HALF or tile(n) == FULL):
			return true
	return false


## Hit chance in percent for a shot from `from` at `to`. 0 if there's no line of sight.
func chance_from(from: Vector2i, to: Vector2i) -> int:
	if from == to or not line_of_sight(from, to):
		return 0
	var c := BASE_HIT
	match cover_against(to, from):
		HALF:
			c -= 20
		FULL:
			c -= 40
		_:
			if _has_any_cover(to):
				c += 20  # flanked: they're behind cover, but not from this side
	if tile(from) == HIGH and tile(to) != HIGH:
		c += 10
	return clamp_chance(c)


func chance(shooter: Unit, target: Unit) -> int:
	return chance_from(shooter.pos, target.pos)


func winner() -> String:
	if alive_units(US).is_empty():
		return REGIME
	if alive_units(REGIME).is_empty():
		return US
	return ""


# ---------- actions ----------

func move(u: Unit, dest: Vector2i) -> bool:
	var r := reachable(u, u.ap)
	if not r.has(dest):
		return false
	u.ap -= ceili(float(r[dest]) / TILES_PER_AP)
	u.pos = dest
	return true


## Returns true on a hit. Shooting (and being shot at) alerts every guard.
func shoot(u: Unit, target: Unit) -> bool:
	var c := chance(u, target)
	if u.ap < 1 or c <= 0 or not target.alive():
		return false
	u.ap -= 1
	alert_all("%s fires" % u.name)
	var hit := rng.randi_range(1, 100) <= c
	if hit:
		target.hp -= 1
		log.append("%s hits %s (%d%%)%s" % [u.name, target.name, c, ", down" if target.hp <= 0 else ""])
	else:
		log.append("%s misses %s (%d%%)" % [u.name, target.name, c])
	return hit


func alert_all(why: String) -> void:
	for g in alive_units(REGIME):
		if g.state == PATROL:
			g.state = ALERT
			log.append("%s is alerted: %s" % [g.name, why])


func end_turn() -> void:
	side = REGIME
	for g in alive_units(REGIME):
		g.ap = AP_PER_TURN
	for g in alive_units(REGIME):
		act_unit(g)
	side = US
	for u in alive_units(US):
		u.ap = AP_PER_TURN
	turn += 1


# ---------- AI (both sides use it; the player normally drives US) ----------

func act_unit(u: Unit) -> void:
	if not u.alive():
		return
	if u.side == REGIME:
		if u.state == PATROL:
			_patrol(u)
			return
		if u.hp == 1 and u.state == ALERT and alive_units(REGIME).size() <= alive_units(US).size():
			u.state = RETREAT
			log.append("%s falls back" % u.name)
		if u.state == RETREAT:
			_retreat(u)
			return
	_fight(u)


func _sees_enemy(u: Unit) -> bool:
	for e in enemies_of(u):
		if _cheb(u.pos, e.pos) <= SIGHT and line_of_sight(u.pos, e.pos):
			return true
	return false


func _patrol(u: Unit) -> void:
	if _sees_enemy(u):
		alert_all("%s spots you" % u.name)
		_fight(u)
		return
	var goal: Vector2i = u.route[u.route_i]
	if u.pos == goal:
		u.route_i = (u.route_i + 1) % u.route.size()
		goal = u.route[u.route_i]
	var best := u.pos
	var best_d := _manhattan(u.pos, goal)
	var r := reachable(u, 1)
	for p in r:
		var d := _manhattan(p, goal)
		if d < best_d:
			best = p
			best_d = d
	if best != u.pos:
		move(u, best)
	if _sees_enemy(u):
		alert_all("%s spots you" % u.name)
		_fight(u)


## Fighting withdrawal: one move toward the north edge (row 0), then a shot
## if there's a decent one, else keep running. Reaching row 0 = out of the fight.
func _retreat(u: Unit) -> void:
	while u.ap > 0 and u.pos.y > 0:
		var best := u.pos
		for p in reachable(u, 1):
			if p.y < best.y or (p.y == best.y and _exposure(u, p) < _exposure(u, best)):
				best = p
		if best == u.pos or not move(u, best):
			break
		if u.ap > 0 and u.pos.y > 0:
			var t := _best_target(u)
			if t != null and chance(u, t) >= 40:
				shoot(u, t)
	if u.pos.y == 0:
		u.escaped = true
		log.append("%s escapes north" % u.name)


func _fight(u: Unit) -> void:
	var foes := enemies_of(u)
	if foes.is_empty():
		return
	# 1. Pick the best tile within one move: good shot, low exposure.
	var here := _spot_score(u, u.pos)
	var best := u.pos
	var best_score := here
	var r := reachable(u, 1)
	for p in r:
		var s := _spot_score(u, p)
		if s > best_score + 0.001:
			best = p
			best_score = s
	if _best_attack(u, best) == 0:
		# No shot from anywhere close: advance on the nearest foe instead.
		best = _advance_tile(u, r, foes)
	if best != u.pos and u.ap > 0:
		move(u, best)
	# 2. Spend what's left on shots.
	while u.ap > 0:
		var t := _best_target(u)
		if t == null or chance(u, t) < 15:
			break
		shoot(u, t)


## Highest hit chance; ties go to the more wounded target.
func _best_target(u: Unit) -> Unit:
	var t: Unit = null
	var tc := 0
	for f in enemies_of(u):
		var c := chance(u, f)
		if c > tc or (c == tc and t != null and f.hp < t.hp):
			t = f
			tc = c
	return t


func _spot_score(u: Unit, p: Vector2i) -> float:
	return _best_attack(u, p) - 0.6 * _exposure(u, p)


func _best_attack(u: Unit, p: Vector2i) -> int:
	var best := 0
	for f in enemies_of(u):
		best = maxi(best, chance_from(p, f.pos))
	return best


func _exposure(u: Unit, p: Vector2i) -> int:
	var worst := 0
	for f in enemies_of(u):
		worst = maxi(worst, chance_from(f.pos, p))
	return worst


func _advance_tile(u: Unit, r: Dictionary, foes: Array) -> Vector2i:
	var best := u.pos
	var best_d := _nearest(u.pos, foes)
	for p in r:
		var d := _nearest(p, foes)
		if d < best_d or (d == best_d and best != u.pos and _exposure(u, p) < _exposure(u, best)):
			best = p
			best_d = d
	return best


static func _nearest(p: Vector2i, foes: Array) -> int:
	var best := 999
	for f in foes:
		best = mini(best, _manhattan(p, f.pos))
	return best


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
