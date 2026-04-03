class_name PartyCard
extends PanelContainer
## Party member/companion card display component. Builds its own UI programmatically.
## Unified for both Characters and Companions. Call set_data() then refresh() to update.

# ── Theme Colors ─────────────────────────────────────────────────────────────
const COLOR_BG = Color(0.102, 0.122, 0.169)
const COLOR_BORDER = Color(0.165, 0.188, 0.251)
const COLOR_BORDER_SHIELD = Color(0.58, 0.64, 0.72)
const COLOR_BORDER_ACTIVE = Color(0.788, 0.659, 0.298)
const COLOR_BORDER_COMPANION = Color(0.292, 0.855, 0.498)
const COLOR_TEXT_PRIMARY = Color(0.941, 0.949, 0.973)
const COLOR_TEXT_MUTED = Color(0.533, 0.573, 0.659)
const COLOR_GREEN = Color(0.133, 0.773, 0.369)
const COLOR_YELLOW = Color(0.918, 0.702, 0.031)
const COLOR_RED = Color(0.937, 0.267, 0.267)

# ── State ────────────────────────────────────────────────────────────────────
var _battler_name: String = ""
var _battler_type: String = ""

static func _sf(base: int) -> int:
	var s = preload("res://Scenes/settings_popup.gd")
	return s.scaled_font(base)  # "Character" or "Companion"
var _is_active_turn: bool = false
var _ui_built: bool = false

# ── Node References (created in _build_ui) ───────────────────────────────────
var _portrait: TextureRect
var _name_label: Label
var _subtitle_label: Label
var _element_icon: TextureRect
var _hp_bar: ProgressBar
var _hp_text: Label
var _shield_row: HBoxContainer
var _shield_label: Label
var _effects_label: Label
var _downed_label: Label


func _ready() -> void:
	if _battler_name != "":
		_build_ui()
		refresh()


func set_data(battler_name: String, battler_type: String) -> void:
	_battler_name = battler_name
	_battler_type = battler_type
	if not _ui_built:
		_build_ui()
	refresh()


func refresh() -> void:
	if not _ui_built or _battler_name == "":
		return

	var data: Dictionary = _get_record()
	if data.is_empty():
		push_warning("PartyCard.refresh: no data for '%s' (%s)" % [_battler_name, _battler_type])
		return

	# Name
	_name_label.text = _battler_name

	# Subtitle (companions only)
	if _battler_type == "Companion":
		var owner: String = str(data.get("Owner", ""))
		if owner != "":
			_subtitle_label.text = "%s's companion" % owner
		else:
			_subtitle_label.text = "Companion"
		_subtitle_label.visible = true
	else:
		_subtitle_label.visible = false

	# Portrait
	var portrait_val = data.get("Portrait", "")
	var portrait_path: String = ""
	if _battler_type == "Character" and portrait_val != null and str(portrait_val) != "":
		portrait_path = "res://UI/Emotes/%s" % str(portrait_val)
	else:
		portrait_path = "res://UI/Character Portraits/%s.png" % _battler_name

	if ResourceLoader.exists(portrait_path):
		var tex = load(portrait_path)
		if tex is Texture2D:
			_portrait.texture = tex
	else:
		_portrait.texture = null

	# Element icon
	_update_element(data)

	# HP — use CharacterManager calculated stats (includes effect bonuses like +30% HP)
	var hp_cur: float = float(data.get("Current_Health", 0.0))
	var hp_max: float = float(data.get("Max_Health", 1.0))
	if _battler_type == "Character":
		var calc = CharacterManager.get_stats(_battler_name)
		if calc and calc.health > 0:
			hp_max = calc.health
	var pct: float = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0

	_hp_bar.value = pct
	_hp_text.text = "%d / %d" % [int(hp_cur), int(hp_max)]

	# HP bar color
	var bar_color: Color
	if pct >= 75.0:
		bar_color = COLOR_GREEN
	elif pct >= 50.0:
		bar_color = COLOR_YELLOW
	elif pct >= 25.0:
		bar_color = COLOR_YELLOW
	else:
		bar_color = COLOR_RED

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = bar_color
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", bar_fill)

	# Shield
	var shield_hp: int = 0
	var shield_duration: int = 0
	var sh_val = data.get("Shield_Health")
	if sh_val != null:
		shield_hp = int(sh_val)
		shield_duration = int(data.get("Shield_Duration", 0))

	if shield_hp > 0:
		_shield_label.text = "Shield: %d HP \u00b7 %dt" % [shield_hp, shield_duration]
		_shield_row.visible = true
	else:
		_shield_row.visible = false

	# Downed
	if hp_cur <= 0:
		_downed_label.visible = true
	else:
		_downed_label.visible = false

	# Effects
	_update_effects()

	# Border update (shield / active / companion)
	_update_border()


