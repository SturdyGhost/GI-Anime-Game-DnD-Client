extends Control

@onready var ActionButton = $Layout/MainSplit/Tabs/PartyManagement/Panel/ActionOptionButton
@onready var CharacterButton = $Layout/MainSplit/Tabs/PartyManagement/Panel/CharacterOptionButton
@onready var ObjectButton = $Layout/MainSplit/Tabs/PartyManagement/Panel/ObjectOptionButton
@onready var QuantityText = $Layout/MainSplit/Tabs/PartyManagement/Panel/QuantityTextEdit
@onready var SpecificsObjectButton = $Layout/MainSplit/Tabs/PartyManagement/Panel/SpecificsOptionButton
@onready var ConfirmButton = $Layout/MainSplit/Tabs/PartyManagement/Panel/ConfirmButton

# Battle Prep references
@onready var EncounterHContainer = $Layout/MainSplit/Tabs/BattlePrep/BP_HBox/EncounterPanel/EncounterHContainer
@onready var EncounterVContainer = $Layout/MainSplit/Tabs/BattlePrep/BP_HBox/EncounterPanel/EncounterHContainer/EncounterVContainer
@onready var EnemyName: LineEdit = $Layout/MainSplit/Tabs/BattlePrep/BP_HBox/EnemyEditorPanel/EnemyEditorVBox/EnemyNameHBox/EnemyName
@onready var BtnAddEnemy: Button = $Layout/MainSplit/Tabs/BattlePrep/BP_HBox/EnemyEditorPanel/EnemyEditorVBox/BtnAddEnemy
@onready var BtnSituation: Button = $Layout/MainSplit/Tabs/BattlePrep/BP_HBox/EnemyEditorPanel/EnemyEditorVBox/BtnSituation
@onready var RestoreBattle = $RestoreBattleButton
@onready var BattlePrepTab = $Layout/MainSplit/Tabs/BattlePrep
@onready var http = HTTPRequest.new()

var owners: Array = []
var matches = []
var searchword
var _suggest_panel: Panel
var _suggest_scroll: ScrollContainer
var _suggest_vbox: VBoxContainer
var _panel_max_height: float = 240.0
var active_party_members = []
var active_companion_members = []
# Fast lookups for specifics -> full record
var _items_by_name: Dictionary = {}     # "ItemName" -> item_record
var _weapons_by_name: Dictionary = {}   # "WeaponName" -> weapon_record

func _ready() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	_populate_owners()
	_build_lookup_maps()
	_wire_buttons()
	_build_suggest_panel()
	get_party()
	check_ready()
	EnemyName.gui_input.connect(_on_enemy_name_gui_input)
	EnemyName.focus_exited.connect(func() -> void: _hide_suggest_panel())
	add_child(http)
	Global.Polling_Timer = Timer.new()
	Global.add_child(Global.Polling_Timer)
	Global.Polling_Timer.one_shot = false
	Global.Polling_Timer.wait_time = 0.1
	Global.Polling_Timer.timeout.connect(Global._check_modified_batch)
	Global.Polling_Timer.start()
	_refresh_specifics_options()

func _process(delta: float) -> void:
	check_matches()
	check_ready()

func _on_data_load_complete():
	print("✅ Global data has finished loading!")
	get_party()

func _build_lookup_maps() -> void:
	_items_by_name.clear()
	for rec in Global.ITEMS.values():
		var item_name: String = str(rec.get("Item", ""))
		if item_name != "" and not _items_by_name.has(item_name):
			_items_by_name[item_name] = rec

	_weapons_by_name.clear()
	for rec in Global.WEAPONS.values():
		var weapon_name: String = str(rec.get("Name", ""))
		if weapon_name != "" and not _weapons_by_name.has(weapon_name):
			_weapons_by_name[weapon_name] = rec


func _on_object_selected(_idx: int) -> void:
	_refresh_specifics_options()

