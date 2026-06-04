extends Node
## Always-on-top connection-health badge. Visible whenever a multiplayer
## session is active (host running, or client connected). Polls
## NetworkManager every REFRESH_INTERVAL_SEC and renders one of:
##
##   green  — healthy (recent ping/pong on both sides)
##   yellow — stale (no traffic for HEALTH_STALE_MS+)
##   red    — critical (no traffic for HEALTH_CRITICAL_MS+, fully disconnected,
##            or — on host — every connected client looks dead from your side,
##            meaning YOU are probably the one who has dropped)
##   gray   — not in a session (overlay hidden)
##
## The label content adapts to role: clients see "DM connected" / "DM slow" /
## "DM unresponsive"; the host sees "N players connected" / "X/N slow" /
## "You appear dropped".

const REFRESH_INTERVAL_SEC: float = 1.0
const DOT_SIZE: Vector2 = Vector2(14, 14)
const FONT_SIZE: int = 26
const COLOR_GREEN: Color  = Color(0.30, 0.80, 0.40)
const COLOR_YELLOW: Color = Color(0.95, 0.78, 0.15)
const COLOR_RED: Color    = Color(0.90, 0.30, 0.30)
const COLOR_GRAY: Color   = Color(0.55, 0.60, 0.66)

var _layer: CanvasLayer
var _panel: PanelContainer
var _dot: ColorRect
var _label: Label
var _timer: Timer

func _ready() -> void:
	_build_ui()
	_timer = Timer.new()
	_timer.wait_time = REFRESH_INTERVAL_SEC
	_timer.autostart = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	_refresh()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# Sit below the typical "Close" button row (~50px tall) and far enough
	# left to not overlap a wide title bar.
	_panel.offset_left = -340
	_panel.offset_top = 56
	_panel.offset_right = -14
	_panel.offset_bottom = 96
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.14, 0.88)
	sb.border_color = Color(0.20, 0.23, 0.30)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	_panel.add_child(hbox)

	_dot = ColorRect.new()
	_dot.custom_minimum_size = DOT_SIZE
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dot.color = COLOR_GRAY
	hbox.add_child(_dot)

	_label = Label.new()
	_label.text = "..."
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.98))
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_label)

	_layer.visible = false


func _refresh() -> void:
	var active: bool = NetworkManager.is_host or NetworkManager.is_connected_to_host
	_layer.visible = active
	if not active:
		return
	var state: Dictionary
	if NetworkManager.is_host:
		state = NetworkManager.get_self_health_state()
	else:
		state = NetworkManager.get_host_health_state()
	_label.text = str(state.get("label", ""))
	match int(state.get("status", -1)):
		0: _dot.color = COLOR_GREEN
		1: _dot.color = COLOR_YELLOW
		2: _dot.color = COLOR_RED
		_: _dot.color = COLOR_GRAY