func set_active_turn(is_active: bool) -> void:
	_is_active_turn = is_active
	if _ui_built:
		_update_border()


func _get_record() -> Dictionary:
	if _battler_type == "Character":
		var cid: String = Global.CHARACTERS_NAME.get(_battler_name, "")
		if cid != "":
			return Global.CHARACTERS.get(cid, {})
	elif _battler_type == "Companion":
		var comp_id: String = Global.COMPANIONS_NAME.get(_battler_name, "")
		if comp_id != "":
			return Global.COMPANIONS.get(comp_id, {})
	return {}


func _update_element(data: Dictionary) -> void:
	var elem: String = str(data.get("Applied_Element", "None"))

	if elem != "None" and elem != "":
		var icon_path: String = "res://UI/Element Icons/%s.png" % elem
		if ResourceLoader.exists(icon_path):
			_element_icon.texture = load(icon_path)
		else:
			_element_icon.texture = null

		# Build reaction tooltip — only show reactions where this element is first
		# Shows: what second element triggers it, what happens, and if it's good/bad
		var tip: String = "%s applied\n" % elem
		var seen = {}
		for reaction in GameDB.reactions_for_element(elem):
			if reaction.first_element != elem:
				continue
			var key = reaction.second_element
			if seen.has(key):
				continue
			seen[key] = true
			var outcome_tag = ""
			match reaction.outcome:
				"FAVORABLE": outcome_tag = " +"
				"UNFAVORABLE": outcome_tag = " -"
				"NEUTRAL": outcome_tag = " ~"
			tip += "+ %s =%s %s\n\n" % [key, outcome_tag, _wrap_effect_text(str(reaction.effect), 80)]
		_element_icon.tooltip_text = tip.strip_edges()
		_element_icon.visible = true
	else:
		_element_icon.texture = null
		_element_icon.tooltip_text = ""
		_element_icon.visible = false


func _update_effects() -> void:
	var effects: Array = Global.get_battler_effects(_battler_name)

	if effects.is_empty():
		_effects_label.text = "No effects"
		_effects_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		_effects_label.tooltip_text = "No active effects on %s" % _battler_name
		return

	_effects_label.text = "%d effect(s)" % effects.size()
	_effects_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)

	var tip: String = ""
	for fx in effects:
		var dur = fx.get("turns_remaining", 0)
		var dur_str = "perm" if dur == -1 else (str(dur) + " left" if dur > 0 else "expiring")
		var stacks_str = ""
		if fx.get("stacks", 0) > 0:
			stacks_str = " x%d" % fx.get("stacks")
		var desc = str(fx.get("description", ""))
		var etype = str(fx.get("effect_type", ""))
		var is_bad = etype in ["FLAT_DAMAGE", "DOT", "DOT_PER_ACTION", "SKIP_TURN", "STUN", "FREEZE", "ROOT", "BLIND", "SLOW", "DISARM", "FEAR", "ROLL_DISADVANTAGE", "RANDOM_TARGET"]
		var marker = "[-] " if is_bad else "[+] "
		if desc != "":
			tip += "%s%s %s%s:\n  %s\n\n" % [marker, dur_str, fx.get("source_name", "?"), stacks_str, _wrap_effect_text(desc, 80)]
		else:
			tip += "%s%s %s%s\n\n" % [marker, dur_str, fx.get("source_name", "?"), stacks_str]
	_effects_label.tooltip_text = tip.strip_edges()


