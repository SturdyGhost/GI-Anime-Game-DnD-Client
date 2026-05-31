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
@onready var DataEditorTab = $Layout/MainSplit/Tabs/DataEditor
var http: Node  # kept for compat, no longer used for HTTP

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

# ── Artifact Generation state ──
var _art_panel: VBoxContainer
var _art_set1_btn: OptionButton
var _art_set2_btn: OptionButton
var _art_rolls: Array = []  # 9 SpinBoxes: [set_d10, type_d12, substat_d20, s1_stat, s1_sign, s1_val, s2_stat, s2_sign, s2_val]
var _art_sub2_row: HBoxContainer
var _art_status: Label

# ── Data Editor state ──
var _de_table_btn: OptionButton
var _de_record_btn: OptionButton
var _de_fields_container: VBoxContainer
var _de_scroll: ScrollContainer
var _de_confirm_btn: Button
var _de_revert_btn: Button
var _de_delete_btn: Button
var _de_new_btn: Button
var _de_status_label: Label
var _de_snapshot: Dictionary = {}      # field -> original value (for revert)
var _de_inputs: Dictionary = {}        # field -> input Control
var _de_current_table: String = ""
var _de_current_rid: String = ""
const _DE_TABLES: Array = ["Characters", "Companions", "Party", "Character_Weapons", "Character_Artifacts", "Character_Items", "BattleEnemies", "Active_Status_Effects", "Game_Config"]

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
	pass  # http node removed
	_refresh_specifics_options()
	_build_data_editor()
	_build_artifact_panel()
	_build_dm_challenge_section()
	# Add Encounter Balancer button to the QuickBar
	var quick_hbox = $Layout/QuickBar/QuickHBox
	var bal_btn = Button.new()
	bal_btn.text = "Encounter Balancer"
	bal_btn.add_theme_font_size_override("font_size", 29)
	bal_btn.pressed.connect(_open_encounter_balancer)
	quick_hbox.add_child(bal_btn)
	if Global.is_offline:
		_show_offline_indicator()
		# Disable item management tab — players self-manage in offline mode
		var tabs = $Layout/MainSplit/Tabs
		tabs.set_tab_disabled(0, true)
		tabs.set_tab_title(0, "Party Management (Disabled Offline)")
		# Default to BattlePrep tab
		tabs.current_tab = 1

func _show_offline_indicator() -> void:
	var indicator = Label.new()
	indicator.name = "OfflineIndicator"
	indicator.text = "OFFLINE"
	indicator.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	indicator.add_theme_font_size_override("font_size", 32)
	indicator.position = Vector2(20, 20)
	add_child(indicator)

func _process(delta: float) -> void:
	check_matches()
	check_ready()

func _on_data_load_complete():
	print("✅ Global data has finished loading!")
	# Rebuild data-dependent UI in case _ready() fired before data was synced.
	# (_ready connects this signal then immediately populates; if data wasn't
	# ready yet, those calls return empty and never refresh without this.)
	_populate_owners()
	_build_lookup_maps()
	get_party()
	_refresh_specifics_options()

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
	# Hide/show artifact panel based on category
	if _art_panel:
		var category_check = ObjectButton.get_item_text(ObjectButton.selected)
		_art_panel.visible = (category_check == "Artifacts")
		QuantityText.visible = (category_check != "Artifacts")
		SpecificsObjectButton.visible = (category_check != "Artifacts")

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
		var char_rec: Dictionary = Global.CHARACTERS[char_record_id]

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
	_suggest_panel.z_index = 4096        # Keep above nearby UI (max is 4096)
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
	print ("Add Enemy Button Pressed")
	var name = EnemyName.text.strip_edges()
	var cardscene = load("res://Scenes/enemy_line_item.tscn")
	var card = cardscene.instantiate()
	card.enemy_name = name
	EncounterVContainer.add_child(card)
	#var enemy_data = Global.ENEMIES[str(float(Global.ENEMIES_NAME[name]))]
	#var phase1hp
	#if enemy_data.get("hp_per_phase") == null:
		#phase1hp = enemy_data.get("phase1_hp")
	#else:
		#phase1hp = enemy_data.get("hp_per_phase")
	#Global.Insert("BattleEnemies",["EnemyName","EnemyID","Current_Health","Max_Health"],[name,Global.ENEMIES_NAME[name],phase1hp,phase1hp])

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
	# Generate challenge quest if none exists
	if Global.active_challenge_quest.is_empty():
		var quest = ChallengeQuestGenerator.generate()
		Global.active_challenge_quest = quest.to_dict()
		NetworkManager.broadcast_table_update("Party")

	Global.Update_Records([{"table":"Characters","record_id": Global.ACTIVE_USER_RECORD_ID,"field":"Ready","value": true}])
	var s = preload("res://Scenes/BattleScene.tscn")
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
		if child.name == "BattleScene":
			child.visible = true
	pass # Replace with function body.

