extends Control


@onready var TurnOrderPanel = $TurnOrderPanel
@onready var Player_Card_Container = $PlayerCardContainer
@onready var Food_Buff_Label = $ActiveFoodBuffHeader/ActiveFoodBuffLabel
@onready var Food_Buff_Turns_Left_Label = $TurnsLeftHeader/TurnsLeftLabel
@onready var Player_Card_Scene = preload("res://Scenes/battle_prep_character.tscn")

var Active_Party = []
var Players_in_party = []
var Ready_Players = []



func _ready() -> void:
	set_names()
	_set_player_cards()
	set_food_buff()
	_connect_card_signals()
	pass


func _process(delta: float) -> void:
	var _dm_name = Global.Current_Party.get("Dungeon_Master", "")
	var _dm_id = Global.CHARACTERS_NAME.get(_dm_name, "")
	if _dm_id != "" and Global.CHARACTERS.get(_dm_id, {}).get("Ready") == true:
		get_tree().change_scene_to_file("res://Scenes/Player_Battle_Scene.tscn")

func _check_ready_players():
	var CharacterData
	for PlayerName in Global.PartyCharacters:
		var _pid = Global.CHARACTERS_NAME.get(PlayerName, "")
		CharacterData = Global.CHARACTERS.get(_pid, {})
		if CharacterData.get("Ready") == true:
			if Ready_Players.has(PlayerName):
				pass
			else:
				Ready_Players.append(PlayerName)
		else:
			if Ready_Players.has(PlayerName):
				Ready_Players.erase(PlayerName)
				pass
			else:
				pass
			
	
		#for PlayerName in Active_Party
func _connect_card_signals():
	for child in Player_Card_Container.get_children():
		if child.has_signal("FoodBuffChanged") and not child.FoodBuffChanged.is_connected(_on_card_food_buff_changed):
			child.FoodBuffChanged.connect(_on_card_food_buff_changed)

func _on_card_food_buff_changed() -> void:
	print ("Refreshing Scene")
	System.refresh(self)
	# Do any parent-level updates triggered by the change
	# e.g., recompute team buffs, totals, enable/disable buttons, etc.
	#refresh_window()

func _set_player_cards():
	for player in Global.PartyCharacters:
		var scene = Player_Card_Scene.instantiate()
		Player_Card_Container.add_child(scene)
		scene.assign_player(player)

func set_food_buff():
	if Global.Current_Party.get("Active_Food_Buff") != null:
		Food_Buff_Label.text = Global.Current_Party.get("Active_Food_Buff")
		Food_Buff_Turns_Left_Label.text = str(Global.Current_Party.get("Buff_Battles_Left"))
	pass

func set_names():
	var party_members = []
	for character in Global.PartyCharacters:
		party_members.append(character)
	for companion in Global.PartyCompanions:
		party_members.append(companion)
	TurnOrderPanel.party_record_id = Global.Current_Party.get("id")
	TurnOrderPanel._set_order(party_members)
	pass


func _on_exit_button_pressed() -> void:
	get_parent().queue_free()
	pass # Replace with function body.
