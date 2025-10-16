extends Panel

# --- Node refs ---
@onready var Splash: TextureRect = $Scroll/Root/Splash
@onready var CompanionName: Label = $CompanionName
@onready var ValElement: Label = $ValElement
@onready var ValWeapon: Label  = $ValWeapon
@onready var ValRegion: Label  = $ValRegion
@onready var ValAscRank: Label = $ValAscRank
@onready var ChangeOption: OptionButton = $ChangeOption

@onready var CardCharged: Panel = $Scroll/Root/AbilitiesBox/CardCharged
@onready var CardSkill: Panel   = $Scroll/Root/AbilitiesBox/CardSkill
@onready var CardBurst: Panel   = $Scroll/Root/AbilitiesBox/CardBurst

@onready var LoreText: RichTextLabel = $Lore

# --- State ---
var _current_companion: String = ""
var _party_row_id: Variant = null  # track which Party row to update

func _ready() -> void:
	_populate_companion_overview()
	_build_change_menu()
	ChangeOption.item_selected.connect(_on_change_option_selected)

# ---------- Data loading / UI fill ----------

func _populate_companion_overview() -> void:
	var active_name = str(Global.ACTIVE_USER_NAME)
	var char_id = Global.CHARACTERS_NAME.get(active_name, null)
	if char_id == null:
		_clear_ui("No active character found.")
		return

	var char_row: Dictionary = Global.CHARACTERS.get(char_id, {})
	_current_companion = str(char_row.get("Companion_Name", ""))

	if _current_companion == "":
		_clear_ui("No companion set.")
		return

	# Grab all 3 ability rows for this companion
	var abilities_by_type: Dictionary = _get_companion_abilities(_current_companion)

	# Pull shared fields from any one row
	var any_row: Dictionary = {}
	if abilities_by_type.has("ChargedAttack"):
		any_row = abilities_by_type["ChargedAttack"]
	elif abilities_by_type.has("Skill"):
		any_row = abilities_by_type["Skill"]
	elif abilities_by_type.has("Burst"):
		any_row = abilities_by_type["Burst"]

	var elem = any_row.get("Element", "")
	var weap = any_row.get("Weapon", "")
	var region = any_row.get("Region", "")
	var asc_rank = any_row.get("Ascension_Rank", "")
	var lore = any_row.get("Lore", "")

	# Fill shared UI
	CompanionName.text = str(_current_companion)
	ValElement.text = elem
	ValWeapon.text = weap
	ValRegion.text = region
	ValAscRank.text = str(asc_rank)

	# Splash
	_load_splash_for(_current_companion)

	# Lore
	LoreText.clear()
	LoreText.append_text(lore)

	# Ability cards
	_fill_ability_card(CardCharged, "Charged Attack", abilities_by_type.get("ChargedAttack", {}))
	_fill_ability_card(CardSkill,   "Skill",          abilities_by_type.get("Skill", {}))
	_fill_ability_card(CardBurst,   "Burst",          abilities_by_type.get("Burst", {}))

	# Cache which party row to patch on change
	_party_row_id = _find_active_party_row_id(active_name)

func _clear_ui(reason: String) -> void:
	CompanionName.text = reason
	ValElement.text = "-"
	ValWeapon.text = "-"
	ValRegion.text = "-"
	ValAscRank.text = "-"
	LoreText.clear()
	Splash.texture = null
	_fill_ability_card(CardCharged, "Charged Attack", {})
	_fill_ability_card(CardSkill,   "Skill", {})
	_fill_ability_card(CardBurst,   "Burst", {})

func _fill_ability_card(card: Panel, title: String, row: Dictionary) -> void:
	var vbox: VBoxContainer = card.get_node("VBox") as VBoxContainer
	var title_lbl: Label = vbox.get_node("Title") as Label
	var grid: GridContainer = vbox.get_node("Grid") as GridContainer
	var val_cd: Label = grid.get_node("ValCD") as Label
	var val_cc: Label = grid.get_node("ValCC") as Label
	var val_move: Label = grid.get_node("ValMove") as Label
	var desc: RichTextLabel = vbox.get_node("Desc") as RichTextLabel

	title_lbl.text = title
	if row.is_empty():
		val_cd.text = "-"
		val_cc.text = "-"
		val_move.text = "-"
		desc.clear()
		desc.append_text("No data.")
	else:
		val_cd.text = str(row.get("Cooldown", "-"))
		val_cc.text = str(row.get("Charge_Cost", "-"))
		val_move.text = str(row.get("Movement", "-"))
		desc.clear()
		desc.append_text(str(row.get("Ability", "-")))

func _load_splash_for(companion_name: String) -> void:
	var hyphenname = companion_name.to_lower().replace(" ","-")
	var path = "res://UI/Splash Arts/" + hyphenname + ".png"
	if ResourceLoader.exists(path):
		var tex = load(path)
		if tex is Texture2D:
			Splash.texture = tex
			return
	Splash.texture = null