# ═══════════════════════════════════════════════════════════════════════════════
# ARTIFACT GENERATION (Party Management tab)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_artifact_panel() -> void:
	var pm_panel = $Layout/MainSplit/Tabs/PartyManagement/Panel
	if pm_panel == null:
		return

	_art_panel = VBoxContainer.new()
	_art_panel.position = Vector2(64, 310)
	_art_panel.size = Vector2(2000, 900)
	_art_panel.add_theme_constant_override("separation", 12)
	_art_panel.visible = false
	pm_panel.add_child(_art_panel)

	# ── Row 1: Set selection ──
	var set_row = HBoxContainer.new()
	set_row.add_theme_constant_override("separation", 12)
	_art_panel.add_child(set_row)

	set_row.add_child(_art_label("Set 1:"))
	_art_set1_btn = OptionButton.new()
	_art_set1_btn.custom_minimum_size.x = 250
	set_row.add_child(_art_set1_btn)

	set_row.add_child(_art_label("Set 2:"))
	_art_set2_btn = OptionButton.new()
	_art_set2_btn.custom_minimum_size.x = 250
	set_row.add_child(_art_set2_btn)

	# Populate set dropdowns from unique artifact set names
	var set_names = []
	for a in Global.ARTIFACTS.values():
		var sn = a.get("Artifact_Set", "")
		if sn != "" and not set_names.has(sn):
			set_names.append(sn)
	set_names.sort()
	for sn in set_names:
		_art_set1_btn.add_item(sn)
		_art_set2_btn.add_item(sn)
	if _art_set2_btn.item_count > 1:
		_art_set2_btn.selected = 1

	# ── Row 2: Piece determination rolls ──
	_art_panel.add_child(_art_label("— Piece Determination —"))
	var r1 = HBoxContainer.new()
	r1.add_theme_constant_override("separation", 12)
	_art_panel.add_child(r1)
	_art_rolls.clear()
	_art_rolls.append(_art_spin(r1, "D10 (Set)", 1, 10))
	_art_rolls.append(_art_spin(r1, "D12 (Piece Type)", 1, 12))
	var d20_substats = _art_spin(r1, "D20 (Substats: 13+=two)", 1, 20)
	d20_substats.value_changed.connect(func(v): _art_update_sub2_visibility())
	_art_rolls.append(d20_substats)

	# ── Row 3: Substat 1 ──
	_art_panel.add_child(_art_label("— Substat 1 —"))
	var r2 = HBoxContainer.new()
	r2.add_theme_constant_override("separation", 12)
	_art_panel.add_child(r2)
	_art_rolls.append(_art_spin(r2, "D8/D10 (Stat Type)", 1, 10))
	_art_rolls.append(_art_spin(r2, "D12 (Sign: 7+=pos)", 1, 12))
	_art_rolls.append(_art_spin(r2, "D20 (Value x0.1)", 1, 20))

	# ── Row 4: Substat 2 ──
	var sub2_label = _art_label("— Substat 2 (if D20 >= 13) —")
	_art_panel.add_child(sub2_label)
	_art_sub2_row = HBoxContainer.new()
	_art_sub2_row.add_theme_constant_override("separation", 12)
	_art_panel.add_child(_art_sub2_row)
	_art_rolls.append(_art_spin(_art_sub2_row, "D8/D10 (Stat Type)", 1, 10))
	_art_rolls.append(_art_spin(_art_sub2_row, "D12 (Sign: 7+=pos)", 1, 12))
	_art_rolls.append(_art_spin(_art_sub2_row, "D20 (Value x0.1)", 1, 20))
	sub2_label.visible = false
	_art_sub2_row.visible = false

	# ── Row 5: Generate button + status ──
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	_art_panel.add_child(btn_row)
	var gen_btn = Button.new()
	gen_btn.text = "Generate Artifact"
	gen_btn.pressed.connect(_art_on_generate)
	btn_row.add_child(gen_btn)
	_art_status = Label.new()
	_art_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(_art_status)

