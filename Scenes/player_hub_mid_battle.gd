extends Node2D
@onready var background_image = $UI/BackgroundImage
var http: Node  # kept for compat, no longer used for HTTP
@onready var HealthButton = $"UI/StatButtonsContainer/Health Button"
@onready var AttackButton = $"UI/StatButtonsContainer/Attack Button"
@onready var DefenseButton = $"UI/StatButtonsContainer/Defense Button"
@onready var ElementalMasteryButton = $"UI/StatButtonsContainer/Elemental Mastery Button"
@onready var EnergyRechargeButton = $"UI/StatButtonsContainer/Energy Recharge Button"
@onready var CriticalDamageButton = $"UI/StatButtonsContainer/Critical Damage Button"

@onready var Mora = $UI/TopHotbar/MoraButton
@onready var TargetList = $UI/TargetListScrollbar/TargetListContainer
@onready var TargetSelection = $UI/PlayerTurnLeftPanel/TargetSelection
@onready var target_row_scene = preload("res://Scenes/target_row_scene.tscn")
@onready var AttackUsedButton = $UI/PlayerTurnLeftPanel/AttackUsedButton
@onready var BurstChargeLabel = $UI/BurstChargeLabel
@onready var EndTurnButton: Button = $UI/EndTurnButton
@onready var TilesMovedEdit = $UI/PlayerTurnLeftPanel/TilesMovedEdit
@onready var BurstChargesEdit = $UI/PlayerTurnLeftPanel/BurstChargesEdit
@onready var AttackRollEdit = $UI/PlayerTurnLeftPanel/AttackRollEdit
@onready var PassiveStacksEdit = $UI/PlayerTurnLeftPanel/PassiveStacksEdit
@onready var ItemUsedButton = $UI/PlayerTurnLeftPanel/ItemUsedButton
@onready var ItemUsedTarget = $UI/PlayerTurnLeftPanel/ItemUsedButton2
@onready var CritBox = $UI/PlayerTurnLeftPanel/CheckBox
@onready var StatusEffectList = $UI/StatusEffects
@onready var FoodBuffItemLabel = $UI/TopHotbar/FoodBuffItemLabel

var battle_id = null
var turn_no = 0
var BattleScene
var last_known_characters_timestamp := ""
var music_files: Array = []
var music_index: int = -1
var Selected_Stat
var Ascension
var Player_data
var Active_Party_With_Companions = []
var Burst_Data
var Skill_Data
var logged
var Weapon_Data
var Turn_Type
var Current_Turn = null
var Current_Battler_Selected_Move
var Current_Battler_Selected_Move_Data

signal turn_ended

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	Current_Turn = Global.Current_Party.get("Current_Turn")
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	tree_exiting.connect(_disconnect_signals)

func _disconnect_signals() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if Global.is_connected("data_load_complete", handler):
		Global.disconnect("data_load_complete", handler)
	set_battlers()
	set_ui()
	pass  # http node removed
	set_targets()
	set_attacks()
	set_items()
	set_status_effects()
	set_battle_id()
	await get_tree().create_timer(1.5).timeout
	if Global.BattlerData == {}:
		_refresh_data()
	pass


func _refresh_data():
	set_battlers()
	check_current_turn_battler_status()
	set_ui()
	set_targets()
	set_attacks()
	set_items()
	set_status_effects()


func _on_data_load_complete():
	print("Global data has finished loading!")
	Current_Turn = Global.Current_Party.get("Current_Turn")
	_refresh_data()
	if battle_id == null:
		battle_id = Global.Current_Party.get("Active_Battle_ID")

	pass  # polling removed — ENet sync
	if Global.PartyCharacters.has(Global.Current_Party.get("Current_Turn")):
		Turn_Type = "Character"
	elif Global.PartyCompanions.has(Global.Current_Party.get("Current_Turn")):
		Turn_Type = "Companion"
	else:
		Turn_Type = "Enemy"


func check_current_turn_battler_status():
	if Global.Current_Battler_Data != null:
		pass

# ---------------------------------------------------------------------------
# Party / Battler setup
# ---------------------------------------------------------------------------

func assign_party():
	for party in Global.PARTY.values():
		if party.get("Party_Member_1") == Global.ACTIVE_USER_NAME or party.get("Party_Member_2") == Global.ACTIVE_USER_NAME or party.get("Party_Member_3") == Global.ACTIVE_USER_NAME or party.get("Party_Member_4") == Global.ACTIVE_USER_NAME:
			Global.Current_Party = party


func set_battlers():
	var Original_Order: Array = get_parent().Original_Order
	Global.BattlerData = BattlerState.build_all(Original_Order)
	# Compute max_burst_charges for each battler (highest charge_cost among their abilities)
	for battler_name in Global.BattlerData:
		var entry: Dictionary = Global.BattlerData[battler_name]
		var max_bc = null
		for ability in entry.get("entity_current_ability_data", {}).values():
			var cost = ability.get("charge_cost", 0)
			if cost > 0:
				if max_bc == null or cost > max_bc:
					max_bc = cost
		entry["max_burst_charges"] = max_bc
	if Global.BattlerData.has(Global.Current_Party.get("Current_Turn")):
		Global.Current_Battler_Data = Global.BattlerData[Global.Current_Party.get("Current_Turn")]

	# Register all battlers with the effect processor (host only)
	if NetworkManager.is_host and Global.effect_processor == null:
		Global.start_battle_effects(Global.BattlerData)

