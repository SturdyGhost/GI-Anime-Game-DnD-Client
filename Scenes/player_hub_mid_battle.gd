extends Node2D
@onready var background_image = $UI/BackgroundImage
@onready var http = HTTPRequest.new()
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
var turn_no= 0
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

func _ready() -> void:
	Current_Turn = Global.Current_Party.get("Current_Turn")
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	var path = "res://Background Music/Inazuma/Player HUB/1-01 Inazuma.mp3"  # replace with your actual file
	set_battlers()
	set_ui()
	add_child(http)
	Global.Polling_Timer = Timer.new()
	Global.add_child(Global.Polling_Timer)
	Global.Polling_Timer.one_shot = false
	Global.Polling_Timer.wait_time = 0.1
	Global.Polling_Timer.timeout.connect(Global._check_modified_batch)
	Global.Polling_Timer.start()
	set_targets()
	set_attacks()
	set_items()
	set_status_effects()
	set_battle_id()
	await get_tree().create_timer(1.5).timeout
	if Global.BattlerData == {}:
		_refresh_data()
	#$UI/NameLabel.text = Global.ACTIVE_USER_NAME
	pass





func assign_party():
	for party in Global.PARTY.values():
		if party.get("Party_Member_1") == Global.ACTIVE_USER_NAME or party.get("Party_Member_2") == Global.ACTIVE_USER_NAME or party.get("Party_Member_3") == Global.ACTIVE_USER_NAME or party.get("Party_Member_4") == Global.ACTIVE_USER_NAME:
			Global.Current_Party = party

func _check_ability_options():
	for weapon in Global.CHARACTER_WEAPONS.values():
		if weapon.get("Owner") == Global.ACTIVE_USER_NAME and weapon.get("Equipped") == true:
			Weapon_Data = weapon
	for ability in Global.ACTIVE_ABILITIES.values():
		if str(ability.get("Entity_ID")) == str(Global.ACTIVE_USER_RECORD_ID) and ability.get("Element") == Player_data.get("Element") and ability.get("Weapon_Type") == Weapon_Data.get("Type") and ability.get("Entity_Type") == "Character":
			var item_id
			if ability.get("Ability_Type") == "Skill":
				Skill_Data = Global.ABILITIES[str(ability.get("Ability_ID"))]
				for item in AttackUsedButton.item_count:
					if AttackUsedButton.get_item_text(item) == Skill_Data.get("name"):
						item_id = item
				if Player_data.get("Skill_CD") == 0:
					AttackUsedButton.set_item_disabled(item_id,false)
				else:
					AttackUsedButton.set_item_disabled(item_id,true)
			elif ability.get("Ability_Type") == "Burst":
				Burst_Data = Global.ABILITIES[str(ability.get("Ability_ID"))]
				for item in AttackUsedButton.item_count:
					if AttackUsedButton.get_item_text(item) == Burst_Data.get("name"):
						item_id = item
				if Player_data.get ("Burst_Charges") >= Burst_Data.get("charge_cost"):
					AttackUsedButton.set_item_disabled(item_id,false)
				else:
					AttackUsedButton.set_item_disabled(item_id,true)
		
			pass
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
	print("✅ Global data has finished loading!")
	Current_Turn = Global.Current_Party.get("Current_Turn")
	_refresh_data()
	if battle_id == null:
		battle_id = Global.Current_Party.get("Active_Battle_ID")
	
	#await get_tree().create_timer(3.0).timeout
	Global.Polling_Timer.start()
	Global.Polling_Timer.paused = false
	if Global.PartyCharacters.has(Global.Current_Party.get("Current_Turn")):
		Turn_Type = "Character"
	elif Global.PartyCompanions.has(Global.Current_Party.get("Current_Turn")):
		Turn_Type = "Companion"
	else:
		Turn_Type = "Enemy"
	# Your logic here


func check_current_turn_battler_status():
	if Global.Current_Battler_Data != null:
		pass


