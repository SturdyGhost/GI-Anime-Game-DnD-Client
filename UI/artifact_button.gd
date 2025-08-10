extends TextureButton
var artifact_type
var abbreviated

@onready var background_icon = $SquareIcon2
@onready var panel = $Panel

func _ready() -> void:
	$RollGoldPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$RollWhitePanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$DamageGoldPanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$DamageWhitePanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel.mouse_filter = Control.MOUSE_FILTER_PASS
	set_artifact()

func set_artifact():
	artifact_type = self.name
	$StatLabel.text = artifact_type
	var abbreviated = ""

	match artifact_type:
		"Flower of Life":
			$SquareIcon2.texture = load("res://UI/Flower Icon.png")
			abbreviated = "-flower"
			$ArtifactIcon.texture = null
			$Stat1Name.text = ""
			$Stat1Value.text = ""
			$Stat2Name.text = ""
			$Stat2Value.text = ""
			$SetNameLabel.text = ""
		"Feather of Death":
			$SquareIcon2.texture = load("res://UI/Feather Icon.png")
			abbreviated = "-plume"
			$ArtifactIcon.texture = null
			$Stat1Name.text = ""
			$Stat1Value.text = ""
			$Stat2Name.text = ""
			$Stat2Value.text = ""
			$SetNameLabel.text = ""
		"Sands of Time":
			$SquareIcon2.texture = load("res://UI/Sands Icon.png")
			abbreviated = "-sands"
			$ArtifactIcon.texture = null
			$Stat1Name.text = ""
			$Stat1Value.text = ""
			$Stat2Name.text = ""
			$Stat2Value.text = ""
			$SetNameLabel.text = ""
		"Goblet of Space":
			$SquareIcon2.texture = load("res://UI/Goblet Icon.png")
			abbreviated = "-goblet"
			$ArtifactIcon.texture = null
			$Stat1Name.text = ""
			$Stat1Value.text = ""
			$Stat2Name.text = ""
			$Stat2Value.text = ""
			$SetNameLabel.text = ""
		"Circlet of Principles":
			$SquareIcon2.texture = load("res://UI/Circlet Icon.png")
			abbreviated = "-circlet"
			$ArtifactIcon.texture = null
			$Stat1Name.text = ""
			$Stat1Value.text = ""
			$Stat2Name.text = ""
			$Stat2Value.text = ""
			$SetNameLabel.text = ""

	for artifact in Global.CHARACTER_ARTIFACTS.values():
		if artifact.get("Owner") == Global.ACTIVE_USER_NAME and artifact.get("Equipped") == true and artifact.get("Type") == artifact_type:
			var set_name = artifact.get("Artifact_Set")
			var hyphen_set = set_name.replace(" ", "-")
			var icon_path = "res://UI/Artifact Icons/" + hyphen_set + abbreviated + ".png"
			var artifact_tex = load(icon_path)
			
			$ArtifactIcon.texture = artifact_tex

			# Update stats
			$Stat1Name.text = artifact.get("Stat_1_Type", "")
			$Stat1Value.text = str(artifact.get("Stat_1_Value", ""))
			$Stat2Name.text = artifact.get("Stat_2_Type", "")
			$Stat2Value.text = str(artifact.get("Stat_2_Value", ""))

			# Update set name label
			$SetNameLabel.text = "(" + set_name + ": " + str(Global.set_count[set_name]) + ")"

			# 🔷 Dominant color from texture
			var dominant_color = get_color_from_set_name(set_name)

			# Apply color to set name label
			$SetNameLabel.add_theme_color_override("font_color", dominant_color)


			break  # Only one artifact per slot, so we can stop here

func get_color_from_set_name(set_name: String) -> Color:
	var hash = hash_djb2(set_name)
	var r = float((hash >> 16) & 0xFF) / 255.0
	var g = float((hash >> 8) & 0xFF) / 255.0
	var b = float(hash & 0xFF) / 255.0
	var color = Color(r, g, b)

	# Pastel-ify it for readability using lerp instead of linear_interpolate
	return color.lerp(Color.WHITE, 0.5)


func hash_djb2(s: String) -> int:
	var hash := 5381
	for i in s.length():
		hash = ((hash << 5) + hash) + s.unicode_at(i)
	return hash & 0xFFFFFF


func _on_panel_mouse_entered() -> void:
	apply_hover_style()
	pass # Replace with function body.


func _on_panel_mouse_exited() -> void:
	clear_hover_style()
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
