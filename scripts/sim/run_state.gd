extends RefCounted
## Everything about one run of the Rail Yards slice, as plain data.
## No scenes, no UI: the rules read and write this, saves serialize it.

const MAX_WEEKS := 6

var run_seed := 0
var week := 1

# Resources (docs/slice-spec.md §3)
var cash := 4
var supplies := 4
var parts := 0
var legitimacy := 0

## Operatives, including you at index 0.
## Each: {name, is_you, is_teodor, out_weeks (0 = ready), dead}
var operatives: Array = []

var heat := 1
var heat_gained := 0        # heat added this week (a quiet week cools down)

## Zones: sentiment 0-100, regime attention this week, intel certainty
## (0 rumor, 1 likely, 2 confirmed), aid runs delivered there.
var zones := {
	"dorms": {"sentiment": 25, "attention": 0, "certainty": 0, "aid_runs": 0, "listens": 0},
	"depot": {"sentiment": 25, "attention": 0, "certainty": 0, "aid_runs": 0, "listens": 0},
}

## Teodor (docs/slice-spec.md §7).
## state: "unmet", "met", "ally", "lost". path: "", "trust", "leverage", "lie".
var teodor := {
	"state": "unmet", "path": "", "loyalty": "", "knows_skim": false,
	"lied": false, "confessed": false, "betrayed": false, "strike_used": false,
}

var strike_weeks := 0          # weeks of strike effect left
var diversion_zone := ""       # zone the regime was pulled toward this week
var broadcast_aired := false
var kills := 0
var prisoners := 0             # White Flag: guards held after surrendering (choices come later)
var surrenders := 0            # guards who gave up, all run (its own stat, not "got out")
var ending := ""               # empty until the run ends
var report: Array[String] = []  # this week's report lines

var rng := RandomNumberGenerator.new()


static func create(seed_value: int) -> RefCounted:
	var s = load("res://scripts/sim/run_state.gd").new()
	s.run_seed = seed_value
	s.rng.seed = seed_value
	s.operatives = [
		{"name": "You", "is_you": true, "is_teodor": false, "out_weeks": 0, "dead": false},
		{"name": "Mara", "is_you": false, "is_teodor": false, "out_weeks": 0, "dead": false},
		{"name": "Kesh", "is_you": false, "is_teodor": false, "out_weeks": 0, "dead": false},
	]
	return s


func ready_operatives() -> Array:
	var out := []
	for i in range(operatives.size()):
		var o: Dictionary = operatives[i]
		if not o.dead and o.out_weeks == 0:
			out.append(i)
	return out


func is_over() -> bool:
	return ending != ""


func to_dict() -> Dictionary:
	return {
		"run_seed": run_seed, "week": week, "cash": cash, "supplies": supplies, "parts": parts,
		"legitimacy": legitimacy, "operatives": operatives.duplicate(true), "heat": heat, "heat_gained": heat_gained,
		"zones": zones.duplicate(true), "teodor": teodor.duplicate(true),
		"strike_weeks": strike_weeks, "diversion_zone": diversion_zone,
		"broadcast_aired": broadcast_aired, "kills": kills, "ending": ending,
		"prisoners": prisoners, "surrenders": surrenders,
		"rng_state": rng.state,
	}


static func from_dict(d: Dictionary) -> RefCounted:
	var s = load("res://scripts/sim/run_state.gd").new()
	for key in ["run_seed", "week", "cash", "supplies", "parts", "legitimacy", "heat", "heat_gained",
			"strike_weeks", "diversion_zone", "broadcast_aired", "kills", "ending"]:
		s.set(key, d[key])
	s.prisoners = int(d.get("prisoners", 0))   # saves from before White Flag have none
	s.surrenders = int(d.get("surrenders", 0))
	s.operatives = d.operatives.duplicate(true)
	s.zones = d.zones.duplicate(true)
	s.teodor = d.teodor.duplicate(true)
	s.rng.seed = d.run_seed
	s.rng.state = d.rng_state
	return s
