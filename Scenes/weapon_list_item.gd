extends GridContainer

signal selected(weapon_data: Dictionary)
signal data_ready

# ---------------- nodes ----------------
@onready var NameLabel: RichTextLabel       = $NameLabel
@onready var TypeLabel: RichTextLabel       = $TypeLabel
@onready var RegionLabel: RichTextLabel     = $RegionLabel
@onready var RefinementLabel: RichTextLabel = $RefinementLabel
@onready var Stat1TypeLabel: RichTextLabel  = $Stat1TypeLabel
@onready var Stat1ValueLabel: RichTextLabel = $Stat1ValueLabel
@onready var Stat2TypeLabel: RichTextLabel  = $Stat2TypeLabel
@onready var Stat2ValueLabel: RichTextLabel = $Stat2ValueLabel
@onready var Stat3TypeLabel: RichTextLabel  = $Stat3TypeLabel
@onready var Stat3ValueLabel: RichTextLabel = $Stat3ValueLabel
@onready var EffectLabel: RichTextLabel     = $EffectLabel
@onready var EquipCheck: CheckBox           = $EquipCheck
@onready var _cols: Array[Control] = [
	$NameLabel,
	$TypeLabel,
	$RegionLabel,
	$RefinementLabel,
	$Stat1TypeLabel,
	$Stat1ValueLabel,
	$Stat2TypeLabel,
	$Stat2ValueLabel,
	$Stat3TypeLabel,
	$Stat3ValueLabel,
	$EffectLabel,
	$EquipCheck,
]

# ---------------- data ----------------
var weapon_data: Dictionary
var is_equipped: bool = false
var weapon
var rarity
var region
var type
var effect
var stat1_type
var stat2_type
var stat3_type
var stat1_value
var stat2_value
var stat3_value
var refinement
var CELL_BG   := Color("2f3d44")
const CELL_BORDER   := Color("a88442")
const CELL_RADIUS: float = 6.0
const GUTTER_X: float = 0.0   # horizontal gap inside each cell
const GUTTER_Y: float = 0.0   # vertical gap inside each cell
var _cell_box: StyleBoxFlat

# Store unformatted strings so we can re-render and re-highlight cleanly
var plain: Dictionary = {
	"Name": "",
	"Type": "",
	"Region": "",
	"Rarity": "",
	"Refinement": "1",
	"Stat1": "",
	"Stat1Value": "0",
	"Stat2": "",
	"Stat2Value": "0",
	"Stat3": "",
	"Stat3Value": "0",
	"Effect": ""
}

const HIGHLIGHT_COLOR := "#E2C290" # your pale gold

func _ready() -> void:
	_build_stylebox()
	CELL_BG.a = 0.35
	EquipCheck.toggled.connect(_on_selected)
	# Redraw when the row or any column resizes
	resized.connect(queue_redraw)
	for c in _cols:
		if c and c.has_signal("resized"):
			c.resized.connect(queue_redraw)
	# also after first layout pass
	call_deferred("queue_redraw")

func _build_stylebox():
	_cell_box = StyleBoxFlat.new()
	_cell_box.bg_color = CELL_BG
	_cell_box.border_color = CELL_BORDER
	_cell_box.border_width_top = 4
	_cell_box.border_width_bottom = 4
	_cell_box.border_width_left = 4
	_cell_box.border_width_right = 4
	_cell_box.border_blend = true
	_cell_box.corner_radius_top_left = CELL_RADIUS
	_cell_box.corner_radius_top_right = CELL_RADIUS
	_cell_box.corner_radius_bottom_left = CELL_RADIUS
	_cell_box.corner_radius_bottom_right = CELL_RADIUS
	_cell_box.anti_aliasing = true

func _safe_str(value) -> String:
	if value == null:
		return ""
	return str(value)