func _get_companion_abilities(name: String) -> Dictionary:
	var out: Dictionary = {}
	for row in Global.COMPANIONS.values():
		if row.get("Name", "") == name:
			var t = str(row.get("Ability_Type", ""))
			out[t] = row
	return out

func _build_change_menu() -> void:
	ChangeOption.clear()
	var names: Array = _unique_unlocked_companion_names()
	names.sort()
	var sel_idx = -1
	for i in range(names.size()):
		ChangeOption.add_item(str(names[i]))
		if str(names[i]) == _current_companion:
			sel_idx = i
	if sel_idx >= 0:
		ChangeOption.select(sel_idx)

func _unique_unlocked_companion_names() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for row in Global.COMPANIONS.values():
		var name = str(row.get("Name", ""))
		var unlocked = bool(row.get("Unlocked", false))
		if unlocked and name != "" and not seen.has(name):
			seen[name] = true
			out.append(name)
	return out

func _find_active_party_row_id(active_char_name: String) -> Variant:
	# Look for a Party row containing the active character's name in any party_member_* field.
	for rid in Global.PARTY.keys():
		var row: Dictionary = Global.PARTY[rid]
		for k in row.keys():
			var ks = str(k)
			if ks.begins_with("party_member_"):
				if str(row[k]) == active_char_name:
					return rid
	# Fallback: first party row if present
	for rid in Global.PARTY.keys():
		return rid
	return null

# ---------- Change companion (DB + UI) ----------

func _on_change_option_selected(index: int) -> void:
	if index < 0:
		return
	var new_name = ChangeOption.get_item_text(index)
	var old_name = _current_companion
	if new_name == old_name:
		return

	# Update DB: Characters for each party member, and Party row fields that equal old_name.
	var updates: Array = []
	var old_vals: Dictionary = {}
	var new_vals: Dictionary = {}
	var meta: Dictionary = {
		"source": "CompanionsOverview",
		"actor": str(Global.ACTIVE_USER_NAME),
		"from": old_name,
		"to": new_name
	}
	var new_comp_data
	for companion in Global.COMPANIONS.values():
		if companion.get("Name") == new_name:
			new_comp_data = companion

	# 1) For each character in the current party row, set Characters.Companion_Name
	if _party_row_id != null and Global.PARTY.has(_party_row_id):
		var prow: Dictionary = Global.PARTY[_party_row_id]
		for k in prow.keys():
			var ks = str(k)
			if ks.begins_with("Party_Member_"):
				var cname = str(prow[k])
				if cname == "":
					continue
				var cid = Global.CHARACTERS_NAME.get(cname, null)
				if cid != null:
					updates.append({"table":"Characters", "record_id": int(cid), "field":"Companion_Name", "value": new_name})
					updates.append({"table":"Characters", "record_id": int(cid), "field":"Companion_Region", "value": new_comp_data.get("Region")})
					updates.append({"table":"Characters", "record_id": int(cid), "field":"Companion_Weapon", "value": new_comp_data.get("Weapon")})
					updates.append({"table":"Characters", "record_id": int(cid), "field":"Companion_Element", "value": new_comp_data.get("Element")})
					# Update in-memory cache too
					if Global.CHARACTERS.has(cid):
						var prev = str(Global.CHARACTERS[cid].get("Companion_Name",""))
						old_vals["Characters:" + str(cid)] = prev
						Global.CHARACTERS[cid]["Companion_Name"] = new_name
						new_vals["Characters:" + str(cid)] = new_name

	# 2) In the Party row, replace any cell equal to old companion name with the new name
	if _party_row_id != null and Global.PARTY.has(_party_row_id):
		var prow2: Dictionary = Global.PARTY[_party_row_id]
		for col in prow2.keys():
			var v = prow2[col]
			if str(v) == old_name:
				updates.append({"table":"Party", "record_id": int(_party_row_id), "field": str(col), "value": new_name})
				old_vals["Party:" + str(col)] = old_name
				new_vals["Party:" + str(col)] = new_name
				# update cache
				Global.PARTY[_party_row_id][col] = new_name

	# Send updates if any
	if updates.size() > 0:
		Global.Update_Records(updates)
		var related_id_str = ""
		if _party_row_id != null:
			related_id_str = str(_party_row_id)

		Global.Log(
			"Companion",
			"Changed companion for party",
			"Party",
			related_id_str,
			old_vals,
			new_vals,
			meta,
			"success",
			"audit"
		)

	# Refresh UI to new companion
	_current_companion = new_name
	_populate_companion_overview()
	_build_change_menu()


func _on_exit_button_pressed() -> void:
	get_parent().queue_free()
	pass # Replace with function body.
