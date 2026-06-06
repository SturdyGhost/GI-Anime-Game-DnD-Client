class_name TurnProcessor
extends RefCounted
## Pure-data turn processor. No UI, no nodes.
## Takes an input dictionary, reads from Global data, returns an updates array.


## Process a complete turn. Returns Array of update dicts for Global.Update_Records().
static func process_turn(input: Dictionary) -> Array:
	var updates: Array = []

	var battler_name: String = str(input.get("battler_name", ""))
	var attack_used: String = str(input.get("attack_used", "None"))
	var attack_roll: int = int(input.get("attack_roll", 0))
	var tiles_moved: int = int(input.get("tiles_moved", 0))
	var burst_gained: int = int(input.get("burst_gained", 0))
	var passive_stacks: int = int(input.get("passive_stacks", 0))
	var critical_hit: bool = input.get("critical_hit", false)
	var item_used: String = str(input.get("item_used", "None"))
	var item_target: String = str(input.get("item_target", "None"))
	var targets: Array = input.get("targets", [])
	var battle_id = input.get("battle_id")
	var turn_no: int = int(input.get("turn_no", 0))

	# ── 1. Validate ──────────────────────────────────────────────────────────
	if not Global.BattlerData.has(battler_name):
		push_warning("TurnProcessor: battler_name '%s' not found in BattlerData" % battler_name)
		return []

	var battler_data: Dictionary = Global.BattlerData[battler_name]
	print("[TurnProcessor] Processing turn for '%s', attack='%s', targets=%d" % [battler_name, attack_used, targets.size()])

	# ── 2. Lookup ability ────────────────────────────────────────────────────
	var ability_data: Dictionary = {}  # The ability definition dict from entity_current_ability_data
	var active_ability_record: Dictionary = {}  # The Active_Abilities row
	var ability_res: AbilityData = null  # The typed resource from GameDB
	var ability_element: String = "Physical"

	if attack_used != "None":
		for ability in battler_data.get("entity_current_ability_data", {}).values():
			if str(ability.get("name", "")) == attack_used:
				ability_data = ability
				var aid = ability.get("id")
				if aid != null:
					ability_res = GameDB.get_ability(int(aid))
				# Find matching Active_Abilities record
				for aa in battler_data.get("entity_current_active_ability_data", {}).values():
					var m_aid = aa.get("Ability_ID")
					var a_id = ability.get("id")
					if m_aid != null and a_id != null and int(m_aid) == int(a_id):
						active_ability_record = aa
				break
		if ability_res:
			ability_element = str(ability_res.element) if ability_res.element != "" else "Physical"
		elif not ability_data.is_empty():
			ability_element = str(ability_data.get("element", "Physical"))

	# ── 3. Turn start effects (host only) ────────────────────────────────────
	if NetworkManager.is_host and Global.effect_processor and battler_name != "":
		var start_ctx: Dictionary = {
			"current_health": battler_data.get("current_health", 0),
			"max_health": battler_data.get("max_health", 0),
			"burst_charges": battler_data.get("burst_charges", 0),
		}
		var _start_actions = Global.effect_processor.on_turn_start(battler_name, start_ctx)

	# ── 4. Process each target ───────────────────────────────────────────────
	var total_damage: int = 0
	var killed_names: Array = []
	var elements_unique: Dictionary = {}

	for t in targets:
		var t_name: String = str(t.get("name", ""))
		var t_table: String = str(t.get("table", ""))
		var t_id = t.get("record_id")
		var t_def_roll: int = int(t.get("defense_roll", 0))
		var t_hits: int = int(t.get("hits", 0))
		var t_raw_dmg: int = int(t.get("raw_damage", 0))
		var t_type: String = str(t.get("attack_type", "Damage"))
		var t_killed: bool = t.get("killed", false)
		var t_shield_hit: bool = t.get("shield_hit", false)
		var t_damage: int = t_raw_dmg
		var t_reaction: bool = false
		var t_current_element: String = "None"

		var t_entity_type: String = ""
		match t_table:
			"Characters": t_entity_type = "Character"
			"Companions": t_entity_type = "Companion"
			"BattleEnemies": t_entity_type = "Enemy"

		if t_type.to_lower() == "healed":
			t_damage = -t_raw_dmg

		# ── 4a. Get ability element and apply ────────────────────────────────
		var t_elem: String = "None"
		if ability_element != "Physical" and ability_element != "None" and ability_element != "":
			t_elem = ability_element

		# ── 4b. Element application ──────────────────────────────────────────
		if t_elem != "None":
			elements_unique[t_elem] = true
			var elem_result = _apply_element(t_table, t_id, t_elem, updates)
			t_reaction = elem_result.get("reaction", false)
			t_current_element = elem_result.get("current_element", "None")

		# ── 4c. Reaction effects (host only) ─────────────────────────────────
		if t_reaction and NetworkManager.is_host and Global.effect_processor and battler_name != "":
			var react_ctx: Dictionary = {
				"reaction_element": t_current_element,
				"attack_element": t_elem,
				"element": t_elem,
				"is_crit": critical_hit,
			}
			var react_actions = Global.effect_processor.process_trigger(battler_name, "ON_REACTION", react_ctx)
			for act in react_actions:
				if act.get("effect_type") == "FLAT_DAMAGE":
					t_damage += int(act.get("value", 0))
				elif act.get("effect_type") == "PERCENT_DAMAGE":
					t_damage = int(t_damage * act.get("value", 1.0))

		# ── 4d. Damage modifiers from ON_HIT / ON_CRIT (host only) ──────────
		if NetworkManager.is_host and Global.effect_processor and battler_name != "" and t_damage > 0:
			var hit_ctx: Dictionary = {
				"attack_type": t_type,
				"element": t_elem,
				"is_crit": critical_hit,
				"target_element": t_current_element,
			}
			var flat_mod: float = Global.effect_processor.sum_flat_damage(battler_name, "ON_HIT", hit_ctx)
			var mult_mod: float = Global.effect_processor.damage_multiplier(battler_name, "ON_HIT", hit_ctx)
			if critical_hit:
				flat_mod += Global.effect_processor.sum_flat_damage(battler_name, "ON_CRIT", hit_ctx)
				mult_mod *= Global.effect_processor.damage_multiplier(battler_name, "ON_CRIT", hit_ctx)
			t_damage = int((t_damage + flat_mod) * mult_mod)

		# ── 4e. Resolve HP / shield ──────────────────────────────────────────
		var t_type_lower: String = t_type.to_lower()
		if t_table != "" and t_id != null and str(t_id) != "" and t_type_lower in ["damage", "true damage", "healed", "shielded"]:
			var record_id: int = int(t_id) if t_id != null else 0
			var key: String = str(record_id)
			var row_data: Dictionary = {}

			if t_table == "Characters":
				row_data = Global.CHARACTERS.get(key, {})
			elif t_table == "Companions":
				row_data = Global.COMPANIONS.get(key, {})
			elif t_table == "BattleEnemies":
				row_data = Global.BATTLEENEMIES.get(key, {})

			if row_data.size() > 0:
				var damage_result = _resolve_damage(row_data, t_table, t_id, t_type, t_damage, record_id, t_entity_type, t_shield_hit, updates)
				t_killed = damage_result.get("killed", t_killed)

		# ── 4f. Track killed and damage ──────────────────────────────────────
		if t_killed:
			killed_names.append(t_name)
		total_damage += t_damage

	# ── 5. Fire ability effects (host only) ──────────────────────────────────
	if attack_used != "None" and NetworkManager.is_host and Global.effect_processor:
		if ability_res and ability_res.effects.size() > 0:
			var atype_str: String = str(active_ability_record.get("Ability_Type", "")) if not active_ability_record.is_empty() else ""
			var use_trigger: String = ""
			match atype_str.to_lower():
				"skill": use_trigger = "ON_SKILL_USE"
				"burst": use_trigger = "ON_BURST_USE"
				_: use_trigger = "ON_HIT"

			# If the ability also has effect_status, skip status-type effects here
			# to avoid double-application (step 8 handles those for all targets)
			var has_status_effect: bool = ability_data.get("effect_status", 0) != null and int(ability_data.get("effect_status", 0)) > 0
			var skip_types: Array = ["SKIP_TURN", "STUN", "FREEZE", "ROOT", "BLIND",
				"SLOW", "DISARM", "FEAR", "TAUNT", "ROLL_ADVANTAGE", "ROLL_DISADVANTAGE"]

			for eff in ability_res.effects:
				if eff.trigger in ["PASSIVE", "START_OF_TURN", "END_OF_TURN"]:
					continue
				# Skip status-type effects if the ability will apply them via step 8
				if has_status_effect and eff.effect_type in skip_types:
					continue
				if eff.trigger == use_trigger or eff.trigger == "ON_HIT":
					# Duplicate so we don't mutate the shared resource
					var eff_copy = eff.duplicate()
					if eff.target == "ALL_ENEMIES":
						for t_entry in targets:
							var fx_name = str(t_entry.get("name", battler_name))
							Global.effect_processor.add_effect(fx_name, eff_copy, "ability", ability_res.name)
							_apply_immediate_effect(eff_copy, fx_name, updates)
					elif eff.target == "TARGET":
						# Apply to ALL targets, not just the first one
						for t_entry in targets:
							var fx_name = str(t_entry.get("name", battler_name))
							Global.effect_processor.add_effect(fx_name, eff_copy.duplicate(), "ability", ability_res.name)
							_apply_immediate_effect(eff_copy, fx_name, updates)
					else:
						var fx_target_name: String = battler_name
						Global.effect_processor.add_effect(fx_target_name, eff_copy, "ability", ability_res.name)
						_apply_immediate_effect(eff_copy, fx_target_name, updates)

		# Also check legacy AbilityEffects
		var aid_val = ability_data.get("id")
		if aid_val != null:
			for eff in AbilityEffects.get_effects(int(aid_val)):
				if eff.trigger in ["PASSIVE", "START_OF_TURN", "END_OF_TURN"]:
					continue
				var atype_str2: String = str(active_ability_record.get("Ability_Type", "")) if not active_ability_record.is_empty() else ""
				var use_trigger2: String = ""
				match atype_str2.to_lower():
					"skill": use_trigger2 = "ON_SKILL_USE"
					"burst": use_trigger2 = "ON_BURST_USE"
					_: use_trigger2 = "ON_HIT"
				if eff.trigger == use_trigger2 or eff.trigger == "ON_HIT":
					var fx_target_name2: String = battler_name if eff.target == "SELF" else (str(targets[0].get("name", battler_name)) if targets.size() > 0 else battler_name)
					Global.effect_processor.add_effect(fx_target_name2, eff, "ability", ability_res.name if ability_res else attack_used)
					_apply_immediate_effect(eff, fx_target_name2, updates)

	# ── 6. Put ability on cooldown ───────────────────────────────────────────
	# Host-authoritative: remaining cooldown lives in BattleManager (keyed by the
	# stable .tres ability id), not the Active_Abilities table. The actual set
	# happens AFTER _process_cooldowns (step 8) so the just-used ability starts at
	# its full duration and isn't decremented this turn.

	# ── 7. Subtract burst charge cost ────────────────────────────────────────
	if not ability_data.is_empty() and ability_data.get("charge_cost", 0) > 0:
		var old_value = battler_data.get("entity_data", {}).get("Burst_Charges")
		if old_value == null:
			old_value = 0
		var charge_cost_val = int(ability_data.get("charge_cost", 0))
		var new_value: int = maxi(int(old_value) - charge_cost_val, 0)
		var table: String = ""
		match battler_data.get("type"):
			"Character": table = "Characters"
			"Companion": table = "Companions"
		if table != "":
			updates.append({
				"table": table,
				"record_id": int(battler_data.get("id", 0)),
				"field": "Burst_Charges",
				"value": new_value,
			})

	# ── 8. Apply status effects from ability ─────────────────────────────────
	if not ability_data.is_empty() and NetworkManager.is_host and Global.effect_processor:
		var raw_es = ability_data.get("effect_status", 0)
		if raw_es != null and int(raw_es) > 0:
			var t_effect_status: int = int(raw_es)
			var raw_dur = ability_data.get("effect_status_duration_rounds", 0)
			var t_effect_status_duration: int = int(raw_dur) if raw_dur != null else 0
			var t_effect_status_target: String = str(ability_data.get("effect_status_target", "target"))

			var status_data = GameDB.status_effects.get(t_effect_status, null)
			var status_name: String = status_data.name if status_data else "Status_%d" % t_effect_status
			var status_effects: Array = StatusEffectsMap.get_effects(status_name)

			# Build list of who gets the effect
			var effect_targets: Array = []
			if t_effect_status_target == "self":
				effect_targets.append(battler_name)
			else:
				# Apply to ALL selected targets, not just the first
				for t_entry in targets:
					var tname = str(t_entry.get("name", ""))
					if tname != "" and not effect_targets.has(tname):
						effect_targets.append(tname)
				if effect_targets.is_empty():
					effect_targets.append(battler_name)

			for effect_target_name in effect_targets:
				for eff in status_effects:
					var eff_copy = eff.duplicate()
					# Always use the ability's specified duration if provided
					if t_effect_status_duration > 0:
						eff_copy.duration = t_effect_status_duration
					elif eff_copy.duration == 0:
						eff_copy.duration = 1  # minimum 1 turn if nothing specified
					Global.effect_processor.add_effect(effect_target_name, eff_copy, "status", status_name)
				print("[TurnProcessor] Applied status '%s' to %s for %d turns" % [status_name, effect_target_name, t_effect_status_duration])

	# ── 9. Consume item ──────────────────────────────────────────────────────
	if item_used != "None":
		_consume_item(item_used, battler_name, updates)

	# ── 10. Gain burst charges ───────────────────────────────────────────────
	# Account for burst cost already subtracted in step 7 so we don't overwrite it
	if burst_gained > 0:
		var cost_already_subtracted: int = 0
		if not ability_data.is_empty():
			cost_already_subtracted = int(ability_data.get("charge_cost", 0))
		_gain_burst_charges(battler_name, burst_gained, updates, cost_already_subtracted)

	# ── 11. Process cooldowns ────────────────────────────────────────────────
	# Tick the acting battler's existing cooldowns down first...
	_process_cooldowns(battler_name, updates)
	# ...THEN put the just-used ability on cooldown at its full static duration, so
	# it isn't decremented this turn (matches end-of-own-turn semantics).
	if not ability_data.is_empty() and int(ability_data.get("cooldown", 0)) > 0:
		BattleManager.put_on_cooldown(battler_name, int(ability_data.get("id", 0)), int(ability_data.get("cooldown", 0)))

	# ── 12. Combat log ───────────────────────────────────────────────────────
	var elements_applied: Array = elements_unique.keys()
	var status_changes: Dictionary = {
		"passive_stacks_total": passive_stacks,
		"killed_targets": killed_names,
	}
	var rolls: Dictionary = {
		"player_attack": attack_roll,
		"critical": critical_hit,
	}
	var misc: Dictionary = {
		"spaces_moved": tiles_moved,
		"item": {"used": item_used != "None", "name": item_used, "target": item_target},
		"attack_ui_type": "Composite",
	}

	Global.CombatLog(
		battle_id, turn_no, "player_turn",
		battler_data.get("type", ""),
		Global.ACTIVE_USER_NAME,
		"Turn", attack_used,
		Global.ACTIVE_USER_NAME,
		false, rolls,
		total_damage, 0, 0,
		burst_gained, elements_applied,
		status_changes, misc
	)

	# ── 13. Return updates ───────────────────────────────────────────────────
	print("[TurnProcessor] Turn complete: %d updates generated" % updates.size())
	return updates


