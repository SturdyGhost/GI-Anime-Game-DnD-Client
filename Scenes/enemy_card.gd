class_name EnemyCard
extends PanelContainer
## Enemy card display component. Builds its own UI programmatically (no .tscn needed).
## Shows condition text instead of HP bars. Call set_data() then refresh() to update.

# ── Theme Colors ─────────────────────────────────────────────────────────────
const COLOR_BG = Color(0.102, 0.122, 0.169)
const COLOR_BORDER = Color(0.165, 0.188, 0.251)
const COLOR_BORDER_SHIELD = Color(0.58, 0.64, 0.72)
const COLOR_BORDER_TARGETED = Color(0.788, 0.659, 0.298)
const COLOR_TEXT_PRIMARY = Color(0.941, 0.949, 0.973)
const COLOR_TEXT_MUTED = Color(0.533, 0.573, 0.659)
const COLOR_GREEN = Color(0.133, 0.773, 0.369)
const COLOR_YELLOW = Color(0.918, 0.702, 0.031)
const COLOR_RED = Color(0.937, 0.267, 0.267)
const COLOR_DEAD = Color(0.6, 0.6, 0.6, 0.8)

const TIER_COLORS = {
	"Common": Color(0.612, 0.639, 0.678),
	"Uncommon": Color(0.290, 0.871, 0.502),
	"Rare": Color(0.376, 0.647, 0.980),
	"Epic": Color(0.753, 0.518, 0.988),
	"Legendary": Color(0.788, 0.659, 0.298),
}

# ── State ────────────────────────────────────────────────────────────────────
var _enemy_id: String = ""
var _ui_built: bool = false

static func _sf(base: int) -> int:
	var s = preload("res://Scenes/settings_popup.gd")
	return s.scaled_font(base)

# ── Node References (created in _build_ui) ───────────────────────────────────
var _portrait: TextureRect
var _name_label: Label
var _tier_label: Label
var _phase_label: Label
var _condition_label: Label
var _shield_label: Label
var _element_icon: TextureRect
var _effects_label: Label


## Enemy-name colour by tier. Common reads as regular text; rarer tiers and the
## two boss tiers each get a distinct tint. Tolerant of casing/underscores in the
## raw tier string (data uses "common", "Epic", "story_boss", etc.).
func _name_color_for_tier(tier_raw: String) -> Color:
	match tier_raw.strip_edges().to_lower():
		"uncommon":   return Color(0.40, 0.91, 0.56)   # light green
		"rare":       return Color(0.46, 0.71, 1.00)   # light blue
		"epic":       return Color(0.80, 0.58, 1.00)   # light purple
		"legendary":  return Color(0.96, 0.80, 0.40)   # light gold/orange
		"story_boss": return Color(0.98, 0.46, 0.46)   # crimson
		"world_boss": return Color(0.36, 0.93, 0.92)   # cyan
		_:            return COLOR_TEXT_PRIMARY         # common / unknown = regular text


func _ready() -> void:
	if _enemy_id != "":
		_build_ui()
		refresh()


func set_data(record_id: String) -> void:
	_enemy_id = record_id
	if not _ui_built:
		_build_ui()
	refresh()