# ------------ existing setter (kept) + now populates 'plain' ------------
func set_weapon_data(data: Dictionary) -> void:
	weapon_data = data

	weapon      = data.get("Weapon", "Unnamed")
	type        = data.get("Type", "Unknown")
	region      = data.get("Region", "Unknown")
	rarity      = data.get("Rarity", "")
	refinement  = data.get("Refinement", 1)
	effect      = data.get("Effect", "")
	is_equipped = data.get("Equipped", false)

	stat1_type  = _safe_str(data.get("Stat_1_Type"))
	stat2_type  = _safe_str(data.get("Stat_2_Type"))
	stat3_type  = _safe_str(data.get("Stat_3_Type"))
	stat1_value = _safe_str(data.get("Stat_1_Value"))
	stat2_value = _safe_str(data.get("Stat_2_Value"))
	stat3_value = _safe_str(data.get("Stat_3_Value"))

	# Fill plain dictionary for consistent rendering/highlighting
	plain.Name       = str(weapon)
	plain.Type       = str(type)
	plain.Region     = str(region)
	plain.Rarity     = str(rarity)
	plain.Refinement = str(refinement)
	plain.Stat1      = str(stat1_type)
	plain.Stat1Value = str(stat1_value)
	plain.Stat2      = str(stat2_type)
	plain.Stat2Value = str(stat2_value)
	plain.Stat3      = str(stat3_type)
	plain.Stat3Value = str(stat3_value)
	plain.Effect     = str(effect)

	_render_plain()

	EquipCheck.button_pressed = is_equipped
	emit_signal("data_ready")

# Render without highlights
func _render_plain() -> void:
	_set_bb(NameLabel,        plain.Name)
	_set_bb(TypeLabel,        plain.Type)
	_set_bb(RegionLabel,      plain.Region,    false, true)  # fit "Mondstadt" etc.
	_set_bb(RefinementLabel,  plain.Refinement)
	_set_bb(Stat1TypeLabel,   plain.Stat1)
	_set_bb(Stat1ValueLabel,  plain.Stat1Value)
	_set_bb(Stat2TypeLabel,   plain.Stat2)
	_set_bb(Stat2ValueLabel,  plain.Stat2Value)
	_set_bb(Stat3TypeLabel,   plain.Stat3)
	_set_bb(Stat3ValueLabel,  plain.Stat3Value)
	_set_bb(EffectLabel,      plain.Effect)

func _set_bb(lbl: Node, s: String, is_bbcode: bool = false, fit_word: bool = false, max_size: int = 0) -> void:
	if lbl and lbl is RichTextLabel:
		var rtl := lbl as RichTextLabel
		rtl.bbcode_enabled = true

		if fit_word:
			var measure_text := s
			if is_bbcode:
				measure_text = _strip_bbcode(s)
			await _fit_word_safe(rtl, measure_text, max_size)

		if is_bbcode:
			rtl.text = s
		else:
			rtl.text = _bb_escape(s)

	elif lbl and lbl is Label:
		(lbl as Label).text = s

func _strip_bbcode(s: String) -> String:
	var out := s
	out = out.replace("[lb]", "[").replace("[rb]", "]")
	var re := RegEx.new()
	re.compile("\\[/?(color|b|i|u|s|url|img|font(?:=[^\\]]+)?|size=[^\\]]+)\\]")
	out = re.sub(out, "", true)
	return out

# ------------ API for parent (sorting / searching) ------------
func get_sort_value(col: String):
	match col:
		# support both header aliases: "Name"/"Weapon", "Stat1"/"Stat1Type", etc.
		"Name", "Weapon":          return plain.Name
		"Type":                    return plain.Type
		"Region":                  return plain.Region
		"Rarity":                  return plain.Rarity
		"Refinement":              return float(plain.Refinement)
		"Stat1", "Stat1Type":      return plain.Stat1
		"Stat1Value":              return float(plain.Stat1Value)
		"Stat2", "Stat2Type":      return plain.Stat2
		"Stat2Value":              return float(plain.Stat2Value)
		"Stat3", "Stat3Type":      return plain.Stat3
		"Stat3Value":              return float(plain.Stat3Value)
		"Effect":                  return plain.Effect
		"Equipped":                return 1 if EquipCheck.button_pressed else 0
		_:                         return ""

func get_search_blob() -> String:
	return ("%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		plain.Name,
		plain.Type,
		plain.Region,
		plain.Refinement,
		plain.Stat1,
		plain.Stat1Value,
		plain.Stat2,
		plain.Stat2Value,
		plain.Stat3,
		plain.Stat3Value,
		plain.Effect,
		str(is_equipped)
	]).to_lower()

