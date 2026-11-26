extends RefCounted
## Mid-fight save (QoL step 4, Nov 25; Duff's call Nov 6: "save mid-fight: yes").
## The Signal Box fight writes user://fight.save at the start of each of your turns, when the
## phone leaves the app, on pause and on Save & quit. Continue on the title drops you back
## into the fight at that turn. Only fights launched by a run are saved (Fight now isn't).
## The file holds the run as it stood when the fight began (diversions already paid), the
## week's plan entries, Teodor before the week, the mission params and the whole Battle.

const PATH := "user://fight.save"
const VERSION := 1


static func save(meta: Dictionary, battle) -> void:
	if not meta.has("state") or battle == null:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_var({
		"version": VERSION,
		"run": meta.state.to_dict(),
		"entries": meta.entries,
		"teodor_before": meta.teodor_before,
		"params": meta.params,
		"battle": battle.to_dict(),
	})


## The saved fight, or {} if there is none, it's from another version, or it doesn't
## belong to this run (a different seed or week: a stale file from an older run).
static func load_for(run_seed: int, week: int) -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = f.get_var()
	if not (d is Dictionary) or int(d.get("version", 0)) != VERSION or not (d.get("run") is Dictionary):
		clear()
		return {}
	if int(d.run.get("run_seed", -1)) != run_seed or int(d.run.get("week", -1)) != week:
		clear()
		return {}
	return d


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