func _art_label(t: String) -> Label:
	var l = Label.new()
	l.text = t
	return l

func _art_spin(parent: Node, hint: String, min_val: int, max_val: int) -> SpinBox:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	parent.add_child(hb)
	var l = Label.new()
	l.text = hint + ":"
	l.custom_minimum_size.x = 200
	hb.add_child(l)
	var sb = SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.value = min_val
	sb.custom_minimum_size.x = 80
	hb.add_child(sb)
	return sb

func _art_update_sub2_visibility() -> void:
	var has_two = int(_art_rolls[2].value) >= 13
	# Sub2 label is the node before _art_sub2_row
	if _art_sub2_row:
		_art_sub2_row.visible = has_two
		# The label before it
		var idx = _art_sub2_row.get_index()
		var parent = _art_sub2_row.get_parent()
		if idx > 0:
			parent.get_child(idx - 1).visible = has_two

func _art_resolve_stat(die_roll: int, piece_type: String) -> String:
	var is_special = piece_type in ["Sands of Time", "Goblet of Space", "Circlet of Principles"]
	if is_special:
		# D10: 1-2 Health, 3-4 Attack, 5-6 Defense, 7-8 EM, 9-10 unique
		match die_roll:
			1, 2: return "Health"
			3, 4: return "Attack"
			5, 6: return "Defense"
			7, 8: return "Elemental_Mastery"
			9, 10:
				match piece_type:
					"Sands of Time": return "Energy_Recharge"
					"Goblet of Space": return "Universal_Added_Damage_Bonus"
					"Circlet of Principles": return "Critical_Damage"
	else:
		# D8: 1-2 Health, 3-4 Attack, 5-6 Defense, 7-8 EM
		match die_roll:
			1, 2: return "Health"
			3, 4: return "Attack"
			5, 6: return "Defense"
			7, 8: return "Elemental_Mastery"
	return "Health"

func _art_resolve_piece(d12: int) -> String:
	if d12 <= 3: return "Flower of Life"
	if d12 <= 6: return "Feather of Death"
	if d12 <= 8: return "Sands of Time"
	if d12 <= 10: return "Goblet of Space"
	return "Circlet of Principles"

func _art_on_generate() -> void:
	var owner_name = CharacterButton.get_item_text(CharacterButton.selected)

	# Read all rolls
	var d10_set = int(_art_rolls[0].value)
	var d12_type = int(_art_rolls[1].value)
	var d20_substats = int(_art_rolls[2].value)
	var s1_stat_die = int(_art_rolls[3].value)
	var s1_sign_die = int(_art_rolls[4].value)
	var s1_val_die = int(_art_rolls[5].value)
	var s2_stat_die = int(_art_rolls[6].value)
	var s2_sign_die = int(_art_rolls[7].value)
	var s2_val_die = int(_art_rolls[8].value)

	# Determine set
	var set_name: String
	if d10_set <= 5:
		set_name = _art_set1_btn.get_item_text(_art_set1_btn.selected)
	else:
		set_name = _art_set2_btn.get_item_text(_art_set2_btn.selected)

	# Determine piece type
	var piece_type = _art_resolve_piece(d12_type)

	# Determine substats count
	var has_two_stats = d20_substats >= 13

	# Substat 1
	var stat_1_type = _art_resolve_stat(s1_stat_die, piece_type)
	var stat_1_sign = 1.0 if s1_sign_die >= 7 else -1.0
	var stat_1_value = stat_1_sign * s1_val_die * 0.1

	# Substat 2
	var stat_2_type = ""
	var stat_2_value = 0.0
	if has_two_stats:
		stat_2_type = _art_resolve_stat(s2_stat_die, piece_type)
		var stat_2_sign = 1.0 if s2_sign_die >= 7 else -1.0
		stat_2_value = stat_2_sign * s2_val_die * 0.1

	# Insert the artifact
	var columns = ["Artifact_Set", "Owner", "Type", "Equipped", "Rarity",
		"Stat_1_Type", "Stat_1_Value", "Stat_2_Type", "Stat_2_Value"]
	var values = [set_name, owner_name, piece_type, false, 5,
		stat_1_type, snapped(stat_1_value, 0.01),
		stat_2_type, snapped(stat_2_value, 0.01)]

	Global.Insert("Character_Artifacts", columns, values)

	# Status feedback
	var msg = "%s: %s %s — %s: %.2f" % [owner_name, set_name, piece_type, stat_1_type, stat_1_value]
	if has_two_stats:
		msg += ", %s: %.2f" % [stat_2_type, stat_2_value]
	_art_status.text = msg

