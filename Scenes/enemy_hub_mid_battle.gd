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
var turn_no := 0
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

# =============================================================================
#  Lifecycle
# =============================================================================

func _ready() -> void:
	Current_Turn = Global.Current_Party.get("Current_Turn")
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	tree_exiting.connect(_disconnect_signals)
	print("[enemy_hub_mid_battle] _ready: setting up UI")
	set_ui()
	set_targets()
	set_attacks()
	set_items()
	set_status_effects()
	set_battle_id()

func _disconnect_signals() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if Global.is_connected("data_load_complete", handler):
		Global.disconnect("data_load_complete", handler)


func _process(_delta: float) -> void:
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
		if party.get("Party_Member_1") == Global.ACTIVE_USER_NAME \
		or party.get("Party_Member_2") == Global.ACTIVE_USER_NAME \
		or party.get("Party_Member_3") == Global.ACTIVE_USER_NAME \
		or party.get("Party_Member_4") == Global.ACTIVE_USER_NAME \
		or party.get("Dungeon_Master") == Global.ACTIVE_USER_NAME:
			Global.Current_Party = party


func _on_data_load_complete():
	print("Global data has finished loading!")
	assign_party()
	Current_Turn = Global.Current_Party.get("Current_Turn")
	check_current_turn_battler_status()
	set_ui()
	set_targets()
	set_attacks()
	set_items()
	set_status_effects()

	pass  # polling removed -- ENet sync
	if Global.PartyCharacters.has(Global.Current_Party.get("Current_Turn")):
		Turn_Type = "Character"
	elif Global.PartyCompanions.has(Global.Current_Party.get("Current_Turn")):
		Turn_Type = "Companion"
	else:
		Turn_Type = "Enemy"


func check_current_turn_battler_status():
	if Global.Current_Battler_Data != null:
		pass


# =============================================================================
#  Battle-ID management
# =============================================================================

func set_battle_id():
	if Global.PARTY.get("Active_Battle_ID") == null and Global.ACTIVE_USER_NAME == 'Dylan':
		var updates = []
		battle_id = CryptoKey.generate_scene_unique_id()
		updates.append({
			"table": "Party",
			"record_id": int(Global.Current_Party.get("id")),
			"field": "Active_Battle_ID",
			"value": battle_id})
		Global.Update_Records(updates)


# =============================================================================
#  Target selection UI
# =============================================================================

func set_targets():
	TargetSelection.clear()
	BattleScene = get_parent()
	Active_Party_With_Companions = Global.Current_Party.get("Turn_Order")
	for Companion in Global.COMPANIONS.values():
		if Companion.get("Active") == true:
			if not Active_Party_With_Companions.has(Companion.get("Name")):
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


# =============================================================================
#  Attack / Item / Status-Effect dropdown population
# =============================================================================

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
				var ability_id := int(item.get("Ability_ID"))
				var ability_res: AbilityData = GameDB.get_ability(ability_id)
				var cooldown = item.get("Ability_Cooldown")
				var ability_name := ability_res.name if ability_res else "Unnamed"
				var desc := ability_res.description if ability_res else ""

				desc = _wrap_text(desc, 100)
				if cooldown == 0:
					AttackUsedButton.add_item(ability_name)
				else:
					AttackUsedButton.add_item(ability_name + " - " + str(cooldown) + " Turns left.")
				var idx = AttackUsedButton.get_item_count() - 1
				if popup:
					popup.set_item_tooltip(idx, desc)
				if AttackUsedButton.get_item_text(idx) != "None" and AttackUsedButton.get_item_text(idx) != ability_name:
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
					if not item.get("Description").to_lower().contains("battle") \
					and not item.get("Description").to_lower().contains("material"):
						var item_name = str(item.get("Name"))
						ItemUsedButton.add_item(item_name)
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

		for key in Global.BattlerData.keys():
			ItemUsedTarget.add_item(key)
			var idx = ItemUsedTarget.get_item_count() - 1
			var desc = Global.BattlerData[key].get("type")
			if popup:
				popup.set_item_tooltip(idx, desc)


