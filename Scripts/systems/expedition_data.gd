class_name ExpeditionData
extends RefCounted

var expedition_name: String
var region: String
var expedition_type: String
var description: String
var base_materials: int
var cache_roll: int
var risk_level: String
var bonus_region: String
var bonus_weapon: String
var bonus_element: String

func _init(data: Dictionary = {}) -> void:
	expedition_name = str(data.get("name", ""))
	region = str(data.get("region", ""))
	expedition_type = str(data.get("type", ""))
	description = str(data.get("description", ""))
	base_materials = int(data.get("base_materials", 3))
	cache_roll = int(data.get("cache_roll", 1))
	risk_level = str(data.get("risk_level", "safe"))
	bonus_region = str(data.get("bonus_region", ""))
	bonus_weapon = str(data.get("bonus_weapon", ""))
	bonus_element = str(data.get("bonus_element", ""))

func to_dict() -> Dictionary:
	return {
		"name": expedition_name, "region": region, "type": expedition_type,
		"description": description, "base_materials": base_materials,
		"cache_roll": cache_roll, "risk_level": risk_level,
		"bonus_region": bonus_region, "bonus_weapon": bonus_weapon,
		"bonus_element": bonus_element,
	}

static func from_dict(d: Dictionary) -> ExpeditionData:
	return ExpeditionData.new(d)