# ═══════════════════════════════════════════════════════════════════════════════
# DATA EDITOR TAB
# ═══════════════════════════════════════════════════════════════════════════════

func _build_data_editor() -> void:
	if DataEditorTab == null:
		return
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	DataEditorTab.add_child(root)

	# ── Top bar: table + record selectors ──
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	var tbl_label = Label.new()
	tbl_label.text = "Table:"
	top.add_child(tbl_label)

	_de_table_btn = OptionButton.new()
	_de_table_btn.custom_minimum_size.x = 200
	for t in _DE_TABLES:
		_de_table_btn.add_item(t)
	_de_table_btn.item_selected.connect(_de_on_table_selected)
	top.add_child(_de_table_btn)

	var rec_label = Label.new()
	rec_label.text = "Record:"
	top.add_child(rec_label)

	_de_record_btn = OptionButton.new()
	_de_record_btn.custom_minimum_size.x = 300
	_de_record_btn.item_selected.connect(_de_on_record_selected)
	top.add_child(_de_record_btn)

	# ── Scrollable field editor ──
	_de_scroll = ScrollContainer.new()
	_de_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_de_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_de_scroll)

	_de_fields_container = VBoxContainer.new()
	_de_fields_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_de_fields_container.add_theme_constant_override("separation", 4)
	_de_scroll.add_child(_de_fields_container)

	# ── Bottom bar: buttons + status ──
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	root.add_child(bottom)

	_de_confirm_btn = Button.new()
	_de_confirm_btn.text = "Confirm Changes"
	_de_confirm_btn.pressed.connect(_de_on_confirm)
	_de_confirm_btn.disabled = true
	bottom.add_child(_de_confirm_btn)

	_de_revert_btn = Button.new()
	_de_revert_btn.text = "Revert"
	_de_revert_btn.pressed.connect(_de_on_revert)
	_de_revert_btn.disabled = true
	bottom.add_child(_de_revert_btn)

	var spacer = Control.new()
	spacer.custom_minimum_size.x = 24
	bottom.add_child(spacer)

	_de_new_btn = Button.new()
	_de_new_btn.text = "New Record"
	_de_new_btn.pressed.connect(_de_on_new_record)
	bottom.add_child(_de_new_btn)

	_de_delete_btn = Button.new()
	_de_delete_btn.text = "Delete Record"
	_de_delete_btn.pressed.connect(_de_on_delete)
	bottom.add_child(_de_delete_btn)

	_de_status_label = Label.new()
	_de_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_de_status_label)

	# Load first table
	_de_on_table_selected(0)

func _de_on_table_selected(_idx: int) -> void:
	_de_current_table = _de_table_btn.get_item_text(_idx)
	_de_record_btn.clear()
	_de_clear_fields()
	_de_status_label.text = ""

	var table_data: Dictionary = Global._synced.get(_de_current_table, {})
	if table_data.is_empty():
		_de_record_btn.add_item("(no records)")
		return

	# Sort record IDs numerically
	var ids = table_data.keys()
	ids.sort_custom(func(a, b): return int(a) < int(b))

	for rid in ids:
		var rec = table_data[rid]
		var display = str(rid)
		# Show name if available for easier identification
		if rec.has("Name") and rec["Name"] != null:
			display = "%s — %s" % [rid, str(rec["Name"])]
		elif rec.has("Weapon") and rec["Weapon"] != null:
			display = "%s — %s" % [rid, str(rec["Weapon"])]
		elif rec.has("Artifact_Set") and rec["Artifact_Set"] != null:
			display = "%s — %s (%s)" % [rid, str(rec["Artifact_Set"]), str(rec.get("Type", ""))]
		elif rec.has("Item") and rec["Item"] != null:
			display = "%s — %s" % [rid, str(rec["Item"])]
		elif rec.has("Dungeon_Master") and rec["Dungeon_Master"] != null:
			display = "%s — Party (%s)" % [rid, str(rec["Dungeon_Master"])]
		_de_record_btn.add_item(display)
		_de_record_btn.set_item_metadata(_de_record_btn.item_count - 1, str(rid))

	if _de_record_btn.item_count > 0:
		_de_on_record_selected(0)

