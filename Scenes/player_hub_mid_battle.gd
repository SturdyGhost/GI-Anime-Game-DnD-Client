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
@onready var Level = $UI/TopHotbar/LvlButton
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

var battle_id= 0
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

signal turn_ended

func _ready() -> void:
	Current_Turn = Global.Current_Party.get("Current_Turn")
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	var path = "res://Background Music/Inazuma/Player HUB/1-01 Inazuma.mp3"  # replace with your actual file
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
	#$UI/NameLabel.text = Global.ACTIVE_USER_NAME
	pass

func _process(delta: float) -> void: 
	if AttackUsedButton.has_selectable_items() == false:
		set_attacks()

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
			if ability.get("Ability_Type") == "Skill":
				Skill_Data = Global.ABILITIES[str(ability.get("Ability_ID"))]
				if Player_data.get("Skill_CD") == 0:
					AttackUsedButton.set_item_disabled(3,false)
				else:
					AttackUsedButton.set_item_disabled(3,true)
			elif ability.get("Ability_Type") == "Burst":
				Burst_Data = Global.ABILITIES[str(ability.get("Ability_ID"))]
				if Player_data.get ("Burst_Charges") >= Burst_Data.get("charge_cost"):
					AttackUsedButton.set_item_disabled(4,false)
				else:
					AttackUsedButton.set_item_disabled(4,true)
		
			pass
	pass

func _on_data_load_complete():
	print("✅ Global data has finished loading!")
	Current_Turn = Global.Current_Party.get("Current_Turn")
	set_ui()
	set_targets()
	set_attacks()
	#await get_tree().create_timer(3.0).timeout
	Global.Polling_Timer.start()
	Global.Polling_Timer.paused = false
	$UI/TopHotbar/Party2Portrait/ElementTexture
	if Global.PartyCharacters.has(Global.Current_Party.get("Current_Turn")):
		Turn_Type = "Character"
	elif Global.PartyCompanions.has(Global.Current_Party.get("Current_Turn")):
		Turn_Type = "Companion"
	else:
		Turn_Type = "Enemy"
	# Your logic here


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
		TargetSelection.add_item(str(Enemy.get("EnemyName")," ",str(int(Enemy.get("id")))))

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
	_check_ability_options()
	Mora.text = str(Global.Current_Party.get("Mora"))
	Level.text = "Level: "+str(int(Player_data.get("Level")))+"/"+str(int(Player_data.get("Level_Cap")))
	BurstChargeLabel.text = "Burst Charges: "+str(Player_data.get("Burst_Charges"))+"/"+str(Burst_Data.get("charge_cost"))




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
	
	Global.CombatLog(
		battle_id,
		turn_no,
		"player_turn",
		"Player",
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
	#emit_signal("turn_ended")
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
