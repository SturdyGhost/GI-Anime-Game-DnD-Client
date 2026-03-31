extends Node2D
@onready var player = $AudioStreamPlayer2D
@onready var background_image = $UI/BackgroundImage
var http: Node  # kept for compat, no longer used for HTTP
@onready var HealthButton = $"UI/StatButtonsContainer/Health Button"
@onready var AttackButton = $"UI/StatButtonsContainer/Attack Button"
@onready var DefenseButton = $"UI/StatButtonsContainer/Defense Button"
@onready var ElementalMasteryButton = $"UI/StatButtonsContainer/Elemental Mastery Button"
@onready var EnergyRechargeButton = $"UI/StatButtonsContainer/Energy Recharge Button"
@onready var CriticalDamageButton = $"UI/StatButtonsContainer/Critical Damage Button"
@onready var RegionButton = $UI/TopHotbar/RegionButton
@onready var ElementButton = $UI/TopHotbar/ElementButton
@onready var Mora = $UI/TopHotbar/MoraButton
@onready var Level = $UI/TopHotbar/LvlButton
@onready var settings_popup_scene := preload("res://Scenes/SettingsPopup.tscn")
var last_known_characters_timestamp := ""
var music_files: Array = []
var music_index: int = -1
var Selected_Stat
var Ascension
var Player_data
var Luck_set = false

var _initial_setup_done := false

func _ready() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	# If data is already available (host, or client already synced), run setup now
	_try_initial_setup()

func trigger_luck_popup():
	var s: PackedScene = preload("res://Scenes/DailyLuck.tscn")
	var dlg = s.instantiate()
	dlg.position = Vector2(1000,450)
	add_child(dlg)

func restore_health():
	if not NetworkManager.is_host:
		return
	var updates = []
	for character in Global.CHARACTERS.values():
		if character.get("Max_Health") != null:
			updates.append({
			"table": "Characters",
			"record_id": int(character.get("id")),
			"field": "Current_Health",
			"value": character.get("Max_Health")})
	if updates.size() > 0:
		Global.Update_Records(updates)
func assign_party():
	Global.PartyCharacters = []
	Global.PartyCompanions = []
	for party in Global.PARTY.values():
		if party.get("Party_Member_1") == Global.ACTIVE_USER_NAME or party.get("Party_Member_2") == Global.ACTIVE_USER_NAME or party.get("Party_Member_3") == Global.ACTIVE_USER_NAME or party.get("Party_Member_4") == Global.ACTIVE_USER_NAME:
			Global.Current_Party = party
			if party.get("Party_Member_1") != "COMPANION" and Global.PartyCharacters.has(party.get("Party_Member_1")) == false:
				Global.PartyCharacters.append(party.get("Party_Member_1"))
			if party.get("Party_Member_2") != "COMPANION" and Global.PartyCharacters.has(party.get("Party_Member_2")) == false:
				Global.PartyCharacters.append(party.get("Party_Member_2"))
			if party.get("Party_Member_3") != "COMPANION" and Global.PartyCharacters.has(party.get("Party_Member_3")) == false:
				Global.PartyCharacters.append(party.get("Party_Member_3"))
			if party.get("Party_Member_4") != "COMPANION" and Global.PartyCharacters.has(party.get("Party_Member_4")) == false:
				Global.PartyCharacters.append(party.get("Party_Member_4"))
	for companion in Global.COMPANIONS.values():
		if companion.get("Active") == true:
			if Global.PartyCompanions.has(companion.get("Name")) == false:
				Global.PartyCompanions.append(companion.get("Name"))
func role_check():
	if Player_data == null or Player_data.is_empty():
		return
	var role = Player_data.get("Role")
	if role == "Scribe":
		$"UI/BottomHotbar/HBoxContainer/Crafting Button".disabled = true
	else:
		$"UI/BottomHotbar/HBoxContainer/Research Button".disabled = true