# =============================================================================
#  Helper Methods
# =============================================================================


## Apply element to a target. Returns { "reaction": bool, "current_element": String }.
## Rules:
##   - No element applied     -> apply the incoming element.
##   - SAME element applied    -> keep it; no reaction, no change.
##   - DIFFERENT element       -> reaction; the existing element is consumed (cleared).
## CRITICAL: Characters/Companions use "Applied_Element", BattleEnemies uses "AppliedElement".
static func _apply_element(t_table: String, t_id, t_elem: String, updates: Array) -> Dictionary:
	var result = {"reaction": false, "current_element": "None"}

	var field: String
	var rec: Dictionary
	var key: String = str(t_id)
	match t_table:
		"Characters":
			field = "Applied_Element"
			rec = Global.CHARACTERS.get(key, {})
		"Companions":
			field = "Applied_Element"
			rec = Global.COMPANIONS.get(key, {})
		"BattleEnemies":
			field = "AppliedElement"
			rec = Global.BATTLEENEMIES.get(key, {})
		_:
			return result

	var current: String = str(rec.get(field, "None"))

	if current == "None":
		# Nothing applied yet — apply the incoming element.
		updates.append({"table": t_table, "record_id": int(t_id), "field": field, "value": t_elem})
	elif current == t_elem:
		# Same element re-applied — it persists, no reaction, no state change.
		result["current_element"] = current
	else:
		# Different element — reaction; the existing element is consumed.
		result["current_element"] = current
		result["reaction"] = true
		updates.append({"table": t_table, "record_id": int(t_id), "field": field, "value": "None"})

	return result