func set_battle_id():
	if Global.PARTY.get("Active_Battle_ID") == null and Global.ACTIVE_USER_NAME == 'Dylan':
		var updates = []
		battle_id = CryptoKey.generate_scene_unique_id()
		updates.append({
			"table": "Party",
			"record_id": Global.Current_Party.get('id'),
			"field": "Active_Battle_ID",
			"value": battle_id})
		Global.Update_Records(updates)


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
				var ability_id = str(item.get("Ability_ID"))
				var ability = Global.ABILITIES.get(ability_id, {})
				var cooldown = item.get("Ability_Cooldown")
				var name = str(ability.get("name", "Unnamed"))
				var desc = str(ability.get("description", ""))
				var charge_cost = 0
				var ability_data = Global.ABILITIES[ability_id]
				if ability_data.get("charge_cost") > 0:
					charge_cost = ability_data.get("charge_cost")

				# Wrap long descriptions every 100 characters
				desc = _wrap_text(desc, 100)
				if cooldown == 0 and charge_cost == 0:
					AttackUsedButton.add_item(name)
				elif charge_cost > 0:
					if Global.Current_Battler_Data.get("burst_charges") > charge_cost:
						AttackUsedButton.add_item(name)
					else:
						AttackUsedButton.add_item(name+" - Not enough charges.")
				else:
					AttackUsedButton.add_item(name+" - "+str(cooldown)+" Turns left.")
				
				var idx = AttackUsedButton.get_item_count() - 1
				if popup:
					popup.set_item_tooltip(idx, desc)
				if AttackUsedButton.get_item_text(idx) != "None" and AttackUsedButton.get_item_text(idx) != name:
					AttackUsedButton.set_item_disabled(idx, true)

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
						var name = str(item.get("Name"))
						ItemUsedButton.add_item(name)
						var desc = "Quantity - x"+str(item.get("Quantity"))+"\n\n"+"Description - "+item.get("Description")
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

