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
@onready var ConfirmButton = $UseCompanionButton

@onready var LoreText: RichTextLabel = $ScrollContainer/Lore

# --- State ---
var _current_companion: String = ""
var _party_row_id: Variant = null  # track which Party row to update
var Companion_List = []
var Companion_ID 
var companion_data
var abilities_by_type: Dictionary

func _ready() -> void:
	_set_initial_companion()
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

	if _current_companion == "":
		_clear_ui("No companion set.")
		return

	# Grab all 3 ability rows for this companion
	abilities_by_type = _get_companion_abilities(_current_companion)
	for companion in Global.COMPANIONS.values():
		if companion.get("Name") == _current_companion:
			companion_data = companion

	# Pull shared fields from any one row
	var any_row: Dictionary = {}
	if abilities_by_type.has("ChargedAttack"):
		any_row = abilities_by_type["ChargedAttack"]
	elif abilities_by_type.has("Skill"):
		any_row = abilities_by_type["Skill"]
	elif abilities_by_type.has("Burst"):
		any_row = abilities_by_type["Burst"]

	var elem = companion_data.get("Element", "")
	var weap = companion_data.get("Weapon", "")
	var region = companion_data.get("Region", "")
	var asc_rank = companion_data.get("Ascension_Rank", "")
	var lore = companion_data.get("Lore", "")
	var unlocked = companion_data.get("Unlocked")

	# Fill shared UI
	CompanionName.text = str(_current_companion)
	ValElement.text = elem
	ValWeapon.text = weap
	ValRegion.text = region
	ValAscRank.text = str(asc_rank)
	if unlocked == false:
		ConfirmButton.disabled = true
	else:
		ConfirmButton.disabled = false

	# Splash
	_load_splash_for(_current_companion)

	# Lore
	LoreText.clear()
	LoreText.append_text(lore)

	# Ability cards
	_fill_ability_card(CardCharged, "ChargedAttack", abilities_by_type.get("ChargedAttack", {}))
	_fill_ability_card(CardSkill,   "Skill",          abilities_by_type.get("Skill", {}))
	_fill_ability_card(CardBurst,   "Burst",          abilities_by_type.get("Burst", {}))

	# Cache which party row to patch on change
	_party_row_id = _find_active_party_row_id(active_name)

func _set_initial_companion():
	for companion in Global.COMPANIONS.values():
		if companion.get("Player_Chosen") == true:
			_current_companion = companion.get("Name")
			Companion_List.append(companion.get("Name"))

func _clear_ui(reason: String) -> void:
	CompanionName.text = reason
	ValElement.text = "-"
	ValWeapon.text = "-"
	ValRegion.text = "-"
	ValAscRank.text = "-"
	LoreText.clear()
	Splash.texture = null
	_fill_ability_card(CardCharged, "ChargedAttack", {})
	_fill_ability_card(CardSkill,   "Skill", {})
	_fill_ability_card(CardBurst,   "Burst", {})

func _fill_ability_card(card: Panel, title: String, row: Dictionary) -> void:
	var vbox: VBoxContainer = card.get_node("VBox") as VBoxContainer
	var title_lbl: Label = vbox.get_node("Title") as Label
	var grid: GridContainer = vbox.get_node("Grid") as GridContainer
	var val_cd: Label = grid.get_node("ValCD") as Label
	var val_cc: Label = grid.get_node("ValCC") as Label
	var val_move: Label = grid.get_node("ValMove") as Label
	var desc: RichTextLabel = vbox.get_node("ScrollContainer/Desc") as RichTextLabel

	title_lbl.text = title
	if row.is_empty():
		val_cd.text = "-"
		val_cc.text = "-"
		val_move.text = "-"
		desc.clear()
		desc.append_text("No data.")
	else:
		val_cd.text = str(row.get("cooldown", "-"))
		val_cc.text = str(row.get("charge_cost", "-"))
		val_move.text = str(row.get("movement", "-"))
		desc.clear()
		desc.append_text(str(row.get("description", "-")))

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
			Companion_ID = int(row.get("id"))
	for ability in Global.ACTIVE_ABILITIES.values():
		if ability.get("Entity_Type") == "Companion" and int(ability.get("Entity_ID")) == Companion_ID:
			var t = str(ability.get("Ability_Type", ""))
			out[t] = Global.ABILITIES[str(int(ability.get("Ability_ID")))]
	return out

