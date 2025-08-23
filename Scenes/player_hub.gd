extends Node2D
@onready var player = $AudioStreamPlayer2D
@onready var background_image = $UI/BackgroundImage
@onready var http = HTTPRequest.new()
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
var last_known_characters_timestamp := ""
var music_files: Array = []
var music_index: int = -1
var Selected_Stat
var Ascension
var Player_data


func _ready() -> void:
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
	role_check()
	#$UI/NameLabel.text = Global.ACTIVE_USER_NAME
	pass

func assign_party():
	for party in Global.PARTY.values():
		if party.get("Party_Member_1") == Global.ACTIVE_USER_NAME or party.get("Party_Member_2") == Global.ACTIVE_USER_NAME or party.get("Party_Member_3") == Global.ACTIVE_USER_NAME or party.get("Party_Member_4") == Global.ACTIVE_USER_NAME:
			Global.Current_Party = party

func role_check():
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
	if Global.ACTIVE_USER_NAME == "Brian C.":
		if music_files.is_empty():
			print("⚠️ No music files found!")
			return
		music_index = randi() % music_files.size()
		var stream_path = music_files[music_index]
		player.stream = load(stream_path)
		player.play()

func _on_data_load_complete():
	print("✅ Global data has finished loading!")
	set_ui()
	#await get_tree().create_timer(3.0).timeout
	Global.Polling_Timer.start()
	Global.Polling_Timer.paused = false
	$UI/TopHotbar/Party2Portrait/ElementTexture
	# Your logic here

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
	assign_party()
	$UI/TopHotbar/CharacterPortrait.set_character(Global.ACTIVE_USER_NAME)
	$UI/TopHotbar/Party1Portrait.set_character(Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]].get("Party_Member_1"))
	$UI/TopHotbar/Party2Portrait.set_character(Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]].get("Party_Member_2"))
	$UI/TopHotbar/CompanionPortrait.set_character(Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]].get("Companion_Name"))
	set_stats()
	$UI/GearContainer/WeaponButton.set_weapon()
	$"UI/GearContainer/Flower of Life".set_artifact()
	$"UI/GearContainer/Feather of Death".set_artifact()
	$"UI/GearContainer/Sands of Time".set_artifact()
	$"UI/GearContainer/Goblet of Space".set_artifact()
	$"UI/GearContainer/Circlet of Principles".set_artifact()
	Mora.text = str(Global.Current_Party.get("Mora"))
	Level.text = "Level: "+str(int(Player_data.get("Level")))+"/"+str(int(Player_data.get("Level_Cap")))
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
						+ pd.get("%s_Manual_Roll_Added_Amount_Override" % key, 0)
	btn.MultipliedRoll  = 1 + pd.get("%s_Multiplier_Roll_Bonus" % key, 0.0) \
						  + pd.get("%s_Manual_Roll_Multiplier_Amount_Override" % key, 0.0)
	btn.AddedDamage     = pd.get("%s_Added_Damage_Bonus" % key, 0) \
						+ pd.get("%s_Manual_Damage_Added_Amount_Override" % key, 0)
	btn.MultipliedDamage = 1 + pd.get("%s_Multiplier_Damage_Bonus" % key, 0.0) \
						   + pd.get("%s_Manual_Damage_Multiplier_Amount_Override" % key, 0.0)

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

func set_region_button_options():
	Ascension = Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]].get("Ascension_Rank")
	for item in RegionButton.get_popup().get_item_count():
		if RegionButton.get_item_text(item) == Global.Current_Region:
			RegionButton.selected = item
		if item > Ascension:
			RegionButton.set_item_disabled(item,true)

func set_element_button_options():
	var current_element = Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]].get("Element")
	var element = Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]].get("Ascension_Material")
	var base_element = element.left(element.length() -4)
	for item in ElementButton.get_popup().get_item_count():
		if ElementButton.get_item_text(item) == current_element:
			ElementButton.selected = item
		if item > Ascension:
			ElementButton.set_item_disabled(item,true)
		if ElementButton.get_item_text(item) == base_element:
			ElementButton.set_item_disabled(item,false)

var _region_busy: bool = false

func _on_region_button_item_selected(index: int) -> void:
	if _region_busy:
		return
	_region_busy = true

	var region = RegionButton.get_item_text(index)
	if region == Global.Current_Region:
		_region_busy = false
		return

	# 1) Local apply first (triggers your music setter if you made it a property)
	var original_region = Global.Current_Region
	Global.Current_Region = region

	# 2) Build updates + tag fields so stale polls don’t revert
	var updates: Array = []
	var players = ["Dylan", "Brian F.", "Brian C."]  # or however you track players
	for name in players:
		var rid = Global.CHARACTERS_NAME[name]
		# local cache so UI stays consistent
		Global.CHARACTERS[rid]["Current_Region"] = region
		# stale-guard tag
		Global.note_local_field_write(str(rid), "Current_Region")
		updates.append({
			"table": "Characters",
			"record_id": float(rid),
			"field": "Current_Region",
			"value": region
		})

	# 3) Update UI now, then send
	set_ui()
	Global.Update_Records(updates)
	Global.Log(
	"location",
	"change_region",
	"Region",
	str(index),
	{"old_region": original_region},
	{"new_region": Global.Current_Region})

	# tiny debounce so rapid clicks don’t overlap writes
	await get_tree().create_timer(0.6).timeout
	_region_busy = false


var _element_busy: bool = false

func _on_element_button_item_selected(index: int) -> void:
	if _element_busy:
		return
	_element_busy = true

	var new_element = ElementButton.get_item_text(index)
	var rid = Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]
	var old = Global.CHARACTERS[rid].get("Element")

	if new_element == old:
		_element_busy = false
		return

	# 1) Local apply
	Global.CHARACTERS[rid]["Element"] = new_element

	# 2) Tag + send
	Global.note_local_field_write(rid, "Element")
	Global.Update_Records([{
		"table": "Characters",
		"record_id": float(rid),
		"field": "Element",
		"value": new_element
	}])
	Global.Log(
	"character",
	"change_element",
	"Element",
	str(index),
	{"old_element": old},
	{"new_element": new_element})
	# 3) Update UI now
	set_ui()

	await get_tree().create_timer(0.6).timeout
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
