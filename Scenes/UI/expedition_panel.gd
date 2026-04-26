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
	var saved_pool = Global.get("_expedition_pool")
	if saved_pool is Array and saved_pool.size() > 0:
		_expedition_pool = []
		for d in saved_pool:
			_expedition_pool.append(ExpeditionData.from_dict(d))
	else:
		_expedition_pool = ExpeditionManager.generate_pool(Global.Current_Region)
		Global._expedition_pool = _expedition_pool.map(func(e): return e.to_dict())

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

	_max_slots = 1
	for char in Global.CHARACTERS.values():
		if str(char.get("User_Type", "")) != "Dungeon Master":
			_max_slots = maxi(_max_slots, int(char.get("Ascension_Rank", 0)))
	_max_slots = maxi(_max_slots, 1)

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
	slots_label.text = "Slots: %d / %d" % [_assignments.size(), _max_slots]
	slots_label.add_theme_font_size_override("font_size", 16)
	slots_label.add_theme_color_override("font_color", SEC)
	header_row.add_child(slots_label)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(func(): panel_closed.emit())
	header_row.add_child(close_btn)

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
		var exp_name: String = str(result.get("expedition", ""))
		var result_label = Label.new()
		if loot.is_empty():
			result_label.text = "%s returned empty-handed from %s" % [comp_name, exp_name]
			result_label.add_theme_color_override("font_color", RED)
		else:
			var items_arr: Array = []
			for k in loot:
				items_arr.append("%s x%d" % [k, loot[k]])
			result_label.text = "%s from %s: %s" % [comp_name, exp_name, ", ".join(items_arr)]
			result_label.add_theme_color_override("font_color", TEXT)
		result_label.add_theme_font_size_override("font_size", 13)
		result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(result_label)

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
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10

	var assigned_name = _assignments.get(index, _assignments.get(str(index), ""))
	if assigned_name != "":
		sb.border_color = GREEN
		sb.border_width_left = 3
	elif _selected_companion != "":
		sb.border_color = ACCENT
		sb.border_width_left = 1

	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var name_label = Label.new()
	name_label.text = exp.expedition_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", TEXT)
	vbox.add_child(name_label)

	var risk_color = MUTED
	if exp.risk_level == "risky":
		risk_color = RED
	elif exp.risk_level == "moderate":
		risk_color = ACCENT

	var desc = Label.new()
	desc.text = "%s | %s risk | Best: %s, %s" % [exp.description, exp.risk_level.capitalize(), exp.bonus_weapon, exp.bonus_element]
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", risk_color)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	if assigned_name != "":
		var assigned_label = Label.new()
		assigned_label.text = "Assigned: %s" % assigned_name
		assigned_label.add_theme_font_size_override("font_size", 13)
		assigned_label.add_theme_color_override("font_color", GREEN)
		vbox.add_child(assigned_label)

		var unassign_btn = Button.new()
		unassign_btn.text = "Unassign"
		unassign_btn.custom_minimum_size = Vector2(0, 28)
		unassign_btn.add_theme_font_size_override("font_size", 12)
		var idx = index
		unassign_btn.pressed.connect(func(): _unassign_expedition(idx))
		vbox.add_child(unassign_btn)
	else:
		var assign_btn = Button.new()
		assign_btn.text = "Assign Companion" if _selected_companion == "" else "Assign %s" % _selected_companion
		assign_btn.custom_minimum_size = Vector2(0, 28)
		assign_btn.add_theme_font_size_override("font_size", 12)
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
	var assigned_names: Array = []
	for v in _assignments.values():
		assigned_names.append(str(v))

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
	if _assignments.size() >= _max_slots and not _assignments.has(index) and not _assignments.has(str(index)):
		Toast.notify("All expedition slots full (max %d)" % _max_slots, Toast.WARNING)
		return
	_assignments[index] = _selected_companion
	_selected_companion = ""
	_save_state()
	_build_ui()

func _unassign_expedition(index: int) -> void:
	_assignments.erase(index)
	_assignments.erase(str(index))
	_save_state()
	_build_ui()

func _save_state() -> void:
	Global._expedition_pool = _expedition_pool.map(func(e): return e.to_dict())
	Global._expedition_assignments = _assignments.duplicate()