func refresh() -> void:
	if not _ui_built or _enemy_id == "":
		return

	var e: Dictionary = Global.BATTLEENEMIES.get(_enemy_id, {})
	if e.is_empty():
		push_warning("EnemyCard.refresh: no data for enemy_id '%s'" % _enemy_id)
		return

	var ename: String = str(e.get("EnemyName", ""))
	var eid: int = int(e.get("id", 0))
	var enemy_def_id = e.get("EnemyID")
	var edata: EnemyData = GameDB.get_enemy(int(enemy_def_id)) if enemy_def_id != null else null

	# Name — colour-coded by the enemy's tier
	_name_label.text = "%s %d" % [ename, eid]
	_name_label.add_theme_color_override("font_color", _name_color_for_tier(str(edata.tier) if edata else ""))

	# Tier
	var tier_name: String = str(edata.tier).capitalize() if edata else ""
	_tier_label.text = tier_name
	_tier_label.add_theme_color_override("font_color", TIER_COLORS.get(tier_name, COLOR_TEXT_MUTED))

	# Phase — read phase_count from the enemy definition
	var phase = int(e.get("Phase", 1))
	var max_phase = 1
	if edata:
		max_phase = edata.phase_count if edata.phase_count > 0 else 1
	if max_phase > 1:
		var phase_name = ""
		if edata:
			phase_name = edata.get_phase_name(phase)
		if phase_name != "":
			_phase_label.text = "Phase %d / %d — %s" % [phase, max_phase, phase_name]
		else:
			_phase_label.text = "Phase %d / %d" % [phase, max_phase]
		_phase_label.visible = true
	else:
		_phase_label.visible = false

	# Portrait
	var portrait_path: String = "res://UI/Enemy Portraits/%s.png" % ename
	if ResourceLoader.exists(portrait_path):
		var tex = load(portrait_path)
		if tex is Texture2D:
			_portrait.texture = tex
	else:
		_portrait.texture = null

	# Condition (HP-based text, no numbers)
	var hp_cur: float = float(e.get("Current_Health", 0.0))
	var hp_max: float = float(e.get("Max_Health", 1.0))
	var pct: float = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0

	var condition_text: String
	var condition_color: Color
	if pct >= 75.0:
		condition_text = "Doing great"
		condition_color = COLOR_GREEN
	elif pct >= 50.0:
		condition_text = "Hurting a bit"
		condition_color = COLOR_YELLOW
	elif pct >= 25.0:
		condition_text = "In trouble"
		condition_color = COLOR_YELLOW
	else:
		condition_text = "Real ragged"
		condition_color = COLOR_RED

	_condition_label.text = condition_text
	_condition_label.add_theme_color_override("font_color", condition_color)

	# Shield
	var shield_hp: int = 0
	var shield_duration: int = 0
	var sh_val = e.get("Shield_Health")
	if sh_val != null:
		shield_hp = int(sh_val)
		shield_duration = int(e.get("Shield_Duration", 0))

	if shield_hp > 0:
		_shield_label.text = "Shielded"
		_shield_label.visible = true
	else:
		_shield_label.visible = false

	_apply_shield_border(shield_hp > 0)

	# Element icon
	var elem: String = str(e.get("AppliedElement", "None"))
	if elem != "None" and elem != "":
		var icon_path: String = "res://UI/Element Icons/%s.png" % elem
		if ResourceLoader.exists(icon_path):
			_element_icon.texture = load(icon_path)
		else:
			_element_icon.texture = null
		# Build reaction tooltip — only where this element is first, no duplicates
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

	# Effects
	_update_effects(ename, eid)

	# Dead state
	var killed: bool = e.get("Killed", false)
	if killed:
		self.modulate = COLOR_DEAD
	else:
		self.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _update_effects(ename: String, eid: int) -> void:
	var battler_label: String = "%s %d" % [ename, eid]
	var effects: Array = Global.get_battler_effects(battler_label)

	if effects.is_empty():
		_effects_label.text = ""
		_effects_label.tooltip_text = ""
		return

	_effects_label.text = "%d effect(s)" % effects.size()

	var tip: String = ""
	for fx in effects:
		var dur = fx.get("turns_remaining", 0)
		var dur_str = "perm" if dur == -1 else (str(dur) + " left" if dur > 0 else "expiring")
		var stacks_str = ""
		if fx.get("stacks", 0) > 0:
			stacks_str = " x%d" % fx.get("stacks")
		var desc = str(fx.get("description", ""))
		var etype = str(fx.get("effect_type", ""))
		# Mark beneficial vs harmful
		var is_bad = etype in ["FLAT_DAMAGE", "DOT", "DOT_PER_ACTION", "SKIP_TURN", "STUN", "FREEZE", "ROOT", "BLIND", "SLOW", "DISARM", "FEAR", "ROLL_DISADVANTAGE", "RANDOM_TARGET"]
		var marker = "[-] " if is_bad else "[+] "
		if desc != "":
			tip += "%s%s %s%s:\n  %s\n\n" % [marker, dur_str, fx.get("source_name", "?"), stacks_str, _wrap_effect_text(desc, 80)]
		else:
			tip += "%s%s %s%s\n\n" % [marker, dur_str, fx.get("source_name", "?"), stacks_str]
	_effects_label.tooltip_text = tip.strip_edges()


func _apply_shield_border(has_shield: bool) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	if has_shield:
		style.border_color = COLOR_BORDER_SHIELD
		style.set_border_width_all(3)
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
	base_style.content_margin_left = 14
	base_style.content_margin_right = 14
	base_style.content_margin_top = 12
	base_style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", base_style)
	custom_minimum_size = Vector2(340, 0)

	# Root HBox: portrait | info column
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	add_child(hbox)

	# Portrait
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(180, 180)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(_portrait)

	# Info column
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# Name
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", _sf(27))
	_name_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.custom_minimum_size.y = 24
	var settings = LabelSettings.new()
	settings.font_size = 27
	var font = ThemeDB.fallback_font
	if font:
		settings.font = font
	_name_label.label_settings = settings
	vbox.add_child(_name_label)

	# Tier (own row)
	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", _sf(23))
	_tier_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_tier_label.custom_minimum_size.y = 22
	vbox.add_child(_tier_label)

	# Phase
	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", _sf(23))
	_phase_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_phase_label.custom_minimum_size.y = 22
	_phase_label.visible = false
	vbox.add_child(_phase_label)

	# Condition
	_condition_label = Label.new()
	_condition_label.add_theme_font_size_override("font_size", _sf(27))
	_condition_label.add_theme_color_override("font_color", COLOR_GREEN)
	_condition_label.custom_minimum_size.y = 24
	vbox.add_child(_condition_label)

	# Bottom row: shield + element + effects
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom)

	_shield_label = Label.new()
	_shield_label.text = "Shielded"
	_shield_label.add_theme_font_size_override("font_size", _sf(23))
	_shield_label.add_theme_color_override("font_color", COLOR_BORDER_SHIELD)
	_shield_label.custom_minimum_size.y = 22
	_shield_label.visible = false
	bottom.add_child(_shield_label)

	_element_icon = TextureRect.new()
	_element_icon.custom_minimum_size = Vector2(32, 32)
	_element_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_element_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_element_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	_element_icon.visible = false
	bottom.add_child(_element_icon)

	_effects_label = Label.new()
	_effects_label.add_theme_font_size_override("font_size", _sf(23))
	_effects_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	_effects_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_effects_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effects_label.custom_minimum_size.y = 22
	bottom.add_child(_effects_label)


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