func _update_border() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	# Determine border state priority: active turn > shield > companion > default
	var has_shield: bool = false
	var data: Dictionary = _get_record()
	if not data.is_empty():
		var sh_val = data.get("Shield_Health")
		if sh_val != null and int(sh_val) > 0:
			has_shield = true

	if _is_active_turn:
		style.border_color = COLOR_BORDER_ACTIVE
		style.set_border_width_all(2)
		# Subtle glow via shadow
		style.shadow_color = Color(COLOR_BORDER_ACTIVE, 0.3)
		style.shadow_size = 4
	elif has_shield:
		style.border_color = COLOR_BORDER_SHIELD
		style.set_border_width_all(3)
	elif _battler_type == "Companion":
		# Companion indicator: green border on all sides (thicker left)
		style.border_color = COLOR_BORDER_COMPANION
		style.set_border_width_all(1)
		style.border_width_left = 3
	else:
		style.border_color = COLOR_BORDER
		style.set_border_width_all(1)

	add_theme_stylebox_override("panel", style)


func _build_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	# Base panel style
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = COLOR_BG
	base_style.border_color = COLOR_BORDER
	base_style.set_border_width_all(1)
	base_style.corner_radius_top_left = 6
	base_style.corner_radius_top_right = 6
	base_style.corner_radius_bottom_left = 6
	base_style.corner_radius_bottom_right = 6
	base_style.content_margin_left = 10
	base_style.content_margin_right = 10
	base_style.content_margin_top = 8
	base_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", base_style)
	custom_minimum_size = Vector2(240, 0)

	# Root HBox: portrait | info column
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	# Portrait
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(52, 52)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(_portrait)

	# Info column
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# Name row: name + element icon
	var name_row = HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	vbox.add_child(name_row)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", _sf(16))
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_label)

	_element_icon = TextureRect.new()
	_element_icon.custom_minimum_size = Vector2(22, 22)
	_element_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_element_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_element_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	_element_icon.visible = false
	name_row.add_child(_element_icon)

	# Subtitle (companions only)
	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", _sf(13))
	_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_subtitle_label.visible = false
	vbox.add_child(_subtitle_label)

	# HP bar
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 10)
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	_hp_bar.show_percentage = false
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# HP bar background style
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.17, 0.22)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("background", bar_bg)

	# HP bar fill style (green by default)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_GREEN
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	_hp_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_hp_bar)

	# HP text
	_hp_text = Label.new()
	_hp_text.add_theme_font_size_override("font_size", _sf(14))
	_hp_text.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(_hp_text)

	# Shield row
	_shield_row = HBoxContainer.new()
	_shield_row.add_theme_constant_override("separation", 4)
	_shield_row.visible = false
	vbox.add_child(_shield_row)

	var shield_icon = TextureRect.new()
	shield_icon.custom_minimum_size = Vector2(16, 16)
	shield_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shield_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Use a placeholder color rect approach since we may not have a shield icon
	_shield_row.add_child(shield_icon)

	_shield_label = Label.new()
	_shield_label.add_theme_font_size_override("font_size", _sf(13))
	_shield_label.add_theme_color_override("font_color", COLOR_BORDER_SHIELD)
	_shield_row.add_child(_shield_label)

	# Effects
	_effects_label = Label.new()
	_effects_label.add_theme_font_size_override("font_size", _sf(13))
	_effects_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_effects_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_effects_label)

	# Downed label
	_downed_label = Label.new()
	_downed_label.text = "DOWNED"
	_downed_label.add_theme_font_size_override("font_size", _sf(14))
	_downed_label.add_theme_color_override("font_color", COLOR_RED)
	_downed_label.visible = false
	vbox.add_child(_downed_label)


func _wrap_effect_text(text: String, limit: int) -> String:
	var result = ""
	var start = 0
	while start < text.length():
		var end = mini(start + limit, text.length())
		if end < text.length():
			var segment = text.substr(start, end - start)
			var space_idx = segment.rfind(" ")
			if space_idx != -1:
				end = start + space_idx + 1
		result += text.substr(start, end - start).strip_edges()
		if end < text.length():
			result += "\n  "
		start = end
	return result