func _refresh_specifics_options() -> void:
	SpecificsObjectButton.clear()

	var category: String = ObjectButton.get_item_text(ObjectButton.selected)

	if category == "Misc.":
		SpecificsObjectButton.add_item("Levels")
		SpecificsObjectButton.add_item("Gold")
		SpecificsObjectButton.add_item("Character Gambles")
		return

	if category == "Items":
		var names: Array[String] = []
		for k in _items_by_name.keys():
			names.append(str(k))
		names.sort()
		for n in names:
			SpecificsObjectButton.add_item(n)
		return

	if category == "Artifacts":
		# Intentionally not implemented yet (manual setup)
		return

	if category == "Weapons":
		var names: Array[String] = []
		for k in _weapons_by_name.keys():
			names.append(str(k))
		names.sort()
		for n in names:
			SpecificsObjectButton.add_item(n)
		return


func _on_confirm_pressed() -> void:
	var action_text: String = ActionButton.get_item_text(ActionButton.selected)
	var owner_name: String = CharacterButton.get_item_text(CharacterButton.selected)
	var category: String = ObjectButton.get_item_text(ObjectButton.selected)

	var specific: String = ""
	if SpecificsObjectButton.item_count > 0 and SpecificsObjectButton.selected >= 0:
		specific = SpecificsObjectButton.get_item_text(SpecificsObjectButton.selected)

	var qty: int = _get_quantity()
	if qty <= 0:
		return

	if category == "Items":
		_process_items(action_text, owner_name, specific, qty)
		return

	if category == "Weapons":
		_process_weapons(action_text, owner_name, specific, qty)
		return

	if category == "Misc.":
		_process_misc(action_text, owner_name, specific, qty)
	# Misc / Artifacts intentionally not implemented
	return


func _get_quantity() -> int:
	# If you are using a LineEdit instead of TextEdit:
	#   var raw := QuantityText.text
	var raw: String = QuantityText.text
	raw = raw.strip_edges()

	if raw == "":
		return 0

	# Allow accidental decimals like "3.0"
	if raw.find(".") != -1:
		raw = raw.split(".")[0]

	if not raw.is_valid_int():
		return 0

	var v: int = int(raw)
	if v < 0:
		v = 0
	return v


func _process_items(action_text: String, owner_name: String, item_name: String, qty: int) -> void:
	if item_name == "":
		return

	var delta: int = qty
	if action_text == "Remove":
		delta = -qty

	# Find existing record (keyed by record_id)
	var found_record_id: String = ""
	var found_record: Dictionary = {}

	for record_id in Global.CHARACTER_ITEMS.keys():
		var rec: Dictionary = Global.CHARACTER_ITEMS[record_id]
		if str(rec.get("Owner", "")) == owner_name and str(rec.get("Name", "")) == item_name:
			found_record_id = str(int(record_id))
			found_record = rec
			break

	if found_record_id != "":
		var old_q: int = int(float(found_record.get("Quantity", 0)))
		var new_q: int = old_q + delta
		if new_q < 0:
			new_q = 0

		var updates: Array = []
		updates.append({
			"table": "Character_Items",
			"record_id": found_record_id,
			"field": "Quantity",
			"value": new_q
		})

		Global.Update_Records(updates)
		return

	# Doesn't exist: only insert if we're giving (delta > 0)
	if delta <= 0:
		return

	if not _items_by_name.has(item_name):
		return

	var base: Dictionary = _items_by_name[item_name]

	var columns: Array = ["Owner", "Name", "Quantity", "Type", "Description", "Rarity"]
	var values: Array = [
		owner_name,
		item_name,
		delta,
		str(base.get("Type", "")),
		str(base.get("Description", "")),
		str(base.get("Rarity", ""))
	]

	Global.Insert("Character_Items", columns, values)


