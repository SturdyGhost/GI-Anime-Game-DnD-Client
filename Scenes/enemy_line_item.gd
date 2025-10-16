extends Control
signal request_details(enemy_id: int)
signal hp_changed(enemy_id: int, current_hp: int, max_hp: int)
signal phase_changed(enemy_id: int, phase: int)
signal killed_toggled(enemy_id: int, is_killed: bool)
signal element_changed(enemy_id: int, element: String)
signal status_changed(enemy_id: int, status: String)

@export var enemy_name: String = ""  

@onready var NameLabel = $Label

var ELEMENTS: Array = [
	{"name": "None", "key": "None", "icon": null},
	{"name": "Fire", "key": "Fire", "icon": preload("res://UI/Element Icons/Fire.png")},
	{"name": "Water", "key": "Water", "icon": preload("res://UI/Element Icons/Water.png")},
	{"name": "Ice", "key": "Ice", "icon": preload("res://UI/Element Icons/Ice.png")},
	{"name": "Electric", "key": "Electric", "icon": preload("res://UI/Element Icons/Electric.png")},
	{"name": "Nature", "key": "Nature", "icon": preload("res://UI/Element Icons/Nature.png")},
	{"name": "Earth", "key": "Earth", "icon": preload("res://UI/Element Icons/Earth.png")},
	{"name": "Wind", "key": "Wind", "icon": preload("res://UI/Element Icons/Wind.png")}
]

var DEFAULT_STATUS: Array = ["None", "Stunned", "Shielded", "Enraged", "Vulnerable", "Marked", "Frozen", "Burning"]

var enemy_id: int = -1
var battle_record_id: int = -1           # <- must be provided later or pre-seeded
var _max_hp: int = 1
var _cur_hp: int = 0
var _icon_path: String = ""
var _notes: String = ""
var _pending_kv: Dictionary = {}         # queued field updates until record_id is known
var found
var _insert_corr_id: String = ""  # put near your vars


func _ready() -> void:
	if enemy_name.strip_edges() != "":
		setup_from_name(enemy_name)

func _on_button_pressed() -> void:
	Global.Remove_Record("BattleEnemies",battle_record_id)
	queue_free()
	pass # Replace with function body.

# Public: call this once you learn the DB record id for this card
func set_battle_record_id(id_value: int) -> void:
	battle_record_id = id_value


# -------------------------- DB IO --------------------------

func _insert_battle_enemy() -> void:
	if not Global or not Global.has_method("Insert"):
		return
	var columns: Array = [
		"EnemyName", "EnemyID", "HP_Current", "HP_Max", "Phase", "Killed",
		"AppliedElement", "StatusEffect"
	]
	var values: Array = [
		NameLabel.text, enemy_id, _cur_hp, _max_hp, 1, false,
		"None", "None"
	]
	# Make a unique correlation id for THIS card
	_insert_corr_id = "ins-%d-%d" % [get_instance_id(), Time.get_ticks_msec()]

	# Prime the latch so Global.Insert includes it in the JSON
	Global.set_next_correlation_id(_insert_corr_id)

	# Listen for the response (one-shot)
	if not Global.insert_finished.is_connected(_on_insert_finished):
		Global.insert_finished.connect(_on_insert_finished)

	Global.Insert("BattleEnemies", columns, values)

	# Audit log
	if Global.has_method("Log"):
		var new_vals := {
			"EnemyName": NameLabel.text,
			"EnemyID": enemy_id,
			"HP_Current": _cur_hp,
			"HP_Max": _max_hp,
			"Phase": 1,
			"Killed": false,
			"AppliedElement": "None",
			"StatusEffect": "None",
			"IconPath": _icon_path,
			"Notes": _notes
		}
		var meta := {"enemy_id": enemy_id, "enemy_name": NameLabel.text}
		Global.Log("EnemyCardCompact", "insert", "BattleEnemies", "", {}, new_vals, meta, "success", "audit")

func _on_insert_finished(corr_id: String, table: String, record_id: int, _payload: Dictionary, ok: bool) -> void:
	# Ignore other inserts
	if corr_id != _insert_corr_id or table != "BattleEnemies":
		return

	if ok and record_id >= 0:
		set_battle_record_id(record_id)  # your existing method; will flush queued Update_Records

	# We’re done listening
	if Global.insert_finished.is_connected(_on_insert_finished):
		Global.insert_finished.disconnect(_on_insert_finished)

func _find_enemy_by_name(name: String) -> Array:
	for k in Global.ENEMIES.keys():
		var row: Dictionary = Global.ENEMIES[k]
		if str(row.get("name", "")) == name:
			return [int(k), row]
	return [-1, {}]

func setup_from_name(name: String) -> void:
	enemy_name = name
	found = _find_enemy_by_name(enemy_name)
	enemy_id = int(found[0])
	var row: Dictionary = found[1]

	# Name
	NameLabel.text = str(row.get("Name", enemy_name))

	# Icon
	_icon_path = str(row.get("IconPath", ""))


	

	# HP: Current = Max on load
	var current_phase = 1
	if row.get("hp_per_phase") != null:
		_max_hp = int(row.get("hp_per_phase"))
	else:
		var key = "phase%s_hp" % str(int(current_phase))
		_max_hp = row.get(key)
	if _max_hp <= 0:
		_max_hp = 1
	_cur_hp = _max_hp




	# Optionally pre-seed known record id (if you stored it on the master row)
	if row.has("BattleRecordID"):
		battle_record_id = int(row["BattleRecordID"])

	# Insert into BattleEnemies using your columns/values signature (no return)
	_insert_battle_enemy()
