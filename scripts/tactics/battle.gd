extends RefCounted
## Tactical core (docs/slice-spec.md §9, M4): a turn-based skirmish as plain
## data. No scenes: the tactical scene reads and drives this, tests run it headless.
##
## Grid: W x H tiles. Crates are half cover, containers full cover; neither can
## be stood on. Gantry tiles are high ground and walkable.
## Each unit: 2 AP, 2 HP. Move = 1 AP per 4 tiles. Shoot = 1 AP, a hit does 1.
## Hit chance: 65 base, half cover -20, full -40, high ground +10, flanking +20,
## clamped 5-95. Cover only counts on the side facing the shooter.
##
## Mission mode (M5, the Signal Box): the same rules plus noise, an alarm with
## reinforcements, the signal box upload, extraction from the south edge,
## Sneak / Subdue / Overwatch / Stabilize / Persuade, and permadeath.
##
## Diversion tools (J1.5, docs/diversion-tools-spec.md): Smoke, Lights out,
## fake Radio call, defector Flashbang. Abstract game actions only: the game
## shows effect and cost, never how the real thing works.

const W := 14
const H := 14

const FLOOR := 0
const HALF := 1
const FULL := 2
const HIGH := 3
const BOX := 4  # the signal box: blocks like a container, upload from next to it

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

const MISSION_SIGHT := 7    # guards see less far in the dark depot yard
const HIDDEN_SIGHT := 2     # a sneaking unit is only spotted this close
const NOISE_MAX := 10
const NOISE_SHOT := 3
const NOISE_SUBDUE := 1
const NOISE_RADIUS := 3     # tiles of hearing per point of noise made
const REINFORCE_DELAY := 2
const REINFORCEMENTS := 3
const UPLOAD_TURNS := 2
const BLEED_TURNS := 2
const PERSUADE_RANGE := 3
const NOISE_SHOUT := 2      # a guard who spots you yells for the others
const BROADCAST_STUN := 1   # regime turns the guards lose watching the footage air

const EXTRA_GUARDS := 1    # J1.5 rebalance: the depot posts one more guard than the run's count
const JUNCTION := 5         # the floodlight junction box: blocks movement, not sight
const JUNCTION_POS := Vector2i(0, 8)
const SMOKE_CHARGES := 1
const SMOKE_RANGE := 5
const SMOKE_TURNS := 2      # regime turns the cloud lasts
const SMOKE_PENALTY := 30   # to hit a unit standing in smoke
const NOISE_SMOKE := 2
const DARK_TURNS := 3
const DARK_ROWS := 6        # rows 0..6: the box's half of the yard, under the floodlight
const NOISE_LIGHTS := 1
const RADIO_BASE := 30
const RADIO_PER_LEGIT := 10
const RADIO_CAP := 85
const RADIO_GUARDS := 2
const BUSY_TURNS := 2
const NOISE_RADIO_FAIL := 3
const FLASH_RANGE := 4
const FLASH_STUN := 1
const NOISE_FLASH := 4


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
	# Mission mode
	var is_you := false
	var op := -1             # index into the run's operatives (-1 = not one of ours)
	var wavering := false
	var defected := false
	var hidden := false      # moved by Sneak and hasn't been loud since
	var overwatch := false
	var subdued := false
	var bleed := 0           # your turns left before a downed squadmate dies
	var stabilized := false
	var dead := false
	# Diversion tools (J1.5)
	var busy := 0            # regime turns chasing a fake radio call
	var stun := 0            # regime turns lost to a flashbang
	var flash := 0           # flashbangs carried (a defector brings 1)
	var check := Vector2i(-1, -1)  # where a guard walks to look (the junction box)

	func alive() -> bool:
		return hp > 0 and not escaped

	func downed() -> bool:
		return hp <= 0 and not dead and not escaped


var tiles := PackedInt32Array()
var units: Array = []
var rng := RandomNumberGenerator.new()
var side := US
var turn := 1
var log: Array[String] = []

var mission := false
var sight := SIGHT
var noise := 0
var alarm := false
var reinforce_in := 0       # turns until reinforcements arrive (0 = none coming)
var stunned := 0            # regime turns the guards spend staring at the broadcast
var upload := 0
var last_upload_turn := 0
var box := Vector2i(-1, -1)
var legitimacy := 0
var kills := 0
var defections := 0
var smoke_left := SMOKE_CHARGES
var smokes: Array = []      # [[centre: Vector2i, regime turns left: int]]
var dark := 0               # turns the floodlit half stays dark
var lights_used := false
var radio_used := false


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