# ---------------------------------------------------------------------------
# Battle ID
# ---------------------------------------------------------------------------

func set_battle_id():
	if Global.PARTY.get("Active_Battle_ID") == null and Global.ACTIVE_USER_NAME == 'Dylan':
		var updates = []
		battle_id = CryptoKey.generate_scene_unique_id()
		updates.append({
			"table": "Party",
			"record_id": int(Global.Current_Party.get('id')),
			"field": "Active_Battle_ID",
			"value": battle_id})
		Global.Update_Records(updates)

# ---------------------------------------------------------------------------
# Target selection UI
# ---------------------------------------------------------------------------

func set_targets():
	TargetSelection.clear()
	BattleScene = get_parent()
	Active_Party_With_Companions = Global.Current_Party.get("Turn_Order")
	for Companion in Global.COMPANIONS.values():
		if Companion.get("Active") == true:
			if Active_Party_With_Companions.has(Companion.get("Name")):
				pass
			else:
				Active_Party_With_Companions.append(Companion.get("Name"))
	for Member in Active_Party_With_Companions:
		TargetSelection.add_item(Member)
	for enemy in Global.BATTLEENEMIES.values():
		var enemy_label = str(enemy.get("EnemyName")) + " " + str(int(enemy.get("id")))
		var found = false

		for i in range(TargetSelection.item_count):
			if TargetSelection.get_item_text(i) == enemy_label:
				found = true
				break

		if not found:
			TargetSelection.add_item(enemy_label)

# ---------------------------------------------------------------------------
# Attack selection with cooldown / charge restrictions
# ---------------------------------------------------------------------------

func set_attacks():
	print("Set Attacks function running")
	var popup: PopupMenu = AttackUsedButton.get_popup()

	if AttackUsedButton.has_selectable_items():
		AttackUsedButton.clear()

	if Current_Turn != null and Global.BattlerData.size() > 0:
		AttackUsedButton.add_item("None")
		var none_index = AttackUsedButton.get_item_count() - 1
		if popup:
			popup.set_item_tooltip(none_index, "No attack used this turn.")

		for item in Global.BattlerData[Current_Turn].get("entity_current_active_ability_data").values():
			if item.get("Ability_Type") != "Passive":
				var ability_id: int = int(item.get("Ability_ID"))
				var ability: AbilityData = GameDB.get_ability(ability_id)
				if ability == null:
					continue
				var cooldown = item.get("Ability_Cooldown")
				var name_text: String = str(ability.name)
				var desc: String = str(ability.description)
				var charge_cost: int = ability.charge_cost if ability.charge_cost > 0 else 0

				# Wrap long descriptions every 100 characters
				desc = _wrap_text(desc, 100)
				if cooldown == 0 and charge_cost == 0:
					AttackUsedButton.add_item(name_text)
				elif charge_cost > 0:
					if int(Global.Current_Battler_Data.get("burst_charges", 0)) >= charge_cost:
						AttackUsedButton.add_item(name_text)
					else:
						AttackUsedButton.add_item(name_text + " - Not enough charges.")
				else:
					AttackUsedButton.add_item(name_text + " - " + str(cooldown) + " Turns left.")

				var idx = AttackUsedButton.get_item_count() - 1
				if popup:
					popup.set_item_tooltip(idx, desc)
				if AttackUsedButton.get_item_text(idx) != "None" and AttackUsedButton.get_item_text(idx) != name_text:
					AttackUsedButton.set_item_disabled(idx, true)

# ---------------------------------------------------------------------------
# Item selection
# ---------------------------------------------------------------------------

func set_items():
	print("Set Items function running")
	var popup: PopupMenu = ItemUsedButton.get_popup()

	if ItemUsedButton.has_selectable_items():
		ItemUsedButton.clear()

	if Current_Turn != null and Global.BattlerData.size() > 0:
		ItemUsedButton.add_item("None")
		var none_index = ItemUsedButton.get_item_count() - 1
		if popup:
			popup.set_item_tooltip(none_index, "No item used this turn.")

		for item in Global.CHARACTER_ITEMS.values():
			if item.get("Owner") == Current_Turn:
				if item.get("Type") == "Consumable" and item.get("Quantity") > 0:
					if not item.get("Description").to_lower().contains("battle") and not item.get("Description").to_lower().contains("material"):
						var name_text = str(item.get("Name"))
						ItemUsedButton.add_item(name_text)
						var desc = "Quantity - x" + str(item.get("Quantity")) + "\n\n" + "Description - " + item.get("Description")
						desc = _wrap_text(desc, 100)
						var idx = ItemUsedButton.get_item_count() - 1
						if popup:
							popup.set_item_tooltip(idx, desc)
	set_item_targets()


func set_item_targets():
	print("Set Items function running")
	var popup: PopupMenu = ItemUsedTarget.get_popup()

	if ItemUsedTarget.has_selectable_items():
		ItemUsedTarget.clear()

	if Current_Turn != null and Global.BattlerData.size() > 0:
		ItemUsedTarget.add_item("None")
		var none_index = ItemUsedTarget.get_item_count() - 1
		if popup:
			popup.set_item_tooltip(none_index, "No item used this turn.")

		for item in Global.BattlerData.keys():
			ItemUsedTarget.add_item(item)
			var idx = ItemUsedTarget.get_item_count() - 1
			var desc = Global.BattlerData[item].get("type")
			if popup:
				popup.set_item_tooltip(idx, desc)

