extends Node2D
@onready var background_image = $UI/BackgroundImage
var http: Node  # kept for compat, no longer used for HTTP



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
	set_ui()
	pass  # http node removed
	set_targets()
	set_attacks()
	set_items()
	set_status_effects()
	set_battle_id()
	#$UI/NameLabel.text = Global.ACTIVE_USER_NAME
	pass

func _process(delta: float) -> void: 
	if AttackUsedButton.has_selectable_items() == false:
		set_attacks()
	if ItemUsedButton.has_selectable_items() == false:
		set_items()
	if StatusEffectList.item_count == 0:
		set_status_effects()
	if battle_id == null:
		battle_id = Global.Current_Party.get("Active_Battle_ID")


func assign_party():
	for party in Global.PARTY.values():
		if party.get("Party_Member_1") == Global.ACTIVE_USER_NAME or party.get("Party_Member_2") == Global.ACTIVE_USER_NAME or party.get("Party_Member_3") == Global.ACTIVE_USER_NAME or party.get("Party_Member_4") == Global.ACTIVE_USER_NAME or party.get("Dungeon_Master") == Global.ACTIVE_USER_NAME:
			Global.Current_Party = party


func _on_data_load_complete():
	print("✅ Global data has finished loading!")
	assign_party()
	Current_Turn = Global.Current_Party.get("Current_Turn")
	check_current_turn_battler_status()
	set_ui()
	set_targets()
	set_attacks()
	set_items()
	set_status_effects()
	
	#await get_tree().create_timer(3.0).timeout
	pass  # polling removed — ENet sync
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
	for Enemy in Global.BATTLEENEMIES.values():
		var enemy_label = str(Enemy.get("EnemyName")) + " " + str(int(Enemy.get("id")))
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

				# Wrap long descriptions every 100 characters
				desc = _wrap_text(desc, 100)
				if cooldown == 0:
					AttackUsedButton.add_item(name)
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

func set_status_effects():
	print("Set Status Effects function running")

	if StatusEffectList.item_count > 0:
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



func _check_characters_update():
	# No longer polls HTTP — data updates arrive via ENet RPC
	pass


func _on_check_characters_response(_result, _code, _headers, _body):
	# Legacy callback — no longer used. Data sync handled by ENet.
	pass



func _on_bug_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/FeedbackPopup.tscn")
	var dlg = s.instantiate()
	dlg.position = Vector2(800,450)
	add_child(dlg)
	pass # Replace with function body.


func process_turn():
	var updates = []
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
		var t_table = row.TargetTable
		var t_id = row.TargetID
		var t_reaction = false
		var t_current_element = "None"
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
		if t_table != null and t_id != null and t_type_lower in ["damage", "true damage", "healed"]:
			var record_id: float = float(t_id)
			var row_data: Dictionary = {}
			var key: String = ""

			if t_table == "Characters":
				# Characters are keyed directly by t_id in your existing code
				key = str(t_id)
				if Global.CHARACTERS.has(key):
					row_data = Global.CHARACTERS[key]
				elif Global.CHARACTERS.has(str(float(t_id))):
					key = str(float(t_id))
					row_data = Global.CHARACTERS[key]

			elif t_table == "Companions":
				# BattleEnemies uses stringified float keys, like "128.0"
				key = str(float(t_id))
				if Global.COMPANIONS.has(key):
					row_data = Global.COMPANIONS[key]

			elif t_table == "BattleEnemies":
				# BattleEnemies uses stringified float keys, like "128.0"
				key = str(float(t_id))
				if Global.BATTLEENEMIES.has(key):
					row_data = Global.BATTLEENEMIES[key]

			# If we actually found a row, apply the HP change
			if row_data.size() > 0:
				var current_hp: int = int(row_data.get("Current_Health", 0))
				var max_hp: int = int(row_data.get("Max_Health", current_hp))

				# t_damage is positive for damage, negative for heals
				var new_hp: int = current_hp - t_damage

				# Clamp to [0, Max_Health]
				if new_hp > max_hp:
					new_hp = max_hp
				if new_hp < 0:
					new_hp = 0

				# Write HP update to DB
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
						t_killed = true  # ensure the log / killed_names reflect this

		#Pulls in and assigns the moveslot data of the move that was selected/used this turn.
		if attack_used_text != "None":
			for ability in Global.Current_Battler_Data.get("entity_current_ability_data").values():
				if ability.get("name") == attack_used_text:
					Current_Battler_Selected_Move_Data = ability
					for move in Global.Current_Battler_Data.get("entity_current_active_ability_data").values():
						if move.get("Ability_ID") == ability.get("id"):
							Current_Battler_Selected_Move = move

		# Checks if the used move applies a status condition, if so, applies that status.
		if int(Current_Battler_Selected_Move_Data.get("effect_status", 0)) > 0:
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


		#Puts the ability on turned cooldown. 
		if Current_Battler_Selected_Move_Data.get("cooldown") != 0:
			updates.append({
				"table": "Active_Abilities",
				"record_id": float(Current_Battler_Selected_Move.get("id")),
				"field": "Ability_Cooldown",
				"value": Current_Battler_Selected_Move_Data.get("cooldown")})

		#Subtracts the burst charge cost of the move from their current burst charges.
		if Current_Battler_Selected_Move_Data.get("charge_cost") != 0:
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

		if t_killed:
			killed_names.append(t_name)

		total_damage += t_damage

		targets.append({
			"name": t_name,
			"target_table": t_table,
			"target_id": t_id,
			"their_roll": t_def_roll,
			"hits": t_hits,
			"attack_type": t_type,
			"current_element": t_current_element,
			"applied_element": t_elem,
			"ignores_def": t_ignores_def,
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

	#Subtract turn from Status Effects For This Entity:
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
	await process_turn()

	emit_signal("turn_ended")
	pass # Replace with function body.


func _on_target_selection_multi_selected(index: int, selected: bool) -> void:

	for child in TargetList.get_children():
		child.queue_free()
	for item in TargetSelection.get_selected_items():
		var row = target_row_scene.instantiate()
		TargetList.add_child(row)
		row.NameLabel.text = TargetSelection.get_item_text(item)
		if Global.PartyCharacters.has(TargetSelection.get_item_text(item)):
			row.TargetTable = "Characters"
			row.TargetID = Global.CHARACTERS_NAME[TargetSelection.get_item_text(item)]
		elif Global.PartyCompanions.has(TargetSelection.get_item_text(item)):
			row.TargetTable = "Companions"
			row.TargetID = Global.COMPANIONS_NAME[TargetSelection.get_item_text(item)]
		else:
			row.TargetTable = "BattleEnemies"
			var parts = TargetSelection.get_item_text(item).split(" ")
			var id_str = parts[-1]
			var id_num = int(id_str)
			row.TargetID = id_num
	pass # Replace with function body.


func _on_visibility_button_pressed() -> void:
	self.visible = false
	pass # Replace with function body.


func _on_visibility_changed() -> void:
	pass # Replace with function body.