func _build_change_menu() -> void:
	ChangeOption.clear()
	var names: Array = _unique_unlocked_companion_names()
	names.sort()
	var sel_idx = -1
	var popup = ChangeOption.get_popup()
	var red_icon := _make_color_icon(Color(1, 0, 0))
	var green_icon := _make_color_icon(Color(0, 1, 0))
	for i in range(names.size()):
		ChangeOption.add_item(str(names[i]))
		for companion in Global.COMPANIONS.values():
			if companion.get("Name") == str(names[i]) and companion.get("Met") == false:
				ChangeOption.set_item_disabled(i,true)
			if companion.get("Name") == str(names[i]) and companion.get("Unlocked") == false and companion.get("Met") == true:
				popup.set_item_icon(i, red_icon)
				popup.set_item_icon_max_width(i, 12) # adds a little paddingm_custom_fg_color(i,red)
			if companion.get("Name") == str(names[i]) and companion.get("Unlocked") == true:
				popup.set_item_icon(i, green_icon)
				popup.set_item_icon_max_width(i, 12)
				
		if str(names[i]) == _current_companion:
			sel_idx = i
	if sel_idx >= 0:
		ChangeOption.select(sel_idx)

func _make_color_icon(color: Color, size := 10) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _unique_unlocked_companion_names() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for row in Global.COMPANIONS.values():
		var name = str(row.get("Name", ""))
		var unlocked = bool(row.get("Unlocked", false))
		if name != "" and not seen.has(name):
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

	# Refresh UI to new companion
	_current_companion = new_name
	_populate_companion_overview()
	_build_change_menu()


func _on_exit_button_pressed() -> void:
	get_parent().queue_free()
	pass # Replace with function body.




func _on_use_companion_button_pressed() -> void:
	var updates: Array = []
	var old_name = []
	var new_list = []
	var old_vals: Dictionary = {}
	var new_vals: Dictionary = {}
	var new_name = ChangeOption.get_item_text(ChangeOption.get_selected_id())
	if Companion_List.has(new_name):
		return
	Companion_List.push_front(new_name)
	while Companion_List.size() > Global.Current_Party.get("Companion_Limit"):
		Companion_List.pop_back()
	
	for name in Companion_List:
		for companion in Global.COMPANIONS.values():
			if companion.get("Name") != new_name and companion.get("Player_Chosen") == true:
				updates.append({"table": "Companions","record_id": int(companion.get("id")),"field": "Player_Chosen","value": false})
				updates.append({"table": "Companions","record_id": int(companion.get("id")),"field": "Active","value": false})
				old_name.append(companion.get("Name"))
	for name in Companion_List:
		for companion in Global.COMPANIONS.values():
			if companion.get("Name") == name:
				updates.append({"table": "Companions","record_id": int(companion.get("id")),"field": "Player_Chosen","value": true})
				updates.append({"table": "Companions","record_id": int(companion.get("id")),"field": "Active","value": true})
				new_list.append(companion.get("Name"))
	# Update DB: Characters for each party member, and Party row fields that equal old_name.

	var meta: Dictionary = {
		"source": "CompanionsOverview",
		"actor": str(Global.ACTIVE_USER_NAME),
		"from": old_name,
		"to": new_list
	}
	var new_comp_data
	var old_comp_data
	for companion in Global.COMPANIONS.values():
		if companion.get("Name") == new_name:
			new_comp_data = companion


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
	get_parent().queue_free()
	pass # Replace with function body.
