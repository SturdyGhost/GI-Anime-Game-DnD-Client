extends Control

signal request_details(enemy_id: int)
signal hp_changed(enemy_id: int, current_hp: int, max_hp: int)
signal phase_changed(enemy_id: int, phase: int)
signal killed_toggled(enemy_id: int, is_killed: bool)
signal element_changed(enemy_id: int, element: String)
signal status_changed(enemy_id: int, status: String)

var enemy_name: String = ""   # Instantiate card with this enemy name

@onready var Icon: TextureRect = $Icon
@onready var NameLabel: Label = $NameLabel
@onready var CurrentHPEdit: LineEdit = $CurrentHPEdit
@onready var MaxHPLabel: Label = $MaxHPLabel
@onready var PhaseSpinbox: SpinBox = $PhaseSpinbox

@onready var ElementButton: OptionButton = $ElementButton
@onready var AppliedElementLabel: Label = $AppliedElementLabel

@onready var StatusEffectButton: OptionButton = $StatusEffectButton
@onready var StatusEffectLabel: Label = $StatusEffectLabel

@onready var DeadToggle: CheckButton = $DeadToggle
@onready var DeadLabel: Label = $DeadLabel

@onready var DetailedInfoButton: Button = $DetailedInfoButton

@export var use_element_icons: bool = true

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
	_populate_element_button()
	_populate_status_button()

	# Hooks
	CurrentHPEdit.text_submitted.connect(_on_current_hp_submit)
	CurrentHPEdit.focus_exited.connect(_on_current_hp_blur)
	PhaseSpinbox.value_changed.connect(_on_phase_changed)
	ElementButton.item_selected.connect(_on_element_selected)
	StatusEffectButton.item_selected.connect(_on_status_selected)
	DeadToggle.toggled.connect(_on_dead_toggled)
	DetailedInfoButton.pressed.connect(_on_details_pressed)

	if enemy_name.strip_edges() != "":
		setup_from_name(enemy_name)

func setup_from_name(name: String) -> void:
	enemy_name = name
	found = _find_enemy_by_name(enemy_name)
	enemy_id = int(found[0])
	var row: Dictionary = found[1]

	# Name
	NameLabel.text = str(row.get("Name", enemy_name))

	# Icon
	_icon_path = str(row.get("IconPath", ""))
	if _icon_path != "":
		if ResourceLoader.exists(_icon_path):
			var tex: Texture2D = load(_icon_path)
			if tex:
				Icon.texture = tex

	# Phase
	PhaseSpinbox.min_value = 0
	PhaseSpinbox.max_value = 99
	PhaseSpinbox.step = 1
	PhaseSpinbox.value = int(row.get("Phase", 1))

	# HP: Current = Max on load
	var current_phase = PhaseSpinbox.value
	if row.get("hp_per_phase") != null:
		_max_hp = int(row.get("hp_per_phase"))
	else:
		var key = "phase%s_hp" % str(int(current_phase))
		_max_hp = row.get(key)
	if _max_hp <= 0:
		_max_hp = 1
	_cur_hp = _max_hp
	CurrentHPEdit.text = str(_cur_hp)
	_update_max_hp_label()


	# Dead
	var is_dead = bool(row.get("Killed", false))
	DeadToggle.button_pressed = is_dead
	DeadLabel.text = "Dead" if is_dead else ""

	# Element
	var elem_val = str(row.get("AppliedElement", row.get("Element", "None")))
	_select_element(elem_val)

	# Status
	var status_val = str(row.get("StatusEffect", row.get("Status", "None")))
	_select_status(status_val)

	# Notes
	_notes = str(row.get("Notes", ""))

	# Optionally pre-seed known record id (if you stored it on the master row)
	if row.has("BattleRecordID"):
		battle_record_id = int(row["BattleRecordID"])

	# Insert into BattleEnemies using your columns/values signature (no return)
	_insert_battle_enemy()

	# Mirror to Global.ENEMIES (includes pre-seeding battle id if you want)
	if Global and Global.ENEMIES and Global.ENEMIES.has(enemy_id):
		Global.ENEMIES[enemy_id]["HP_Current"] = _cur_hp
		Global.ENEMIES[enemy_id]["HP_Max"] = _max_hp
		Global.ENEMIES[enemy_id]["Phase"] = int(PhaseSpinbox.value)
		Global.ENEMIES[enemy_id]["Killed"] = DeadToggle.button_pressed
		Global.ENEMIES[enemy_id]["AppliedElement"] = _get_selected_element_key()
		Global.ENEMIES[enemy_id]["StatusEffect"] = _get_selected_text(StatusEffectButton)
		if battle_record_id >= 0:
			Global.ENEMIES[enemy_id]["BattleRecordID"] = battle_record_id

