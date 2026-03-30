extends Control

var s 
var hp_cur: float 
var hp_max: float
var pct: float = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
var type
var tableid
var card_name
var shield_hp: int = 0
var shield_duration: int = 0

@onready var CardPortrait = $PM_Portrait
@onready var CardName = $PM_Name
@onready var CardElement = $PM_Element
@onready var CardWeapon = $PM_Weapon
@onready var CardHealthBar = $PM_Bar
@onready var CardStatus = $PM_Status
@onready var CardAppliedElement = $AppliedElement
@onready var ShieldHIcon = $Shield_Health_Icon
@onready var ShieldHLabel = $Shield_Health_Icon/Label
@onready var ShieldDIcon = $Shield_Duration_Icon
@onready var ShieldDLabel = $Shield_Duration_Icon/Label
@onready var CardPanel = $Panel



func set_card(cname):
	s = Global.CHARACTERS[Global.CHARACTERS_NAME[cname]]
	card_name = cname
	type = "Character"
	tableid = s.get("id")
	hp_cur = s.get("Current_Health")
	hp_max = s.get("Max_Health")
	pct = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
	CardName.text = cname
	CardHealthBar.value = pct
	var sh = s.get("Shield_Health")
	shield_hp = 0
	if sh != null:
		shield_hp = int(sh)
		shield_duration = int(s.get("Shield_Duration"))

	_apply_shield_border(shield_hp > 0.0)
	CardHealthBar.tooltip_text = str(int(hp_cur)) + " / " + str(int(hp_max))
	CardPortrait.texture = load("res://UI/Emotes/"+s.get("Portrait"))
	if s.get("Applied_Element") != "None":
		CardAppliedElement.texture = load("res://UI/Element Icons/"+s.get("Applied_Element")+".png")
		CardAppliedElement.tooltip_text = ""
		for reaction in GameDB.reactions_for_element(s.get("Applied_Element")):
			CardAppliedElement.tooltip_text += reaction.second_element+" - "+split_at_space_after_limit(reaction.effect, 100)+"\n \n"
	else:
		CardAppliedElement.texture = null


func set_companion_card(cname):
	var comp_id = Global.COMPANIONS_NAME.get(cname, "")
	if comp_id != "":
		s = Global.COMPANIONS.get(comp_id, null)
	else:
		for companion in Global.COMPANIONS.values():
			if companion.get("Name") == cname:
				s = companion
				break
	if s == null:
		push_warning("set_companion_card: companion '%s' not found" % cname)
		return
	type = "Companion"
	tableid = s.get("id")
	CardName.text = cname
	card_name = cname
	hp_cur = s.get("Current_Health")
	hp_max = s.get("Max_Health")
	var sh = s.get("Shield_Health")
	shield_hp = 0
	if sh != null:
		shield_hp = int(sh)
		shield_duration = int(s.get("Shield_Duration"))

	_apply_shield_border(shield_hp > 0.0)
	pct = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
	CardHealthBar.value = pct
	CardHealthBar.tooltip_text = str(int(hp_cur)) + " / " + str(int(hp_max))
	var Lower = cname.to_lower().replace(" ","-")
	CardPortrait.texture = load("res://UI/Character Portaits/ui-avatarIcon-"+Lower+".png")
	if s.get("Applied_Element") != "None":
		CardAppliedElement.texture = load("res://UI/Element Icons/"+s.get("Applied_Element")+".png")
		CardAppliedElement.tooltip_text = ""
		for reaction in GameDB.reactions_for_element(s.get("Applied_Element")):
			CardAppliedElement.tooltip_text += reaction.second_element+" - "+split_at_space_after_limit(reaction.effect, 100)+"\n \n"
	else:
		CardAppliedElement.texture = null

func split_at_space_after_limit(text: String, limit: int = 100,max_lines: int = 3) -> String:
	var lines: Array = []
	var start: int = 0
	var n: int = text.length()

	while start < n and lines.size() < max_lines:
		if n - start <= limit:
			lines.append(text.substr(start, n - start).strip_edges())
			break

		var split_at: int = text.find(" ", start + limit)
		if split_at == -1:
			split_at = start + limit

		lines.append(text.substr(start, split_at - start).strip_edges())
		start = min(split_at + 1, n)  # skip the space

	return "\n".join(lines)