func apply_highlight(tokens: Array) -> void:
	_set_bb(NameLabel,        _highlight_bbcode(plain.Name, tokens), true)
	_set_bb(TypeLabel,        _highlight_bbcode(plain.Type, tokens), true)
	_set_bb(RegionLabel,      _highlight_bbcode(plain.Region, tokens), true, true)
	_set_bb(RefinementLabel,  _highlight_bbcode(plain.Refinement, tokens), true)
	_set_bb(Stat1TypeLabel,   _highlight_bbcode(plain.Stat1, tokens), true)
	_set_bb(Stat1ValueLabel,  _highlight_bbcode(plain.Stat1Value, tokens), true)
	_set_bb(Stat2TypeLabel,   _highlight_bbcode(plain.Stat2, tokens), true)
	_set_bb(Stat2ValueLabel,  _highlight_bbcode(plain.Stat2Value, tokens), true)
	_set_bb(Stat3TypeLabel,   _highlight_bbcode(plain.Stat3, tokens), true)
	_set_bb(Stat3ValueLabel,  _highlight_bbcode(plain.Stat3Value, tokens), true)
	_set_bb(EffectLabel,      _highlight_bbcode(plain.Effect, tokens), true)

# ------------ helpers ------------
func _highlight_bbcode(plain_text: String, tokens: Array) -> String:
	if tokens.is_empty() or plain_text.is_empty():
		return _bb_escape(plain_text)

	var lower = plain_text.to_lower()
	var ranges: Array = [] # Array[Vector2i(start, end)]

	for t in tokens:
		if t == "":
			continue
		var needle = str(t).to_lower()
		var i = 0
		while true:
			var idx = lower.findn(needle, i)
			if idx == -1:
				break
			ranges.append(Vector2i(idx, idx + needle.length()))
			i = idx + needle.length()

	if ranges.is_empty():
		return _bb_escape(plain_text)

	ranges.sort_custom(func(a, b): return a.x < b.x)
	ranges = _merge_ranges(ranges)

	var out = ""
	var pos = 0
	for r in ranges:
		if pos < r.x:
			out += _bb_escape(plain_text.substr(pos, r.x - pos))
		out += "[color=%s]%s[/color]" % [HIGHLIGHT_COLOR, _bb_escape(plain_text.substr(r.x, r.y - r.x))]
		pos = r.y
	if pos < plain_text.length():
		out += _bb_escape(plain_text.substr(pos, plain_text.length() - pos))
	return out

func _merge_ranges(ranges: Array) -> Array:
	var merged: Array = []
	for r in ranges:
		if merged.is_empty():
			merged.append(r)
		else:
			var last: Vector2i = merged[merged.size() - 1]
			if r.x <= last.y:
				last.y = max(last.y, r.y)
				merged[merged.size() - 1] = last
			else:
				merged.append(r)
	return merged

func _bb_escape(s: String) -> String:
	# Escape BBCode brackets for RichTextLabel
	return s.replace("[", "[lb]").replace("]", "[rb]")

# Fit the longest word so it won't wrap mid-word
func _fit_word_safe(rtl: RichTextLabel, plain_text: String, max_size: int, min_size: int = 10) -> void:
	if rtl == null:
		return
	rtl.bbcode_enabled = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # keep word boundaries

	# Measure against the current control width
	var width := rtl.size.x
	if width <= 0.0:
		await get_tree().process_frame
		width = rtl.size.x

	var font := rtl.get_theme_font("normal")
	var base_size := rtl.get_theme_font_size("normal")
	if font == null:
		return

	var words := plain_text.split(" ", false, 0)
	if words.is_empty():
		words = [plain_text]

	var size := max_size if max_size > 0 else base_size
	while size > min_size:
		var longest := 0.0
		for w in words:
			var w_width := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if w_width > longest:
				longest = w_width
		if longest <= width:
			break
		size -= 1

	rtl.add_theme_font_size_override("normal_font_size", size)
	rtl.text = plain_text  # bbcode already handled by caller if needed

func _draw() -> void:
	var count: int = get_child_count()
	for i in range(count):
		var c = get_child(i)
		if !(c is Control):
			continue
		var ctrl := c as Control

		# Cell rect from this GridContainer's layout
		var r: Rect2 = Rect2(ctrl.position, ctrl.size)

		# Apply tiny gutter, pixel align for crisp 1px borders
		r.position.x = floor(r.position.x + GUTTER_X) + 0.5
		r.position.y = floor(r.position.y + GUTTER_Y) + 0.5
		r.size.x = max(0.0, floor(r.size.x - GUTTER_X * 2.0))
		r.size.y = max(0.0, floor(r.size.y - GUTTER_Y * 2.0))

		draw_style_box(_cell_box, r)

# ------------ your existing signal passthrough ------------
func _on_selected(pressed: bool) -> void:
	if pressed:
		emit_signal("selected", weapon_data)
