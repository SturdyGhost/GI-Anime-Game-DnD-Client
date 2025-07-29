extends Control

var Player_Data = Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]]
var Weapon = Player_Data["Current Weapon"]
var StatValue = 25
var AddedRoll = 20
var MultipliedRoll = 1.2
var AddedDamage = 15
var MultipliedDamage = 1.3
var is_hovered = false
var Weapon_Data = Global.WEAPONS[Global.WEAPONS_NAME[Weapon]]

@onready var panel = $Panel



func _ready() -> void:
	set_weapon()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	$Stat1GoldPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Stat1WhitePanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Stat2GoldPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Stat2WhitePanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Stat3GoldPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Stat3WhitePanel.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	$StatLabel.text = Weapon
	$StatCurrentValue.text = str(StatValue)
	$RollModifierValues.text = "+" + str(AddedRoll) +" | x" + str(MultipliedRoll)
	$DamageModifierValues.text = "+" + str(AddedDamage) +" | x" + str(MultipliedDamage)


func _on_button_pressed() -> void:
	pass # Replace with function body.


func apply_hover_style():
	var original_style = panel.get("theme_override_styles/panel") as StyleBoxFlat

	# Duplicate the style so we don't modify the shared one
	var unique_style := original_style.duplicate()
	unique_style.border_width_bottom = 10
	unique_style.border_width_top = 10
	unique_style.border_width_left = 10
	unique_style.border_width_right = 10
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

func set_weapon():
	Weapon = "Thundering Pulse"
	Weapon_Data = Global.WEAPONS[Global.WEAPONS_NAME[Weapon]]
	shrink_text_to_fit($WeaponLabel)
	var WeaponIconPath = "res://UI/Weapon Icons/" + Global.normalize_text_filename(str(Weapon))
	$WeaponIcon.texture = load(WeaponIconPath)
	if Weapon_Data.has("Effect"):
		var WeaponEffect = Weapon_Data["Effect"]
		$Tooltip/Label.text = WeaponEffect
	else:
		var WeaponEffect = ""
		$Tooltip/Label.text = WeaponEffect
	if Weapon_Data.has("Stat 1 Type"):
		match Weapon_Data["Stat 1 Type"]:
			"Health":
				var Stat1Type = Weapon_Data["Stat 1 Type"]
				var Stat1Value = Weapon_Data["Stat 1 Value"]
				$Stat1Label.text = Stat1Type +" | +" + str(Stat1Value)
			"Attack":
				var Stat1Type = Weapon_Data["Stat 1 Type"]
				var Stat1Value = Weapon_Data["Stat 1 Value"]
				$Stat1Label.text = Stat1Type +" | +" + str(Stat1Value)
			"Defense":
				var Stat1Type = Weapon_Data["Stat 1 Type"]
				var Stat1Value = Weapon_Data["Stat 1 Value"]
				$Stat1Label.text = Stat1Type +" | +" + str(Stat1Value)
			"Elemental Mastery":
				var Stat1Type = "E.M."
				var Stat1Value = Weapon_Data["Stat 1 Value"]
				$Stat1Label.text = Stat1Type +" | +" + str(Stat1Value)
			"Energy Recharge":
				var Stat1Type = "E.R."
				var Stat1Value = Weapon_Data["Stat 1 Value"]
				$Stat1Label.text = Stat1Type +" | +" + str(Stat1Value)
			"Critical Damage":
				var Stat1Type = "Crit. Dmg."
				var Stat1Value = Weapon_Data["Stat 1 Value"]
				$Stat1Label.text = Stat1Type +" | +" + str(Stat1Value)
	else:
		$Stat1Label.text = ""
	if Weapon_Data.has("Stat 2 Type"):
		match Weapon_Data["Stat 2 Type"]:
			"Health":
				var Stat2Type = Weapon_Data["Stat 2 Type"]
				var Stat2Value = Weapon_Data["Stat 2 Value"]
				$Stat2Label.text = Stat2Type +" | +" + str(Stat2Value)
			"Attack":
				var Stat2Type = Weapon_Data["Stat 2 Type"]
				var Stat2Value = Weapon_Data["Stat 2 Value"]
				$Stat2Label.text = Stat2Type +" | +" + str(Stat2Value)
			"Defense":
				var Stat2Type = Weapon_Data["Stat 2 Type"]
				var Stat2Value = Weapon_Data["Stat 2 Value"]
				$Stat2Label.text = Stat2Type +" | +" + str(Stat2Value)
			"Elemental Mastery":
				var Stat2Type = "E.M."
				var Stat2Value = Weapon_Data["Stat 2 Value"]
				$Stat2Label.text = Stat2Type +" | +" + str(Stat2Value)
			"Energy Recharge":
				var Stat2Type = "E.R."
				var Stat2Value = Weapon_Data["Stat 2 Value"]
				$Stat2Label.text = Stat2Type +" | +" + str(Stat2Value)
			"Critical Damage":
				var Stat2Type = "Crit. Dmg."
				var Stat2Value = Weapon_Data["Stat 2 Value"]
				$Stat2Label.text = Stat2Type +" | +" + str(Stat2Value)
	else:
		$Stat2Label.text = ""
	if Weapon_Data.has("Stat 3 Type"):
		match Weapon_Data["Stat 3 Type"]:
			"Health":
				var Stat3Type = Weapon_Data["Stat 3 Type"]
				var Stat3Value = Weapon_Data["Stat 3 Value"]
				$Stat3Label.text = Stat3Type +" | +" + str(Stat3Value)
			"Attack":
				var Stat3Type = Weapon_Data["Stat 3 Type"]
				var Stat3Value = Weapon_Data["Stat 3 Value"]
				$Stat3Label.text = Stat3Type +" | +" + str(Stat3Value)
			"Defense":
				var Stat3Type = Weapon_Data["Stat 3 Type"]
				var Stat3Value = Weapon_Data["Stat 3 Value"]
				$Stat3Label.text = Stat3Type +" | +" + str(Stat3Value)
			"Elemental Mastery":
				var Stat3Type = "E.M."
				var Stat3Value = Weapon_Data["Stat 3 Value"]
				$Stat3Label.text = Stat3Type +" | +" + str(Stat3Value)
			"Energy Recharge":
				var Stat3Type = "E.R."
				var Stat3Value = Weapon_Data["Stat 3 Value"]
				$Stat3Label.text = Stat3Type +" | +" + str(Stat3Value)
			"Critical Damage":
				var Stat3Type = "Crit. Dmg."
				var Stat3Value = Weapon_Data["Stat 3 Value"]
				$Stat3Label.text = Stat3Type +" | +" + str(Stat3Value)
	else:
		$Stat3Label.text = ""




func shrink_text_to_fit(label: Label, min_size: int = 8, max_size: int = 60) -> void:
	if label == null or not label is Label:
		return
	
	var max_width: float = label.size.x
	var base_font: Font = label.get_theme_font("font")
	var font_size: int = max_size

	while font_size >= min_size:
		var string_size: Vector2 = base_font.get_string_size(Weapon, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if string_size.x <= max_width:
			break
		font_size -= 1

	# Apply resized font
	$WeaponLabel.set("theme_override_font_sizes/font_size",font_size)
	$WeaponLabel.text = Weapon
	
	#resized_font. = font_size
	#label.get
	#


func _on_description_info_mouse_entered() -> void:
	$Tooltip.visible = true
	pass # Replace with function body.


func _on_description_info_mouse_exited() -> void:
	$Tooltip.visible = false
	pass # Replace with function body.