func _process_misc(action_text: String, owner_name: String, property_name: String, qty: int) -> void:
	if qty <= 0:
		return

	# Determine delta based on Give/Remove
	var delta: int = qty
	if action_text == "Remove":
		delta = -qty

	# -----------------------------
	# PARTY-LEVEL PROPERTIES
	# -----------------------------
	if property_name == "Gold":
		var party_id: String = str(int(Global.Current_Party.get("id")))
		var current_mora: int = int(float(Global.Current_Party.get("Mora", 0)))
		var new_mora: int = current_mora + delta
		if new_mora < 0:
			new_mora = 0

		var updates: Array = [{
			"table": "Party",
			"record_id": party_id,
			"field": "Mora",
			"value": new_mora
		}]
		Global.Update_Records(updates)
		return

	if property_name == "Character Gambles":
		var party_id2: String = str(int(Global.Current_Party.get("id")))
		var current_gambles: int = int(float(Global.Current_Party.get("Gambles", 0)))
		var new_gambles: int = current_gambles + delta
		if new_gambles < 0:
			new_gambles = 0

		var updates2: Array = [{
			"table": "Party",
			"record_id": party_id2,
			"field": "Gambles",
			"value": new_gambles
		}]
		Global.Update_Records(updates2)
		return

	# -----------------------------
	# CHARACTER-LEVEL PROPERTIES
	# -----------------------------
	if property_name == "Levels":
		if not Global.CHARACTERS_NAME.has(owner_name):
			return

		var char_record_id: String = str(int(Global.CHARACTERS_NAME[owner_name]))
		var char_rec: Dictionary = Global.CHARACTERS[str(float(char_record_id))]

		var current_level: int = int(float(char_rec.get("Level", 0)))
		var level_cap: int = int(float(char_rec.get("Level_Cap", 0)))
		var current_unspent: int = int(float(char_rec.get("Unspent_Skill_Points", 0)))

		# Removing levels: just decrease Level by qty (no cap logic)
		if action_text == "Remove":
			var new_level: int = current_level - qty
			if new_level < 0:
				new_level = 0

			var updates3: Array = [{
				"table": "Characters",
				"record_id": char_record_id,
				"field": "Level",
				"value": new_level
			}]
			Global.Update_Records(updates3)
			return

		# Giving levels: clamp to Level Cap, and add Unspent_Skill_Points
		if action_text == "Give":
			var target_level: int = int(current_level+qty)
			if target_level > level_cap:
				target_level = level_cap

			var increase_amount: int = target_level - current_level
			print ("Current Level: " + str(current_level) +" - Target Level: " + str(target_level)+" - Increase Amount: "+str(increase_amount)+" - Quantity: "+str(qty))
			if increase_amount <= 0:

				return

			var new_unspent: int = current_unspent + increase_amount

			var updates4: Array = []
			updates4.append({
				"table": "Characters",
				"record_id": char_record_id,
				"field": "Level",
				"value": target_level
			})
			updates4.append({
				"table": "Characters",
				"record_id": char_record_id,
				"field": "Unspent_Skill_Points",
				"value": new_unspent
			})

			Global.Update_Records(updates4)
			return

	# If property_name is something unexpected, do nothing
	return


func _process_weapons(action_text: String, owner_name: String, weapon_name: String, qty: int) -> void:
	if weapon_name == "":
		return

	var delta: int = qty
	if action_text == "Remove":
		delta = -qty

	# Find existing record
	var found_record_id: String = ""
	var found_record: Dictionary = {}

	for record_id in Global.CHARACTER_WEAPONS.keys():
		var rec: Dictionary = Global.CHARACTER_WEAPONS[record_id]
		if str(rec.get("Owner", "")) == owner_name and str(rec.get("Weapon", "")) == weapon_name:
			found_record_id = str(int(record_id))
			found_record = rec
			break

	if found_record_id != "":
		var old_q: int = int(float(found_record.get("Quantity", 0)))
		var new_q: int = old_q + delta
		if new_q < 0:
			new_q = 0

		var updates: Array = []
		updates.append({
			"table": "Character_Weapons",
			"record_id": found_record_id,
			"field": "Quantity",
			"value": new_q
		})

		Global.Update_Records(updates)
		return

	# Doesn't exist: only insert if we're giving
	if delta <= 0:
		return

	if not _weapons_by_name.has(weapon_name):
		return

	var base: Dictionary = _weapons_by_name[weapon_name]

	var columns: Array = [
		"Owner", "Weapon", "Type", "Rarity", "Region", "Quantity",
		"Effect", "Stat_1_Type", "Stat_2_Type", "Stat_3_Type",
		"Stat_1_Value", "Stat_2_Value", "Stat_3_Value",
		"Refinement", "Equipped"
	]

	var values: Array = [
		owner_name,
		weapon_name,
		str(base.get("Type", "")),
		str(base.get("Rarity", "")),
		str(base.get("Region", "")),
		delta,
		str(base.get("Effect", "")),
		str(base.get("Stat_1_Type", "")),
		str(base.get("Stat_2_Type", "")),
		str(base.get("Stat_3_Type", "")),
		base.get("Stat_1_Value", 0),
		base.get("Stat_2_Value", 0),
		base.get("Stat_3_Value", 0),
		0,      # Refinement always 0
		false   # Equipped always false
	]

	Global.Insert("Character_Weapons", columns, values)