func set_battlers():
	Global.BattlerData = {}
	print ("Set Battlers Function running.")
	if get_parent().Original_Order.size() > 0:
		for battler in get_parent().Original_Order:
			var b_id
			var b_type
			var b_complete_data
			var b_complete_weapon_data = null
			var b_complete_active_ability_data = {}
			var b_complete_ability_data = {}
			var b_active_status_effects = {}
			var b_active_abilities = {}
			var b_active_ability_data = {}
			var b_current_health
			var b_max_health
			var b_burst_charges = null
			var b_max_burst_charges = null
			var b_applied_element
			var b_skipped_status
			var b_skipped_duration
			var b_killed_status
			if Global.PartyCharacters.has(battler):
				b_type = "Character"
				b_complete_data = Global.CHARACTERS[Global.CHARACTERS_NAME[battler]]
				b_id = b_complete_data.get("id")
				b_burst_charges = b_complete_data.get("Burst_Charges")
				for weapon in Global.CHARACTER_WEAPONS.values():
					if weapon.get("Owner") == battler and weapon.get("Equipped") == true:
						b_complete_weapon_data = weapon
				for aa in Global.ACTIVE_ABILITIES.values():
					if aa.get("Entity_Type") == b_type and aa.get("Entity_ID") == b_id:
						b_complete_active_ability_data[aa.get("id")] = aa
						b_complete_ability_data[aa.get("Ability_ID")] = Global.ABILITIES[str(aa.get("Ability_ID"))]
						if aa.get("Element") == b_complete_data.get("Element") and aa.get("Weapon_Type") == b_complete_weapon_data.get("Type"):
							b_active_abilities[aa.get("id")] = aa
							b_active_ability_data[aa.get("Ability_ID")] = Global.ABILITIES[str(aa.get("Ability_ID"))]
			elif Global.PartyCompanions.has(battler):
				b_type = "Companion"
				b_complete_data = Global.COMPANIONS[Global.COMPANIONS_NAME[battler]]
				b_id = b_complete_data.get("id")
				b_burst_charges = b_complete_data.get("Burst_Charges")
				for aa in Global.ACTIVE_ABILITIES.values():
					if aa.get("Entity_Type") == b_type and aa.get("Entity_ID") == b_id:
						b_complete_active_ability_data[aa.get("id")] = aa
						b_complete_ability_data[aa.get("Ability_ID")] = Global.ABILITIES[str(aa.get("Ability_ID"))]
						b_active_abilities[aa.get("id")] = aa
						b_active_ability_data[aa.get("Ability_ID")] = Global.ABILITIES[str(aa.get("Ability_ID"))]
			else:
				b_type = "Enemy"
				b_id = battler.split(" ")[-1]
				b_complete_data = Global.BATTLEENEMIES[str(float(b_id))]
				for aa in Global.ACTIVE_ABILITIES.values():
					if aa.get("Entity_Type") == b_type and aa.get("Entity_ID") == b_complete_data.get("EnemyID"):
						b_complete_active_ability_data[aa.get("id")] = aa
						b_complete_ability_data[aa.get("Ability_ID")] = Global.ABILITIES[str(aa.get("Ability_ID"))]
						b_active_abilities[aa.get("id")] = aa
						b_active_ability_data[aa.get("Ability_ID")] = Global.ABILITIES[str(aa.get("Ability_ID"))]
			for status in Global.ACTIVE_STATUS_EFFECTS.values():
				if status.get("Entity_Type") == b_type and str(float(status.get("Entity_ID"))) == str(float(b_id)):
					b_active_status_effects[status.get("id")] = status
			b_current_health = b_complete_data.get("Current_Health")
			b_max_health = b_complete_data.get("Max_Health")
			b_skipped_status = b_complete_data.get("Skipped")
			b_skipped_duration = b_complete_data.get("Skip_Duration")
			b_applied_element = b_complete_data.get("Applied_Element")
			b_killed_status = b_complete_data.get("Killed")
			for ability in b_active_ability_data.values():
				if ability.get("charge_cost") > 0:
					if b_max_burst_charges == null:
						b_max_burst_charges = ability.get("charge_cost")
					else:
						if ability.get("charge_cost") > b_max_burst_charges:
							b_max_burst_charges = ability.get("charge_cost")
			Global.BattlerData[battler] = {
				"id": b_id,
				"name": battler,
				"type": b_type,
				"entity_data": b_complete_data,
				"entity_weapon_data": b_complete_weapon_data,
				"entity_total_active_ability_data": b_complete_active_ability_data,
				"entity_total_ability_data": b_complete_ability_data,
				"entity_current_active_ability_data": b_active_abilities,
				"entity_current_ability_data": b_active_ability_data,
				"entity_status_effect_data": b_active_status_effects,
				"current_health": b_current_health,
				"max_health": b_max_health,
				"burst_charges": b_burst_charges,
				"max_burst_charges": b_max_burst_charges,
				"applied_element": b_applied_element,
				"killed_status": b_killed_status,
				"skipped_status": b_skipped_status,
				"skipped_duration": b_skipped_duration}
		Global.Current_Battler_Data = Global.BattlerData[Global.Current_Party.get("Current_Turn")]
		pass


func set_status_effects():
	print("Set Status Effects function running")
	StatusEffectList.clear()


	if Current_Turn != null and Global.BattlerData.size() > 0:
		var entries: Array = []

		for item in Global.ACTIVE_STATUS_EFFECTS.values():
			if str(float(item.get("Entity_ID"))) == str(float(Global.Current_Battler_Data.get("id"))) and item.get("Entity_Type") == Global.Current_Battler_Data.get("type"):
				var status_effect: Dictionary = Global.STATUS_EFFECTS[str(float(item.get("Status_ID")))]
				var name: String = str(status_effect.get("Name", ""))
				var duration: int = int(item.get("Duration", 0))
				var description = str(status_effect.get("Description"))

				entries.append({
					"name": name,
					"duration": duration,
					"description": description,
					"status_effect": status_effect,
					"active_item": item
				})

		# Sort by shortest duration, then alphabetically by name
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var da: int = int(a.get("duration", 0))
			var db: int = int(b.get("duration", 0))

			if da != db:
				return da < db

			var na: String = str(a.get("name", "")).to_lower()
			var nb: String = str(b.get("name", "")).to_lower()
			return na < nb
		)

		# Add in sorted order
		for e in entries:
			StatusEffectList.add_item(str(str(e.get("duration"))+' - '+e.get("name", "")))
			var idx = StatusEffectList.get_item_count() - 1

			var desc = "Turns Left: " + str(e.get("duration")) + "\nName: "+e.get("name")+"\nDescription: " + str(e.get("description", ""))
			desc = _wrap_text(desc, 100)
			StatusEffectList.set_item_tooltip(idx, desc)

		if StatusEffectList.item_count == 0:
			StatusEffectList.add_item("None")



