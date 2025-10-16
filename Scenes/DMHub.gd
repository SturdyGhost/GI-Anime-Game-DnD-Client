extends Control

# ---------------- Node Refs ----------------
@onready var ModeSwitch: OptionButton = $Layout/TopBarDM/ModeSwitch
@onready var PartyList: VBoxContainer = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/PartyListPanel/PartyListScroll/PartyList
@onready var DMLog: RichTextLabel = $Layout/MainSplit/DMLogPanel/DMLogVBox/DMLog

# Give
@onready var GiveTarget: OptionButton = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/GiveItemBox/GiveItemVBox/GiveTargetHBox/GiveTarget
@onready var GiveItemName: LineEdit = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/GiveItemBox/GiveItemVBox/GiveNameHBox/GiveItemName
@onready var GiveQty: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/GiveItemBox/GiveItemVBox/GiveQtyHBox/GiveQty
@onready var GiveConfirm: Button = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/GiveItemBox/GiveItemVBox/GiveConfirm

# Remove
@onready var RemoveTarget: OptionButton = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/RemoveItemBox/RemoveItemVBox/RemoveTargetHBox/RemoveTarget
@onready var RemoveItemName: OptionButton = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/RemoveItemBox/RemoveItemVBox/RemoveItemHBox/RemoveItemName
@onready var RemoveQty: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/RemoveItemBox/RemoveItemVBox/RemoveQtyHBox/RemoveQty
@onready var RemoveConfirm: Button = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/RemoveItemBox/RemoveItemVBox/RemoveConfirm

# Artifact
@onready var ArtifactOwner: OptionButton = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactOwnerHBox/ArtifactOwner
@onready var ArtifactSet: LineEdit = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactSetHBox/ArtifactSet
@onready var ArtifactType: OptionButton = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactTypeHBox/ArtifactType
@onready var ArtifactRarity: OptionButton = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactRarityHBox/ArtifactRarity
@onready var Stat1Type: LineEdit = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactStatsHBox/Stat1Type
@onready var Stat1Value: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactStatsHBox/Stat1Value
@onready var Stat2Type: LineEdit = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactStatsHBox/Stat2Type
@onready var Stat2Value: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactStatsHBox/Stat2Value
@onready var ArtifactGenerate: Button = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/ArtifactBox/ArtifactVBox/ArtifactGenerate

# Ascend
@onready var AscendOwner: OptionButton = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/AscendBox/AscendVBox/AscendOwnerHBox/AscendOwner
@onready var PointsHP: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/AscendBox/AscendVBox/AscendPointsGrid/HP
@onready var PointsATK: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/AscendBox/AscendVBox/AscendPointsGrid/ATK
@onready var PointsDEF: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/AscendBox/AscendVBox/AscendPointsGrid/DEF
@onready var PointsEM: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/AscendBox/AscendVBox/AscendPointsGrid/EM
@onready var PointsER: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/AscendBox/AscendVBox/AscendPointsGrid/ER
@onready var PointsCD: SpinBox = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/AscendBox/AscendVBox/AscendPointsGrid/CD
@onready var AscendConfirm: Button = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/AscendBox/AscendVBox/AscendConfirm

# Unlock Companion
@onready var UnlockOwner: OptionButton = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/UnlockBox/UnlockHBox/UnlockOwner
@onready var UnlockCompanionName: LineEdit = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/UnlockBox/UnlockHBox/UnlockCompanionName
@onready var UnlockConfirm: Button = $Layout/MainSplit/Tabs/PartyManagement/PM_HBox/MemberPanel/MemberVBox/UnlockBox/UnlockConfirm

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

func _ready() -> void:
	_populate_mode_switch()
	_populate_owners()
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

func _process(delta: float) -> void:
	if BattlePrepTab.visible == true:
		check_matches()
		check_ready()

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
	var ready_members = active_party_members.size()
	for entry in active_party_members:
		if Global.CHARACTERS[Global.CHARACTERS_NAME[entry]].get("Ready") == false:
			ready_members -= 1
	if ready_members == active_party_members.size():
		BtnSituation.disabled = false
	else:
		BtnSituation.disabled = true
	pass

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