## The Signal Box (spec §9). `params`: {guards, legitimacy, squad: [{name, op,
## is_you}], seed}. The box sits at the north end of the depot yard; the squad
## comes in from the south edge and leaves the same way.
const BOX_POS := Vector2i(7, 1)
const GUARD_ROUTES := [
	[Vector2i(1, 2), Vector2i(7, 2)],
	[Vector2i(12, 3), Vector2i(12, 7)],
	[Vector2i(5, 6), Vector2i(8, 6)],
	[Vector2i(9, 0), Vector2i(4, 0)],
	[Vector2i(12, 0), Vector2i(13, 2)],  # J1.5: 5th guard, NE corner by the box (not the entry row)
	[Vector2i(1, 6), Vector2i(1, 10)],
	[Vector2i(10, 9), Vector2i(13, 9)],
	[Vector2i(8, 8), Vector2i(12, 8)],
]
const SQUAD_XS := [3, 7, 11, 1, 5, 9]


static func create_mission(params: Dictionary) -> RefCounted:
	var b = create_skirmish(int(params.get("seed", 1)))
	b.units.clear()
	b.mission = true
	b.sight = MISSION_SIGHT
	b.legitimacy = int(params.get("legitimacy", 0))
	b.box = BOX_POS
	b.set_tile(BOX_POS, BOX)
	b.set_tile(JUNCTION_POS, JUNCTION)
	var squad: Array = params.get("squad", [{"name": "You", "op": 0, "is_you": true}])
	for i in range(mini(squad.size(), SQUAD_XS.size())):
		var m: Dictionary = squad[i]
		var u = b.add_unit(str(m.name), US, Vector2i(SQUAD_XS[i], H - 1))
		u.op = int(m.get("op", -1))
		u.is_you = bool(m.get("is_you", false))
	var n := clampi(int(params.get("guards", 4)) + EXTRA_GUARDS, 1, GUARD_ROUTES.size())
	var waver: int = b.rng.randi_range(0, n - 1)
	for i in range(n):
		var g = b.add_unit("Guard %d" % (i + 1), REGIME, GUARD_ROUTES[i][0])
		g.route = GUARD_ROUTES[i]
		g.wavering = i == waver
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
	return in_bounds(p) and (tile(p) == FLOOR or tile(p) == HIGH) and unit_at(p) == null


## Containers and the signal box block sight and give full cover.
func _blocks(p: Vector2i) -> bool:
	return tile(p) == FULL or tile(p) == BOX


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
		if in_smoke(p):
			return false  # smoke: nothing is seen or hit through the cloud
		if _cheb(p, a) <= 1 or _cheb(p, b) <= 1:
			continue
		if _blocks(p):
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
		if t == FULL or t == BOX:
			best = FULL
		elif t == HALF and best != FULL:
			best = HALF
	return best


func _has_any_cover(p: Vector2i) -> bool:
	for d in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		var n: Vector2i = p + d
		if in_bounds(n) and tile(n) != FLOOR and tile(n) != HIGH and tile(n) != JUNCTION:
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
	if in_smoke(to):
		c -= SMOKE_PENALTY  # firing blind at where you last saw them
	return clamp_chance(c)


func chance(shooter: Unit, target: Unit) -> int:
	return chance_from(shooter.pos, target.pos)


## What a guard can do on his next turn, for "threat on tap". Mirrors _fight:
## he moves up to 2 AP, or moves 1 AP and shoots (only at 15%+).
## {"move": {tile: true}, "shoot": {tile: best hit %}}. Shoot covers every
## floor/high tile he could fire on, empty or not, so you can plan around it.
const AI_MIN_SHOT := 15

func threat(g: Unit) -> Dictionary:
	var keep := g.ap
	g.ap = AP_PER_TURN
	var move_to := reachable(g, AP_PER_TURN)
	var from: Array = reachable(g, 1).keys()
	g.ap = keep
	from.append(g.pos)
	var shoot := {}
	for y in range(H):
		for x in range(W):
			var p := Vector2i(x, y)
			if p == g.pos or not (tile(p) == FLOOR or tile(p) == HIGH):
				continue
			var best := 0
			for q in from:
				best = maxi(best, chance_from(q, p))
			if best >= AI_MIN_SHOT:
				shoot[p] = best
	var mv := {}
	for p in move_to:
		mv[p] = true
	return {"move": mv, "shoot": shoot}


