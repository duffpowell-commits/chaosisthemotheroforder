extends RefCounted
## Player-facing text for the slice UI: action cards, choices, bulletins, endings.

const ACTIONS := {
	"aid": {"title": "Aid run", "desc": "Food and medicine. Support +10. Quiet unless it fails.", "zone": "Deliver where?"},
	"expose": {"title": "Expose", "desc": "Posters and leaflets. Support +8, Legitimacy +1. Heat +1.", "zone": "Paper which walls?"},
	"recruit": {"title": "Recruit", "desc": "Find new hands. +1 operative, +2 if the zone is Sympathetic. Heat +1.", "zone": "Recruit where?"},
	"scavenge": {"title": "Scavenge", "desc": "Scrapyards: cash, supplies or parts. Small risk of being stopped."},
	"listen": {"title": "Listen", "desc": "Sit in the bars and stairwells. Confirms what a zone really thinks.", "zone": "Listen where?"},
	"lay_low": {"title": "Lay low", "desc": "Keep the cell quiet. Heat −3."},
	"see_teodor": {"title": "See Teodor", "desc": "The dock foreman at the Freight Depot. What you say to him matters."},
	"diversion": {"title": "Signal Fire", "desc": "Fake a protest to pull the regime's eyes elsewhere. Fails get people arrested.", "zone": "Stage the decoy where?"},
	"strike": {"title": "Call the strike", "desc": "Teodor stops the cranes. Depot +20, regime attention −1 for 2 weeks. Heat +2."},
	"signal_box": {"title": "Signal box op", "desc": "Lead a squad into the depot, air the raid footage, get out. Everyone free this week goes with you."},
	"confess": {"title": "Tell Teodor the truth", "desc": "There was never a plan for Kell. He might stay. He might not."},
	"rally": {"title": "Call the rally", "desc": "Both zones are Ready. Fill the Rail Yards. Without proof, it gets crushed."},
	"seize": {"title": "Seize the district", "desc": "Take the Rail Yards by force. Fast. You will hold it like an occupier."},
}

## The ledger look of the action picker (Nov 25, Duff picked "All six"): one short
## line per action plus effect chips, so the numbers read at a glance. Chip kinds:
## good (green, +), heat (red, flame icon), bad (red outline), info (ink outline).
## Costs come from Rules.ACTIONS, not from here. Keep in sync with ACTIONS above.
const ACTION_CARDS := {
	"aid": {"line": "Food and medicine. Quiet unless it fails.", "fx": [["+10 Support", "good"]]},
	"expose": {"line": "Posters and leaflets.", "fx": [["+8 Support", "good"], ["+1 Legitimacy", "good"], ["+1 Heat", "heat"]]},
	"recruit": {"line": "Find new hands.", "fx": [["+1 operative", "good"], ["+2 if Sympathetic", "good"], ["+1 Heat", "heat"]]},
	"scavenge": {"line": "Scrapyards. You might get stopped.", "fx": [["+cash, supplies or parts", "good"]]},
	"listen": {"line": "Bars and stairwells.", "fx": [["Confirms a zone's mood", "info"]]},
	"lay_low": {"line": "Keep the cell quiet.", "fx": [["−3 Heat", "good"]]},
	"diversion": {"line": "A fake protest pulls patrols away.", "fx": [["Moves 2 patrols", "good"], ["+1 Heat", "heat"], ["Fail: arrested", "bad"]]},
	"see_teodor": {"line": "The dock foreman at the Freight Depot. What you say to him matters.", "fx": []},
	"strike": {"line": "Teodor stops the cranes.", "fx": [["+20 Depot", "good"], ["−1 patrols, 2 weeks", "good"], ["+2 Heat", "heat"]]},
	"confess": {"line": "There was never a plan for Kell.", "fx": [["He might walk", "bad"]]},
	"signal_box": {"line": "Air the raid footage, get out.", "fx": [["Everyone free goes", "info"]]},
	"rally": {"line": "Both zones are Ready. Fill the Rail Yards.", "fx": [["No proof: crushed", "bad"]]},
	"seize": {"line": "Take the Rail Yards by force.", "fx": [["You hold it like an occupier", "bad"]]},
}

## Plan actions that ask "how?" before they're committed. The Signal Box used to
## (quiet or loud); since M5 you decide that in the mission itself.
const CHOICES := {}

## Display names for dialogue speakers.
const SPEAKERS := {"YOU": "You", "TEODOR": "Teodor", "MARA": "Mara", "KESH": "Kesh"}

const ZONE_NAMES := {"dorms": "The Dormitories", "depot": "The Freight Depot"}

const HEAT_LEVELS := [
	[9, "FOUND"], [7, "Targeted raids"], [5, "Checkpoint raids"], [3, "Patrols"], [0, "Quiet"],
]

const ENDINGS := {
	"district_turns": {
		"title": "The District Turns",
		"text": "They came out of the dormitories with the footage still playing on the station screens. Nobody fired. By morning the checkpoint was a market again. The Continuity Government called it a misunderstanding. Nobody in the Rail Yards believed them anymore.",
		"grade": 1.0,
	},
	"yards_silent": {
		"title": "The Yards Go Silent",
		"text": "The cranes stood still for nine days. No cargo left Port Varga. Teodor stood on a container and read the names of the disappeared, and the dock repeated every one. The yards belong to the people who work them now. Holding them will be harder than taking them.",
		"grade": 1.0,
	},
	"occupiers": {
		"title": "Occupiers",
		"text": "You hold the Rail Yards. The people inside their doors watch you the way they watched the police. State TV plays your men on a loop. You won the street and lost the argument. The district stays cold.",
		"grade": 0.35,
	},
	"captured": {
		"title": "Captured",
		"text": "They came at four in the morning. The interrogation room has no windows. Somewhere above you the cell is still working: the posters, the aid runs, the names. Whatever you built is walking on without you now.",
		"grade": 0.15,
	},
	"window_closes": {
		"title": "The Window Closes",
		"text": "Week six ended and the soldiers came in trucks. The curfew moved to seven. The posters came down. Nobody was shot, and nothing changed, and everyone remembers that you tried.",
		"grade": 0.0,
	},
}


## The regime's spin on the week for the state TV bulletin.
static func regime_bulletin(s) -> Array[String]:
	var lines: Array[String] = []
	var avg := (int(s.zones.dorms.sentiment) + int(s.zones.depot.sentiment)) / 2
	if s.broadcast_aired:
		lines.append("The Ministry warns that doctored footage is circulating. Citizens should report anyone sharing it.")
	if s.heat >= 7:
		lines.append("Security forces have identified the leaders of the extremist cell. Arrests are imminent.")
	elif s.heat >= 4:
		lines.append("Patrols are reinforced in District 7 after extremist activity.")
	if avg >= 50:
		lines.append("A small number of agitators disrupted the Rail Yards. Most residents reject them.")
	else:
		lines.append("Calm continues in District 7. The Emergency Order remains in force for your protection.")
	lines.append("The Harbor Exchange closed at a record high.")
	return lines


static func heat_label(heat: int) -> String:
	for pair in HEAT_LEVELS:
		if heat >= pair[0]:
			return pair[1]
	return "Quiet"