func get_party():
	for entry in Global.PARTY.values():
		if entry.get("Dungeon_Master") == Global.ACTIVE_USER_NAME:
			Global.Current_Party = entry
			active_party_members.append(entry.get("Party_Member_1"))
			active_party_members.append(entry.get("Party_Member_2"))
			if entry.get("Party_Member_3") != "COMPANION":
				active_party_members.append(entry.get("Party_Member_3"))
			if entry.get("Party_Member_4") != "COMPANION":
				active_party_members.append(entry.get("Party_Member_4"))
	for entry in Global.COMPANIONS.values():
		if entry.get("Active") == true and active_companion_members.has(entry.get("Name")) == false:
			active_companion_members.append(entry.get("Name"))

func check_ready():
	if active_party_members.size() > 0:
		var players_ready = true
		for entry in active_party_members:
			if Global.CHARACTERS[Global.CHARACTERS_NAME[entry]].get("Ready") == false:
				players_ready = false
				break
		if players_ready == true:
			BtnSituation.disabled = false
		else:
			BtnSituation.disabled = true


func check_matches():
	if EnemyName.text != "" and EnemyName.text != searchword:
		searchword = EnemyName.text
		matches = Global.find_substring_matches_ci(EnemyName.text,Global.EnemyList)
		_update_suggestion_panel()
	elif EnemyName.text == "":
		matches = []
		_hide_suggest_panel()

func _build_suggest_panel() -> void:
	_suggest_panel = Panel.new()
	_suggest_panel.name = "EnemySuggestPanel"
	_suggest_panel.visible = false
	_suggest_panel.top_level = true      # Control has this; positions in global coords
	_suggest_panel.z_index = 10000       # Keep above nearby UI
	_suggest_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_suggest_scroll = ScrollContainer.new()
	_suggest_scroll.clip_contents = false
	_suggest_scroll.anchors_preset = Control.PRESET_FULL_RECT
	_suggest_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suggest_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_suggest_panel.add_child(_suggest_scroll)

	_suggest_vbox = VBoxContainer.new()
	_suggest_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_suggest_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_suggest_scroll.add_child(_suggest_vbox)

	# Attach to the scene (root or your DMHub; top_level=true uses global coords either way)
	get_tree().root.add_child(_suggest_panel)

func _update_suggestion_panel() -> void:
	if matches.size() == 0:
		_hide_suggest_panel()
		return

	_render_suggestions(matches)
	_open_panel_at_input()

func _render_suggestions(names: Array) -> void:
	for c in _suggest_vbox.get_children():
		c.queue_free()

	for n in names:
		var b := Button.new()
		b.text = str(n)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE       # <-- critical: never grab keyboard focus
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func() -> void: _apply_suggestion(str(n)))
		_suggest_vbox.add_child(b)


func _open_panel_at_input() -> void:
	var r: Rect2 = EnemyName.get_global_rect()
	var row_h: float = 30.0
	var desired_h: float = min(_panel_max_height, row_h * float(matches.size()))

	_suggest_panel.size = Vector2(r.size.x, desired_h)
	_suggest_panel.global_position = Vector2(r.position.x, r.position.y + r.size.y)
	_suggest_panel.show()
	# keep typing without interruption

