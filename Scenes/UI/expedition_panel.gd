class_name ExpeditionPanel
extends Control

signal panel_closed

const BG = Color(0.102, 0.122, 0.169)
const PANEL = Color(0.133, 0.157, 0.22)
const CARD = Color(0.165, 0.192, 0.27)
const TEXT = Color(0.941, 0.949, 0.973)
const SEC = Color(0.69, 0.722, 0.8)
const MUTED = Color(0.471, 0.51, 0.627)
const ACCENT = Color(0.788, 0.659, 0.298)
const GREEN = Color(0.292, 0.855, 0.498)
const RED = Color(0.937, 0.267, 0.267)

var _expedition_pool: Array = []
var _available_companions: Array = []
var _assignments: Dictionary = {}
var _pending_results: Array = []
var _selected_companion: String = ""
var _max_slots: int = 1

func _ready() -> void:
	_load_state()
	_build_ui()

func _load_state() -> void:
	# Load from Party record (synced to all clients) or Global fallback
	var party = Global.Current_Party
	var pool_json = str(party.get("Expedition_Pool", "")) if party else ""
	var assign_json = str(party.get("Expedition_Assignments", "")) if party else ""

	if pool_json != "":
		var parsed = JSON.parse_string(pool_json)
		if parsed is Array and parsed.size() > 0:
			_expedition_pool = []
			for d in parsed:
				_expedition_pool.append(ExpeditionData.from_dict(d))

	# Fallback to Global if Party doesn't have it yet
	if _expedition_pool.is_empty():
		var saved_pool = Global.get("_expedition_pool")
		if saved_pool is Array and saved_pool.size() > 0:
			_expedition_pool = []
			for d in saved_pool:
				_expedition_pool.append(ExpeditionData.from_dict(d))
		else:
			_expedition_pool = ExpeditionManager.generate_pool(Global.Current_Region)
			_save_state()

	if assign_json != "":
		var parsed = JSON.parse_string(assign_json)
		if parsed is Dictionary:
			_assignments = parsed

	if _assignments.is_empty():
		var saved_assignments = Global.get("_expedition_assignments")
		if saved_assignments is Dictionary:
			_assignments = saved_assignments.duplicate()

	var results = Global.get("_expedition_results")
	if results is Array:
		_pending_results = results

	_available_companions = []
	for comp in Global.COMPANIONS.values():
		if comp.get("Unlocked", false) and not comp.get("Active", false):
			_available_companions.append(comp)

	_max_slots = 2
	for char in Global.CHARACTERS.values():
		if str(char.get("User_Type", "")) != "Dungeon Master":
			_max_slots = maxi(_max_slots, int(char.get("Ascension_Rank", 0)) * 2)
	_max_slots = maxi(_max_slots, 2)

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	bg.add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	# Header
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	root.add_child(header_row)

	var title = Label.new()
	title.text = "EXPEDITIONS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header_row.add_child(title)

	var slots_label = Label.new()
	slots_label.text = "Companions: %d / %d" % [_total_deployed(), _max_slots]
	slots_label.add_theme_font_size_override("font_size", 16)
	slots_label.add_theme_color_override("font_color", SEC)
	header_row.add_child(slots_label)

	var refresh_btn = Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.custom_minimum_size = Vector2(80, 40)
	refresh_btn.pressed.connect(_refresh_pool)
	header_row.add_child(refresh_btn)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(func(): panel_closed.emit())
	header_row.add_child(close_btn)

	var info_label = Label.new()
	info_label.text = "Assign idle companions to expeditions. Results are collected after your next battle."
	info_label.add_theme_font_size_override("font_size", 13)
	info_label.add_theme_color_override("font_color", MUTED)
	root.add_child(info_label)

	# Pending results
	if _pending_results.size() > 0:
		_build_results_section(root)

	# Main content
	var content = HBoxContainer.new()
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	root.add_child(content)

	_build_expedition_list(content)
	_build_companion_list(content)

