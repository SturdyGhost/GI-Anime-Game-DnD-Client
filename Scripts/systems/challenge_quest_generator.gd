class_name ChallengeQuestGenerator
extends RefCounted

## Element pairs for reaction challenges — ordered as "apply A then B"
const REACTION_PAIRS := [
	["Fire", "Ice"],       # Melt
	["Ice", "Fire"],       # Reverse Melt
	["Fire", "Water"],     # Vaporize
	["Water", "Fire"],     # Reverse Vaporize
	["Fire", "Electric"],  # Overloaded
	["Ice", "Electric"],   # Superconduct
	["Electric", "Water"], # Electro-Charged
	["Nature", "Water"],   # Bloom
	["Fire", "Nature"],    # Burning
	["Wind", "Fire"],      # Swirl (Fire)
	["Wind", "Ice"],       # Swirl (Ice)
	["Wind", "Electric"],  # Swirl (Electro)
	["Wind", "Water"],     # Swirl (Hydro)
	["Earth", "Fire"],     # Crystallize (Fire)
	["Earth", "Ice"],      # Crystallize (Ice)
	["Earth", "Electric"], # Crystallize (Electro)
	["Earth", "Water"],    # Crystallize (Hydro)
	["Ice", "Water"],      # Freeze
	["Nature", "Electric"],# Quicken
]

const ELEMENT_COLORS := {
	"Fire": "ef4444",
	"Water": "3b82f6",
	"Ice": "67e8f9",
	"Electric": "a78bfa",
	"Nature": "4ade80",
	"Wind": "6ee7b7",
	"Earth": "d4a017",
}

const NON_REACTION_CHALLENGES := [
	{"text": "Defeat an enemy with a charged attack", "category": "kill"},
	{"text": "Defeat an enemy with an elemental skill", "category": "kill"},
	{"text": "Defeat an enemy with an elemental burst", "category": "kill"},
	{"text": "Defeat an enemy with a normal attack", "category": "kill"},
	{"text": "No party member takes a crit", "category": "defense"},
	{"text": "No party member is knocked out", "category": "defense"},
	{"text": "Every party member deals damage this battle", "category": "tactical"},
	{"text": "Apply 3 different status effects", "category": "tactical"},
	{"text": "Land 2 or more critical hits", "category": "tactical"},
	{"text": "Use at least 2 elemental bursts", "category": "tactical"},
	{"text": "Win within 8 turns", "category": "speed"},
	{"text": "Win within 6 turns", "category": "speed"},
	{"text": "Win without using any items", "category": "defense"},
]

static func _color_element(element: String) -> String:
	var hex = ELEMENT_COLORS.get(element, "ffffff")
	return "[color=#%s]%s[/color]" % [hex, element]

const QUEST_GIVERS := [
	{"name": "Zhiqiong", "personality": "Generous", "multiplier": 1.5},
	{"name": "Katheryne", "personality": "Fair", "multiplier": 1.0},
	{"name": "Cyrus", "personality": "Fair", "multiplier": 1.0},
	{"name": "Lan", "personality": "Stingy", "multiplier": 0.6},
	{"name": "Ying'er", "personality": "Generous", "multiplier": 1.5},
	{"name": "Wagner", "personality": "Stingy", "multiplier": 0.6},
	{"name": "Sara", "personality": "Fair", "multiplier": 1.0},
	{"name": "Dori", "personality": "Shrewd", "multiplier": 0.75},
	{"name": "Dunyarzad", "personality": "Generous", "multiplier": 1.5},
]

static func generate() -> ChallengeQuest:
	var giver = QUEST_GIVERS[randi() % QUEST_GIVERS.size()]

	# ~40% chance of a reaction challenge, ~60% other
	var text: String
	var category: String
	if randf() < 0.4:
		var pair = REACTION_PAIRS[randi() % REACTION_PAIRS.size()]
		text = "Trigger a %s then %s reaction" % [_color_element(pair[0]), _color_element(pair[1])]
		category = "reaction"
	else:
		var challenge = NON_REACTION_CHALLENGES[randi() % NON_REACTION_CHALLENGES.size()]
		text = challenge["text"]
		category = challenge["category"]

	return ChallengeQuest.new(
		text,
		category,
		giver["name"],
		giver["personality"],
		giver["multiplier"]
	)