# --- Helper function for natural word wrapping ---
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
				end = start + space_index + 1  # include the space itself

		result += text.substr(start, end - start).strip_edges()
		if end < text.length():
			result += "\n"

		start = end

	return result
func set_background():
	var path = "res://Background Images/Player HUB/%s.jpg" % Global.Current_Region  # Adjust as needed

	if ResourceLoader.exists(path):
		var texture = load(path)
		background_image.texture = texture
	else:
		print("⚠️ Background image not found:", path)

func set_ui():
	assign_party()
	set_stats()
	#_check_ability_options()
	Mora.text = str(Global.Current_Party.get("Mora"))
	if Global.Current_Battler_Data != null:
		BurstChargeLabel.text = "Burst Charges: "+str(Global.Current_Battler_Data.get("burst_charges"))+"/"+str(Global.Current_Battler_Data.get("max_burst_charges"))
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






func _apply_stat(btn, key: String, val) -> void:
	var pd = Player_data
	btn.Stat = key
	btn.StatValue = val
	btn.AddedRoll        = pd.get("%s_Added_Roll_Bonus" % key, 0) \
						+ pd.get("%s_Manual_Roll_Added_Amount_Override" % key, 0) \
						+ pd.get("Universal_Added_Roll_Bonus")
	btn.MultipliedRoll  = 1 + pd.get("%s_Multiplier_Roll_Bonus" % key, 0.0) \
						  + pd.get("%s_Manual_Roll_Multiplier_Amount_Override" % key, 0.0)\
						+ pd.get("Universal_Multiplier_Roll_Bonus")
	btn.AddedDamage     = pd.get("%s_Added_Damage_Bonus" % key, 0) \
						+ pd.get("%s_Manual_Damage_Added_Amount_Override" % key, 0)\
						+ pd.get("Universal_Added_Damage_Bonus")
	btn.MultipliedDamage = 1 + pd.get("%s_Multiplier_Damage_Bonus" % key, 0.0) \
						   + pd.get("%s_Manual_Damage_Multiplier_Amount_Override" % key, 0.0)\
						+ pd.get("Universal_Multiplier_Damage_Bonus")

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

func _on_health_button_pressed() -> void:
	Selected_Stat = "Health"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	var s: PackedScene = preload("res://Scenes/stat_summary.tscn")
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
	dlg.update_stat_summary(Selected_Stat)
	pass # Replace with function body.

func _on_attack_button_pressed() -> void:
	Selected_Stat = "Attack"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	var s: PackedScene = preload("res://Scenes/stat_summary.tscn")
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
	dlg.update_stat_summary(Selected_Stat)
	pass # Replace with function body.

func _on_defense_button_pressed() -> void:
	Selected_Stat = "Defense"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	var s: PackedScene = preload("res://Scenes/stat_summary.tscn")
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
	dlg.update_stat_summary(Selected_Stat)
	pass # Replace with function body.

func _on_elemental_mastery_button_pressed() -> void:
	Selected_Stat = "Elemental_Mastery"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	var s: PackedScene = preload("res://Scenes/stat_summary.tscn")
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
	dlg.update_stat_summary(Selected_Stat)
	pass # Replace with function body.

func _on_energy_recharge_button_pressed() -> void:
	Selected_Stat = "Energy_Recharge"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	var s: PackedScene = preload("res://Scenes/stat_summary.tscn")
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
	dlg.update_stat_summary(Selected_Stat)
	pass # Replace with function body.

func _on_critical_damage_button_pressed() -> void:
	Selected_Stat = "Critical_Damage"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	var s: PackedScene = preload("res://Scenes/stat_summary.tscn")
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
	dlg.update_stat_summary(Selected_Stat)
	pass # Replace with function body.


func _on_weapon_button_pressed() -> void:
	print ("Weapon Button has been pressed")
	var s = preload("res://Scenes/weapon_detail_scene.tscn")
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



