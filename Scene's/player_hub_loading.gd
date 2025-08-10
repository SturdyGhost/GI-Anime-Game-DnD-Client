extends Node2D

@onready var http = $HTTPRequest
@onready var LoadingBar = $Control/LoadingProgress
var current_table_index := 0
var tables_to_fetch = Global.TABLES
var Table_Count = Global.TABLES.size()
var Tables_Processed = 0
var completed_tables := []


func _ready():
	Global.table_loaded.connect(_on_table_loaded)
	Global.data_load_complete.connect(_on_all_tables_loaded)
	Global.Refresh_Data(Global.TABLES)


func _on_table_loaded(table_name: String, count: int):
	Tables_Processed += 1
	update_progress_bar()

func _on_all_tables_loaded():
	print("✅ All tables loaded. Moving to hub.")
	print ("Total Records: " + str(Global.total_records))
	get_tree().change_scene_to_file("res://Scene's/player_hub.tscn")


func update_progress_bar():
	Tables_Processed += 1

	var current_value = LoadingBar.value
	var target_value = current_value

	if Tables_Processed < Table_Count:
		# Random bump between 5 and 15 (or tweak as you like)
		target_value += randi_range(4, 8)
		target_value = clamp(target_value, 0, 99)  # Avoid overshooting before final
	else:
		# Final table — set to 100%
		target_value = 100

	# Animate the value change
	var tween = create_tween()
	tween.tween_property(LoadingBar, "value", target_value, 0.1)
	tween.tween_callback(Callable(self, "_on_progress_tween_finished"))

func _on_progress_tween_finished():
	if LoadingBar.value >= 100:
		print("✅ Loading complete. Switching to PlayerHub...")
		get_tree().change_scene_to_file("res://Scene's/player_hub.tscn")