# ---------------------------------------------------------------------------
# Status effects display
# ---------------------------------------------------------------------------

func set_status_effects():
	StatusEffectList.clear()

	var b_name = Global.ACTIVE_USER_NAME
	var effects = Global.get_battler_effects(b_name)

	var entries: Array = []
	for fx in effects:
		var dur = fx.get("turns_remaining", 0)
		var dur_str = ""
		if dur == -1:
			dur_str = "perm"
		elif dur > 0:
			dur_str = str(dur)
		else:
			dur_str = "0"

		var desc = fx.get("description", "")
		if desc == "":
			desc = "%s %s" % [fx.get("effect_type", ""), fx.get("effect_stat", "")]

		var stacks_str = ""
		if fx.get("stacks", 0) > 0:
			stacks_str = " [%d/%d]" % [fx.get("stacks"), fx.get("max_stacks", 0)]

		entries.append({
			"name": fx.get("source_name", "Unknown"),
			"duration": dur,
			"dur_str": dur_str,
			"description": desc,
			"source_type": fx.get("source_type", ""),
			"stacks_str": stacks_str,
			"effect_type": fx.get("effect_type", ""),
		})

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: int = int(a.get("duration", 0))
		var db: int = int(b.get("duration", 0))
		if da != db:
			return da < db
		return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
	)

	for e in entries:
		StatusEffectList.add_item("%s - %s%s" % [e.get("dur_str"), e.get("name"), e.get("stacks_str")])
		var idx = StatusEffectList.get_item_count() - 1
		var tip = "Source: %s\nType: %s\nTurns Left: %s%s\n\n%s" % [
			e.get("source_type"), e.get("effect_type"),
			e.get("dur_str"), e.get("stacks_str"),
			e.get("description")
		]
		StatusEffectList.set_item_tooltip(idx, _wrap_text(tip, 100))

	if StatusEffectList.item_count == 0:
		StatusEffectList.add_item("None")

# ---------------------------------------------------------------------------
# Ability options check (legacy)
# ---------------------------------------------------------------------------

func _check_ability_options():
	for weapon in Global.CHARACTER_WEAPONS.values():
		if weapon.get("Owner") == Global.ACTIVE_USER_NAME and weapon.get("Equipped") == true:
			Weapon_Data = weapon
	for ability in Global.ACTIVE_ABILITIES.values():
		if int(ability.get("Entity_ID")) == int(Global.ACTIVE_USER_RECORD_ID) and ability.get("Element") == Player_data.get("Element") and ability.get("Weapon_Type") == Weapon_Data.get("Type") and ability.get("Entity_Type") == "Character":
			var item_id
			var ability_id: int = int(ability.get("Ability_ID"))
			if ability.get("Ability_Type") == "Skill":
				var skill: AbilityData = GameDB.get_ability(ability_id)
				if skill == null:
					continue
				Skill_Data = skill
				for idx in AttackUsedButton.item_count:
					if AttackUsedButton.get_item_text(idx) == skill.name:
						item_id = idx
				if Player_data.get("Skill_CD") == 0:
					AttackUsedButton.set_item_disabled(item_id, false)
				else:
					AttackUsedButton.set_item_disabled(item_id, true)
			elif ability.get("Ability_Type") == "Burst":
				var burst: AbilityData = GameDB.get_ability(ability_id)
				if burst == null:
					continue
				Burst_Data = burst
				for idx in AttackUsedButton.item_count:
					if AttackUsedButton.get_item_text(idx) == burst.name:
						item_id = idx
				if Player_data.get("Burst_Charges") >= burst.charge_cost:
					AttackUsedButton.set_item_disabled(item_id, false)
				else:
					AttackUsedButton.set_item_disabled(item_id, true)

# ---------------------------------------------------------------------------
# UI Setup
# ---------------------------------------------------------------------------

func set_background():
	var path = "res://Background Images/Player HUB/%s.jpg" % Global.Current_Region

	if ResourceLoader.exists(path):
		var texture = load(path)
		background_image.texture = texture
	else:
		print("Background image not found: ", path)


func set_ui():
	assign_party()
	set_stats()
	Mora.text = str(Global.Current_Party.get("Mora"))
	if Global.Current_Battler_Data != null:
		BurstChargeLabel.text = "Burst Charges: " + str(int(Global.Current_Battler_Data.get("burst_charges", 0))) + "/" + str(int(Global.Current_Battler_Data.get("max_burst_charges", 0)))
	for child in TargetList.get_children():
		child.queue_free()
	TilesMovedEdit.text = str(0)
	BurstChargesEdit.text = str(0)
	PassiveStacksEdit.text = str(0)
	AttackRollEdit.text = str(0)
	if Global.Current_Party.get("Active_Food_Buff") != "None":
		FoodBuffItemLabel.text = Global.Current_Party.get("Active_Food_Buff")
		var item_data
		for item in Global.ITEMS.values():
			if item.get("Item") == Global.Current_Party.get("Active_Food_Buff"):
				item_data = item
		FoodBuffItemLabel.tooltip_text = item_data.get("Description")
	else:
		FoodBuffItemLabel.text = "None"
		FoodBuffItemLabel.tooltip_text = "No Food Buff Active."

# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

func _apply_stat(btn, key: String, val) -> void:
	var pd = Player_data
	btn.Stat = key
	btn.StatValue = val
	btn.AddedRoll        = pd.get("%s_Added_Roll_Bonus" % key, 0) \
						+ pd.get("%s_Manual_Roll_Added_Amount_Override" % key, 0) \
						+ pd.get("Universal_Added_Roll_Bonus", 0)
	btn.MultipliedRoll  = 1 + pd.get("%s_Multiplier_Roll_Bonus" % key, 0.0) \
						  + pd.get("%s_Manual_Roll_Multiplier_Amount_Override" % key, 0.0)\
						+ pd.get("Universal_Multiplier_Roll_Bonus", 0.0)
	btn.AddedDamage     = pd.get("%s_Added_Damage_Bonus" % key, 0) \
						+ pd.get("%s_Manual_Damage_Added_Amount_Override" % key, 0)\
						+ pd.get("Universal_Added_Damage_Bonus", 0)
	btn.MultipliedDamage = 1 + pd.get("%s_Multiplier_Damage_Bonus" % key, 0.0) \
						   + pd.get("%s_Manual_Damage_Multiplier_Amount_Override" % key, 0.0)\
						+ pd.get("Universal_Multiplier_Damage_Bonus", 0.0)


func set_stats():
	Player_data = Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]]
	var rows = [
	[HealthButton,            "Health",             Global.Current_Health],
	[AttackButton,            "Attack",             Global.Current_Attack],
	[DefenseButton,           "Defense",            Global.Current_Defense],
	[ElementalMasteryButton,  "Elemental_Mastery",  Global.Current_Elemental_Mastery],
	[EnergyRechargeButton,    "Energy_Recharge",    Global.Current_Energy_Recharge],
	[CriticalDamageButton,    "Critical_Damage",    Global.Current_Critical_Damage],]
	for r in rows:
		_apply_stat(r[0], r[1], r[2])

	HealthButton.set_stats()
	AttackButton.set_stats()
	DefenseButton.set_stats()
	ElementalMasteryButton.set_stats()
	EnergyRechargeButton.set_stats()
	CriticalDamageButton.set_stats()
	var updates = []


func get_artifacts():
	for artifact in Global.CHARACTER_ARTIFACTS.values():
		if artifact.get("Owner") == Global.ACTIVE_USER_NAME and artifact.get("Equipped") == true:
			match artifact.get("Type"):
				"Flower of Life":
					pass
				"Feather of Death":
					pass
				"Sands of Time":
					pass
				"Goblet of Space":
					pass
				"Circlet of Principles":
					pass

# ---------------------------------------------------------------------------
# Stat panel popups
# ---------------------------------------------------------------------------

func _open_stat_summary(stat_name: String) -> void:
	Selected_Stat = stat_name
	print("Toggling Stat Panel for: " + Selected_Stat)
	var s: PackedScene = preload("res://Scenes/stat_summary.tscn")
	var dlg = s.instantiate()

	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO

	win.add_child(dlg)
	add_child(win)

	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dlg.update_stat_summary(Selected_Stat)


func _on_health_button_pressed() -> void:
	_open_stat_summary("Health")


func _on_attack_button_pressed() -> void:
	_open_stat_summary("Attack")


func _on_defense_button_pressed() -> void:
	_open_stat_summary("Defense")


func _on_elemental_mastery_button_pressed() -> void:
	_open_stat_summary("Elemental_Mastery")


func _on_energy_recharge_button_pressed() -> void:
	_open_stat_summary("Energy_Recharge")


func _on_critical_damage_button_pressed() -> void:
	_open_stat_summary("Critical_Damage")

# ---------------------------------------------------------------------------
# Other popup buttons
# ---------------------------------------------------------------------------

func _on_weapon_button_pressed() -> void:
	print("Weapon Button has been pressed")
	var s = preload("res://Scenes/weapon_detail_scene.tscn")
	var dlg = s.instantiate()

	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO

	win.add_child(dlg)
	add_child(win)

	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)


func _check_characters_update():
	# No longer polls HTTP — data updates arrive via ENet RPC
	pass


func _on_check_characters_response(_result, _code, _headers, _body):
	# Legacy callback — no longer used. Data sync handled by ENet.
	pass


func _on_inventory_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/PlayerInventory.tscn")
	var dlg = s.instantiate()
	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO
	win.add_child(dlg)
	add_child(win)
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)


func _on_talents_button_pressed() -> void:
	var s: PackedScene = preload("res://UI/Tabs.tscn")
	var dlg = s.instantiate()
	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO
	dlg.TableType = "Talents"
	win.add_child(dlg)
	add_child(win)
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)


func _on_constellations_button_pressed() -> void:
	var s: PackedScene = preload("res://UI/Tabs.tscn")
	var dlg = s.instantiate()
	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO
	dlg.TableType = "Constellations"
	win.add_child(dlg)
	add_child(win)
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)


func _on_abilities_button_pressed() -> void:
	var s: PackedScene = preload("res://UI/Tabs.tscn")
	var dlg = s.instantiate()
	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO
	dlg.TableType = "Abilities"
	win.add_child(dlg)
	add_child(win)
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)


func _on_bug_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/FeedbackPopup.tscn")
	var dlg = s.instantiate()
	dlg.position = Vector2(800, 450)
	add_child(dlg)