func _refocus_enemy_input() -> void:
	if is_instance_valid(EnemyName):
		var col: int = EnemyName.caret_column
		EnemyName.grab_focus()
		EnemyName.caret_column = col

func _hide_suggest_panel() -> void:
	if is_instance_valid(_suggest_panel):
		_suggest_panel.hide()

func _on_enemy_name_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			# Accept first suggestion if available
			if matches.size() > 0:
				_apply_suggestion(str(matches[0]))
				EnemyName.accept_event()
		elif event.keycode == KEY_ESCAPE:
			_hide_suggest_panel()
			EnemyName.accept_event()


func _on_gui_focus_changed(new_focus: Control) -> void:
	# Hide only if focus moves to something that's NOT the popup or the input.
	if new_focus == null:
		_hide_suggest_panel()
		return
	if new_focus == EnemyName:
		return
	if _suggest_panel != null and _suggest_panel.is_ancestor_of(new_focus):
		return
	_hide_suggest_panel()

func _apply_suggestion(name: String) -> void:
	EnemyName.text = name
	EnemyName.caret_column = EnemyName.text.length()
	_hide_suggest_panel()
	# Ensure caret stays in the LineEdit after clicking a suggestion
	call_deferred("_refocus_enemy_input")


func _populate_owners() -> void:
	owners.clear()
	if "Characters" in Global:
		for key in Global.Characters.keys():
			var rec = Global.Characters[key]
			if rec.has("UserType") and str(rec["UserType"]) == "Player":
				owners.append(rec["Name"])
	else:
		owners = ["Brian C.", "Brian F.", "Dylan"]
	owners.sort()

func _wire_buttons() -> void:
	BtnAddEnemy.pressed.connect(_on_add_enemy_pressed)
	BtnSituation.pressed.connect(_on_situation_pressed)
	ObjectButton.item_selected.connect(_on_object_selected)
	ConfirmButton.pressed.connect(_on_confirm_pressed)





# ---------------- Battle Prep ----------------
func _on_add_enemy_pressed() -> void:
	var name = EnemyName.text.strip_edges()
	var cardscene = load("res://Scenes/enemy_line_item.tscn")
	var card = cardscene.instantiate()
	card.enemy_name = name
	EncounterVContainer.add_child(card)
	var enemy_data = Global.ENEMIES[str(float(Global.ENEMIES_NAME[name]))]
	var phase1hp
	if enemy_data.get("hp_per_phase") == null:
		phase1hp = enemy_data.get("phase1_hp")
	else:
		phase1hp = enemy_data.get("hp_per_phase")
	Global.Insert("BattleEnemies",["EnemyName","EnemyID","Current_Health","Max_Health"],[name,Global.ENEMIES_NAME[name],phase1hp,phase1hp])

func _make_enemy_card(name: String, hp: int) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(160, 120)
	var v = VBoxContainer.new()
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	var l = Label.new()
	l.text = name
	var hp_label = Label.new()
	hp_label.text = "HP: " + str(hp)
	v.add_child(l)
	v.add_child(hp_label)
	panel.add_child(v)
	return panel



func _on_situation_pressed() -> void:
	await(Global.Update_Records([{"table":"Characters","record_id": Global.ACTIVE_USER_RECORD_ID,"field":"Ready","value": true}]))
	var s: PackedScene = preload("res://Scenes/Enemy_Battle_Scene.tscn")
	var dlg = s.instantiate()
	add_child(dlg)
	for child in EncounterVContainer.get_children():
		child.queue_free()
	pass

func _clear_encounter() -> void:
	for c in EncounterVContainer.get_children():
		c.queue_free()


func _on_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/ResearchDMPanel.tscn")
	var dlg = s.instantiate()

	var win := Window.new()
	win.exclusive = true               # makes it modal, blocks hover/clicks
	win.transparent = true             # so only your dlg visuals show
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO

	win.add_child(dlg)
	add_child(win)

	# Optional: center or full-rect dlg inside window
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass # Replace with function body.


func _on_restore_battle_button_pressed() -> void:
	for child in get_children():
		if child.name == "Player_Battle_Scene":
			child.visible = true
			
	pass # Replace with function body.