## Shot preview for the Shoot button: {"chance", "result" ("down"/"wounded"), "noise"}.
func shot_preview(u: Unit, target: Unit) -> Dictionary:
	return {
		"chance": chance(u, target),
		"result": "down" if target.hp <= 1 else "wounded",
		"noise": NOISE_SHOT if mission and u.side == US else 0,
	}


func winner() -> String:
	if mission:
		return ""
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
	u.hidden = false
	if u.side == REGIME:
		_trigger_overwatch(u)
	return true


## Returns true on a hit. Shooting (and being shot at) alerts every guard.
func shoot(u: Unit, target: Unit) -> bool:
	var c := chance(u, target)
	if not u.alive() or u.ap < 1 or c <= 0 or not target.alive():
		return false
	u.ap -= 1
	return _fire(u, target, c)


func _fire(u: Unit, target: Unit, c: int) -> bool:
	u.hidden = false
	alert_all("%s fires" % u.name)
	if u.side == US:
		add_noise(NOISE_SHOT, u.pos)
	var hit := rng.randi_range(1, 100) <= c
	if hit:
		target.hp -= 1
		log.append("%s %s %s (%d%%)%s" % [u.name, _verb(u, "hits"), target.name, c, ", down" if target.hp <= 0 else ""])
		if target.hp <= 0 and mission:
			if target.side == REGIME:
				kills += 1
			else:
				target.bleed = BLEED_TURNS
	else:
		log.append("%s %s %s (%d%%)" % [u.name, _verb(u, "misses"), target.name, c])
	return hit


# ---------- mission actions ----------

## One silent move of up to 4 tiles for both AP. Patrols only spot a sneaking
## unit from HIDDEN_SIGHT tiles away.
func sneak(u: Unit, dest: Vector2i) -> bool:
	if not mission or u.ap < AP_PER_TURN or not reachable(u, 1).has(dest):
		return false
	u.ap = 0
	u.pos = dest
	u.hidden = true
	return true


func can_subdue(u: Unit, target: Unit) -> bool:
	return mission and u.alive() and u.ap >= 1 and target != null and target.alive() \
		and target.side != u.side and _cheb(u.pos, target.pos) == 1


## Non-lethal takedown from an adjacent tile. Always works; it's close and quiet.
func subdue(u: Unit, target: Unit) -> bool:
	if not can_subdue(u, target):
		return false
	u.ap -= 1
	target.hp = 0
	target.subdued = true
	log.append("%s %s %s" % [u.name, _verb(u, "subdues"), target.name])
	add_noise(NOISE_SUBDUE, target.pos)
	return true


## Spend the rest of the turn watching: the first guard that moves where this
## unit can see it draws a shot.
func overwatch(u: Unit) -> bool:
	if not mission or not u.alive() or u.ap < 1:
		return false
	u.ap = 0
	u.overwatch = true
	log.append("%s %s on overwatch" % [u.name, _verb(u, "is")])
	return true


func _trigger_overwatch(g: Unit) -> void:
	for w in alive_units(US):
		if not g.alive():
			return
		if not w.overwatch or _cheb(w.pos, g.pos) > sight:
			continue
		var c := chance(w, g)
		if c > 0:
			w.overwatch = false
			log.append("%s %s" % [w.name, _verb(w, "reacts")])
			_fire(w, g, c)


func can_upload(u: Unit) -> bool:
	return mission and u.alive() and u.ap >= 1 and upload < UPLOAD_TURNS \
		and last_upload_turn != turn and _cheb(u.pos, box) == 1


## Work the signal box. Two separate turns of it and the footage airs; every
## screen in the district lights up and every guard knows where you are.
func do_upload(u: Unit) -> bool:
	if not can_upload(u):
		return false
	u.ap -= 1
	upload += 1
	last_upload_turn = turn
	if upload < UPLOAD_TURNS:
		log.append("%s %s the upload" % [u.name, _verb(u, "starts")])
		return true
	log.append("The footage is on every screen in the district")
	alert_all("the broadcast")
	stunned = BROADCAST_STUN
	return true


func stabilize_target(u: Unit) -> Unit:
	if not mission or not u.alive() or u.ap < 1:
		return null
	for o in units:
		if o.side == US and o.downed() and not o.stabilized and _cheb(u.pos, o.pos) <= 1:
			return o
	return null


