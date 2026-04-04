extends Control

## ============================================================================
## KLEE FISH BLAST — Minigame
## ============================================================================
## Fish spawn at random positions. Click them to blast for points.
## Bigger fish = more points. Timer counts down from 30 seconds.
## Results saved to Minigames_Results via Global.Insert().
## ============================================================================

signal game_finished(score: int)

@onready var fish_container: Node2D = $FishContainer
@onready var score_label: Label = $UI/TopBar/ScoreLabel
@onready var timer_label: Label = $UI/TopBar/TimerLabel
@onready var start_button: Button = $UI/StartButton
@onready var result_panel: PanelContainer = $UI/ResultPanel
@onready var result_score_label: Label = $UI/ResultPanel/VBox/ResultScoreLabel
@onready var result_close_button: Button = $UI/ResultPanel/VBox/CloseButton

const GAME_DURATION: float = 30.0
const SPAWN_INTERVAL_MIN: float = 0.4
const SPAWN_INTERVAL_MAX: float = 1.2
const FISH_LIFETIME_MIN: float = 0.8
const FISH_LIFETIME_MAX: float = 2.0
const FISH_MIN_SIZE: float = 0.6
const FISH_MAX_SIZE: float = 1.4

var score: int = 0
var time_left: float = 0.0
var game_active: bool = false
var _spawn_timer: float = 0.0
var _next_spawn: float = 1.0

# Fish colors for variety
const FISH_COLORS: Array = [
	Color(0.2, 0.6, 1.0),    # Blue
	Color(1.0, 0.5, 0.2),    # Orange
	Color(0.3, 0.9, 0.3),    # Green
	Color(1.0, 0.85, 0.1),   # Gold — rare, worth more
	Color(0.9, 0.2, 0.5),    # Pink — rare, worth more
]

func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_start_game)
	if result_close_button:
		result_close_button.pressed.connect(_close_results)
	if result_panel:
		result_panel.visible = false
	if score_label:
		score_label.text = "Score: 0"
	if timer_label:
		timer_label.text = "0:30"

func _process(delta: float) -> void:
	if not game_active:
		return

	# Countdown
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_end_game()
		return

	var secs = int(time_left)
	var tenths = int((time_left - secs) * 10)
	timer_label.text = "0:%02d.%d" % [secs, tenths]

	# Spawn fish
	_spawn_timer += delta
	if _spawn_timer >= _next_spawn:
		_spawn_timer = 0.0
		_next_spawn = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
		# Spawn faster as time runs out
		if time_left < 10.0:
			_next_spawn *= 0.6
		_spawn_fish()

func _start_game() -> void:
	# Clear any leftover fish
	for child in fish_container.get_children():
		child.queue_free()

	score = 0
	time_left = GAME_DURATION
	game_active = true
	_spawn_timer = 0.0
	_next_spawn = 0.5
	start_button.visible = false
	result_panel.visible = false
	score_label.text = "Score: 0"

func _end_game() -> void:
	game_active = false

	# Clear remaining fish
	for child in fish_container.get_children():
		child.queue_free()

	# Determine rewards based on score thresholds
	var reward_count = 0
	if score >= 800:
		reward_count = randi_range(4, 6)
	elif score >= 700:
		reward_count = randi_range(2, 3)
	elif score >= 600:
		reward_count = 1

	var rewarded_materials: Array = []
	if reward_count > 0:
		rewarded_materials = _grant_region_materials(reward_count)

	# Show results
	var result_text = "Final Score: %d" % score
	if rewarded_materials.size() > 0:
		result_text += "\n\nRewards:"
		for mat in rewarded_materials:
			result_text += "\n  %s x%d" % [mat["name"], mat["qty"]]
	elif score < 600:
		result_text += "\n\nScore 600+ for rewards!"
	result_score_label.text = result_text
	result_panel.visible = true
	start_button.visible = true
	start_button.text = "Play Again"

	# Save result to database
	_save_result()
	game_finished.emit(score)

func _grant_region_materials(count: int) -> Array:
	# Collect all materials for the current region
	var region = str(Global.Current_Region)
	var all_materials: Array = []
	for cache in Global.MATERIAL_CACHES.values():
		if str(cache.get("Region", "")) != region:
			continue
		var mats_str = str(cache.get("Materials", ""))
		if mats_str == "" or mats_str == "null":
			continue
		if mats_str.begins_with("[") and mats_str.ends_with("]"):
			mats_str = mats_str.substr(1, mats_str.length() - 2)
		for part in mats_str.split(","):
			var clean = part.strip_edges()
			if clean != "" and not all_materials.has(clean):
				all_materials.append(clean)

	if all_materials.is_empty():
		return []

	# Pick random materials and give them to the player
	var given: Array = []
	for i in count:
		var mat_name = all_materials[randi() % all_materials.size()]
		# Check if we already picked this one — stack it
		var found = false
		for g in given:
			if g["name"] == mat_name:
				g["qty"] += 1
				found = true
				break
		if not found:
			given.append({"name": mat_name, "qty": 1})

	# Actually give the items using the upsert pattern from gathering
	for g in given:
		_upsert_character_item(g["name"], g["qty"])

	return given