func _build_results_section(parent: VBoxContainer) -> void:
	var results_card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.2, 0.12)
	sb.border_color = GREEN
	sb.border_width_left = 2
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	results_card.add_theme_stylebox_override("panel", sb)
	parent.add_child(results_card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	results_card.add_child(vbox)

	var header = Label.new()
	header.text = "EXPEDITION RESULTS"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", GREEN)
	vbox.add_child(header)

	for result in _pending_results:
		var loot: Dictionary = result.get("loot", {})
		var comp_name: String = str(result.get("companion", ""))
		var owner_name: String = str(result.get("owner", ""))
		var exp_name: String = str(result.get("expedition", ""))
		var failed: bool = result.get("failed", false)
		var bonus_list: Array = result.get("bonuses", [])
		var bonus_total: float = result.get("bonus_total", 1.0)

		var owner_text = " for %s" % owner_name if owner_name != "" else ""
		var result_label = Label.new()
		if failed or loot.is_empty():
			result_label.text = "%s returned empty-handed from %s%s" % [comp_name, exp_name, owner_text]
			result_label.add_theme_color_override("font_color", RED)
		else:
			var items_arr: Array = []
			for k in loot:
				items_arr.append("%s x%d" % [k, loot[k]])
			result_label.text = "%s from %s%s: %s" % [comp_name, exp_name, owner_text, ", ".join(items_arr)]
			result_label.add_theme_color_override("font_color", TEXT)
		result_label.add_theme_font_size_override("font_size", 13)
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(result_label)

		if bonus_list.size() > 0:
			var bonus_label = Label.new()
			bonus_label.text = "  Bonus x%.0f%% — %s" % [bonus_total * 100, ", ".join(bonus_list)]
			bonus_label.add_theme_font_size_override("font_size", 11)
			bonus_label.add_theme_color_override("font_color", MUTED)
			bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(bonus_label)

	var collect_btn = Button.new()
	collect_btn.text = "Dismiss Results"
	collect_btn.custom_minimum_size = Vector2(0, 32)
	collect_btn.pressed.connect(func():
		Global._expedition_results = []
		_pending_results = []
		_build_ui()
	)
	vbox.add_child(collect_btn)

func _build_expedition_list(parent: HBoxContainer) -> void:
	var left = VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	parent.add_child(left)

	var header = Label.new()
	header.text = "Available Expeditions"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", TEXT)
	left.add_child(header)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	left.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for i in range(_expedition_pool.size()):
		var exp = _expedition_pool[i]
		_build_expedition_card(list, exp, i)

func _build_expedition_card(parent: VBoxContainer, exp: ExpeditionData, index: int) -> void:
	var card = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14

	var assigned_name = _get_assigned_names(index)
	if assigned_name.size() > 0:
		sb.border_color = GREEN
		sb.border_width_left = 3
	elif _selected_companion != "":
		# Check if selected companion has any match with this expedition
		var match_count := 0
		for comp in Global.COMPANIONS.values():
			if str(comp.get("Name", "")) == _selected_companion:
				if str(comp.get("Region", "")) == exp.bonus_region:
					match_count += 1
				if str(comp.get("Weapon", "")) == exp.bonus_weapon:
					match_count += 1
				if str(comp.get("Element", "")) == exp.bonus_element:
					match_count += 1
				break
		if match_count >= 2:
			sb.border_color = GREEN
			sb.set_border_width_all(2)
		elif match_count == 1:
			sb.border_color = ACCENT
			sb.set_border_width_all(2)
		else:
			sb.border_color = MUTED
			sb.border_width_left = 1

	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = exp.expedition_name
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(name_label)

	var risk_color = MUTED
	if exp.risk_level == "risky":
		risk_color = RED
	elif exp.risk_level == "moderate":
		risk_color = ACCENT

	var risk_text = "High" if exp.risk_level == "risky" else exp.risk_level.capitalize()
	var desc = Label.new()
	desc.text = "%s | %s risk | Best: %s, %s" % [exp.description, risk_text, exp.bonus_weapon, exp.bonus_element]
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", risk_color)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	# Show expected materials from this expedition's cache
	var cache_materials := _get_expedition_materials(exp)
	if cache_materials.size() > 0:
		var mats_label = Label.new()
		mats_label.text = "Rewards: %s" % ", ".join(cache_materials)
		mats_label.add_theme_font_size_override("font_size", 14)
		mats_label.add_theme_color_override("font_color", SEC)
		mats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(mats_label)

	# Risk indicator
	var failure_rate = _calc_failure_rate(exp, index)
	var chance_label = Label.new()
	chance_label.text = "Success Chance"
	chance_label.add_theme_font_size_override("font_size", 11)
	chance_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(chance_label)
	var risk_bar_bg = ColorRect.new()
	risk_bar_bg.custom_minimum_size = Vector2(0, 6)
	risk_bar_bg.color = Color(0.15, 0.15, 0.15)
	vbox.add_child(risk_bar_bg)
	var risk_bar = ColorRect.new()
	var safety = 1.0 - failure_rate  # 0 = dangerous, 1 = safe
	risk_bar.custom_minimum_size = Vector2(0, 6)
	risk_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	risk_bar.color = Color(RED).lerp(GREEN, safety)
	# Use a container to clip the bar width
	var risk_clip = Control.new()
	risk_clip.custom_minimum_size = Vector2(0, 6)
	risk_clip.size_flags_horizontal = SIZE_EXPAND_FILL
	risk_clip.clip_contents = true
	risk_bar_bg.add_child(risk_clip)
	risk_clip.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	risk_bar.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	risk_bar.anchor_right = safety
	risk_clip.add_child(risk_bar)

	if assigned_name.size() > 0:
		var assigned_label = Label.new()
		assigned_label.text = "Assigned: %s" % ", ".join(assigned_name)
		assigned_label.add_theme_font_size_override("font_size", 14)
		assigned_label.add_theme_color_override("font_color", GREEN)
		assigned_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(assigned_label)

		var btn_row = HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		vbox.add_child(btn_row)

		var unassign_btn = Button.new()
		unassign_btn.text = "Unassign Last"
		unassign_btn.custom_minimum_size = Vector2(0, 30)
		unassign_btn.add_theme_font_size_override("font_size", 13)
		var idx = index
		unassign_btn.pressed.connect(func(): _unassign_expedition(idx))
		btn_row.add_child(unassign_btn)

		# Allow adding more companions to the same expedition
		if _selected_companion != "" and _selected_companion not in assigned_name:
			var add_btn = Button.new()
			add_btn.text = "Add %s" % _selected_companion
			add_btn.custom_minimum_size = Vector2(0, 30)
			add_btn.add_theme_font_size_override("font_size", 13)
			add_btn.pressed.connect(func(): _assign_to_expedition(idx))
			btn_row.add_child(add_btn)
	else:
		var assign_btn = Button.new()
		assign_btn.text = "Assign Companion" if _selected_companion == "" else "Assign %s" % _selected_companion
		assign_btn.custom_minimum_size = Vector2(0, 30)
		assign_btn.add_theme_font_size_override("font_size", 13)
		assign_btn.disabled = _selected_companion == ""
		var idx = index
		assign_btn.pressed.connect(func(): _assign_to_expedition(idx))
		vbox.add_child(assign_btn)

func _build_companion_list(parent: HBoxContainer) -> void:
	var right = VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	parent.add_child(right)

	var header = Label.new()
	header.text = "Idle Companions (%d)" % _available_companions.size()
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", TEXT)
	right.add_child(header)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	right.add_child(scroll)

	var list = VBoxContainer.new()
	list.size_flags_horizontal = SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# Already assigned companions
	var assigned_names: Array = _all_assigned_names()

	for comp in _available_companions:
		var comp_name = str(comp.get("Name", ""))
		if comp_name in assigned_names:
			continue

		var btn = Button.new()
		btn.text = "%s — %s %s (%s)" % [
			comp_name,
			str(comp.get("Element", "")),
			str(comp.get("Weapon", "")),
			str(comp.get("Region", "")),
		]
		btn.add_theme_font_size_override("font_size", 13)
		btn.custom_minimum_size = Vector2(0, 36)

		if _selected_companion == comp_name:
			var btn_sb = StyleBoxFlat.new()
			btn_sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2)
			btn_sb.border_color = ACCENT
			btn_sb.set_border_width_all(2)
			btn_sb.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", btn_sb)

		var cn = comp_name
		btn.pressed.connect(func(): _select_companion(cn))
		list.add_child(btn)