func load_region_music(region: String) -> void:
	music_files.clear()
	var folder_path = "res://Background Music/%s/Player HUB/" % region
	var dir = DirAccess.open(folder_path)
	var count = 0
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			file_name = dir.get_next()
			# Skip .import, hidden files, and folders
			if file_name.ends_with(".import") or dir.current_is_dir():
				var new_file_name = file_name.left(file_name.length()-7)
				music_files.append(folder_path + new_file_name)
				count += 1
				file_name = dir.get_next()
				continue

			if file_name.ends_with(".ogg") or file_name.ends_with(".mp3") or file_name.ends_with(".wav"):
				music_files.append(folder_path + file_name)
				count += 1


			file_name = dir.get_next()

		dir.list_dir_end()
		print("Total music files loaded:", count)
	else:
		print("⚠️ Could not open music folder:", folder_path)

func play_next_track():
	if Global.ACTIVE_USER_NAME == "Brian F.":
		if music_files.is_empty():
			print("⚠️ No music files found!")
			return
		music_index = randi() % music_files.size()
		var stream_path = music_files[music_index]
		player.stream = load(stream_path)
		player.play()

func _try_initial_setup() -> void:
	if _initial_setup_done:
		return
	if not Global.CHARACTERS_NAME.has(Global.ACTIVE_USER_NAME):
		return
	_initial_setup_done = true
	set_ui()
	role_check()
	restore_health()
	if Global.Luck_Set == false:
		trigger_luck_popup()
		Global.Luck_Set = true
	else:
		Market.Refresh_Stock(Global.Current_Region)

func _on_data_load_complete():
	if not _initial_setup_done:
		_try_initial_setup()
	else:
		set_ui()

func _on_audio_stream_player_2d_finished() -> void:
	play_next_track()
	pass # Replace with function body.

func set_background():
	var path = "res://Background Images/Player HUB/%s.jpg" % Global.Current_Region  # Adjust as needed

	if ResourceLoader.exists(path):
		var texture = load(path)
		background_image.texture = texture
	else:
		print("⚠️ Background image not found:", path)

func set_ui():
	if not Global.CHARACTERS_NAME.has(Global.ACTIVE_USER_NAME):
		return
	assign_party()
	$UI/TopHotbar/CharacterPortrait.set_character(Global.ACTIVE_USER_NAME)

	match Global.ACTIVE_USER_NAME:
		"Brian C.":
			$UI/TopHotbar/Party1Portrait.set_character("Brian F.")
			$UI/TopHotbar/Party2Portrait.set_character("Dylan")
		"Brian F.":
			$UI/TopHotbar/Party1Portrait.set_character("Brian C.")
			$UI/TopHotbar/Party2Portrait.set_character("Dylan")
		"Dylan":
			$UI/TopHotbar/Party1Portrait.set_character("Brian C.")
			$UI/TopHotbar/Party2Portrait.set_character("Brian F.")

	set_stats()
	$UI/GearContainer/WeaponButton.set_weapon()
	$"UI/GearContainer/Flower of Life".set_artifact()
	$"UI/GearContainer/Feather of Death".set_artifact()
	$"UI/GearContainer/Sands of Time".set_artifact()
	$"UI/GearContainer/Goblet of Space".set_artifact()
	$"UI/GearContainer/Circlet of Principles".set_artifact()
	Mora.text = str(Global.Current_Party.get("Mora"))
	Level.text = "Level: "+str(int(Player_data.get("Level")))+"/"+str(int(Player_data.get("Level_Cap")))
	var array = 0
	for player in Global.PartyCharacters:
		var _pid = Global.CHARACTERS_NAME.get(player, "")
		array += Global.CHARACTERS.get(_pid, {}).get("Max_Health", 0)
	Global.AverageHealth = array / max(Global.PartyCharacters.size(), 1)
	var updates = []
	for Companion in Global.COMPANIONS.values():
		if Companion.get("Current_Health") != Global.AverageHealth:
			updates.append({"table": "Companions","record_id": int(Companion.get("id")),"field": "Current_Health","value": Global.AverageHealth})
			updates.append({"table": "Companions","record_id": int(Companion.get("id")),"field": "Max_Health","value": Global.AverageHealth})
	if updates.size() > 0:
		Global.Update_Records(updates)
	if Global.Region_Changed == 1:
		set_background()
		load_region_music(Global.Current_Region)
		play_next_track()
		Global.Region_Changed = 0
	set_region_button_options()
	set_element_button_options()

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
	var _sid = Global.CHARACTERS_NAME.get(Global.ACTIVE_USER_NAME, "")
	Player_data = Global.CHARACTERS.get(_sid, {})
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
	if Player_data.get("Current_Health") != int(Global.Current_Health) or Player_data.get("Max_Health") != int(Global.Current_Health):
		updates.append({"table": "Characters", "record_id": Global.ACTIVE_USER_RECORD_ID,"field":"Max_Health","value": int(Global.Current_Health) })
		updates.append({"table": "Characters", "record_id": Global.ACTIVE_USER_RECORD_ID,"field":"Current_Health","value": int(Global.Current_Health) })
		Global.Update_Records(updates)

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