func stabilize(u: Unit) -> bool:
	var o := stabilize_target(u)
	if o == null:
		return false
	u.ap -= 1
	o.stabilized = true
	log.append("%s %s %s" % [u.name, _verb(u, "stabilizes"), o.name])
	return true


func can_leave(u: Unit) -> bool:
	return mission and u.alive() and u.pos.y == H - 1


## Off the south edge and out of the mission.
func leave(u: Unit) -> bool:
	if not can_leave(u):
		return false
	u.ap = 0
	u.escaped = true
	log.append("%s %s out" % [u.name, _verb(u, "gets")])
	return true


func persuade_chance() -> int:
	return clamp_chance(40 + 10 * legitimacy)


func can_persuade(u: Unit, target: Unit) -> bool:
	return mission and u.is_you and u.alive() and u.ap >= 1 and target != null and target.alive() \
		and target.side == REGIME and target.wavering and _cheb(u.pos, target.pos) <= PERSUADE_RANGE \
		and line_of_sight(u.pos, target.pos)


## Talk a Wavering guard over. One try: if it fails, they stop wavering.
func persuade(u: Unit, target: Unit) -> bool:
	if not can_persuade(u, target):
		return false
	u.ap -= 1
	var c := persuade_chance()
	target.wavering = false
	if rng.randi_range(1, 100) <= c:
		target.side = US
		target.defected = true
		target.state = ALERT
		target.ap = 0
		target.route = []
		target.flash = 1
		defections += 1
		log.append("%s lowers his rifle and joins you (%d%%)" % [target.name, c])
		return true
	target.state = ALERT
	log.append("%s won't listen (%d%%)" % [target.name, c])
	return false


# ---------- diversion tools (J1.5) ----------

func in_smoke(p: Vector2i) -> bool:
	for sm in smokes:
		if _cheb(p, sm[0]) <= 1:
			return true
	return false