func update_stats():
	var s
	match type:
		"Character":
			s = Global.CHARACTERS.get(str(tableid), {})
		"Companion":
			s = Global.COMPANIONS.get(str(tableid), {})
	if s.is_empty():
		return
	hp_cur = s.get("Current_Health")
	hp_max = s.get("Max_Health")
	pct = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
	CardHealthBar.value = pct
	CardHealthBar.tooltip_text = str(int(hp_cur)) + " / " + str(int(hp_max))
	var sh = s.get("Shield_Health")
	shield_hp = 0
	if sh != null:
		shield_hp = int(sh)
		shield_duration = int(s.get("Shield_Duration"))

	_apply_shield_border(shield_hp > 0.0)
	if s.get("Applied_Element") != "None":
		CardAppliedElement.texture = load("res://UI/Element Icons/"+s.get("Applied_Element")+".png")
		CardAppliedElement.tooltip_text = ""
		for reaction in GameDB.reactions_for_element(s.get("Applied_Element")):
			CardAppliedElement.tooltip_text += reaction.second_element+" - "+split_at_space_after_limit(reaction.effect, 100)+"\n \n"
	else:
		CardAppliedElement.texture = null
	if hp_cur <= 0:
		self.modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		self.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_update_effects_display()

func _update_effects_display() -> void:
	if not has_node("EffectsLabel"):
		var lbl = Label.new()
		lbl.name = "EffectsLabel"
		lbl.position = Vector2(0, 170)
		lbl.custom_minimum_size = Vector2(200, 20)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(lbl)

	var lbl = $EffectsLabel
	var effects = Global.get_battler_effects(card_name)
	if effects.is_empty():
		lbl.text = ""
		lbl.tooltip_text = ""
		return

	# Count non-passive effects for display
	var display_effects = []
	for fx in effects:
		if fx.get("trigger") == "PASSIVE" and fx.get("source_type") == "gear":
			continue
		display_effects.append(fx)

	if display_effects.is_empty():
		lbl.text = ""
		lbl.tooltip_text = ""
		return

	# Short summary on card
	var names = []
	for fx in display_effects:
		var n = fx.get("source_name", fx.get("effect_type", "?"))
		if not names.has(n):
			names.append(n)
	lbl.text = "%d effect(s)" % display_effects.size()

	# Detailed tooltip
	var tip = ""
	for fx in display_effects:
		var dur_str = ""
		var dur = fx.get("turns_remaining", 0)
		if dur == -1:
			dur_str = "permanent"
		elif dur > 0:
			dur_str = "%d turn(s)" % dur
		else:
			dur_str = "instant"

		var stacks_str = ""
		if fx.get("stacks", 0) > 0:
			stacks_str = " [%d/%d stacks]" % [fx.get("stacks"), fx.get("max_stacks", 0)]

		var desc = fx.get("description", "")
		if desc == "":
			desc = "%s %s" % [fx.get("effect_type", ""), fx.get("effect_stat", "")]

		tip += "%s (%s)%s — %s\n  %s\n\n" % [
			fx.get("source_name", "Unknown"),
			dur_str,
			stacks_str,
			fx.get("source_type", ""),
			desc.strip_edges()
		]
	lbl.tooltip_text = tip.strip_edges()


func _apply_shield_border(has_shield: bool) -> void:
	if has_shield:
		# Get the current theme's panel style
		var base_style = CardPanel.get_theme_stylebox("panel")
		ShieldDIcon.visible = true
		ShieldHIcon.visible = true
		ShieldDLabel.text = str(shield_duration)
		ShieldHLabel.text = str(shield_hp)

		if base_style != null:
			# Duplicate so we don't modify the global theme
			var sb = base_style.duplicate()

			# Ensure it's a StyleBoxFlat (default panels usually are)
			if sb is StyleBoxFlat:
				# Thicker gray border
				sb.border_color = Color(0.55, 0.55, 0.55, 1.0)
				sb.border_width_left = 6
				sb.border_width_top = 6
				sb.border_width_right = 6
				sb.border_width_bottom = 6

			CardPanel.add_theme_stylebox_override("panel", sb)
	else:
		CardPanel.remove_theme_stylebox_override("panel")
		ShieldDIcon.visible = false
		ShieldHIcon.visible = false
