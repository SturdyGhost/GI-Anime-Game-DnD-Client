extends Control
const PARTY_KEYS = ["Party_Member_1", "Party_Member_2", "Party_Member_3", "Party_Member_4"]
const TURN_KEYS  = ["First_Turn", "Second_Turn", "Third_Turn", "Fourth_Turn"]

@onready var PartyRow   : HBoxContainer  = $PartyRow
@onready var PartyTpl    = preload("res://Scenes/party_member_template.tscn")
@onready var TurnList   : ItemList       = $Body/TurnList
@onready var EnemyFlow  : GridContainer  = $Body/EnemyScroll/EnemyFlow
@onready var EnemyTpl    = preload("res://Scenes/enemy_card_template.tscn")
@onready var RefreshTimer: Timer         = $RefreshTimer
@onready var Background = $Background
@onready var player = $AudioStreamPlayer
@onready var PlayerTurnUI = $Player_Hub
@onready var VisibilityButton = $VisibilityToggleButton

const COL_NEXT    : Color = Color(0.545, 0.827, 0.867, 0.18)
const COL_CURRENT : Color = Color(0.886, 0.761, 0.564, 0.28)
var companion_name = []
var music_files: Array = []
var music_index: int = -1
var ordered: Array = []
var Original_Order = []

func _ready() -> void:
	var handler = Callable(self, "_on_data_load_complete")
	if not Global.is_connected("data_load_complete", handler):
		Global.connect("data_load_complete", handler)
	_refresh_all()
	set_background()
	load_region_music(Global.Current_Region)
	play_next_track()
	check_turn_ui(Global.Current_Party.get("Current_Turn"))
	set_battlers()


func _refresh_all() -> void:
	_refresh_party()
	_refresh_enemies()
	_refresh_turns()

func _on_data_load_complete():
	check_turn_ui(Global.Current_Party.get("Current_Turn"))
	set_battlers()

func _refresh_party() -> void:
	for c in PartyRow.get_children():
		if c != PartyTpl:
			c.queue_free()
	for member in Global.Current_Party.get("Turn_Order"):
		var row = PartyTpl.instantiate()
		row.visible = true
		PartyRow.add_child(row)
		if Global.PartyCharacters.has(member):
			row.set_card(member)
		else:
			row.set_companion_card(member)


func _refresh_enemies() -> void:
	for c in EnemyFlow.get_children():
		if c != EnemyTpl:
			c.queue_free()
	for e in Global.BATTLEENEMIES.values():
		var card = EnemyTpl.instantiate()
		card.visible = true
		EnemyFlow.add_child(card)
		card.set_card(str(e.get("id")))

func set_battlers():
	Global.BattlerData = {}
	print ("Set Battlers Function running.")
	if Original_Order.size() > 0:
		for battler in Original_Order:
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
				if status.get("Entity_Type") == b_type and status.get("Entity_ID") == b_id:
					b_active_status_effects[status.get("id")] = status
			b_current_health = b_complete_data.get("Current_Health")
			b_max_health = b_complete_data.get("Max_Health")
			b_skipped_status = b_complete_data.get("Skipped")
			b_skipped_duration = b_complete_data.get("Skip_Duration")
			b_applied_element = b_complete_data.get("Applied_Element")
			b_killed_status = b_complete_data.get("Killed")
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
				"applied_element": b_applied_element,
				"killed_status": b_killed_status,
				"skipped_status": b_skipped_status,
				"skipped_duration": b_skipped_duration}
		pass

func _refresh_turns() -> void:
	TurnList.clear()
	ordered = []
	Original_Order = Global.Current_Party.get("Turn_Order")
	for e in Global.BATTLEENEMIES.values():
		Original_Order.append(e.get("EnemyName")+" "+str(int(e.get("id"))))
	ordered = Original_Order
	var current = str(Global.Current_Party.get("Current_Turn"))
	print (current)
	var idx := ordered.find(current)
	print (idx)
	if idx >= 0:
		var rot := []
		for i in range(idx, ordered.size()):
			rot.append(ordered[i])
		for j in range(0, idx):
			rot.append(ordered[j])
		ordered = rot
	var preview_len = min(23, ordered.size() * 2)
	for i in range(preview_len):
		var nm := str(ordered[i % ordered.size()])
		var prefix := ("▶ " if i == 0 else ("⟶ " if i == 1 else ""))
		var ii := TurnList.add_item(prefix + nm)
		TurnList.set_item_selectable(ii,false)
		if i >= ordered.size():TurnList.set_item_disabled(ii,true)
		if idx > Original_Order.find(nm):TurnList.set_item_disabled(ii,true)
		if i == 0: TurnList.set_item_custom_bg_color(ii, COL_CURRENT)
		elif i == 1: TurnList.set_item_custom_bg_color(ii, COL_NEXT)
	TurnList.select(-1)

func set_background():
	Background.texture = load("res://Background Images/BattleScene/"+Global.Current_Region+".png")

func load_region_music(region: String) -> void:
	music_files.clear()
	var folder_path = "res://Background Music/%s/Battle HUB/" % region
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


func _on_audio_stream_player_finished() -> void:
	play_next_track()
	pass # Replace with function body.


func _on_button_pressed() -> void:
	advance_turn()


func advance_turn():
	var SecondTurnText = TurnList.get_item_text(1)
	var updates = [{
		"table": "Party",            # Adjust if your table name differs
		"record_id": int(Global.Current_Party.get("id")),  # Must be the Party's record id
		"field": "Current_Turn",
		"value": str(SecondTurnText.right(SecondTurnText.length()-2))
	}]
	Global.Update_Records(updates)
	await Global.data_load_complete
	assign_party()
	_refresh_turns()

func assign_party():
	for party in Global.PARTY.values():
		if party.get("Party_Member_1") == Global.ACTIVE_USER_NAME or party.get("Party_Member_2") == Global.ACTIVE_USER_NAME or party.get("Party_Member_3") == Global.ACTIVE_USER_NAME or party.get("Party_Member_4") == Global.ACTIVE_USER_NAME:
			Global.Current_Party = party


func check_turn_ui(current_turn):
	if current_turn == Global.ACTIVE_USER_NAME:
		VisibilityButton.visible = true
		PlayerTurnUI.visible = true
	elif Global.COMPANIONS_NAME.has(current_turn):
		if Global.COMPANIONS[Global.COMPANIONS_NAME[current_turn]].get("Owner") == Global.ACTIVE_USER_NAME:
			VisibilityButton.visible = true
			PlayerTurnUI.visible = true
	elif Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]].get("UserType") == "Dungeon Master":
			VisibilityButton.visible = true
			PlayerTurnUI.visible = true
	else:
			VisibilityButton.visible = false
			PlayerTurnUI.visible = false
			pass

func _on_visibility_toggle_button_pressed() -> void:
	PlayerTurnUI.visible = true
	pass # Replace with function body.
