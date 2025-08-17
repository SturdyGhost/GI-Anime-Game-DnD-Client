extends GridContainer

@onready var NameLabel       = $NameLabel
@onready var TypeLabel       = $TypeLabel
@onready var Stat1TypeLabel  = $Stat1TypeLabel
@onready var Stat1ValueLabel = $Stat1ValueLabel
@onready var Stat2TypeLabel  = $Stat2TypeLabel
@onready var Stat2ValueLabel = $Stat2ValueLabel
@onready var TwoPieceSetLabel  = $"2PieceSetLabel"
@onready var FourPieceSetLabel = $"4PieceSetLabel"
@onready var EquipCheck: CheckBox = $EquipCheck

var _row: Dictionary = {}
var _highlight_q: String = ""   # current search text

func _ready() -> void:
	if EquipCheck and not EquipCheck.is_connected("pressed", Callable(self, "_on_EquipCheck_pressed")):
		EquipCheck.pressed.connect(_on_EquipCheck_pressed)
	_apply()

func set_data(row: Dictionary) -> void:
	_row = row.duplicate(true)
	_apply()

func set_highlight(q: String) -> void:
	_highlight_q = q
	_apply()  # re-render with highlight

func _apply() -> void:
	# enable bbcode so we can color matches

	if NameLabel:        NameLabel.text        = _hl(str(_row.get("Name","")),       _highlight_q)
	if TypeLabel:        TypeLabel.text        = _hl(str(_row.get("Type","")),       _highlight_q)
	if Stat1TypeLabel:   Stat1TypeLabel.text   = _hl(str(_row.get("Stat1","")),      _highlight_q)
	if Stat1ValueLabel:  Stat1ValueLabel.text  = _hl(_fmt_num(_row.get("Stat1Value",0.0)), _highlight_q)
	var s2k = str(_row.get("Stat2",""))
	var s2v = _row.get("Stat2Value", null)
	if s2v == null or s2k == "" or s2k == "<null>":
		if Stat2TypeLabel:  Stat2TypeLabel.text  = ""
		if Stat2ValueLabel: Stat2ValueLabel.text = ""
	else:
		if Stat2TypeLabel:  Stat2TypeLabel.text  = _hl(s2k, _highlight_q)    # or just s2k if no highlighter
		if Stat2ValueLabel: Stat2ValueLabel.text = _hl(_fmt_num(s2v), _highlight_q)
	if TwoPieceSetLabel: TwoPieceSetLabel.text = _hl(str(_row.get("TwoPiece","")),   _highlight_q)
	if FourPieceSetLabel:FourPieceSetLabel.text= _hl(str(_row.get("FourPiece","")),  _highlight_q)

	if EquipCheck:
		var eq = _row.get("Equipped", null)
		EquipCheck.disabled = false
		EquipCheck.button_pressed = (eq != null and bool(eq))

# optional local handler (parent handles exclusivity)
func _on_EquipCheck_pressed() -> void:
	pass

func _fmt_num(v) -> String:
	var t := typeof(v)
	if t == TYPE_FLOAT or t == TYPE_INT:
		return "%+0.2f" % v
	if t == TYPE_NIL:
		return ""
	return "%+0.2f" % str(v).to_float()


# case-insensitive highlighter; wraps matches in a color
func _hl(text: String, q: String) -> String:
	if q == null or q.strip_edges() == "":
		return text
	var t := text
	var src := text.to_lower()
	var pat := q.to_lower()
	var out := ""
	var i := 0
	var idx := src.find(pat, i)
	while idx != -1:
		out += t.substr(i, idx - i)
		out += "[color=#E2C290]" + t.substr(idx, pat.length()) + "[/color]"
		i = idx + pat.length()
		idx = src.find(pat, i)
	out += t.substr(i)
	return out