# ---------------------------------------------------------------------------
# PROCESS TURN — main entry point
# ---------------------------------------------------------------------------

func process_turn():
	var updates = []
	var spaces_moved: int = int(TilesMovedEdit.text)
	var burst_charges_gained: int = int(BurstChargesEdit.text)
	var attack_roll: int = int(AttackRollEdit.text)
	var passive_stacks_total: int = int(PassiveStacksEdit.text)

	var item_used_text: String = ItemUsedButton.get_item_text(ItemUsedButton.selected)
	var item_target_text: String = ItemUsedTarget.get_item_text(ItemUsedTarget.selected)
	var attack_used_text: String = AttackUsedButton.get_item_text(AttackUsedButton.selected)
	var critical_hit: bool = CritBox.button_pressed
	var battler_name: String = Global.ACTIVE_USER_NAME

	# ----- Turn start effects (host only) -----
	if NetworkManager.is_host and Global.effect_processor:
		var start_ctx = {
			"current_health": Global.Current_Battler_Data.get("current_health", 0),
			"max_health": Global.Current_Battler_Data.get("max_health", 0),
			"burst_charges": Global.Current_Battler_Data.get("burst_charges", 0),
		}
		var _start_actions = Global.effect_processor.on_turn_start(battler_name, start_ctx)
		# TODO: process START_OF_TURN actions (DOT damage, healing, etc.)

	# ----- Per-target collection -----
	var targets: Array = []
	var total_damage: int = 0
	var elements_unique: Dictionary = {}
	var killed_names: Array = []

	for row in TargetList.get_children():
		if not row.has_node("NameLabel"):
			continue

		var t_name: String = row.NameLabel.text
		var t_def_roll: int = int(row.RollEdit.text)
		var t_hits: int = int(row.HitsEdit.text)
		var t_raw_dmg: int = int(row.DamageEdit.text)
		var t_type: String = row.AttackType.get_item_text(row.AttackType.selected)
		var t_elem: String = row.AppliedElement.get_item_text(row.AppliedElement.selected)
		var t_killed: bool = row.KilledStatus.button_pressed
		var t_shield_hit: bool = row.ShieldHit.button_pressed
		var t_table = row.TargetTable
		var t_id = row.TargetID
		var t_reaction = false
		var t_current_element = "None"
		var t_effect_status_target = "self"
		var t_effect_status = 0
		var t_effect_status_duration = 0
		var t_entity_type: String = ""

		match t_table:
			"Characters":
				t_entity_type = "Character"
			"Companions":
				t_entity_type = "Companion"
			"BattleEnemies":
				t_entity_type = "Enemy"

		var t_ignores_def: bool = t_type.to_lower() in ["true damage", "pierce", "ignore def"]
		var t_damage: int = t_raw_dmg
		if t_type.to_lower() == "healed":
			t_damage = -t_raw_dmg

		# --- Element application and reaction detection ---
		if t_elem != "None":
			elements_unique[t_elem] = true
			var elem_result := _apply_element(t_table, t_id, t_elem, updates)
			t_reaction = elem_result.get("reaction", false)
			t_current_element = elem_result.get("current_element", "None")

			# --- Reaction effects (host only) ---
			if t_reaction and NetworkManager.is_host and Global.effect_processor:
				var react_ctx = {"reaction_element": t_current_element, "attack_element": t_elem, "element": t_elem, "is_crit": critical_hit}
				var react_actions = Global.effect_processor.process_trigger(battler_name, "ON_REACTION", react_ctx)
				for act in react_actions:
					if act.get("effect_type") == "FLAT_DAMAGE":
						t_damage += int(act.get("value", 0))
					elif act.get("effect_type") == "PERCENT_DAMAGE":
						t_damage = int(t_damage * act.get("value", 1.0))

		# --- Damage modifiers from effects (host only) ---
		if NetworkManager.is_host and Global.effect_processor and t_damage > 0:
			var hit_ctx = {"attack_type": t_type, "element": t_elem, "is_crit": critical_hit, "target_element": t_current_element}
			var flat_mod = Global.effect_processor.sum_flat_damage(battler_name, "ON_HIT", hit_ctx)
			var mult_mod = Global.effect_processor.damage_multiplier(battler_name, "ON_HIT", hit_ctx)
			if critical_hit:
				flat_mod += Global.effect_processor.sum_flat_damage(battler_name, "ON_CRIT", hit_ctx)
				mult_mod *= Global.effect_processor.damage_multiplier(battler_name, "ON_CRIT", hit_ctx)
			t_damage = int((t_damage + flat_mod) * mult_mod)

		# --- HP / Shield / KO logic ---
		var t_type_lower: String = t_type.to_lower()
		if t_table != null and t_id != null and t_type_lower in ["damage", "true damage", "healed", "shielded"]:
			var record_id: int = int(t_id)
			var key: String = str(record_id)
			var row_data: Dictionary = {}

			if t_table == "Characters":
				if Global.CHARACTERS.has(key):
					row_data = Global.CHARACTERS[key]
			elif t_table == "Companions":
				if Global.COMPANIONS.has(key):
					row_data = Global.COMPANIONS[key]
			elif t_table == "BattleEnemies":
				if Global.BATTLEENEMIES.has(key):
					row_data = Global.BATTLEENEMIES[key]

			if row_data.size() > 0:
				var damage_result := _resolve_damage(row_data, t_table, t_id, t_type, t_damage, record_id, t_entity_type, t_shield_hit, updates)
				t_killed = damage_result.get("killed", t_killed)

		# --- Ability status effect application on targets ---
		if attack_used_text != "None":
			for ability in Global.Current_Battler_Data.get("entity_current_ability_data").values():
				if ability.get("name") == attack_used_text:
					Current_Battler_Selected_Move_Data = ability
					for move in Global.Current_Battler_Data.get("entity_current_active_ability_data").values():
						if int(move.get("Ability_ID")) == int(ability.get("id")):
							Current_Battler_Selected_Move = move

		if Current_Battler_Selected_Move_Data:
			# Put ability on cooldown
			if Current_Battler_Selected_Move_Data.get("cooldown", 0) > 0:
				updates.append({
					"table": "Active_Abilities",
					"record_id": int(Current_Battler_Selected_Move.get("id")),
					"field": "Ability_Cooldown",
					"value": Current_Battler_Selected_Move_Data.get("cooldown")})

			# Subtract burst charge cost
			if Current_Battler_Selected_Move_Data.get("charge_cost", 0) > 0:
				var old_value = Global.Current_Battler_Data.get("entity_data").get("Burst_Charges")
				var new_value = int(old_value - Current_Battler_Selected_Move_Data.get("charge_cost"))
				if new_value <= 0:
					new_value = 0
				var table: String = ""
				match Global.Current_Battler_Data.get("type"):
					"Character":
						table = "Characters"
					"Companion":
						table = "Companions"
				if table != "":
					updates.append({
						"table": table,
						"record_id": int(Global.Current_Battler_Data.get("id")),
						"field": "Burst_Charges",
						"value": new_value})

			# Apply status effect to target via EffectProcessor
			if int(Current_Battler_Selected_Move_Data.get("effect_status", 0)) > 0:
				t_effect_status_target = str(Current_Battler_Selected_Move_Data.get("effect_status_target", "target"))
				t_effect_status = int(Current_Battler_Selected_Move_Data.get("effect_status"))
				t_effect_status_duration = int(Current_Battler_Selected_Move_Data.get("effect_status_duration_rounds", 0))

				if t_effect_status_target == "target" and NetworkManager.is_host and Global.effect_processor:
					# Look up status name from GameDB
					var status_data = GameDB.status_effects.get(t_effect_status, null)
					var status_name = status_data.name if status_data else "Status_%d" % t_effect_status
					var status_effects = StatusEffectsMap.get_effects(status_name)
					for eff in status_effects:
						if eff.duration == 0:
							eff.duration = t_effect_status_duration + 1
						Global.effect_processor.add_effect(t_name, eff, "status", status_name)

		if t_killed:
			killed_names.append(t_name)

		total_damage += t_damage

		targets.append({
			"name": t_name,
			"target_table": t_table,
			"target_id": t_id,
			"target_type": t_entity_type,
			"their_roll": t_def_roll,
			"hits": t_hits,
			"attack_type": t_type,
			"current_element": t_current_element,
			"applied_element": t_elem,
			"applied_status_effect": t_effect_status,
			"applied_status_effect_duration": t_effect_status_duration,
			"ignores_def": t_ignores_def,
			"shield_hit": t_shield_hit,
			"killed": t_killed,
			"damage": t_damage,
			"reaction": t_reaction
		})

	# ----- Item usage -----
	var item_info: Dictionary = {
		"used": item_used_text != "None",
		"name": item_used_text,
		"target": item_target_text,
	}

	# ----- Burst charge gain -----
	if burst_charges_gained > 0:
		_gain_burst_charges(burst_charges_gained, updates)

	# ----- End-of-turn cooldowns and status decrements -----
	_process_cooldowns_and_status(updates)

	# ----- Consume item if used -----
	if item_used_text != "None":
		_consume_item(item_used_text, updates)

	# ----- Build aggregated combat log -----
	var action_type: String = "Turn"
	var action_name: String = attack_used_text

	var elements_applied: Array = elements_unique.keys()
	var status_changes: Dictionary = {
		"passive_stacks_total": passive_stacks_total,
		"killed_targets": killed_names
	}

	var rolls: Dictionary = {
		"player_attack": attack_roll,
		"critical": critical_hit
	}

	var misc: Dictionary = {
		"spaces_moved": spaces_moved,
		"item": item_info,
		"targets": targets,
		"attack_ui_type": "Composite"
	}

	var hp_before: int = 0
	var hp_after: int = 0

	Global.CombatLog(
		battle_id,
		turn_no,
		"player_turn",
		Global.Current_Battler_Data.get("type"),
		Global.ACTIVE_USER_NAME,
		action_type,
		action_name,
		Global.ACTIVE_USER_NAME,
		false,
		rolls,
		total_damage,
		hp_before,
		hp_after,
		burst_charges_gained,
		elements_applied,
		status_changes,
		misc
	)
	Global.Update_Records(updates)