static func area3(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var p := c + Vector2i(dx, dy)
			if in_bounds(p):
				out.append(p)
	return out


func can_smoke(u: Unit, at: Vector2i) -> bool:
	return mission and u.alive() and u.side == US and u.ap >= 1 and smoke_left > 0 \
		and in_bounds(at) and _cheb(u.pos, at) <= SMOKE_RANGE and (at == u.pos or line_of_sight(u.pos, at))


## Smoke flare: a 3x3 cloud for 2 regime turns. Loud enough that every guard
## who can see the cloud comes to look.
func smoke(u: Unit, at: Vector2i) -> bool:
	if not can_smoke(u, at):
		return false
	u.ap -= 1
	smoke_left -= 1
	u.hidden = false
	var seen := []
	for g in alive_units(REGIME):
		if _cheb(g.pos, at) <= sight and line_of_sight(g.pos, at):
			seen.append(g)
	smokes.append([at, SMOKE_TURNS])
	log.append("%s %s a smoke flare" % [u.name, _verb(u, "pops")])
	for g in seen:
		if g.state == PATROL:
			g.state = ALERT
			log.append("%s sees the smoke" % g.name)
	add_noise(NOISE_SMOKE, at)
	return true


func can_lights_out(u: Unit) -> bool:
	return mission and u.alive() and u.side == US and u.ap >= 1 and not lights_used \
		and _cheb(u.pos, JUNCTION_POS) == 1 and tile(JUNCTION_POS) == JUNCTION


## Kill the floodlight: the box's half of the yard goes dark for 3 turns.
## The nearest patrol walks over to see what happened to the junction box.
func lights_out(u: Unit) -> bool:
	if not can_lights_out(u):
		return false
	u.ap -= 1
	lights_used = true
	dark = DARK_TURNS
	log.append("The floodlight dies. The north yard goes black")
	var near := lights_checker()
	if near != null:
		near.check = JUNCTION_POS
		log.append("%s goes to check the junction box" % near.name)
	add_noise(NOISE_LIGHTS, u.pos)
	return true


func radio_chance() -> int:
	return 0 if alarm else mini(RADIO_CAP, RADIO_BASE + RADIO_PER_LEGIT * legitimacy)


func can_radio(u: Unit) -> bool:
	return mission and u.alive() and u.is_you and u.ap >= 1 and not radio_used and _cheb(u.pos, box) == 1


## Who a successful call would send away: the guards nearest You who aren't
## already busy, stunned or Wavering.
func radio_targets(u: Unit) -> Array:
	# Not the Wavering one: he's the guard you're trying to talk over (J1.5 review).
	var gs: Array = alive_units(REGIME).filter(func(g): return g.busy == 0 and g.stun == 0 and not g.wavering)
	gs.sort_custom(func(a, b): return _manhattan(a.pos, u.pos) < _manhattan(b.pos, u.pos))
	return gs.slice(0, RADIO_GUARDS)


## Fake radio call from the box: "trouble at the far gate". Works or backfires.
## Nobody believes a call once the alarm is ringing (0%).
func radio(u: Unit) -> bool:
	if not can_radio(u):
		return false
	u.ap -= 1
	radio_used = true
	var c := radio_chance()
	if rng.randi_range(1, 100) <= c:
		for g in radio_targets(u):
			g.busy = BUSY_TURNS
			g.check = Vector2i(-1, -1)
			log.append("%s answers the call and heads out" % g.name)
		return true
	log.append("They hear a stranger on their channel (%d%%)" % c)
	alert_all("the radio")
	add_noise(NOISE_RADIO_FAIL, u.pos)
	return false


## A guard on a wild goose chase walks for the nearer side edge; when the
## chase is over he comes back on alert.
func _chase_radio(u: Unit) -> void:
	var edge_x := 0 if u.pos.x < W / 2 else W - 1
	var best := u.pos
	for p in reachable(u, AP_PER_TURN):
		if absi(p.x - edge_x) < absi(best.x - edge_x):
			best = p
	if best != u.pos:
		move(u, best)
	u.busy -= 1
	if u.busy == 0 and u.alive():
		u.state = ALERT
		log.append("%s realises it was a fake and comes back" % u.name)


func can_flash(u: Unit, at: Vector2i) -> bool:
	return mission and u.alive() and u.side == US and u.flash > 0 and u.ap >= 1 \
		and in_bounds(at) and _cheb(u.pos, at) <= FLASH_RANGE and line_of_sight(u.pos, at)


func flash_targets(at: Vector2i) -> Array:
	return alive_units(REGIME).filter(func(g): return _cheb(g.pos, at) <= 1)


## The defector's flashbang: guards within 1 tile of the blast lose their next turn.
func flashbang(u: Unit, at: Vector2i) -> bool:
	if not can_flash(u, at):
		return false
	u.ap -= 1
	u.flash -= 1
	u.hidden = false
	log.append("%s throws a flashbang" % u.name)
	for g in flash_targets(at):
		g.stun = FLASH_STUN
		g.state = ALERT
		log.append("%s is stunned" % g.name)
	add_noise(NOISE_FLASH, at)
	return true


## Would `n` more noise sound the alarm? For previews: no hidden math.
func trips_alarm(n: int) -> bool:
	return mission and not alarm and n > 0 and noise + n >= NOISE_MAX


## The guard who'd walk over to check the junction box after lights out.
func lights_checker() -> Unit:
	var near: Unit = null
	for g in alive_units(REGIME):
		if g.state == PATROL and (near == null or _manhattan(g.pos, JUNCTION_POS) < _manhattan(near.pos, JUNCTION_POS)):
			near = g
	return near


## Mission noise. Wakes patrols within NOISE_RADIUS tiles per point; at 10 the
## alarm sounds and reinforcements come REINFORCE_DELAY turns later.
func add_noise(n: int, at: Vector2i) -> void:
	if not mission or n <= 0:
		return
	noise = mini(NOISE_MAX, noise + n)
	for g in alive_units(REGIME):
		if g.state == PATROL and _cheb(g.pos, at) <= n * NOISE_RADIUS:
			g.state = ALERT
			log.append("%s hears something" % g.name)
	if noise >= NOISE_MAX and not alarm:
		alarm = true
		reinforce_in = REINFORCE_DELAY
		log.append("The alarm sounds")
		alert_all("the alarm")


func _reinforce() -> void:
	var n := 0
	for x in [7, 2, 12, 5, 9, 0, 13]:
		if n >= REINFORCEMENTS:
			break
		var p := Vector2i(x, 0)
		if not standable(p):
			continue
		var g := add_unit("Riot %d" % (n + 1), REGIME, p)
		g.state = ALERT
		g.ap = 0
		n += 1
	log.append("Reinforcements pour in from the north")


func is_over() -> bool:
	if mission:
		return alive_units(US).is_empty() or turn > TURN_LIMIT
	return winner() != ""


## What happened, for the run. Call once the mission is over. Downed squadmates
## left behind die; stabilized ones are carried out if anyone got out.
func mission_result() -> Dictionary:
	var anyone_out := false
	for u in units:
		if u.side == US and u.escaped:
			anyone_out = true
	var dead: Array = []
	var hurt: Array = []
	var out: Array = []
	var subdued := 0
	for u in units:
		if u.subdued:
			subdued += 1
		if u.side != US or u.defected:
			continue
		if u.escaped:
			out.append(u.name)
		elif u.dead or not (u.stabilized and anyone_out):
			dead.append(u.name)
		else:
			hurt.append(u.name)
	return {"aired": upload >= UPLOAD_TURNS, "kills": kills, "defections": defections,
		"subdued": subdued, "dead": dead, "hurt": hurt, "out": out,
		"you_dead": dead.has(_you_name())}


## "You" takes the plain verb: "You hit", "Mara hits".
static func _verb(u: Unit, third: String) -> String:
	if u.name != "You":
		return third
	return {"is": "are", "hits": "hit", "misses": "miss", "gets": "get"}.get(third, third.trim_suffix("s"))


func _you_name() -> String:
	for u in units:
		if u.is_you:
			return u.name
	return ""


func alert_all(why: String) -> void:
	for g in alive_units(REGIME):
		if g.state == PATROL:
			g.state = ALERT
			log.append("%s is alerted: %s" % [g.name, why])


func end_turn() -> void:
	if mission:
		for u in units:
			if u.side == US and u.downed() and not u.stabilized:
				u.bleed -= 1
				if u.bleed <= 0:
					u.dead = true
					log.append("%s %s out" % [u.name, _verb(u, "bleeds")])
	side = REGIME
	for g in alive_units(REGIME):
		g.ap = AP_PER_TURN
	if stunned > 0:
		stunned -= 1
		log.append("Every guard stares at the screens")
	else:
		for g in alive_units(REGIME):
			if g.stun > 0:
				g.stun -= 1
				log.append("%s is still reeling" % g.name)
				continue
			act_unit(g)
	for sm in smokes:
		sm[1] -= 1
	smokes = smokes.filter(func(sm): return sm[1] > 0)
	if dark > 0:
		dark -= 1
		if dark == 0:
			log.append("The floodlight comes back on")
	if mission and reinforce_in > 0:
		reinforce_in -= 1
		if reinforce_in == 0:
			_reinforce()
	side = US
	for u in alive_units(US):
		u.ap = AP_PER_TURN
		u.overwatch = false
	turn += 1


# ---------- AI (both sides use it; the player normally drives US) ----------

func act_unit(u: Unit) -> void:
	if not u.alive():
		return
	if u.side == REGIME and u.busy > 0:
		_chase_radio(u)
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
	if u.busy > 0:
		return false
	for e in enemies_of(u):
		if can_spot(u.pos, e):
			return true
	return false


## Could a guard at `from` spot `e`? Sneaking or dark: only up close. Smoke: never.
func can_spot(from: Vector2i, e: Unit) -> bool:
	if in_smoke(from) or in_smoke(e.pos):
		return false
	var r := HIDDEN_SIGHT if e.hidden else sight
	if dark > 0 and (from.y <= DARK_ROWS or e.pos.y <= DARK_ROWS):
		r = mini(r, HIDDEN_SIGHT)
	return _cheb(from, e.pos) <= r and line_of_sight(from, e.pos)


## Skirmish: one sighting alerts everyone. Mission: the guard shouts, which
## is noise; only guards in earshot react, and it pushes toward the alarm.
func _spotted_by(u: Unit) -> void:
	if not mission:
		alert_all("%s spots you" % u.name)
		return
	u.state = ALERT
	log.append("%s spots you and shouts" % u.name)
	add_noise(NOISE_SHOUT, u.pos)


func _patrol(u: Unit) -> void:
	if _sees_enemy(u):
		_spotted_by(u)
		_fight(u)
		return
	var goal: Vector2i = u.route[u.route_i]
	if u.check.x >= 0:
		if _cheb(u.pos, u.check) <= 1:
			log.append("%s checks the junction box" % u.name)
			u.check = Vector2i(-1, -1)
		else:
			goal = u.check
	if u.check.x < 0 and u.pos == goal:
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
	if u.alive() and _sees_enemy(u):
		_spotted_by(u)
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
		if not u.alive():
			return
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
	if not u.alive():
		return
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