## Handle HP changes, shield absorption, shield break, and KO logic.
## Returns { "killed": bool }.
static func _resolve_damage(row_data: Dictionary, t_table: String, t_id, t_type: String, t_damage: int, record_id: int, t_entity_type: String, t_shield_hit: bool, updates: Array) -> Dictionary:
	var result = {"killed": false}
	var t_type_lower: String = t_type.to_lower()

	# ── Shield grant (no HP change) ──────────────────────────────────────────
	if t_type_lower == "shielded":
		var incoming_shield: int = abs(t_damage)
		updates.append({
			"table": t_table,
			"record_id": record_id,
			"field": "Shield_Health",
			"value": incoming_shield,
		})
		row_data["Shield_Health"] = incoming_shield
		updates.append({
			"table": t_table,
			"record_id": record_id,
			"field": "Shield_Duration",
			"value": 4,
		})
		row_data["Shield_Duration"] = 4

	else:
		# ── Damage / Heal (with optional shield-hit routing) ─────────────────
		var current_hp: int = int(row_data.get("Current_Health", 0))
		var max_hp: int = int(row_data.get("Max_Health", current_hp))
		var hp_damage: int = t_damage

		# Route damage through shield if flagged
		if t_shield_hit and hp_damage > 0:
			var sh_val = row_data.get("Shield_Health")
			var cur_shield: int = 0
			if sh_val != null:
				cur_shield = int(sh_val)

			if cur_shield > 0:
				if hp_damage <= cur_shield:
					# Shield absorbs all incoming damage
					var remaining_shield: int = cur_shield - hp_damage
					updates.append({
						"table": t_table,
						"record_id": record_id,
						"field": "Shield_Health",
						"value": remaining_shield,
					})
					row_data["Shield_Health"] = remaining_shield
					hp_damage = 0

				else:
					# Shield breaks; spillover hits HP
					var overflow: int = hp_damage - cur_shield

					# If damage STRICTLY exceeds shield, apply Status_ID 19 (shield break) for 2 turns
					if hp_damage > cur_shield:
						var found_break: bool = false
						for active_status in Global.ACTIVE_STATUS_EFFECTS.values():
							if int(active_status.get("Status_ID", 0)) == 19 \
							and str(active_status.get("Entity_Type")) == str(t_entity_type) \
							and int(active_status.get("Entity_ID", 0)) == int(t_id):
								found_break = true
								updates.append({
									"table": "Active_Status_Effects",
									"record_id": int(active_status.get("id", 0)),
									"field": "Duration",
									"value": 2,
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
						"value": null,
					})
					row_data["Shield_Health"] = null
					updates.append({
						"table": t_table,
						"record_id": record_id,
						"field": "Shield_Duration",
						"value": null,
					})
					row_data["Shield_Duration"] = null
					hp_damage = overflow

		# Apply HP change (positive = damage, negative = heal)
		var new_hp: int = current_hp - hp_damage
		if new_hp > max_hp:
			new_hp = max_hp
		if new_hp < 0:
			new_hp = 0

		updates.append({
			"table": t_table,
			"record_id": record_id,
			"field": "Current_Health",
			"value": new_hp,
		})
		row_data["Current_Health"] = new_hp

		# If HP hit 0 from damage, mark as Skipped (and Killed for BattleEnemies)
		if new_hp == 0 and t_type_lower in ["damage", "true damage"]:
			updates.append({
				"table": t_table,
				"record_id": record_id,
				"field": "Skipped",
				"value": true,
			})
			row_data["Skipped"] = true

			if t_table == "BattleEnemies":
				updates.append({
					"table": t_table,
					"record_id": record_id,
					"field": "Killed",
					"value": true,
				})
				row_data["Killed"] = true
				result["killed"] = true

	return result