func _select_companion(comp_name: String) -> void:
	if _selected_companion == comp_name:
		_selected_companion = ""
	else:
		_selected_companion = comp_name
	_build_ui()

func _assign_to_expedition(index: int) -> void:
	if _selected_companion == "":
		return
	if _total_deployed() >= _max_slots:
		Toast.notify("All companion slots full (%d/%d)" % [_total_deployed(), _max_slots], Toast.WARNING)
		return
	# Don't allow the same companion assigned twice
	if _selected_companion in _all_assigned_names():
		Toast.notify("%s is already on an expedition" % _selected_companion, Toast.WARNING)
		return
	var current = _get_assigned_names(index)
	current.append(_selected_companion)
	_assignments[index] = current
	_selected_companion = ""
	_save_state()
	_build_ui()

func _unassign_expedition(index: int) -> void:
	var current = _get_assigned_names(index)
	if current.size() > 0:
		current.pop_back()
	if current.is_empty():
		_assignments.erase(index)
		_assignments.erase(str(index))
	else:
		_assignments[index] = current
	_save_state()
	_build_ui()

## Get list of companion names assigned to a given expedition index.
## Supports both old format (string) and new format (array).
func _get_assigned_names(index: int) -> Array:
	var val = _assignments.get(index, _assignments.get(str(index), null))
	if val == null:
		return []
	if val is Array:
		return val
	if val is String and val != "":
		return [val]
	return []