func _de_on_record_selected(_idx: int) -> void:
	if _idx < 0 or _idx >= _de_record_btn.item_count:
		return
	_de_current_rid = str(_de_record_btn.get_item_metadata(_idx))
	_de_load_record()

func _de_load_record() -> void:
	_de_clear_fields()
	_de_snapshot.clear()
	_de_inputs.clear()
	_de_status_label.text = ""
	_de_confirm_btn.disabled = true
	_de_revert_btn.disabled = true

	var table_data = Global._synced.get(_de_current_table, {})
	var rec = table_data.get(_de_current_rid, {})
	if rec.is_empty():
		return

	# Sort keys: id first, Name second, then alphabetical
	var keys = rec.keys()
	keys.sort()
	var sorted_keys = []
	if "id" in keys:
		sorted_keys.append("id")
		keys.erase("id")
	if "Name" in keys:
		sorted_keys.append("Name")
		keys.erase("Name")
	sorted_keys.append_array(keys)

	for field in sorted_keys:
		var value = rec[field]
		_de_snapshot[field] = value
		var row = _de_make_field_row(field, value)
		_de_fields_container.add_child(row)

func _de_make_field_row(field: String, value) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label = Label.new()
	label.text = field
	label.custom_minimum_size.x = 280
	row.add_child(label)

	var input: Control
	var is_readonly = (field == "id")

	if value is bool:
		var cb = CheckBox.new()
		cb.button_pressed = value
		cb.disabled = is_readonly
		cb.toggled.connect(func(_v): _de_mark_dirty())
		input = cb
	elif value is int:
		var sb = SpinBox.new()
		sb.min_value = -999999
		sb.max_value = 999999
		sb.value = value
		sb.editable = not is_readonly
		sb.custom_minimum_size.x = 200
		sb.value_changed.connect(func(_v): _de_mark_dirty())
		input = sb
	elif value is float:
		var sb = SpinBox.new()
		sb.min_value = -999999.0
		sb.max_value = 999999.0
		sb.step = 0.01
		sb.value = value
		sb.editable = not is_readonly
		sb.custom_minimum_size.x = 200
		sb.value_changed.connect(func(_v): _de_mark_dirty())
		input = sb
	elif value is Array:
		var le = LineEdit.new()
		var parts = []
		for v in value:
			parts.append(str(v))
		le.text = ", ".join(parts)
		le.editable = not is_readonly
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_changed.connect(func(_t): _de_mark_dirty())
		input = le
	else:
		# String or null — use LineEdit
		var le = LineEdit.new()
		le.text = str(value) if value != null else ""
		le.editable = not is_readonly
		le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		le.text_changed.connect(func(_t): _de_mark_dirty())
		input = le

	row.add_child(input)
	_de_inputs[field] = input
	return row

func _de_mark_dirty() -> void:
	_de_confirm_btn.disabled = false
	_de_revert_btn.disabled = false
	_de_status_label.text = "Unsaved changes"

func _de_clear_fields() -> void:
	for child in _de_fields_container.get_children():
		child.queue_free()
	_de_inputs.clear()

func _de_read_input(field: String) -> Variant:
	var input = _de_inputs.get(field)
	if input == null:
		return _de_snapshot.get(field)
	if input is CheckBox:
		return input.button_pressed
	elif input is SpinBox:
		# Preserve int vs float from original
		var orig = _de_snapshot.get(field)
		if orig is int:
			return int(input.value)
		return input.value
	elif input is LineEdit:
		var orig = _de_snapshot.get(field)
		if orig is Array:
			# Parse comma-separated back to array
			var parts = []
			for p in input.text.split(","):
				parts.append(p.strip_edges())
			return parts
		if orig is int:
			return int(input.text) if input.text.is_valid_int() else 0
		if orig is float:
			return float(input.text) if input.text.is_valid_float() else 0.0
		return input.text
	return _de_snapshot.get(field)