## Process effects that need immediate game-state changes (shields, heals).
static func _apply_immediate_effect(eff, target_name: String, updates: Array) -> void:
	var target_info = _resolve_target(target_name)
	var target_table: String = target_info.get("table", "")
	var target_rid: int = target_info.get("record_id", 0)

	if target_table == "" or target_rid == 0:
		return

	match eff.effect_type:
		"SHIELD_GENERATE":
			var shield_val: int = int(eff.effect_value)
			updates.append({"table": target_table, "record_id": target_rid, "field": "Shield_Health", "value": shield_val})
			updates.append({"table": target_table, "record_id": target_rid, "field": "Shield_Duration", "value": 4})
			print("[TurnProcessor] Shield %d HP generated on %s" % [shield_val, target_name])
		"HEAL":
			var heal_val: int = int(eff.effect_value)
			var rec: Dictionary = {}
			if target_table == "Characters":
				rec = Global.CHARACTERS.get(str(target_rid), {})
			elif target_table == "Companions":
				rec = Global.COMPANIONS.get(str(target_rid), {})
			elif target_table == "BattleEnemies":
				rec = Global.BATTLEENEMIES.get(str(target_rid), {})
			var cur_hp: int = int(rec.get("Current_Health", 0))
			var max_hp: int = int(rec.get("Max_Health", cur_hp))
			var new_hp: int = mini(cur_hp + heal_val, max_hp)
			updates.append({"table": target_table, "record_id": target_rid, "field": "Current_Health", "value": new_hp})
			print("[TurnProcessor] Healed %s for %d HP" % [target_name, heal_val])