# Public: call this once you learn the DB record id for this card
func set_battle_record_id(id_value: int) -> void:
	battle_record_id = id_value
	_try_flush_updates()

# -------------------------- DB IO --------------------------

func _insert_battle_enemy() -> void:
	if not Global or not Global.has_method("Insert"):
		return
	var columns: Array = [
		"EnemyName", "EnemyID", "HP_Current", "HP_Max", "Phase", "Killed",
		"AppliedElement", "StatusEffect"
	]
	var values: Array = [
		NameLabel.text, enemy_id, _cur_hp, _max_hp, int(PhaseSpinbox.value), DeadToggle.button_pressed,
		_get_selected_element_key(), _get_selected_text(StatusEffectButton)
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
			"Phase": int(PhaseSpinbox.value),
			"Killed": DeadToggle.button_pressed,
			"AppliedElement": _get_selected_element_key(),
			"StatusEffect": _get_selected_text(StatusEffectButton),
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

func _queue_update(field: String, value) -> void:
	_pending_kv[field] = value
	_try_flush_updates()

func _try_flush_updates() -> void:
	if battle_record_id < 0:
		return
	if _pending_kv.size() == 0:
		return

	var updates: Array = []
	for k in _pending_kv.keys():
		updates.append({
			"table": "BattleEnemies",
			"record_id": battle_record_id,
			"field": str(k),
			"value": _pending_kv[k]
		})
	Global.Update_Records(updates)

	# Log one combined audit entry
	if Global.has_method("Log"):
		var meta := {"enemy_id": enemy_id, "enemy_name": NameLabel.text}
		Global.Log("EnemyCardCompact", "update", "BattleEnemies", str(battle_record_id), {}, _pending_kv.duplicate(true), meta, "success", "audit")

	_pending_kv.clear()

# -------------------------- UI EVENTS --------------------------

func _on_current_hp_submit(new_text: String) -> void:
	_apply_current_hp_from_text(new_text)

func _on_current_hp_blur() -> void:
	_apply_current_hp_from_text(CurrentHPEdit.text)

func _apply_current_hp_from_text(s: String) -> void:
	var parsed = _parse_int_or_default(s, _cur_hp)
	_cur_hp = clamp(parsed, 0, _max_hp)
	CurrentHPEdit.text = str(_cur_hp)

	if Global and Global.ENEMIES and Global.ENEMIES.has(enemy_id):
		Global.ENEMIES[enemy_id]["HP_Current"] = _cur_hp

	_queue_update("HP_Current", _cur_hp)
	emit_signal("hp_changed", enemy_id, _cur_hp, _max_hp)

func _on_phase_changed(value: float) -> void:
	var phase_i = int(value)
	if Global and Global.ENEMIES and Global.ENEMIES.has(enemy_id):
		Global.ENEMIES[enemy_id]["Phase"] = phase_i
	_queue_update("Phase", phase_i)
	emit_signal("phase_changed", enemy_id, phase_i)

func _on_dead_toggled(pressed: bool) -> void:
	DeadLabel.text = "Dead" if pressed else ""
	if Global and Global.ENEMIES and Global.ENEMIES.has(enemy_id):
		Global.ENEMIES[enemy_id]["Killed"] = pressed
	_queue_update("Killed", pressed)
	emit_signal("killed_toggled", enemy_id, pressed)

func _on_element_selected(_index: int) -> void:
	var key = _get_selected_element_key()
	AppliedElementLabel.text = "Element: " + _get_selected_text(ElementButton)
	if Global and Global.ENEMIES and Global.ENEMIES.has(enemy_id):
		Global.ENEMIES[enemy_id]["AppliedElement"] = key
	_queue_update("AppliedElement", key)
	emit_signal("element_changed", enemy_id, key)

func _on_status_selected(_index: int) -> void:
	var txt = _get_selected_text(StatusEffectButton)
	StatusEffectLabel.text = "Status: " + txt
	if Global and Global.ENEMIES and Global.ENEMIES.has(enemy_id):
		Global.ENEMIES[enemy_id]["StatusEffect"] = txt
	_queue_update("StatusEffect", txt)
	emit_signal("status_changed", enemy_id, txt)

func _on_details_pressed() -> void:
	emit_signal("request_details", enemy_id)

# -------------------------- ELEMENTS & STATUS --------------------------

func _populate_element_button() -> void:
	ElementButton.clear()
	for e in ELEMENTS:
		if use_element_icons and e["icon"] != null:
			ElementButton.add_icon_item(e["icon"], e["name"])
		else:
			ElementButton.add_item(e["name"])

func _select_element(target_key_or_name: String) -> void:
	var idx = 0
	for i in range(ELEMENTS.size()):
		if str(ELEMENTS[i]["key"]) == target_key_or_name or str(ELEMENTS[i]["name"]) == target_key_or_name:
			idx = i
			break
	ElementButton.select(idx)
	AppliedElementLabel.text = "Element: " + str(ELEMENTS[idx]["name"])

func _get_selected_element_key() -> String:
	var idx = ElementButton.selected
	if idx < 0 or idx >= ELEMENTS.size():
		return "None"
	return str(ELEMENTS[idx]["key"])

func _populate_status_button() -> void:
	StatusEffectButton.clear()
	for s in DEFAULT_STATUS:
		StatusEffectButton.add_item(str(s))

func _select_status(target_val: String) -> void:
	var idx = 0
	for i in range(StatusEffectButton.item_count):
		if StatusEffectButton.get_item_text(i) == target_val:
			idx = i
			break
	StatusEffectButton.select(idx)
	StatusEffectLabel.text = "Status: " + StatusEffectButton.get_item_text(idx)

# -------------------------- HELPERS --------------------------

func _update_max_hp_label() -> void:
	MaxHPLabel.text = "/ " + str(_max_hp)

func _get_selected_text(btn: OptionButton) -> String:
	var idx = btn.selected
	if idx < 0 or idx >= btn.item_count:
		return ""
	return btn.get_item_text(idx)

func _find_enemy_by_name(name: String) -> Array:
	for k in Global.ENEMIES.keys():
		var row: Dictionary = Global.ENEMIES[k]
		if str(row.get("name", "")) == name:
			return [int(k), row]
	return [-1, {}]

func _parse_int_or_default(s: String, def: int) -> int:
	var t = s.strip_edges()
	if t == "":
		return def
	var sign = 1
	if t.begins_with("+"):
		t = t.substr(1, t.length() - 1)
	elif t.begins_with("-"):
		sign = -1
		t = t.substr(1, t.length() - 1)
	var digits := ""
	for ch in t:
		if String(ch).is_valid_int():
			digits += ch
	if digits == "":
		return def
	var val = int(digits) * sign
	return val


func _on_button_pressed() -> void:
	Global.Remove_Record("BattleEnemies",battle_record_id)
	queue_free()
	pass # Replace with function body.
