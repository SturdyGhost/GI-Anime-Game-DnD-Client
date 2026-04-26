class_name ChallengeQuestGenerator
extends RefCounted

const CHALLENGES := [
	{"text": "Trigger a Melt reaction", "category": "reaction"},
	{"text": "Trigger a Vaporize reaction", "category": "reaction"},
	{"text": "Trigger an Overloaded reaction", "category": "reaction"},
	{"text": "Trigger a Superconduct reaction", "category": "reaction"},
	{"text": "Trigger a Bloom reaction", "category": "reaction"},
	{"text": "Trigger a Burning reaction", "category": "reaction"},
	{"text": "Trigger an Electro-Charged reaction", "category": "reaction"},
	{"text": "Trigger a Swirl reaction", "category": "reaction"},
	{"text": "Trigger a Crystallize reaction", "category": "reaction"},
	{"text": "Trigger a Freeze reaction", "category": "reaction"},
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
	var challenge = CHALLENGES[randi() % CHALLENGES.size()]
	var giver = QUEST_GIVERS[randi() % QUEST_GIVERS.size()]
	return ChallengeQuest.new(
		challenge["text"],
		challenge["category"],
		giver["name"],
		giver["personality"],
		giver["multiplier"]
	)