## Resolve a battler name to its table and record_id.
## Returns { "table": String, "record_id": int }.
static func _resolve_target(target_name: String) -> Dictionary:
	# Check Characters
	var cid: String = Global.CHARACTERS_NAME.get(target_name, "")
	if cid != "":
		return {"table": "Characters", "record_id": int(cid)}

	# Check Companions
	var comp_id: String = Global.COMPANIONS_NAME.get(target_name, "")
	if comp_id != "":
		return {"table": "Companions", "record_id": int(comp_id)}

	# Check BattleEnemies by label (format: "EnemyName ID")
	for e in Global.BATTLEENEMIES.values():
		var label: String = str(e.get("EnemyName", "")) + " " + str(e.get("id", ""))
		if label == target_name:
			return {"table": "BattleEnemies", "record_id": int(e.get("id", 0))}

	push_warning("TurnProcessor._resolve_target: could not find '%s'" % target_name)
	return {"table": "", "record_id": 0}


## Tick effect durations and ability cooldowns for a battler at end of turn.
## `_updates` is retained for call-site compatibility but no longer used (cooldowns
## are tracked in BattleManager rather than appended as table updates).
static func _process_cooldowns(battler_name: String, _updates: Array) -> void:
	# Tick effect durations via processor (host only)
	if NetworkManager.is_host and Global.effect_processor and battler_name != "":
		Global.effect_processor.on_turn_end(battler_name)
		Global.sync_active_effects()

	# Subtract 1 turn from this battler's ability cooldowns (host-authoritative,
	# tracked in BattleManager keyed by the stable .tres ability id).
	BattleManager.tick_battler(battler_name)