func _populate_mode_switch() -> void:
	ModeSwitch.clear()
	ModeSwitch.add_item("Party View")
	ModeSwitch.add_item("Battle Prep")
	ModeSwitch.add_item("World State")

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
	_fill_option_with_array(GiveTarget, owners)
	_fill_option_with_array(RemoveTarget, owners)
	_fill_option_with_array(ArtifactOwner, owners)
	_fill_option_with_array(AscendOwner, owners)
	_fill_option_with_array(UnlockOwner, owners)
	# Fill artifact type/rarity options
	ArtifactType.clear()
	for t in ["Flower","Feather","Sands","Goblet","Circlet"]:
		ArtifactType.add_item(t)
	ArtifactRarity.clear()
	for r in [1,2,3,4,5]:
		ArtifactRarity.add_item(str(r))

func _fill_option_with_array(ob: OptionButton, arr: Array) -> void:
	ob.clear()
	for i in arr.size():
		ob.add_item(str(arr[i]), i)
	if arr.size() > 0:
		ob.select(0)

func _wire_buttons() -> void:
	GiveConfirm.pressed.connect(_on_give_confirm)
	RemoveTarget.item_selected.connect(_on_remove_owner_selected)
	RemoveConfirm.pressed.connect(_on_remove_confirm)
	ArtifactGenerate.pressed.connect(_on_artifact_generate)
	AscendConfirm.pressed.connect(_on_ascend_confirm)
	UnlockConfirm.pressed.connect(_on_unlock_confirm)
	BtnAddEnemy.pressed.connect(_on_add_enemy_pressed)
	BtnSituation.pressed.connect(_on_situation_pressed)


# ---------------- Inventory: Give ----------------
func _on_give_confirm() -> void:
	var owner = owners[GiveTarget.get_selected_id()] if owners.size() > 0 else ""
	var name = GiveItemName.text.strip_edges()
	var qty = int(GiveQty.value)
	if owner == "" or name == "" or qty <= 0:
		return
	var existing_id = _find_item_entry(owner, name)
	if existing_id >= 0:
		var current_qty = _get_item_quantity(existing_id)
		var new_qty = current_qty + qty
		var updates = [{"table":"Character_Items","record_id": float(existing_id), "field":"Quantity", "value": new_qty}]
		if "Update" in Global:
			Global.Update(updates)
	else:
		if "Insert" in Global:
			Global.Insert("Character_Items",
				["Owner","Name","Type","Rarity","Quantity","Description"],
				[owner, name, "", "", qty, "Granted via DM Hub"])

# ---------------- Inventory: Remove ----------------
func _on_remove_owner_selected(_index: int) -> void:
	_populate_remove_item_names()

func _populate_remove_item_names() -> void:
	RemoveItemName.clear()
	var owner = owners[RemoveTarget.get_selected_id()] if owners.size() > 0 else ""
	if owner == "":
		return
	var items = _get_items_for_owner(owner)
	for item_name in items:
		RemoveItemName.add_item(item_name)

func _on_remove_confirm() -> void:
	var owner = owners[RemoveTarget.get_selected_id()] if owners.size() > 0 else ""
	var item_name = RemoveItemName.get_item_text(RemoveItemName.get_selected_id()) if RemoveItemName.item_count > 0 else ""
	var qty = int(RemoveQty.value)
	if owner == "" or item_name == "" or qty <= 0:
		return
	var existing_id = _find_item_entry(owner, item_name)
	if existing_id < 0:
		return
	var current_qty = _get_item_quantity(existing_id)
	var new_qty = current_qty - qty
	if new_qty < 0:
		new_qty = 0
	var updates = [{"table":"Character_Items","record_id": float(existing_id), "field":"Quantity", "value": new_qty}]
	if "Update" in Global:
		Global.Update(updates)

# Helpers for Character_Items
func _find_item_entry(owner: String, name: String) -> int:
	if "Character_Items" in Global:
		for key in Global.Character_Items.keys():
			var row = Global.Character_Items[key]
			if str(row.get("Owner")) == owner and str(row.get("Name")).to_lower() == name.to_lower():
				return int(row.get("id", key))
	return -1

func _get_item_quantity(row_id: int) -> int:
	if "Character_Items" in Global:
		for key in Global.Character_Items.keys():
			var row = Global.Character_Items[key]
			var id_val = int(row.get("id", key))
			if id_val == row_id:
				return int(row.get("Quantity", 0))
	return 0

