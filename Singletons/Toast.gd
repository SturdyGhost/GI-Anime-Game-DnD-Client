extends CanvasLayer
## Toast banner system — shows temporary notifications at the top of the screen.
## Usage: Toast.notify("Region changed to Liyue")
## Usage: Toast.notify("Disconnected from host", Toast.ERROR)
## Usage: Toast.notify("Brian C. connected", Toast.SUCCESS)

enum Level { INFO, SUCCESS, WARNING, ERROR }

# Expose enum values directly so callers use Toast.SUCCESS not Toast.Level.SUCCESS
const INFO := Level.INFO
const SUCCESS := Level.SUCCESS
const WARNING := Level.WARNING
const ERROR := Level.ERROR

const DURATION := 3.0
const FADE_TIME := 0.4
const MAX_TOASTS := 4

const COLORS := {
	Level.INFO:    Color(0.15, 0.15, 0.2, 0.9),
	Level.SUCCESS: Color(0.1, 0.35, 0.15, 0.9),
	Level.WARNING: Color(0.4, 0.35, 0.1, 0.9),
	Level.ERROR:   Color(0.45, 0.1, 0.1, 0.9),
}

const FONT_COLORS := {
	Level.INFO:    Color(0.85, 0.85, 0.9),
	Level.SUCCESS: Color(0.7, 1.0, 0.75),
	Level.WARNING: Color(1.0, 0.95, 0.6),
	Level.ERROR:   Color(1.0, 0.7, 0.7),
}

var _container: VBoxContainer

func _ready() -> void:
	layer = 100
	_container = VBoxContainer.new()
	_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_container.position = Vector2(0, 20)
	_container.add_theme_constant_override("separation", 6)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)

func notify(message: String, level: int = Level.INFO, duration: float = DURATION) -> void:
	# Trim old toasts
	while _container.get_child_count() >= MAX_TOASTS:
		_container.get_child(0).queue_free()

	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.get(level, COLORS[Level.INFO])
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 300)
	margin.add_theme_constant_override("margin_right", 300)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(panel)

	var label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", FONT_COLORS.get(level, FONT_COLORS[Level.INFO]))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	_container.add_child(margin)

	# Fade in
	margin.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(margin, "modulate:a", 1.0, FADE_TIME)
	tween.tween_interval(duration)
	tween.tween_property(margin, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(margin.queue_free)