## Subtract item from inventory when used.
static func _consume_item(item_name: String, battler_name: String, updates: Array) -> void:
	var battler_data: Dictionary = Global.BattlerData.get(battler_name, {})
	var owner_name: String = battler_data.get("name", battler_name)

	for entry in Global.CHARACTER_ITEMS.values():
		if entry.get("Owner") == owner_name and entry.get("Name") == item_name:
			updates.append({
				"table": "Character_Items",
				"record_id": int(entry.get("id", 0)),
				"field": "Quantity",
				"value": int(entry.get("Quantity", 1)) - 1,
			})
			print("[TurnProcessor] Consumed item '%s' from %s" % [item_name, owner_name])
			return
	push_warning("TurnProcessor._consume_item: item '%s' not found for '%s'" % [item_name, owner_name])


## Add burst charges gained this turn, capped at the highest charge_cost among abilities.
static func _gain_burst_charges(battler_name: String, amount: int, updates: Array, cost_subtracted: int = 0) -> void:
	var battler_data: Dictionary = Global.BattlerData.get(battler_name, {})

	var highest_charge_cost: int = 0
	for ability in battler_data.get("entity_current_ability_data", {}).values():
		var cc = ability.get("charge_cost", 0)
		if cc != null and int(cc) > highest_charge_cost:
			highest_charge_cost = int(cc)

	if highest_charge_cost == 0:
		return

	var current_charges = battler_data.get("entity_data", {}).get("Burst_Charges", 0)
	if current_charges == null:
		current_charges = 0
	current_charges = int(current_charges)

	# Account for burst cost already subtracted earlier in the same turn
	var effective_current: int = maxi(current_charges - cost_subtracted, 0)

	if effective_current >= highest_charge_cost:
		return

	var new_charge_amount: int = mini(effective_current + amount, highest_charge_cost)
	var table: String = ""
	match battler_data.get("type"):
		"Character": table = "Characters"
		"Companion": table = "Companions"

	if table != "":
		updates.append({
			"table": table,
			"record_id": int(battler_data.get("id", 0)),
			"field": "Burst_Charges",
			"value": new_charge_amount,
		})
		print("[TurnProcessor] Burst charges: %d -> %d (cap: %d)" % [current_charges, new_charge_amount, highest_charge_cost])