func _check_characters_update():
	if http.is_connected("request_completed", _on_check_characters_response):
		http.request_completed.disconnect(_on_check_characters_response)

	var url = Global.API_BASE+"/check_modified?nocache=" + str(Time.get_ticks_msec())
	http.request_completed.connect(_on_check_characters_response)
	http.request(url)


func _on_check_characters_response(result, code, headers, body):
	http.request_completed.disconnect(_on_check_characters_response)

	if code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json:
			var new_timestamp = json.get("modified", "")
			print("🧠 Flask returned timestamp:", new_timestamp)
			print("📦 Godot cached timestamp: ", last_known_characters_timestamp)
			if last_known_characters_timestamp == "":
				last_known_characters_timestamp = new_timestamp
			else:
				if new_timestamp != last_known_characters_timestamp:
					print("Characters table changed! Refreshing...")
					last_known_characters_timestamp = new_timestamp
					
					Global.Refresh_Data(["Characters"])
					# Optionally call scene refresh logic here



func _on_inventory_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/PlayerInventory.tscn")
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


func _on_talents_button_pressed() -> void:
	var s: PackedScene = preload("res://UI/Tabs.tscn")
	var dlg = s.instantiate()
	var win := Window.new()
	win.exclusive = true               # makes it modal, blocks hover/clicks
	win.transparent = true             # so only your dlg visuals show
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO
	dlg.TableType = "Talents"
	win.add_child(dlg)
	add_child(win)
	# Optional: center or full-rect dlg inside window
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass # Replace with function body.


func _on_constellations_button_pressed() -> void:
	var s: PackedScene = preload("res://UI/Tabs.tscn")
	var dlg = s.instantiate()
	var win := Window.new()
	win.exclusive = true               # makes it modal, blocks hover/clicks
	win.transparent = true             # so only your dlg visuals show
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO
	dlg.TableType = "Constellations"
	win.add_child(dlg)
	add_child(win)
	# Optional: center or full-rect dlg inside window
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass # Replace with function body.


func _on_abilities_button_pressed() -> void:
	var s: PackedScene = preload("res://UI/Tabs.tscn")
	var dlg = s.instantiate()
	var win := Window.new()
	win.exclusive = true               # makes it modal, blocks hover/clicks
	win.transparent = true             # so only your dlg visuals show
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO
	dlg.TableType = "Abilities"
	win.add_child(dlg)
	add_child(win)
	# Optional: center or full-rect dlg inside window
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass # Replace with function body.


func _on_bug_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/FeedbackPopup.tscn")
	var dlg = s.instantiate()
	dlg.position = Vector2(800,450)
	add_child(dlg)
	pass # Replace with function body.