func _de_on_confirm() -> void:
	if _de_current_table == "" or _de_current_rid == "":
		return

	var updates = []
	for field in _de_inputs.keys():
		if field == "id":
			continue
		var new_val = _de_read_input(field)
		var old_val = _de_snapshot.get(field)
		if _de_values_differ(old_val, new_val):
			updates.append({
				"table": _de_current_table,
				"record_id": int(_de_current_rid),
				"field": field,
				"value": new_val
			})

	if updates.is_empty():
		_de_status_label.text = "No changes detected"
		_de_confirm_btn.disabled = true
		_de_revert_btn.disabled = true
		return

	Global.Update_Records(updates)

	# Update snapshot to new values
	for u in updates:
		_de_snapshot[u["field"]] = u["value"]

	_de_confirm_btn.disabled = true
	_de_revert_btn.disabled = true
	_de_status_label.text = "Saved %d field(s)" % updates.size()

func _de_on_revert() -> void:
	# Restore all inputs to snapshot values
	for field in _de_inputs.keys():
		var input = _de_inputs[field]
		var orig = _de_snapshot.get(field)
		if input is CheckBox:
			input.button_pressed = bool(orig) if orig != null else false
		elif input is SpinBox:
			input.value = float(orig) if orig != null else 0.0
		elif input is LineEdit:
			if orig is Array:
				var parts = []
				for v in orig:
					parts.append(str(v))
				input.text = ", ".join(parts)
			else:
				input.text = str(orig) if orig != null else ""
	_de_confirm_btn.disabled = true
	_de_revert_btn.disabled = true
	_de_status_label.text = "Reverted"

func _de_values_differ(a, b) -> bool:
	if typeof(a) != typeof(b):
		return str(a) != str(b)
	return a != b

func _de_on_new_record() -> void:
	if _de_current_table == "":
		return

	var table_data: Dictionary = Global._synced.get(_de_current_table, {})

	# Build a blank record using the first existing record as a field template
	var template: Dictionary = {}
	if not table_data.is_empty():
		var first = table_data.values()[0]
		for key in first.keys():
			var v = first[key]
			if key == "id":
				template[key] = 0  # placeholder, Insert assigns real id
			elif v is bool:
				template[key] = false
			elif v is int:
				template[key] = 0
			elif v is float:
				template[key] = 0.0
			elif v is Array:
				template[key] = []
			else:
				template[key] = ""
	else:
		template = {"id": 0, "Name": ""}

	# Build columns/values for Insert (skip id — host assigns it)
	var columns = []
	var values = []
	for key in template.keys():
		if key == "id":
			continue
		columns.append(key)
		values.append(template[key])

	Global.Insert(_de_current_table, columns, values)
	_de_status_label.text = "New record created"

	# Refresh after a short delay to let the insert propagate
	await get_tree().create_timer(0.3).timeout
	_de_on_table_selected(_de_table_btn.selected)
	# Select the last record (newest)
	if _de_record_btn.item_count > 0:
		_de_record_btn.selected = _de_record_btn.item_count - 1
		_de_on_record_selected(_de_record_btn.item_count - 1)

func _de_on_delete() -> void:
	if _de_current_table == "" or _de_current_rid == "":
		return

	var rid = int(_de_current_rid)
	Global.Remove_Record(_de_current_table, rid)
	_de_status_label.text = "Deleted record %d from %s" % [rid, _de_current_table]
	_de_clear_fields()

	# Refresh table list
	await get_tree().create_timer(0.3).timeout
	_de_on_table_selected(_de_table_btn.selected)


# ── Challenge Quest (DM controls) ──

var _challenge_container: VBoxContainer = null

func _build_dm_challenge_section() -> void:
	# Add challenge quest controls to the BattlePrep tab, inside the encounter panel
	var encounter_panel = EncounterVContainer.get_parent()
	if encounter_panel == null:
		return

	_challenge_container = VBoxContainer.new()
	_challenge_container.add_theme_constant_override("separation", 6)
	# Insert at the top of the encounter panel's parent
	encounter_panel.add_child(_challenge_container)
	encounter_panel.move_child(_challenge_container, 0)
	_refresh_dm_challenge_display()

