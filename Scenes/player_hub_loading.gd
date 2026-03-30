extends Node2D

@onready var LoadingBar = $Control/LoadingProgress
var Table_Count = Global.TABLES.size()
var Tables_Processed = 0

func _ready():
	Global.table_loaded.connect(_on_table_loaded)
	Global.data_load_complete.connect(_on_all_tables_loaded)

	var has_data = not Global._synced.is_empty()
	if NetworkManager.is_host and has_data:
		_on_all_tables_loaded()
	elif not NetworkManager.is_host and has_data:
		_on_all_tables_loaded()


func _on_table_loaded(table_name: String, count: int):
	Tables_Processed += 1
	update_progress_bar()


func _on_all_tables_loaded():
	print("All tables loaded. Moving to hub.")
	print("All tables loaded, transitioning to hub.")
	if Global.ACTIVE_USER_TYPE == "Player":
		get_tree().change_scene_to_file("res://Scenes/player_hub.tscn")
	elif Global.ACTIVE_USER_TYPE == "Dungeon Master":
		get_tree().change_scene_to_file("res://Scenes/DMHub.tscn")


func update_progress_bar():
	Tables_Processed += 1

	var current_value = LoadingBar.value
	var target_value = current_value

	if Tables_Processed < Table_Count:
		target_value += randi_range(4, 8)
		target_value = clamp(target_value, 0, 99)
	else:
		target_value = 100

	var tween = create_tween()
	tween.tween_property(LoadingBar, "value", target_value, 0.1)
	tween.tween_callback(Callable(self, "_on_progress_tween_finished"))

func _on_progress_tween_finished():
	if LoadingBar.value >= 100:
		print("Loading complete. Switching to hub...")
		if Global.ACTIVE_USER_TYPE == "Player":
			get_tree().change_scene_to_file("res://Scenes/player_hub.tscn")
		elif Global.ACTIVE_USER_TYPE == "Dungeon Master":
			get_tree().change_scene_to_file("res://Scenes/DMHub.tscn")