func _on_exit_button_pressed() -> void:
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Are you sure you want to quit?"
	confirmation.connect("confirmed", Callable(self, "_on_quit_confirmed"))
	add_child(confirmation)
	confirmation.popup_centered()
	
func _on_quit_confirmed():
	get_tree().quit()



func _check_characters_update():
	# No longer polls HTTP — data updates arrive via ENet RPC
	pass


func _on_check_characters_response(_result, _code, _headers, _body):
	# Legacy callback — no longer used. Data sync handled by ENet.
	pass

func set_region_button_options():
	Ascension = Player_data.get("Ascension_Rank", 0)
	for item in RegionButton.get_popup().get_item_count():
		if RegionButton.get_item_text(item) == Global.Current_Region:
			RegionButton.selected = item
		if item > Ascension:
			RegionButton.set_item_disabled(item,true)

func set_element_button_options():
	var weapon_type
	for weapon in Global.CHARACTER_WEAPONS.values():
		if weapon.get("Owner") == Global.ACTIVE_USER_NAME and weapon.get("Equipped") == true:
			weapon_type = weapon.get("Type")
	var current_element = Player_data.get("Element", "")
	var element = Player_data.get("Ascension_Material", "")
	var base_element = element.left(element.length() -4)
	for item in ElementButton.get_popup().get_item_count():
		if ElementButton.get_item_text(item) == current_element:
			ElementButton.selected = item
		ElementButton.set_item_disabled(item,false)
		if item > Ascension:
			ElementButton.set_item_disabled(item,true)
		if ElementButton.get_item_text(item) == base_element:
			ElementButton.set_item_disabled(item,false)
		var ability_count = 0
		for ability in Global.ACTIVE_ABILITIES.values():
			var eid = ability.get("Entity_ID")
			if ability.get("Element") == ElementButton.get_item_text(item) \
			and str(ability.get("Weapon_Type", "")) == str(weapon_type) \
			and eid != null and int(eid) == Global.ACTIVE_USER_RECORD_ID \
			and ability.get("Entity_Type") == "Character":
				ability_count += 1
		if ability_count == 0:
			ElementButton.set_item_disabled(item,true)


var _region_busy: bool = false

func _on_region_button_item_selected(index: int) -> void:
	if _region_busy:
		return
	_region_busy = true

	var region = RegionButton.get_item_text(index)
	if region == Global.Current_Region:
		_region_busy = false
		return

	Global.Current_Region = region

	var party_id = int(Global.Current_Party.get("id", 0))
	if party_id == 0:
		_region_busy = false
		return

	Global.Update_Records([{
		"table": "Party",
		"record_id": party_id,
		"field": "Current_Region",
		"value": region
	}])

	set_ui()

	await get_tree().create_timer(0.3).timeout
	_region_busy = false