func process_turn():
	var updates = []
	var processed_self_inflicted_status = false
	var spaces_moved: int = int(TilesMovedEdit.text)
	var burst_charges_gained: int = int(BurstChargesEdit.text)
	var attack_roll: int = int(AttackRollEdit.text)
	var passive_stacks_total: int = int(PassiveStacksEdit.text)

	var item_used_text: String = ItemUsedButton.get_item_text(ItemUsedButton.selected)      # e.g., "Healing Potion (Small)" or "None"
	var item_target_text: String = ItemUsedTarget.get_item_text(ItemUsedTarget.selected)     # "Self", "Nobody", or a name
	var attack_used_text: String = AttackUsedButton.get_item_text(AttackUsedButton.selected)   # "None" or actual skill/attack name
	var critical_hit: bool = CritBox.button_pressed

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
		var t_type: String = row.AttackType.get_item_text(row.AttackType.selected)        # "Damage" | "Heal" | "True Damage" | etc.
		var t_elem: String = row.AppliedElement.get_item_text(row.AppliedElement.selected)     # "None" | "Electric" | ...
		var t_killed: bool = row.KilledStatus.button_pressed
		var t_shield_hit: bool = row.ShieldHit.button_pressed
		var t_table = row.TargetTable
		var t_id = row.TargetID
		var t_reaction = false
		var t_current_element = "None"
		var t_effect_status_target = "self"
		var t_effect_status = 0
		var t_effect_status_duration = 0
		var t_entity_type
		
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
			t_damage = -t_raw_dmg  # represent healing as negative damage in the aggregate
			

		#Processes applying the Element to the Target and triggering the reaction if applicable.
		if t_elem != "None":
			elements_unique[t_elem] = true
			match t_table:
				"Characters":
					if Global.CHARACTERS[t_id].get("Applied_Element") == "None":
						updates.append({
							"table": "Characters",
							"record_id": float(t_id),
							"field": "Applied_Element",
							"value": t_elem})
					else:
						t_current_element = Global.CHARACTERS[t_id].get("Applied_Element")
						t_reaction = true
						updates.append({
							"table": "Characters",
							"record_id": float(t_id),
							"field": "Applied_Element",
							"value": "None"})
				"Companions":
					if Global.COMPANIONS[str(float(t_id))].get("AppliedElement") == "None":
						updates.append({
							"table": "Companions",
							"record_id": float(t_id),
							"field": "Applied_Element",
							"value": t_elem})
					else:
						t_current_element = Global.COMPANIONS[str(float(t_id))].get("AppliedElement")
						t_reaction = true
						updates.append({
							"table": "Companions",
							"record_id": float(t_id),
							"field": "Applied_Element",
							"value": "None"})
				"BattleEnemies":
					if Global.BATTLEENEMIES[str(float(t_id))].get("AppliedElement") == "None":
						updates.append({
							"table": "BattleEnemies",
							"record_id": float(t_id),
							"field": "AppliedElement",
							"value": t_elem})
					else:
						t_current_element = Global.BATTLEENEMIES[str(float(t_id))].get("AppliedElement")
						t_reaction = true
						updates.append({
							"table": "BattleEnemies",
							"record_id": float(t_id),
							"field": "AppliedElement",
							"value": "None"})

		# ----- HP / KO handling for this target -----
		var t_type_lower: String = t_type.to_lower()

		# Only process if we have a real target and a supported attack type
		# NOTE: includes "shielded" now.
		if t_table != null and t_id != null and t_type_lower in ["damage", "true damage", "healed", "shielded"]:
			var record_id: float = float(t_id)
			var row_data: Dictionary = {}
			var key: String = ""

			if t_table == "Characters":
				key = str(t_id)
				if Global.CHARACTERS.has(key):
					row_data = Global.CHARACTERS[key]
				elif Global.CHARACTERS.has(str(float(t_id))):
					key = str(float(t_id))
					row_data = Global.CHARACTERS[key]

			elif t_table == "Companions":
				key = str(float(t_id))
				if Global.COMPANIONS.has(key):
					row_data = Global.COMPANIONS[key]

			elif t_table == "BattleEnemies":
				key = str(float(t_id))
				if Global.BATTLEENEMIES.has(key):
					row_data = Global.BATTLEENEMIES[key]

			# If we actually found a row, apply the change
			if row_data.size() > 0:
				# ----------------------------
				# SHIELD GRANT (no HP change)
				# ----------------------------
				if t_type_lower == "shielded":
					var incoming_shield: int = int(t_raw_dmg)

					# Null-safe current shield read
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

					# Start with your existing model: positive = damage, negative = healing
					var hp_damage: int = t_damage

					# If this attack was flagged as hitting a shield, route DAMAGE through Shield_Health first.
					# Only applies to actual damage (positive). Healing should not consume shield.
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

								# No HP damage gets through
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
											# Set/refresh duration to 2 (or keep higher if you prefer)
											updates.append({
												"table": "Active_Status_Effects",
												"record_id": int(active_status.get("id")),
												"field": "Duration",
												"value": 2
											})
											break

									if not found_break:
										var cols_break = ["Entity_ID","Entity_Type","Status_ID","Duration"]
										var vals_break = [int(t_id), str(t_entity_type), 19, 2]
										Global.Insert("Active_Status_Effects", cols_break, vals_break)

								# Clear shield (set to null so your UI logic "not null and >0" turns off)
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

								# Only the overflow reaches HP
								hp_damage = overflow

					# Apply HP change (hp_damage is positive for damage, negative for heals)
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
							t_killed = true


		#Pulls in and assigns the moveslot data of the move that was selected/used this turn.
		if attack_used_text != "None":
			for ability in Global.Current_Battler_Data.get("entity_current_ability_data").values():
				if ability.get("name") == attack_used_text:
					Current_Battler_Selected_Move_Data = ability
					for move in Global.Current_Battler_Data.get("entity_current_active_ability_data").values():
						if move.get("Ability_ID") == ability.get("id"):
							Current_Battler_Selected_Move = move

		#Puts the ability on turned cooldown. 
		if Current_Battler_Selected_Move_Data:
			if Current_Battler_Selected_Move_Data.get("cooldown") > 0:
				updates.append({
					"table": "Active_Abilities",
					"record_id": float(Current_Battler_Selected_Move.get("id")),
					"field": "Ability_Cooldown",
					"value": Current_Battler_Selected_Move_Data.get("cooldown")})

			#Subtracts the burst charge cost of the move from their current burst charges.
			if Current_Battler_Selected_Move_Data.get("charge_cost") > 0:
				var old_value = Global.Current_Battler_Data.get("entity_data").get("Burst_Charges")
				var new_value = int(old_value-Current_Battler_Selected_Move_Data.get("charge_cost"))
				var table
				if new_value <= 0:
					new_value = 0
				match Global.Current_Battler_Data.get("type"):
					"Character":
						table = "Characters"
					"Companion":
						table = "Companions"
				updates.append({
					"table": table,
					"record_id": float(Global.Current_Battler_Data.get("id")),
					"field": "Burst_Charges",
					"value": new_value})

			# Checks if the used move applies a status condition, if so, applies that status.
			if int(Current_Battler_Selected_Move_Data.get("effect_status", 0)) > 0:
				if Current_Battler_Selected_Move_Data.get("effect_status_target") == "target":
					t_effect_status_target = Current_Battler_Selected_Move_Data.get("effect_status_target")
					t_effect_status = int(Current_Battler_Selected_Move_Data.get("effect_status"))
					t_effect_status_duration = int(Current_Battler_Selected_Move_Data.get("effect_status_duration", 0))

					var found_existing = false

					for active_status in Global.ACTIVE_STATUS_EFFECTS.values():
						if int(active_status.get("Status_ID", 0)) == t_effect_status \
						and str(active_status.get("Entity_Type")) == str(t_entity_type) \
						and int(active_status.get("Entity_ID", 0)) == int(t_id):

							found_existing = true

							updates.append({
								"table": "Active_Status_Effects",
								"record_id": int(active_status.get("id")),
								"field": "Duration",
								"value": int(t_effect_status_duration + 1)
							})
							break

					if not found_existing:
						var cols = ["Entity_ID","Entity_Type","Status_ID","Duration"]
						var vals = [int(t_id), str(t_entity_type), int(t_effect_status), int(t_effect_status_duration + 1)]
						Global.Insert("Active_Status_Effects", cols, vals)

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

	# ----- Item info (on self) -----
	var item_info: Dictionary = {
		"used": item_used_text != "None",
		"name": item_used_text,
		"target": item_target_text,
		# If you have a heal value field somewhere, include it (example assumes none):
	}

	#Adds Burst Charges Gained.
	if burst_charges_gained > 0:
		var highest_charge_cost = 0
		for ability in Global.Current_Battler_Data.get("entity_current_ability_data").values():
			if ability.get("charge_cost") > highest_charge_cost:
				highest_charge_cost = ability.get("charge_cost")
		var current_charges = Global.Current_Battler_Data.get("entity_data").get("Burst_Charges")
		if current_charges < highest_charge_cost:
			if current_charges + burst_charges_gained >= highest_charge_cost:
				match Global.Current_Battler_Data.get("type"):
					"Character":
						updates.append({
							"table": "Characters",
							"record_id": Global.Current_Battler_Data.get("id"),
							"field": "Burst_Charges",
							"value": highest_charge_cost})
					"Companion":
						updates.append({
							"table": "Companions",
							"record_id": Global.Current_Battler_Data.get("id"),
							"field": "Burst_Charges",
							"value": highest_charge_cost})
			else:
				var new_charge_amount = current_charges + burst_charges_gained
				match Global.Current_Battler_Data.get("type"):
					"Character":
						updates.append({
							"table": "Characters",
							"record_id": Global.Current_Battler_Data.get("id"),
							"field": "Burst_Charges",
							"value": new_charge_amount})
					"Companion":
						updates.append({
							"table": "Companions",
							"record_id": Global.Current_Battler_Data.get("id"),
							"field": "Burst_Charges",
							"value": new_charge_amount})
		pass

	# ----- Build single aggregated log -----
	var action_type: String = "Turn"                 # composite—item + attack(s) in one turn
	var action_name: String = attack_used_text       # keep the attack name the UI selected (or "None")

	var elements_applied: Array = elements_unique.keys()
	var status_changes: Dictionary = {
		"passive_stacks_total": passive_stacks_total,
		"killed_targets": killed_names
	}

	var rolls: Dictionary = {
		"player_attack": attack_roll,
		"critical": critical_hit
		# per-target rolls are inside misc.targets[]
	}

	var misc: Dictionary = {
		"spaces_moved": spaces_moved,
		"item": item_info,
		"targets": targets,           # full per-target breakdown lives here
		"attack_ui_type": "Composite" # optional tag for your analytics
	}

	# You can compute hp_before/after if you track it locally; 0 for now.
	var hp_before: int = 0
	var hp_after: int = 0

	#Subtract turn from Status Effects For This Entity.
	for entry in Global.ACTIVE_STATUS_EFFECTS.values():
		if entry.get("Entity_Type") == Global.Current_Battler_Data.get("type") and str(float(entry.get("Entity_ID"))) == str(float(Global.Current_Battler_Data.get("id"))):
			if int(entry.get("Duration"))-1 > 0:
				updates.append({
								"table": "Active_Status_Effects",
								"record_id": entry.get("id"),
								"field": "Duration",
								"value": int(entry.get("Duration"))-1})
			else:
				Global.Remove_Record("Active_Status_Effects",entry.get("id"))

	#Subtracts turn from Move Cooldowns for this Entity.
	for entry in Global.ACTIVE_ABILITIES.values():
		if entry.get("Entity_Type") == Global.Current_Battler_Data.get("type") and str(float(entry.get("Entity_ID"))) == str(float(Global.Current_Battler_Data.get("id"))) and entry.get("Ability_Cooldown") > 0:
			updates.append({
				"table": "Active_Abilities",
				"record_id": entry.get("id"),
				"field": "Ability_Cooldown",
				"value": int(entry.get("Ability_Cooldown"))-1})

	#Subtracts Item from inventory if used
	if item_used_text != "None":
		for entry in Global.CHARACTER_ITEMS.values():
			if entry.get("Owner") == Global.Current_Battler_Data.get("name") and entry.get("Name") == item_used_text:
				updates.append({
					"table": "Character_Items",
					"record_id": entry.get("id"),
					"field": "Quantity",
					"value": int(entry.get("Quantity"))-1})

	Global.CombatLog(
		battle_id,
		turn_no,
		"player_turn",
		Global.Current_Battler_Data.get("type"),
		Global.ACTIVE_USER_NAME,
		action_type,
		action_name,
		Global.ACTIVE_USER_NAME,       # target_id: primary target = self (item on self)
		false,                         # ignores_def at top-level; per-target stored in misc.targets[*].ignores_def
		rolls,
		total_damage,                  # aggregate of all per-target damage (heals negative)
		hp_before,
		hp_after,
		burst_charges_gained,          # energy_change for the turn
		elements_applied,              # unique elements applied across targets
		status_changes,
		misc
	)
	Global.Update_Records(updates)
	pass

func _on_end_turn_button_pressed() -> void:
	#self.visible = false
	process_turn()
	emit_signal("turn_ended")
	pass # Replace with function body.


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
			var id_num = float(id_str)
			row.TargetID = str(id_num)
			data = Global.BATTLEENEMIES[row.TargetID]
			if data.get("Shield_Health"):
				row.TargetShieldAmount = data.get("Shield_Health")
			else:
				row.TargetShieldAmount = 0
	pass # Replace with function body.


func _on_visibility_button_pressed() -> void:
	self.visible = false
	pass # Replace with function body.


func _on_visibility_changed() -> void:
	pass # Replace with function body.
