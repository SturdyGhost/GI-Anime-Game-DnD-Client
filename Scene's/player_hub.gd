extends Node2D

@onready var player = $AudioStreamPlayer2D
@onready var background_image = $UI/BackgroundImage

var music_files: Array = []
var music_index: int = -1
var Current_Region = Global.Current_Region
var Selected_Stat

@onready var HealthButton = $"UI/StatButtonsContainer/Health Button"
@onready var AttackButton = $"UI/StatButtonsContainer/Attack Button"
@onready var DefenseButton = $"UI/StatButtonsContainer/Defense Button"
@onready var ElementalMasteryButton = $"UI/StatButtonsContainer/Elemental Mastery Button"
@onready var EnergyRechargeButton = $"UI/StatButtonsContainer/Energy Recharge Button"
@onready var CriticalDamageButton = $"UI/StatButtonsContainer/Critical Damage Button"

func _ready() -> void:
	set_background()
	set_stats()
	load_region_music(Current_Region)
	play_next_track()
	#$UI/NameLabel.text = Global.ACTIVE_USER_NAME

	pass

func load_region_music(region: String) -> void:
	music_files.clear()
	var folder_path = "res://Background Music/%s/Player HUB/" % region
	var dir = DirAccess.open(folder_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".mp3"):  # or .mp3, .wav
				music_files.append(folder_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("⚠️ Could not open music folder:", folder_path)

func play_next_track():
	if music_files.is_empty():
		print("⚠️ No music files found!")
		return
	music_index = randi() % music_files.size()
	var stream_path = music_files[music_index]
	player.stream = load(stream_path)
	player.play()

func _on_audio_stream_player_2d_finished() -> void:
	play_next_track()
	pass # Replace with function body.

func set_background():
	var path = "res://Background Images/Player HUB/%s.jpg" % Current_Region  # Adjust as needed

	if ResourceLoader.exists(path):
		var texture = load(path)
		background_image.texture = texture
	else:
		print("⚠️ Background image not found:", path)

func set_stats():
	var Player_data = Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]]
	HealthButton.Stat = "Health"
	HealthButton.StatValue = Player_data["Health Base Points"]*2
	HealthButton.AddedRoll = Player_data["Health Added Roll Bonus"]
	HealthButton.MultipliedRoll = 1+Player_data["Health Multiplier Roll Bonus"]
	HealthButton.AddedDamage = Player_data["Health Added Damage Bonus"]
	HealthButton.MultipliedDamage = 1+Player_data["Health Multiplier Damage Bonus"]
	AttackButton.Stat = "Attack"
	AttackButton.StatValue = Player_data["Attack Base Points"]
	AttackButton.AddedRoll = Player_data["Attack Added Roll Bonus"]
	AttackButton.MultipliedRoll = 1+Player_data["Attack Multiplier Roll Bonus"]
	AttackButton.AddedDamage = Player_data["Attack Added Damage Bonus"]
	AttackButton.MultipliedDamage = 1+Player_data["Attack Multiplier Damage Bonus"]
	DefenseButton.Stat = "Defense"
	DefenseButton.StatValue = Player_data["Defense Base Points"]
	DefenseButton.AddedRoll = Player_data["Defense Added Roll Bonus"]
	DefenseButton.MultipliedRoll = 1+Player_data["Defense Multiplier Roll Bonus"]
	DefenseButton.AddedDamage = Player_data["Defense Added Damage Bonus"]
	DefenseButton.MultipliedDamage = 1+Player_data["Defense Multiplier Damage Bonus"]
	ElementalMasteryButton.Stat = "Elemental Mastery"
	ElementalMasteryButton.StatValue = Player_data["Elemental Mastery Base Points"]
	ElementalMasteryButton.AddedRoll = Player_data["Elemental Mastery Added Roll Bonus"]
	ElementalMasteryButton.MultipliedRoll = 1+Player_data["Elemental Mastery Multiplier Roll Bonus"]
	ElementalMasteryButton.AddedDamage = Player_data["Elemental Mastery Added Damage Bonus"]
	ElementalMasteryButton.MultipliedDamage = 1+Player_data["Elemental Mastery Multiplier Damage Bonus"]
	EnergyRechargeButton.Stat = "Energy Recharge"
	EnergyRechargeButton.StatValue = Player_data["Energy Recharge Base Points"]*.1
	EnergyRechargeButton.AddedRoll = Player_data["Energy Recharge Added Roll Bonus"]
	EnergyRechargeButton.MultipliedRoll = 1+Player_data["Energy Recharge Multiplier Roll Bonus"]
	EnergyRechargeButton.AddedDamage = Player_data["Energy Recharge Added Damage Bonus"]
	EnergyRechargeButton.MultipliedDamage = 1+Player_data["Energy Recharge Multiplier Damage Bonus"]
	ElementalMasteryButton.MultipliedDamage = 1+Player_data["Energy Recharge Multiplier Damage Bonus"]
	CriticalDamageButton.Stat = "Critical Damage"
	CriticalDamageButton.StatValue = Player_data["Critical Damage Base Points"]*.1
	CriticalDamageButton.AddedRoll = Player_data["Critical Damage Added Roll Bonus"]
	CriticalDamageButton.MultipliedRoll = 1+Player_data["Critical Damage Multiplier Roll Bonus"]
	CriticalDamageButton.AddedDamage = Player_data["Critical Damage Added Damage Bonus"]
	CriticalDamageButton.MultipliedDamage = 1+Player_data["Critical Damage Multiplier Damage Bonus"]
	
	HealthButton.set_stats()
	AttackButton.set_stats()
	DefenseButton.set_stats()
	ElementalMasteryButton.set_stats()
	EnergyRechargeButton.set_stats()
	CriticalDamageButton.set_stats()



func _on_health_button_pressed() -> void:
	Selected_Stat = "Health"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	pass # Replace with function body.

func _on_attack_button_pressed() -> void:
	Selected_Stat = "Attack"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	pass # Replace with function body.

func _on_defense_button_pressed() -> void:
	Selected_Stat = "Defense"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	pass # Replace with function body.

func _on_elemental_mastery_button_pressed() -> void:
	Selected_Stat = "Elemental Mastery"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	pass # Replace with function body.

func _on_energy_recharge_button_pressed() -> void:
	Selected_Stat = "Energy Recharge"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	pass # Replace with function body.

func _on_critical_damage_button_pressed() -> void:
	Selected_Stat = "Critical Damage"
	print ("Toggling Stat Panel for: " + Selected_Stat)
	pass # Replace with function body.


func _on_weapon_button_pressed() -> void:
	print ("Weapon Button has been pressed")
	pass # Replace with function body.