func _get_items_for_owner(owner: String) -> Array:
	var out: Array = []
	if "Character_Items" in Global:
		for key in Global.Character_Items.keys():
			var row = Global.Character_Items[key]
			if str(row.get("Owner")) == owner:
				out.append(str(row.get("Name")))
	out.sort()
	return out

# ---------------- Artifact Generation ----------------
func _on_artifact_generate() -> void:
	var owner = owners[ArtifactOwner.get_selected_id()] if owners.size() > 0 else ""
	var set_name = ArtifactSet.text.strip_edges()
	var type_name = ArtifactType.get_item_text(ArtifactType.get_selected_id()) if ArtifactType.item_count > 0 else ""
	var rarity = int(ArtifactRarity.get_item_text(ArtifactRarity.get_selected_id())) if ArtifactRarity.item_count > 0 else 1
	var stat1_t = Stat1Type.text.strip_edges()
	var stat1_v = int(Stat1Value.value)
	var stat2_t = Stat2Type.text.strip_edges()
	var stat2_v = int(Stat2Value.value)
	if owner == "" or set_name == "" or type_name == "":
		return
	if "Insert" in Global:
		Global.Insert("Character_Artifacts",
			["Artifact Set","Owner","Type","Stat 1 Type","Stat 2 Type","Stat 1 Value","Stat 2 Value","Equipped","Rarity"],
			[set_name, owner, type_name, stat1_t, stat2_t, stat1_v, stat2_v, false, rarity])

# ---------------- Ascension ----------------
func _on_ascend_confirm() -> void:
	var owner = owners[AscendOwner.get_selected_id()] if owners.size() > 0 else ""
	if owner == "":
		return
	var rec = _find_character_record(owner)
	if rec.is_empty():
		return
	var char_id = float(rec.get("Id", 0))
	var updates = []
	updates.append({"table":"Characters","record_id": char_id,"field":"Health Base Points","value": int(PointsHP.value)})
	updates.append({"table":"Characters","record_id": char_id,"field":"Attack Base Points","value": int(PointsATK.value)})
	updates.append({"table":"Characters","record_id": char_id,"field":"Defense Base Points","value": int(PointsDEF.value)})
	updates.append({"table":"Characters","record_id": char_id,"field":"Elemental Mastery Base Points","value": int(PointsEM.value)})
	updates.append({"table":"Characters","record_id": char_id,"field":"Energy Recharge Base Points","value": int(PointsER.value)})
	updates.append({"table":"Characters","record_id": char_id,"field":"Critical Damage Base Points","value": int(PointsCD.value)})
	if "Update" in Global:
		Global.Update(updates)

func _find_character_record(owner: String) -> Dictionary:
	if "Characters" in Global:
		for key in Global.Characters.keys():
			var rec = Global.Characters[key]
			if str(rec.get("Name")) == owner:
				return rec
	return {}

# ---------------- Unlock Companion ----------------
func _on_unlock_confirm() -> void:
	var owner = owners[UnlockOwner.get_selected_id()] if owners.size() > 0 else ""
	var companion = UnlockCompanionName.text.strip_edges()
	if owner == "" or companion == "":
		return
	var rec = _find_character_record(owner)
	if rec.is_empty():
		return
	var char_id = float(rec.get("Id", 0))
	var updates = [{"table":"Characters","record_id": char_id,"field":"Companion Name","value": companion}]
	if "Update" in Global:
		Global.Update(updates)

# ---------------- Battle Prep ----------------
func _on_add_enemy_pressed() -> void:
	if EncounterVContainer.get_child_count() >= 15:
		return
	var name = EnemyName.text.strip_edges()
	var cardscene = load("res://Scenes/enemy_line_item.tscn")
	var card = cardscene.instantiate()
	card.enemy_name = name
	EncounterVContainer.add_child(card)

	

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

func _on_preset_pressed() -> void:
	# Example preset: add 3 Hilichurls and 1 Mitachurl
	_clear_encounter()
	var names = ["Hilichurl","Hilichurl","Hilichurl","Mitachurl"]
	for n in names:
		EncounterVContainer.add_child(_make_enemy_card(n, 20 if n == "Hilichurl" else 60))

func _on_situation_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/dm_battle_scene.tscn")
	var dlg = s.instantiate()
	add_child(dlg)
	for child in EncounterVContainer.get_children():
		child.queue_free()
	self.visible = false
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
		if child.name == "DMBattleScene":
			child.visible = true
			RestoreBattle.visible = false
			
	pass # Replace with function body.
