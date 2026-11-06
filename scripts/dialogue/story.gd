extends RefCounted
## Glue between the week loop and Teodor's scenes (docs/slice-spec.md §7).
## Pure functions, so the headless tests can drive a run exactly like the UI:
##   1. pre_scenes() before the week resolves; their `choice` fills the plan.
##   2. Rules.resolve_week().
##   3. post_beats() for what happened to Teodor (betrayal, found out, ...).

const Dialogue = preload("res://scripts/dialogue/dialogue.gd")
const SCRIPT_PATH := "res://dialogue/teodor.dlg"

## Every scene the game can start directly.
const ALL_NODES := ["meet", "talk", "confess", "strike", "confess_stayed", "confess_left", "found_out", "betrayal"]

## Who appears in a scene's portrait, by speaker name.
const PORTRAITS := {
	"TEODOR": "res://docs/renders/portrait_teodor.png",
	"MARA": "res://docs/renders/portrait_mara.png",
	"KESH": "res://docs/renders/portrait_kesh.png",
}

static var _cache := {}


static func load_nodes() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(SCRIPT_PATH, FileAccess.READ)
		if f == null:
			push_error("story: can't open " + SCRIPT_PATH)
			return {}
		_cache = Dialogue.parse(f.get_as_text())
	return _cache


## What a scene's conditions can see.
static func context(s) -> Dictionary:
	var t: Dictionary = s.teodor
	return {
		"aid_runs": int(s.zones.depot.aid_runs), "knows_skim": bool(t.knows_skim),
		"lied": bool(t.lied), "confessed": bool(t.confessed), "path": str(t.path),
		"loyalty": str(t.loyalty), "legitimacy": int(s.legitimacy), "heat": int(s.heat),
		"week": int(s.week),
	}


static func context_keys() -> Array:
	return ["aid_runs", "knows_skim", "lied", "confessed", "path", "loyalty", "legitimacy", "heat", "week"]


## Scenes to play before the week resolves: [{node, entry}], entry = index in plan.
static func pre_scenes(s, plan: Array) -> Array:
	var out := []
	for i in range(plan.size()):
		match plan[i].action:
			"see_teodor":
				out.append({"node": "meet" if s.teodor.state == "unmet" else "talk", "entry": i})
			"confess":
				out.append({"node": "confess", "entry": i})
			"strike":
				out.append({"node": "strike", "entry": i})
	return out


## Scenes for what the week did to Teodor. `before` is his state before resolving.
static func post_beats(before: Dictionary, after: Dictionary, plan: Array) -> Array[String]:
	var out: Array[String] = []
	var confessed_now := plan.any(func(p): return p.action == "confess")
	if confessed_now:
		out.append("confess_stayed" if after.state == "ally" else "confess_left")
		return out
	if before.state == "ally" and after.state == "lost":
		if after.betrayed and not before.betrayed:
			out.append("betrayal")
		elif before.lied and not before.confessed:
			out.append("found_out")
	return out