var _element_busy: bool = false

func _on_element_button_item_selected(index: int) -> void:
	if _element_busy:
		return
	_element_busy = true

	var new_element = ElementButton.get_item_text(index)
	var rid = Global.CHARACTERS_NAME.get(Global.ACTIVE_USER_NAME, "")
	if rid == "":
		_element_busy = false
		return
	var char_data = Global._synced.get("Characters", {}).get(rid, {})
	var old = char_data.get("Element", "")
	var weap_type = ""
	for weapon in Global.CHARACTER_WEAPONS.values():
		if weapon.get("Owner") == Global.ACTIVE_USER_NAME and weapon.get("Equipped") == true:
			weap_type = str(weapon.get("Type", ""))
			break
	if new_element == old:
		_element_busy = false
		return

	# check if user has at least one ability for this weapon + element
	var has_matching_ability := false
	for ability in Global.ACTIVE_ABILITIES.values():
		var eid = ability.get("Entity_ID")
		if ability.get("Entity_Type") == "Character" \
		and eid != null and int(eid) == Global.ACTIVE_USER_RECORD_ID \
		and str(ability.get("Weapon_Type", "")) == weap_type \
		and str(ability.get("Element", "")) == new_element:
			has_matching_ability = true
			break

	if not has_matching_ability:
		_element_busy = false
		return

	Global.Update_Records([{
		"table": "Characters",
		"record_id": int(rid),
		"field": "Element",
		"value": new_element
	}])

	set_ui()

	await get_tree().create_timer(0.3).timeout
	_element_busy = false

func _open_artifact_detail(slot_short: String) -> void:
	var s: PackedScene = preload("res://Scenes/artifact_detail_scene.tscn")
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
	dlg.open_for_type(slot_short)

func _on_flower_of_life_pressed() -> void:
	print ("Flower Button Pressed")
	_open_artifact_detail("Flower of Life")
	pass # Replace with function body.


func _on_feather_of_death_pressed() -> void:
	print ("Feather Button Pressed")
	_open_artifact_detail("Feather of Death")
	pass # Replace with function body.


func _on_sands_of_time_pressed() -> void:
	print ("Sands Button Pressed")
	_open_artifact_detail("Sands of Time")
	pass # Replace with function body.


func _on_goblet_of_space_pressed() -> void:
	print ("Goblet Button Pressed")
	_open_artifact_detail("Goblet of Space")
	pass # Replace with function body.


func _on_circlet_of_principles_pressed() -> void:
	print ("Circlet Button Pressed")
	_open_artifact_detail("Circlet of Principles")
	pass # Replace with function body.


func _on_crafting_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/CraftingMenu.tscn")
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


func _on_refresh_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/player_hub_loading.tscn")
	pass # Replace with function body.


func _on_gather_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/gathering.tscn")
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


func _on_market_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/MarketPanel.tscn")
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


func _on_research_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/ResearchPanel.tscn")
	var dlg = s.instantiate()

	var win := Window.new()
	win.exclusive = true               # makes it modal, blocks hover/clicks
	win.transparent = true             # so only your dlg visuals show
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO

	win.add_child(dlg)
	dlg.open_auto()
	add_child(win)

	# Optional: center or full-rect dlg inside window
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass # Replace with function body.


func _on_combat_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/player_battle_prep.tscn")
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


func _on_companions_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/CompanionsOverview.tscn")
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


func _on_settings_button_pressed() -> void:
	var popup = settings_popup_scene.instantiate()
	add_child(popup)
	popup.popup_centered()


func _on_minigames_button_pressed() -> void:
	var s: PackedScene = preload("res://Scenes/MinigamesMenu.tscn")
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
	pass # Replace with function body.