# ---------------------------------------------------------------------------
# process_turn helpers
# ---------------------------------------------------------------------------

## Handle element application on a target. Returns { "reaction": bool, "current_element": String }
func _apply_element(t_table: String, t_id, t_elem: String, updates: Array) -> Dictionary:
	var result := { "reaction": false, "current_element": "None" }

	match t_table:
		"Characters":
			if Global.CHARACTERS[t_id].get("Applied_Element") == "None":
				updates.append({
					"table": "Characters",
					"record_id": int(t_id),
					"field": "Applied_Element",
					"value": t_elem})
			else:
				result["current_element"] = Global.CHARACTERS[t_id].get("Applied_Element")
				result["reaction"] = true
				updates.append({
					"table": "Characters",
					"record_id": int(t_id),
					"field": "Applied_Element",
					"value": "None"})
		"Companions":
			if Global.COMPANIONS.get(str(t_id), {}).get("Applied_Element", "None") == "None":
				updates.append({
					"table": "Companions",
					"record_id": int(t_id),
					"field": "Applied_Element",
					"value": t_elem})
			else:
				result["current_element"] = Global.COMPANIONS.get(str(t_id), {}).get("Applied_Element", "None")
				result["reaction"] = true
				updates.append({
					"table": "Companions",
					"record_id": int(t_id),
					"field": "Applied_Element",
					"value": "None"})
		"BattleEnemies":
			if Global.BATTLEENEMIES[t_id].get("AppliedElement") == "None":
				updates.append({
					"table": "BattleEnemies",
					"record_id": int(t_id),
					"field": "AppliedElement",
					"value": t_elem})
			else:
				result["current_element"] = Global.BATTLEENEMIES[t_id].get("AppliedElement")
				result["reaction"] = true
				updates.append({
					"table": "BattleEnemies",
					"record_id": int(t_id),
					"field": "AppliedElement",
					"value": "None"})

	return result


