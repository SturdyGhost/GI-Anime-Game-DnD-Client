extends Control
const PARTY_KEYS = ["Party_Member_1", "Party_Member_2", "Party_Member_3", "Party_Member_4"]
const TURN_KEYS  = ["First_Turn", "Second_Turn", "Third_Turn", "Fourth_Turn"]

@onready var PartyRow   = $PartyContainer/PartyRow
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
	if PlayerTurnUI.has_signal("turn_ended"):
		PlayerTurnUI.turn_ended.connect(_on_child_turn_ended)
	_set_party_and_companions()
	_refresh_all()
	set_background()
	load_region_music(Global.Current_Region)
	play_next_track()
	check_turn_ui(Global.Current_Party.get("Current_Turn"))
	_build_battlers()


func _on_child_turn_ended() -> void:
	advance_turn()

func update_enemies():
	var updates = []
	for record in Global.BATTLEENEMIES.values():
		var enemy_name = str(record.get("EnemyName"))
		var enemy_id := str(record.get("id"))
		var expected_suffix = " " + enemy_id
		if not enemy_name.ends_with(expected_suffix):
			updates.append({
				"table": "BattleEnemies",
				"record_id": int(record.get("id")),
				"field": "EnemyName",
				"value": enemy_name + expected_suffix
			})
	Global.Update_Records(updates)

func _set_party_and_companions():
	for entry in Global.Current_Party.get("Turn_Order"):
		if Global.CHARACTERS_NAME.has(entry):
			Global.PartyCharacters.append(entry)
		elif Global.COMPANIONS_NAME.has(entry):
			Global.PartyCompanions.append(entry)

func _refresh_all() -> void:
	_refresh_party()
	_refresh_enemies()
	_refresh_turns()

func _on_data_load_complete():
	if _battle_ending:
		return
	check_turn_ui(Global.Current_Party.get("Current_Turn"))
	_build_battlers()
	_update_party_ui()
	check_battle_end()
	if _battle_ending:
		return
	var ct = Global.Current_Party.get("Current_Turn", "")
	if Global.BattlerData.has(ct):
		Global.Current_Battler_Data = Global.BattlerData[ct]

func _refresh_party() -> void:
	for c in PartyRow.get_children():
		if c != PartyTpl:
			c.queue_free()
	for member in Global.Current_Party.get("Turn_Order"):
		if not Global.PartyCharacters.has(member) and not Global.PartyCompanions.has(member):
			continue
		var row = PartyTpl.instantiate()
		row.visible = true
		PartyRow.add_child(row)
		if Global.PartyCharacters.has(member):
			row.set_card(member)
		elif Global.PartyCompanions.has(member):
			row.set_companion_card(member)

func _update_party_ui():
	for c in PartyRow.get_children():
		if c.tableid != null:
			c.update_stats()

func _refresh_enemies() -> void:
	for c in EnemyFlow.get_children():
		if c != EnemyTpl:
			c.queue_free()
	for e in Global.BATTLEENEMIES.values():
		var card = EnemyTpl.instantiate()
		card.visible = true
		EnemyFlow.add_child(card)
		card.set_card(str(e.get("id")))

func _build_battlers() -> void:
	if Original_Order.size() > 0:
		Global.BattlerData = BattlerState.build_all(Original_Order)
		Global.Current_Battler_Data = Global.BattlerData[Global.Current_Party.get("Current_Turn")]
		# Register all battlers with the effect processor (host only)
		if NetworkManager.is_host and Global.effect_processor == null:
			Global.start_battle_effects(Global.BattlerData)

func _refresh_turns() -> void:
	TurnList.clear()
	ordered = []
	Original_Order = Global.Current_Party.get("Turn_Order")
	for e in Global.BATTLEENEMIES.values():
		var label = str(e.get("EnemyName")) + " " + str(e.get("id"))
		if not Original_Order.has(label):
			Original_Order.append(label)
	ordered = Original_Order
	var current = str(Global.Current_Party.get("Current_Turn"))
	var idx := ordered.find(current)
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
		TurnList.set_item_selectable(ii, false)
		if i >= ordered.size(): TurnList.set_item_disabled(ii, true)
		if idx > Original_Order.find(nm): TurnList.set_item_disabled(ii, true)
		if i == 0: TurnList.set_item_custom_bg_color(ii, COL_CURRENT)
		elif i == 1: TurnList.set_item_custom_bg_color(ii, COL_NEXT)
	TurnList.deselect_all()

func set_background():
	Global.Current_Region = Global.Current_Party.get("Current_Region", Global.Current_Region)
	Background.texture = load("res://Background Images/BattleScene/" + Global.Current_Region + ".png")

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
				var new_file_name = file_name.left(file_name.length() - 7)
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
		print("Could not open music folder:", folder_path)

func play_next_track():
	if Global.ACTIVE_USER_NAME == "Brian F.":
		if music_files.is_empty():
			print("No music files found!")
			return
		music_index = randi() % music_files.size()
		var stream_path = music_files[music_index]
		player.stream = load(stream_path)
		player.play()


func _on_audio_stream_player_finished() -> void:
	play_next_track()


func _on_button_pressed() -> void:
	advance_turn()

var _battle_ending := false

func check_battle_end():
	if _battle_ending:
		return
	var all_enemies_dead := true
	var all_players_down := true

	for enemy in Global.BATTLEENEMIES.values():
		if enemy.get("Killed") == false:
			all_enemies_dead = false
			break

	for player_name in Global.PartyCharacters:
		var char_id = Global.CHARACTERS_NAME.get(player_name, "")
		var health = Global.CHARACTERS.get(char_id, {}).get("Current_Health", 0)
		if health > 0:
			all_players_down = false
			break

	if all_enemies_dead or all_players_down:
		_battle_ending = true
		print("Battle ending")
		for enemy in Global.BATTLEENEMIES.values():
			Global.Remove_Record("BattleEnemies", int(enemy.get("id")))
		Global.end_battle_effects()
		get_tree().change_scene_to_file("res://Scenes/player_hub_loading.tscn")


func advance_turn():
	var SecondTurnText = TurnList.get_item_text(1)
	var updates = [{
		"table": "Party",
		"record_id": int(Global.Current_Party.get("id")),
		"field": "Current_Turn",
		"value": str(SecondTurnText.right(SecondTurnText.length() - 2))
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
	_refresh_turns()
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

func _on_visibility_toggle_button_pressed() -> void:
	PlayerTurnUI.visible = true


func _on_visibility_toggle_button_2_pressed() -> void:
	self.visible = false
