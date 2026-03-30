extends Control
var e
var ename
var enemyid
var elem
var tier
var phase
var hp_cur
var hp_max
var pct
var bar
var eid: int
var status
var shield_value
var shield_hp: int = 0
var shield_duration: int = 0

@onready var CardName = $EC_Name
@onready var CardPortrait = $EC_Portrait
@onready var CardHealthText = $EC_HealthText
@onready var CardSubText = $EC_Sub
@onready var CardHealthBar = $EC_Bar
@onready var CardElement = $EC_AppliedElement
@onready var CardTier = $EC_TierText
@onready var CardPanel = $Panel
@onready var ShieldHIcon = $Shield_Health_Icon
@onready var ShieldHLabel = $Shield_Health_Icon/Label
@onready var ShieldDIcon = $Shield_Duration_Icon
@onready var ShieldDLabel = $Shield_Duration_Icon/Label


func _process(delta: float) -> void:
	if eid != null:
		if eid > 0:
			set_card(str(int(eid)))


func set_card(id):
	e = Global.BATTLEENEMIES.get(id, {})
	if e.is_empty():
		return
	ename = str(e.get("EnemyName", ""))
	eid = e["id"]
	enemyid = e["EnemyID"]
	elem = str(e.get("AppliedElement","—"))
	var edata = GameDB.get_enemy(int(enemyid))
	tier = str(edata.tier) if edata else ""
	phase = str(e.get("Phase","—"))
	hp_cur = float(e.get("Current_Health",0.0))
	hp_max= float(e.get("Max_Health",0.0))
	status = str(e.get("StatusEffect"))
	pct = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
	CardName.text = str(str(ename)+" "+str(int(eid)))
	CardSubText.text = "Phase: "+ phase +"\n"+"Status Effect: \n"+status
	CardTier.text = tier.capitalize()
	CardHealthBar.value = pct
	CardHealthText.text = ( "Doing great" if pct >= 75.0 else ("Hurting a bit" if pct >= 50.0 else ("In trouble" if pct >= 25.0 else "On last legs")) )
	shield_value = e.get("Shield_Health")
	if shield_value != null:
		shield_hp = int(shield_value)
		shield_duration = int(e.get("Shield_Duration"))
	_apply_shield_border(shield_hp > 0.0)
	if elem != "None":
		CardElement.texture = load("res://UI/Element Icons/"+str(elem)+".png")
		CardElement.tooltip_text = ""
		for reaction in GameDB.reactions_for_element(elem):
			CardElement.tooltip_text += reaction.second_element + " - " + split_at_space_after_limit(reaction.effect, 100) + "\n \n"
	if e.get("Killed", false):
		self.modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		self.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var path = str("res://UI/Enemy Portraits/" + ename + ".png")
	if path != "":
		var tex = load(path)
		if tex is Texture2D:
			CardPortrait.texture = tex

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