func _upsert_character_item(material_name: String, add_qty: int) -> void:
	var char_name = str(Global.ACTIVE_USER_NAME)
	var char_id = Global.CHARACTERS_NAME.get(char_name, null)
	if char_id == null:
		return

	var existing_id = ""
	var existing_qty = 0
	for rec_id in Global.CHARACTER_ITEMS.keys():
		var rec = Global.CHARACTER_ITEMS[rec_id]
		if rec.get("Owner", null) == char_name and str(rec.get("Name", "")) == material_name:
			existing_id = rec_id
			existing_qty = int(rec.get("Quantity", 0))
			break

	if existing_id != "":
		var new_qty = existing_qty + add_qty
		Global.Update_Records([{"table": "Character_Items", "record_id": int(existing_id), "field": "Quantity", "value": new_qty}])
	else:
		var item_type = null
		var item_rarity = null
		var item_description = null
		for item in Global.ITEMS.values():
			if item.get("Item") == material_name:
				item_type = item.get("Type")
				item_rarity = item.get("Rarity")
				item_description = item.get("Description")
		Global.Insert("Character_Items",
			["Owner", "Name", "Quantity", "Type", "Rarity", "Description"],
			[char_name, material_name, add_qty, item_type, item_rarity, item_description])

func _save_result() -> void:
	if not Global.ACTIVE_USER_NAME.is_empty():
		Global.Insert("Minigames_Results",
			["Player", "Minigame", "Score", "Date"],
			[Global.ACTIVE_USER_NAME, "Klee Fish Blast", score,
			 Time.get_datetime_string_from_system()])

func _close_results() -> void:
	result_panel.visible = false
	# Close the window containing this minigame
	var win = get_parent()
	while win and not (win is Window):
		win = win.get_parent()
	if win and win is Window:
		win.queue_free()

# ---------------------------------------------------------------------------
# Fish Spawning
# ---------------------------------------------------------------------------

func _spawn_fish() -> void:
	var fish = _create_fish_node()
	fish_container.add_child(fish)

	# Random position within the play area (leave margins)
	var vp = get_viewport_rect().size
	var margin = 100
	fish.position = Vector2(
		randf_range(margin, vp.x - margin),
		randf_range(margin + 80, vp.y - margin)  # +80 for UI at top
	)

	# Random lifetime — fish disappears if not clicked
	var lifetime = randf_range(FISH_LIFETIME_MIN, FISH_LIFETIME_MAX)
	var tween = create_tween()
	# Fade in
	fish.modulate.a = 0.0
	tween.tween_property(fish, "modulate:a", 1.0, 0.15)
	# Wait
	tween.tween_interval(lifetime - 0.5)
	# Fade out and remove
	tween.tween_property(fish, "modulate:a", 0.0, 0.35)
	tween.tween_callback(fish.queue_free)

func _create_fish_node() -> Node2D:
	var fish = Node2D.new()
	var scale_factor = randf_range(FISH_MIN_SIZE, FISH_MAX_SIZE)

	# Determine fish type and points
	var color_idx = randi() % FISH_COLORS.size()
	var color = FISH_COLORS[color_idx]
	var points = 10
	if color_idx == 3:  # Gold
		points = 50
	elif color_idx == 4:  # Pink
		points = 30
	elif scale_factor > 1.1:
		points = 20  # Big fish worth more

	fish.set_meta("points", points)
	fish.set_meta("scale_factor", scale_factor)

	# Draw the fish body using a Polygon2D
	var body = Polygon2D.new()
	var fish_shape: PackedVector2Array = PackedVector2Array([
		Vector2(-30, 0), Vector2(-15, -12), Vector2(10, -10),
		Vector2(25, -5), Vector2(30, 0), Vector2(25, 5),
		Vector2(10, 10), Vector2(-15, 12)
	])
	body.polygon = fish_shape
	body.color = color
	body.scale = Vector2(scale_factor, scale_factor)
	fish.add_child(body)

	# Tail
	var tail = Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-30, 0), Vector2(-45, -10), Vector2(-45, 10)
	])
	tail.color = color.darkened(0.2)
	tail.scale = Vector2(scale_factor, scale_factor)
	fish.add_child(tail)

	# Eye
	var eye = Polygon2D.new()
	eye.polygon = _circle_points(3, 6)
	eye.position = Vector2(15 * scale_factor, -3 * scale_factor)
	eye.color = Color.WHITE
	fish.add_child(eye)

	return fish

# Fish click detection via _input (Area2D input_event unreliable in sub-windows)
func _input(event: InputEvent) -> void:
	if not game_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		# Check all fish — closest first if overlapping
		var best_fish: Node2D = null
		var best_dist = 999999.0
		for fish in fish_container.get_children():
			if not is_instance_valid(fish):
				continue
			var dist = click_pos.distance_to(fish.position)
			var radius = 30.0 * fish.get_meta("scale_factor", 1.0)
			if dist <= radius and dist < best_dist:
				best_fish = fish
				best_dist = dist

		if best_fish:
			_blast_fish(best_fish)

func _blast_fish(fish: Node2D) -> void:
	var points = fish.get_meta("points", 10)
	score += points
	score_label.text = "Score: %d" % score

	# Spawn a score popup
	_spawn_score_popup(fish.global_position, points)

	# Blast effect — quick scale up and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fish, "scale", Vector2(2, 2), 0.15)
	tween.tween_property(fish, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(fish.queue_free)

func _spawn_score_popup(pos: Vector2, points: int) -> void:
	var lbl = Label.new()
	lbl.text = "+%d" % points
	lbl.position = pos - Vector2(20, 20)
	lbl.add_theme_font_size_override("font_size", 28)
	if points >= 50:
		lbl.modulate = Color(1, 0.85, 0.1)
	elif points >= 30:
		lbl.modulate = Color(0.9, 0.2, 0.5)
	else:
		lbl.modulate = Color.WHITE
	add_child(lbl)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "position:y", pos.y - 60, 0.6)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(lbl.queue_free)

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle = TAU * i / segments
		pts.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return pts
