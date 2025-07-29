extends Node2D

@onready var http = $HTTPRequest
@onready var LoadingBar = $Control/LoadingProgress
var current_table_index := 0
var tables_to_fetch = Global.TABLES
var Table_Count = Global.TABLES.size()
var Tables_Processed = 0


func _ready() -> void:

	fetch_next_table()
	pass

func fetch_next_table():
	if current_table_index >= tables_to_fetch.size():
		print("✅ All tables loaded.")

		#print(Global.CHARACTERS)
		return

	var table_name = tables_to_fetch[current_table_index]
	var url = "https://godot-airtable-backend.onrender.com/get_table?table=%s&email=%s" % [table_name, Global.ACTIVE_USER_EMAIL]
	print("Fetching table:", table_name)

	var error = http.request(url)
	if error != OK:
		print("❌ Request failed for table:", table_name, "Error code:", error)


func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("❌ Failed to fetch table data. Code:", response_code)
		current_table_index += 1
		update_progress_bar()
		fetch_next_table()
		return

	var raw = body.get_string_from_utf8()
	var data = JSON.parse_string(raw)

	if data == null:
		print("❌ Failed to parse JSON")
		current_table_index += 1
		fetch_next_table()
		return

	var table_name = tables_to_fetch[current_table_index]
	var records = data.get("records", [])

	match table_name:
		"Characters":
			for record in records:
				Global.CHARACTERS[record["id"]] = record["fields"]
				Global.CHARACTERS_NAME[record["fields"]["Name"]] = record["id"]
		"Artifacts":
			for record in records:
				Global.ARTIFACTS[record["id"]] = record["fields"]
				Global.ARTIFACTS_NAME[record["fields"]["Artifact Set"]] = record["id"]
		"Reactions":
			for record in records:
				Global.REACTIONS[record["id"]] = record["fields"]
		"Weapons":
			for record in records:
				Global.WEAPONS[record["id"]] = record["fields"]
				Global.WEAPONS_NAME[record["fields"]["Name"]] = record["id"]
		"Abilities":
			for record in records:
				Global.ABILITIES[record["id"]] = record["fields"]
		"Companions":
			for record in records:
				Global.COMPANIONS[record["id"]] = record["fields"]
				Global.COMPANIONS_NAME[record["fields"]["Name"]] = record["id"]
		"Crafting Recipes":
			for record in records:
				Global.CRAFTINGRECIPES[record["id"]] = record["fields"]
				Global.CRAFTINGRECIPES_NAME[record["fields"]["Product"]] = record["id"]
		"Items":
			for record in records:
				Global.ITEMS[record["id"]] = record["fields"]
				Global.ITEMS_NAME[record["fields"]["Item"]] = record["id"]
		"Enemies":
			for record in records:
				Global.ENEMIES[record["id"]] = record["fields"]
				Global.ENEMIES_NAME[record["fields"]["Name"]] = record["id"]
		"BattleEnemies":
			for record in records:
				Global.BATTLEENEMIES[record["id"]] = record["fields"]
		_:
			pass
	current_table_index += 1
	update_progress_bar()
	fetch_next_table()
	print("✅ Loaded table: ", table_name, " with ", records.size(), " records.")

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
	tween.tween_property(LoadingBar, "value", target_value, 0.9)
	tween.tween_callback(Callable(self, "_on_progress_tween_finished"))

func _on_progress_tween_finished():
	if LoadingBar.value >= 100:
		print("✅ Loading complete. Switching to PlayerHub...")
		get_tree().change_scene_to_file("res://Scene's/player_hub.tscn")
