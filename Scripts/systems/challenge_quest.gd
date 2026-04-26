class_name ChallengeQuest
extends RefCounted

var challenge_text: String
var challenge_category: String
var quest_giver_name: String
var quest_giver_personality: String
var reward_multiplier: float
var completed: bool = false

func _init(text: String = "", category: String = "", giver: String = "", personality: String = "Fair", multiplier: float = 1.0) -> void:
	challenge_text = text
	challenge_category = category
	quest_giver_name = giver
	quest_giver_personality = personality
	reward_multiplier = multiplier

func to_player_dict() -> Dictionary:
	return {
		"challenge_text": challenge_text,
		"quest_giver_name": quest_giver_name,
		"quest_giver_personality": quest_giver_personality,
	}

func to_dict() -> Dictionary:
	return {
		"challenge_text": challenge_text,
		"challenge_category": challenge_category,
		"quest_giver_name": quest_giver_name,
		"quest_giver_personality": quest_giver_personality,
		"reward_multiplier": reward_multiplier,
		"completed": completed,
	}

static func from_dict(d: Dictionary) -> ChallengeQuest:
	var q = ChallengeQuest.new()
	q.challenge_text = str(d.get("challenge_text", ""))
	q.challenge_category = str(d.get("challenge_category", ""))
	q.quest_giver_name = str(d.get("quest_giver_name", ""))
	q.quest_giver_personality = str(d.get("quest_giver_personality", "Fair"))
	q.reward_multiplier = float(d.get("reward_multiplier", 1.0))
	q.completed = bool(d.get("completed", false))
	return q