## Handle HP changes, shield absorption, shield break, and KO logic.
## Returns { "killed": bool }
func _resolve_damage(row_data: Dictionary, t_table: String, t_id, t_type: String, t_damage: int, record_id: int, t_entity_type: String, t_shield_hit: bool, updates: Array) -> Dictionary:
	var result := { "killed": false }
	var t_type_lower: String = t_type.to_lower()

	# ----------------------------
	# SHIELD GRANT (no HP change)
	# ----------------------------
	if t_type_lower == "shielded":
		var incoming_shield: int = abs(t_damage)

		var sh_val = row_data.get("Shield_Health")
		var cur_shield: int = 0
		if sh_val != null:
			cur_shield = int(sh_val)

		var new_shield: int = incoming_shield

		updates.append({
			"table": t_table,
			"record_id": record_id,
			"field": "Shield_Health",
			"value": new_shield
		})
		row_data["Shield_Health"] = new_shield

		updates.append({
			"table": t_table,
			"record_id": record_id,
			"field": "Shield_Duration",
			"value": 4
		})
		row_data["Shield_Duration"] = 4

	else:
		# ----------------------------
		# DAMAGE/HEAL (with optional shield-hit routing)
		# ----------------------------
		var current_hp: int = int(row_data.get("Current_Health", 0))
		var max_hp: int = int(row_data.get("Max_Health", current_hp))

		var hp_damage: int = t_damage

		# If flagged as hitting a shield, route DAMAGE through Shield_Health first.
		if t_shield_hit and hp_damage > 0:
			var sh_val2 = row_data.get("Shield_Health")
			var cur_shield2: int = 0
			if sh_val2 != null:
				cur_shield2 = int(sh_val2)

			if cur_shield2 > 0:
				if hp_damage < cur_shield2:
					# Shield absorbs all incoming damage
					var remaining_shield: int = cur_shield2 - hp_damage

					updates.append({
						"table": t_table,
						"record_id": record_id,
						"field": "Shield_Health",
						"value": remaining_shield
					})
					row_data["Shield_Health"] = remaining_shield

					hp_damage = 0

				else:
					# Shield breaks; spillover hits HP
					var overflow: int = hp_damage - cur_shield2

					# If damage EXCEEDS shield health (strictly), apply Status_ID 19 for 2 turns
					if hp_damage > cur_shield2:
						var found_break = false
						for active_status in Global.ACTIVE_STATUS_EFFECTS.values():
							if int(active_status.get("Status_ID", 0)) == 19 \
							and str(active_status.get("Entity_Type")) == str(t_entity_type) \
							and int(active_status.get("Entity_ID", 0)) == int(t_id):

								found_break = true
								updates.append({
									"table": "Active_Status_Effects",
									"record_id": int(active_status.get("id")),
									"field": "Duration",
									"value": 2
								})
								break

						if not found_break:
							var cols_break = ["Entity_ID", "Entity_Type", "Status_ID", "Duration"]
							var vals_break = [int(t_id), str(t_entity_type), 19, 2]
							Global.Insert("Active_Status_Effects", cols_break, vals_break)

					# Clear shield
					updates.append({
						"table": t_table,
						"record_id": record_id,
						"field": "Shield_Health",
						"value": null
					})
					row_data["Shield_Health"] = null

					updates.append({
						"table": t_table,
						"record_id": record_id,
						"field": "Shield_Duration",
						"value": null
					})
					row_data["Shield_Duration"] = null

					hp_damage = overflow

		# Apply HP change (positive = damage, negative = heal)
		var new_hp: int = current_hp - hp_damage

		# Clamp to [0, Max_Health]
		if new_hp > max_hp:
			new_hp = max_hp
		if new_hp < 0:
			new_hp = 0

		updates.append({
			"table": t_table,
			"record_id": record_id,
			"field": "Current_Health",
			"value": new_hp
		})
		row_data["Current_Health"] = new_hp

		# If HP hit 0 from DAMAGE, mark as Skipped (and Killed for BattleEnemies)
		if new_hp == 0 and t_type_lower in ["damage", "true damage"]:
			updates.append({
				"table": t_table,
				"record_id": record_id,
				"field": "Skipped",
				"value": true
			})
			row_data["Skipped"] = true

			if t_table == "BattleEnemies":
				updates.append({
					"table": t_table,
					"record_id": record_id,
					"field": "Killed",
					"value": true
				})
				row_data["Killed"] = true
				result["killed"] = true

	return result


