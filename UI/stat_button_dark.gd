extends Control

var Stat = "Health"
var StatValue = 25
var AddedRoll = 20
var MultipliedRoll = 1.2
var AddedDamage = 15
var MultipliedDamage = 1.3
var is_hovered = false

@onready var panel = $Panel



func _ready() -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	$RollGoldPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$RollWhitePanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$DamageGoldPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$DamageWhitePanel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta):
	var mouse_pos = get_viewport().get_mouse_position()
	var is_now_hovered = panel.get_global_rect().has_point(mouse_pos)

	if is_now_hovered and !is_hovered:
		is_hovered = true
		apply_hover_style()
	elif !is_now_hovered and is_hovered:
		is_hovered = false
		clear_hover_style()


func set_stats():
	$StatLabel.text = Stat
	$StatCurrentValue.text = str(StatValue)
	$RollModifierValues.text = "+" + str(AddedRoll) +" | x" + str(MultipliedRoll)
	$DamageModifierValues.text = "+" + str(AddedDamage) +" | x" + str(MultipliedDamage)


func _on_button_pressed() -> void:
	pass # Replace with function body.


func apply_hover_style():
	var original_style = panel.get("theme_override_styles/panel") as StyleBoxFlat

	# Duplicate the style so we don't modify the shared one
	var unique_style := original_style.duplicate()
	unique_style.border_width_bottom = 6
	unique_style.border_width_top = 6
	unique_style.border_width_left = 6
	unique_style.border_width_right = 6

	panel.set("theme_override_styles/panel", unique_style)

func clear_hover_style():
	var original_style = panel.get("theme_override_styles/panel") as StyleBoxFlat

	# Duplicate the style so we don't modify the shared one
	var unique_style := original_style.duplicate()
	unique_style.border_width_bottom = 0
	unique_style.border_width_top = 0
	unique_style.border_width_left = 0
	unique_style.border_width_right = 0

	panel.set("theme_override_styles/panel", unique_style)