## Total number of companions deployed across all expeditions.
func _total_deployed() -> int:
	var count := 0
	for v in _assignments.values():
		if v is Array:
			count += v.size()
		elif v is String and v != "":
			count += 1
	return count

## All companion names currently assigned anywhere.
func _all_assigned_names() -> Array:
	var names: Array = []
	for v in _assignments.values():
		if v is Array:
			names.append_array(v)
		elif v is String and v != "":
			names.append(v)
	return names

## Calculate current failure rate for an expedition given assigned companions.
func _calc_failure_rate(exp: ExpeditionData, index: int) -> float:
	var base_failure: float
	match exp.risk_level:
		"risky":
			base_failure = 0.90
		"moderate":
			base_failure = 0.60
		_:
			base_failure = 0.15
	var total_matches := 0
	for comp_name in _get_assigned_names(index):
		for comp in Global.COMPANIONS.values():
			if str(comp.get("Name", "")) == comp_name:
				if str(comp.get("Region", "")) == exp.bonus_region:
					total_matches += 1
				if str(comp.get("Weapon", "")) == exp.bonus_weapon:
					total_matches += 1
				if str(comp.get("Element", "")) == exp.bonus_element:
					total_matches += 1
				break
	return maxf(base_failure - (total_matches * 0.05), 0.0)

func _refresh_pool() -> void:
	_expedition_pool = ExpeditionManager.generate_pool(Global.Current_Region)
	_assignments.clear()
	_selected_companion = ""
	_save_state()
	_build_ui()

func _save_state() -> void:
	var pool_dicts = _expedition_pool.map(func(e): return e.to_dict())
	Global._expedition_pool = pool_dicts
	Global._expedition_assignments = _assignments.duplicate()

	# Persist to Party record so it syncs to all clients
	var party = Global.Current_Party
	if party and party.get("id") != null:
		var party_id = int(party.get("id"))
		var updates = [
			{"table": "Party", "record_id": party_id, "field": "Expedition_Pool", "value": JSON.stringify(pool_dicts)},
			{"table": "Party", "record_id": party_id, "field": "Expedition_Assignments", "value": JSON.stringify(_assignments)},
		]
		if NetworkManager.is_host:
			Global.Update_Records(updates)
			NetworkManager.broadcast_table_update("Party")
		else:
			NetworkManager.request_update.rpc_id(1, JSON.stringify(updates))

func _get_expedition_materials(exp: ExpeditionData) -> Array:
	for c in GameDB.material_caches.values():
		var c_region = c.region if c is MaterialCacheData else str(c.get("Region", ""))
		var c_roll = c.roll if c is MaterialCacheData else int(c.get("Roll", 0))
		if c_region == exp.region and c_roll == exp.cache_roll:
			return LootGenerator.parse_materials(c)
	return []