## Tick effect durations and ability cooldowns for the current battler at end of turn.
func _process_cooldowns_and_status(updates: Array) -> void:
	var b_name = Global.ACTIVE_USER_NAME

	# Tick effect durations via processor (host only) — only this battler's effects
	if NetworkManager.is_host and Global.effect_processor:
		Global.effect_processor.on_turn_end(b_name)
		Global.sync_active_effects()

	# Subtract turn from Move Cooldowns for this entity (kept separate from effects)
	for entry in Global.ACTIVE_ABILITIES.values():
		if entry.get("Entity_Type") == Global.Current_Battler_Data.get("type") and int(entry.get("Entity_ID")) == int(Global.Current_Battler_Data.get("id")) and entry.get("Ability_Cooldown") > 0:
			updates.append({
				"table": "Active_Abilities",
				"record_id": int(entry.get("id")),
				"field": "Ability_Cooldown",
				"value": int(entry.get("Ability_Cooldown")) - 1})


## Subtract item from inventory when used.
func _consume_item(item_name: String, updates: Array) -> void:
	for entry in Global.CHARACTER_ITEMS.values():
		if entry.get("Owner") == Global.Current_Battler_Data.get("name") and entry.get("Name") == item_name:
			updates.append({
				"table": "Character_Items",
				"record_id": int(entry.get("id")),
				"field": "Quantity",
				"value": int(entry.get("Quantity")) - 1})


## Add burst charges gained this turn, capped at the highest charge cost among abilities.
func _gain_burst_charges(burst_charges_gained: int, updates: Array) -> void:
	var highest_charge_cost = 0
	for ability in Global.Current_Battler_Data.get("entity_current_ability_data").values():
		if ability.get("charge_cost", 0) > highest_charge_cost:
			highest_charge_cost = ability.get("charge_cost", 0)
	var current_charges = Global.Current_Battler_Data.get("entity_data").get("Burst_Charges")
	if current_charges < highest_charge_cost:
		var new_charge_amount = current_charges + burst_charges_gained
		if new_charge_amount >= highest_charge_cost:
			new_charge_amount = highest_charge_cost
		var table: String = ""
		match Global.Current_Battler_Data.get("type"):
			"Character":
				table = "Characters"
			"Companion":
				table = "Companions"
		if table != "":
			updates.append({
				"table": table,
				"record_id": int(Global.Current_Battler_Data.get("id")),
				"field": "Burst_Charges",
				"value": new_charge_amount})

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## Helper function for natural word wrapping
func _wrap_text(text: String, limit: int) -> String:
	var result = ""
	var start = 0

	while start < text.length():
		var end = min(start + limit, text.length())

		# If not at the end, find the last space before the limit
		if end < text.length():
			var segment = text.substr(start, end - start)
			var space_index = segment.rfind(" ")
			if space_index != -1:
				end = start + space_index + 1

		result += text.substr(start, end - start).strip_edges()
		if end < text.length():
			result += "\n"

		start = end

	return result

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_end_turn_button_pressed() -> void:
	process_turn()
	emit_signal("turn_ended")


func _on_target_selection_multi_selected(index: int, selected: bool) -> void:

	for child in TargetList.get_children():
		child.queue_free()
	for item in TargetSelection.get_selected_items():
		var row = target_row_scene.instantiate()
		TargetList.add_child(row)
		row.NameLabel.text = TargetSelection.get_item_text(item)
		var data
		if Global.PartyCharacters.has(TargetSelection.get_item_text(item)):
			row.TargetTable = "Characters"
			row.TargetID = Global.CHARACTERS_NAME[TargetSelection.get_item_text(item)]
			data = Global.CHARACTERS[row.TargetID]
			if data.get("Shield_Health"):
				row.TargetShieldAmount = data.get("Shield_Health")
			else:
				row.TargetShieldAmount = 0
		elif Global.PartyCompanions.has(TargetSelection.get_item_text(item)):
			row.TargetTable = "Companions"
			row.TargetID = Global.COMPANIONS_NAME[TargetSelection.get_item_text(item)]
			data = Global.COMPANIONS[row.TargetID]
			if data.get("Shield_Health"):
				row.TargetShieldAmount = data.get("Shield_Health")
			else:
				row.TargetShieldAmount = 0
		else:
			row.TargetTable = "BattleEnemies"
			var parts = TargetSelection.get_item_text(item).split(" ")
			var id_str = parts[-1]
			row.TargetID = id_str
			data = Global.BATTLEENEMIES[row.TargetID]
			if data.get("Shield_Health"):
				row.TargetShieldAmount = data.get("Shield_Health")
			else:
				row.TargetShieldAmount = 0


func _on_visibility_button_pressed() -> void:
	self.visible = false


func _on_visibility_changed() -> void:
	pass