func _refresh_dm_challenge_display() -> void:
	if _challenge_container == null:
		return
	for c in _challenge_container.get_children():
		c.queue_free()

	var quest = Global.active_challenge_quest

	var header = Label.new()
	header.text = "CHALLENGE QUEST"
	header.add_theme_font_size_override("font_size", 29)
	header.add_theme_color_override("font_color", Color(0.788, 0.659, 0.298))
	_challenge_container.add_child(header)

	if quest.is_empty():
		var empty_label = Label.new()
		empty_label.text = "No challenge quest set. One will generate when battle starts."
		empty_label.add_theme_font_size_override("font_size", 23)
		empty_label.add_theme_color_override("font_color", Color(0.533, 0.573, 0.659))
		_challenge_container.add_child(empty_label)

		var gen_btn = Button.new()
		gen_btn.text = "Generate Now"
		gen_btn.custom_minimum_size = Vector2(0, 30)
		gen_btn.pressed.connect(func():
			var q = ChallengeQuestGenerator.generate()
			Global.active_challenge_quest = q.to_dict()
			NetworkManager.broadcast_table_update("Party")
			_refresh_dm_challenge_display()
		)
		_challenge_container.add_child(gen_btn)
	else:
		var giver = str(quest.get("quest_giver_name", ""))
		var personality = str(quest.get("quest_giver_personality", ""))
		var multiplier = float(quest.get("reward_multiplier", 1.0))
		var giver_label = Label.new()
		giver_label.text = "%s (%s) — x%.0f%% reward" % [giver, personality, multiplier * 100]
		giver_label.add_theme_font_size_override("font_size", 23)
		giver_label.add_theme_color_override("font_color", Color(0.533, 0.573, 0.659))
		_challenge_container.add_child(giver_label)

		var challenge_label = RichTextLabel.new()
		challenge_label.bbcode_enabled = true
		challenge_label.fit_content = true
		challenge_label.scroll_active = false
		challenge_label.text = str(quest.get("challenge_text", ""))
		challenge_label.add_theme_font_size_override("normal_font_size", 15)
		challenge_label.add_theme_color_override("default_color", Color(0.941, 0.949, 0.973))
		_challenge_container.add_child(challenge_label)

		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		_challenge_container.add_child(btn_row)

		var reroll_btn = Button.new()
		reroll_btn.text = "Reroll"
		reroll_btn.custom_minimum_size = Vector2(0, 28)
		reroll_btn.pressed.connect(func():
			var q = ChallengeQuestGenerator.generate()
			Global.active_challenge_quest = q.to_dict()
			NetworkManager.broadcast_table_update("Party")
			_refresh_dm_challenge_display()
		)
		btn_row.add_child(reroll_btn)

		var edit_btn = Button.new()
		edit_btn.text = "Edit"
		edit_btn.custom_minimum_size = Vector2(0, 28)
		edit_btn.pressed.connect(_dm_edit_challenge)
		btn_row.add_child(edit_btn)

		var clear_btn = Button.new()
		clear_btn.text = "Clear"
		clear_btn.custom_minimum_size = Vector2(0, 28)
		clear_btn.pressed.connect(func():
			Global.active_challenge_quest = {}
			NetworkManager.broadcast_table_update("Party")
			_refresh_dm_challenge_display()
		)
		btn_row.add_child(clear_btn)

	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_challenge_container.add_child(sep)

func _dm_edit_challenge() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Edit Challenge"
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	var text_input = LineEdit.new()
	text_input.text = str(Global.active_challenge_quest.get("challenge_text", ""))
	text_input.placeholder_text = "Challenge text..."
	text_input.custom_minimum_size = Vector2(400, 36)
	vbox.add_child(text_input)

	var mult_row = HBoxContainer.new()
	mult_row.add_theme_constant_override("separation", 8)
	vbox.add_child(mult_row)
	var mult_label = Label.new()
	mult_label.text = "Reward multiplier:"
	mult_row.add_child(mult_label)
	var mult_input = SpinBox.new()
	mult_input.min_value = 0.25
	mult_input.max_value = 3.0
	mult_input.step = 0.25
	mult_input.value = float(Global.active_challenge_quest.get("reward_multiplier", 1.0))
	mult_row.add_child(mult_input)

	dialog.confirmed.connect(func():
		var q = Global.active_challenge_quest.duplicate()
		q["challenge_text"] = text_input.text
		q["reward_multiplier"] = mult_input.value
		Global.active_challenge_quest = q
		NetworkManager.broadcast_table_update("Party")
		dialog.queue_free()
		_refresh_dm_challenge_display()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(500, 200))


# ── Encounter Balancer ──

func _open_encounter_balancer() -> void:
	var s: PackedScene = preload("res://Scenes/UI/encounter_balancer.tscn")
	var dlg = s.instantiate()

	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO

	dlg.panel_closed.connect(func(): win.queue_free())
	win.add_child(dlg)
	add_child(win)

	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