func set_status_effects():
	StatusEffectList.clear()

	var b_name = str(Current_Turn) if Current_Turn != null else ""
	var effects = Global.get_battler_effects(b_name)

	var entries: Array = []
	for fx in effects:
		var dur = fx.get("turns_remaining", 0)
		var dur_str = "perm" if dur == -1 else str(dur)
		var desc = fx.get("description", "")
		if desc == "":
			desc = "%s %s" % [fx.get("effect_type", ""), fx.get("effect_stat", "")]
		var stacks_str = ""
		if fx.get("stacks", 0) > 0:
			stacks_str = " [%d/%d]" % [fx.get("stacks"), fx.get("max_stacks", 0)]
		entries.append({
			"name": fx.get("source_name", "Unknown"),
			"duration": dur, "dur_str": dur_str,
			"description": desc, "source_type": fx.get("source_type", ""),
			"stacks_str": stacks_str, "effect_type": fx.get("effect_type", ""),
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
			e.get("dur_str"), e.get("stacks_str"), e.get("description")
		]
		StatusEffectList.set_item_tooltip(idx, _wrap_text(tip, 100))

	if StatusEffectList.item_count == 0:
		StatusEffectList.add_item("None")


# =============================================================================
#  Text wrapping helper
# =============================================================================

func _wrap_text(text: String, limit: int) -> String:
	var result = ""
	var start = 0
	while start < text.length():
		var end = min(start + limit, text.length())
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


# =============================================================================
#  Background / UI
# =============================================================================

func set_background():
	var path = "res://Background Images/Player HUB/%s.jpg" % Global.Current_Region
	if ResourceLoader.exists(path):
		var texture = load(path)
		background_image.texture = texture
	else:
		print("Background image not found: ", path)


func set_ui():
	assign_party()


func _check_characters_update():
	pass  # No longer polls HTTP -- data updates arrive via ENet RPC


func _on_check_characters_response(_result, _code, _headers, _body):
	pass  # Legacy callback -- no longer used. Data sync handled by ENet.


func _on_bug_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/FeedbackPopup.tscn")
	var dlg = s.instantiate()
	dlg.position = Vector2(800, 450)
	add_child(dlg)


# =============================================================================
#  Turn processing -- main entry point
# =============================================================================

func process_turn():
	var updates := []
	var spaces_moved: int = int(TilesMovedEdit.text)
	var burst_charges_gained: int = int(BurstChargesEdit.text)
	var attack_roll: int = int(AttackRollEdit.text)
	var passive_stacks_total: int = int(PassiveStacksEdit.text)

	var item_used_text: String = ItemUsedButton.get_item_text(ItemUsedButton.selected)
	var item_target_text: String = ItemUsedTarget.get_item_text(ItemUsedTarget.selected)
	var attack_used_text: String = AttackUsedButton.get_item_text(AttackUsedButton.selected)
	var critical_hit: bool = CritBox.button_pressed
	var battler_name: String = str(Current_Turn) if Current_Turn != null else ""

	# ----- Turn start effects (host only) -----
	if NetworkManager.is_host and Global.effect_processor and battler_name != "":
		var start_ctx = {}
		if Global.Current_Battler_Data:
			start_ctx = {
				"current_health": Global.Current_Battler_Data.get("current_health", 0),
				"max_health": Global.Current_Battler_Data.get("max_health", 0),
				"burst_charges": Global.Current_Battler_Data.get("burst_charges", 0),
			}
		var _start_actions = Global.effect_processor.on_turn_start(battler_name, start_ctx)

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
		var t_table = row.TargetTable
		var t_id = row.TargetID
		var t_reaction = false
		var t_current_element = "None"
		var t_effect_status = 0
		var t_effect_status_duration = 0
		var t_entity_type: String

		match t_table:
			"Characters":
				t_entity_type = "Character"
			"Companions":
				t_entity_type = "Companion"
			"BattleEnemies":
				t_entity_type = "Enemy"
			_:
				t_entity_type = ""

		var t_ignores_def: bool = t_type.to_lower() in ["true damage", "pierce", "ignore def"]
		var t_damage: int = t_raw_dmg
		if t_type.to_lower() == "healed":
			t_damage = -t_raw_dmg

		# -- Element application --
		if t_elem != "None":
			elements_unique[t_elem] = true
			_apply_element(t_table, t_id, t_elem, updates)
			var _record := _get_target_record(t_table, t_id)
			if _record.size() > 0:
				var elem_field := "Applied_Element" if t_table in ["Characters", "Companions"] else "AppliedElement"
				for u in updates:
					if u.get("table") == t_table and u.get("record_id") == int(t_id) \
					and u.get("field") == elem_field and u.get("value") == "None":
						t_reaction = true
						t_current_element = _record.get(elem_field, "None")
						break

			# --- Reaction effects (host only) ---
			if t_reaction and NetworkManager.is_host and Global.effect_processor and battler_name != "":
				var react_ctx = {"reaction_element": t_current_element, "attack_element": t_elem, "element": t_elem, "is_crit": critical_hit}
				var react_actions = Global.effect_processor.process_trigger(battler_name, "ON_REACTION", react_ctx)
				for act in react_actions:
					if act.get("effect_type") == "FLAT_DAMAGE":
						t_damage += int(act.get("value", 0))
					elif act.get("effect_type") == "PERCENT_DAMAGE":
						t_damage = int(t_damage * act.get("value", 1.0))

		# --- Damage modifiers from effects (host only) ---
		if NetworkManager.is_host and Global.effect_processor and battler_name != "" and t_damage > 0:
			var hit_ctx = {"attack_type": t_type, "element": t_elem, "is_crit": critical_hit, "target_element": t_current_element}
			var flat_mod = Global.effect_processor.sum_flat_damage(battler_name, "ON_HIT", hit_ctx)
			var mult_mod = Global.effect_processor.damage_multiplier(battler_name, "ON_HIT", hit_ctx)
			if critical_hit:
				flat_mod += Global.effect_processor.sum_flat_damage(battler_name, "ON_CRIT", hit_ctx)
				mult_mod *= Global.effect_processor.damage_multiplier(battler_name, "ON_CRIT", hit_ctx)
			t_damage = int((t_damage + flat_mod) * mult_mod)

		# -- HP / KO handling --
		var t_type_lower: String = t_type.to_lower()
		if t_table != null and t_id != null and t_type_lower in ["damage", "true damage", "healed"]:
			var record_id: int = int(t_id)
			var row_data: Dictionary = _get_target_record(t_table, t_id)

			if row_data.size() > 0:
				_resolve_damage(row_data, t_table, t_id, t_type, t_damage, record_id, updates)

				# Check if killed (HP reached 0 from damage)
				if int(row_data.get("Current_Health", 0)) == 0 and t_type_lower in ["damage", "true damage"]:
					t_killed = true

		# -- Move selection & status application --
		if attack_used_text != "None":
			for ability in Global.Current_Battler_Data.get("entity_current_ability_data").values():
				if ability.get("name") == attack_used_text:
					Current_Battler_Selected_Move_Data = ability
					for move in Global.Current_Battler_Data.get("entity_current_active_ability_data").values():
						if int(move.get("Ability_ID")) == int(ability.get("id")):
							Current_Battler_Selected_Move = move

		# Apply status effect to target via EffectProcessor
		if Current_Battler_Selected_Move_Data != null \
		and int(Current_Battler_Selected_Move_Data.get("effect_status", 0)) > 0:
			t_effect_status = int(Current_Battler_Selected_Move_Data.get("effect_status"))
			t_effect_status_duration = int(Current_Battler_Selected_Move_Data.get("effect_status_duration", 0))

			if NetworkManager.is_host and Global.effect_processor:
				var status_data = GameDB.status_effects.get(t_effect_status, null)
				var status_name = status_data.name if status_data else "Status_%d" % t_effect_status
				var status_effects = StatusEffectsMap.get_effects(status_name)
				for eff in status_effects:
					if eff.duration == 0:
						eff.duration = t_effect_status_duration + 1
					Global.effect_processor.add_effect(t_name, eff, "status", status_name)

		# -- Ability cooldown --
		if Current_Battler_Selected_Move_Data != null \
		and Current_Battler_Selected_Move_Data.get("cooldown") != 0:
			updates.append({
				"table": "Active_Abilities",
				"record_id": int(Current_Battler_Selected_Move.get("id")),
				"field": "Ability_Cooldown",
				"value": Current_Battler_Selected_Move_Data.get("cooldown")})

		# -- Burst charge cost subtraction --
		if Current_Battler_Selected_Move_Data != null \
		and Current_Battler_Selected_Move_Data.get("charge_cost") != 0:
			var old_value = Global.Current_Battler_Data.get("entity_data").get("Burst_Charges")
			var new_value = int(old_value - Current_Battler_Selected_Move_Data.get("charge_cost"))
			if new_value <= 0:
				new_value = 0
			var table: String
			match Global.Current_Battler_Data.get("type"):
				"Character":
					table = "Characters"
				"Companion":
					table = "Companions"
			updates.append({
				"table": table,
				"record_id": int(Global.Current_Battler_Data.get("id")),
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

	# ----- Item info -----
	var item_info: Dictionary = {
		"used": item_used_text != "None",
		"name": item_used_text,
		"target": item_target_text,
	}

	# ----- Burst charges gained -----
	if burst_charges_gained > 0:
		_gain_burst_charges(burst_charges_gained, updates)

	# ----- Cooldowns & status effect tick-down -----
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



# =============================================================================
#  Helper: get target record from the appropriate Global table
# =============================================================================

func _get_target_record(t_table: String, t_id) -> Dictionary:
	var key: String = str(int(t_id))
	match t_table:
		"Characters":
			return Global.CHARACTERS.get(key, {})
		"Companions":
			return Global.COMPANIONS.get(key, {})
		"BattleEnemies":
			return Global.BATTLEENEMIES.get(key, {})
	return {}


# =============================================================================
#  Helper: apply element to a target (or trigger reaction)
# =============================================================================

func _apply_element(t_table: String, t_id, t_elem: String, updates: Array) -> void:
	var record_id := int(t_id)
	match t_table:
		"Characters":
			if Global.CHARACTERS[str(record_id)].get("Applied_Element") == "None":
				updates.append({
					"table": "Characters",
					"record_id": record_id,
					"field": "Applied_Element",
					"value": t_elem})
			else:
				updates.append({
					"table": "Characters",
					"record_id": record_id,
					"field": "Applied_Element",
					"value": "None"})
		"Companions":
			if Global.COMPANIONS.get(str(record_id), {}).get("Applied_Element", "None") == "None":
				updates.append({
					"table": "Companions",
					"record_id": record_id,
					"field": "Applied_Element",
					"value": t_elem})
			else:
				updates.append({
					"table": "Companions",
					"record_id": record_id,
					"field": "Applied_Element",
					"value": "None"})
		"BattleEnemies":
			if Global.BATTLEENEMIES[str(record_id)].get("AppliedElement") == "None":
				updates.append({
					"table": "BattleEnemies",
					"record_id": record_id,
					"field": "AppliedElement",
					"value": t_elem})
			else:
				updates.append({
					"table": "BattleEnemies",
					"record_id": record_id,
					"field": "AppliedElement",
					"value": "None"})


# =============================================================================
#  Helper: resolve HP damage/heal on a target
# =============================================================================

func _resolve_damage(row_data: Dictionary, t_table: String, t_id, t_type: String, t_damage: int, record_id: int, updates: Array) -> void:
	var current_hp: int = int(row_data.get("Current_Health", 0))
	var max_hp: int = int(row_data.get("Max_Health", current_hp))

	# t_damage is positive for damage, negative for heals
	var new_hp: int = current_hp - t_damage

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

	# If HP hit 0 from damage, mark as Skipped (and Killed for enemies)
	var t_type_lower := t_type.to_lower()
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


# =============================================================================
#  Helper: tick down cooldowns and status effect durations for current battler
# =============================================================================

func _process_cooldowns_and_status(updates: Array) -> void:
	var b_name = str(Current_Turn) if Current_Turn != null else ""
	var battler_type: String = Global.Current_Battler_Data.get("type") if Global.Current_Battler_Data else ""
	var battler_id: int = int(Global.Current_Battler_Data.get("id")) if Global.Current_Battler_Data else 0

	# Tick effect durations via processor (host only)
	if NetworkManager.is_host and Global.effect_processor and b_name != "":
		Global.effect_processor.on_turn_end(b_name)
		Global.sync_active_effects()

	# Subtract 1 turn from ability cooldowns (kept separate from effects)
	for entry in Global.ACTIVE_ABILITIES.values():
		if entry.get("Entity_Type") == battler_type \
		and int(entry.get("Entity_ID")) == battler_id \
		and entry.get("Ability_Cooldown") > 0:
			updates.append({
				"table": "Active_Abilities",
				"record_id": int(entry.get("id")),
				"field": "Ability_Cooldown",
				"value": int(entry.get("Ability_Cooldown")) - 1})


# =============================================================================
#  Helper: consume an item from the current battler's inventory
# =============================================================================

func _consume_item(item_name: String, updates: Array) -> void:
	for entry in Global.CHARACTER_ITEMS.values():
		if entry.get("Owner") == Global.Current_Battler_Data.get("name") \
		and entry.get("Name") == item_name:
			updates.append({
				"table": "Character_Items",
				"record_id": int(entry.get("id")),
				"field": "Quantity",
				"value": int(entry.get("Quantity")) - 1})


# =============================================================================
#  Helper: add burst charges (capped at highest charge cost)
# =============================================================================

func _gain_burst_charges(burst_charges_gained: int, updates: Array) -> void:
	var highest_charge_cost = 0
	for ability in Global.Current_Battler_Data.get("entity_current_ability_data").values():
		if ability.get("charge_cost") > highest_charge_cost:
			highest_charge_cost = ability.get("charge_cost")

	var current_charges = Global.Current_Battler_Data.get("entity_data").get("Burst_Charges")
	if current_charges < highest_charge_cost:
		var new_charge_amount: int
		if current_charges + burst_charges_gained >= highest_charge_cost:
			new_charge_amount = highest_charge_cost
		else:
			new_charge_amount = current_charges + burst_charges_gained

		var table: String
		match Global.Current_Battler_Data.get("type"):
			"Character":
				table = "Characters"
			"Companion":
				table = "Companions"
		updates.append({
			"table": table,
			"record_id": int(Global.Current_Battler_Data.get("id")),
			"field": "Burst_Charges",
			"value": new_charge_amount})


# =============================================================================
#  Button / signal handlers
# =============================================================================

func _on_end_turn_button_pressed() -> void:
	await process_turn()
	emit_signal("turn_ended")


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
			row.TargetID = int(id_str)


func _on_visibility_button_pressed() -> void:
	self.visible = false


func _on_visibility_changed() -> void:
	pass
