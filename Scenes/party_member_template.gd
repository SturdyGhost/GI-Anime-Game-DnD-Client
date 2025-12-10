extends Control

var s 
var hp_cur: float 
var hp_max: float
var pct: float = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
var type
var tableid

@onready var CardPortrait = $PM_Portrait
@onready var CardName = $PM_Name
@onready var CardElement = $PM_Element
@onready var CardWeapon = $PM_Weapon
@onready var CardHealthBar = $PM_Bar
@onready var CardStatus = $PM_Status
@onready var CardAppliedElement = $AppliedElement



func set_card(cname):
	s = Global.CHARACTERS[Global.CHARACTERS_NAME[cname]]
	type = "Player"
	tableid = s.get("id")
	hp_cur = s.get("Current_Health")
	hp_max = s.get("Max_Health")
	pct = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
	CardName.text = cname
	CardElement.text = str(s.get("Element","—"))
	CardWeapon.text = str(s.get("Weapon_Type","—"))
	CardHealthBar.value = pct
	CardHealthBar.tooltip_text = str(int(hp_cur)) + " / " + str(int(hp_max))
	CardPortrait.texture = load("res://UI/Emotes/"+s.get("Portrait"))
	if s.get("Applied_Element") != "None":
		CardAppliedElement.texture = load("res://UI/Element Icons/"+s.get("Applied_Element")+".png")
		CardAppliedElement.tooltip_text = ""
		for reaction in Global.REACTIONS.values():
			if reaction.get("First_Element") == s.get("Applied_Element"):
				CardAppliedElement.tooltip_text += reaction.get("Second_Element")+" - "+split_at_space_after_limit(reaction.get("Effect"), 100)+"\n \n"
	else:
		CardAppliedElement.texture = null


func set_companion_card(cname):
	for companion in Global.COMPANIONS.values():
		if companion.get("Name") == cname:
			type = "Companion"
			tableid = companion.get("id")
			s = companion
			
		
		pass
	CardName.text = cname
	var Lower = cname.to_lower().replace(" ","-")
	CardElement.text = str(s.get("Element","—"))
	CardWeapon.text = str(s.get("Weapon","—"))
	CardHealthBar.visible = false
	CardPortrait.texture = load("res://UI/Character Portaits/ui-avatarIcon-"+Lower+".png")
	if s.get("Applied_Element") != "None":
		CardAppliedElement.texture = load("res://UI/Element Icons/"+s.get("Applied_Element")+".png")
		CardAppliedElement.tooltip_text = ""
		for reaction in Global.REACTIONS.values():
			if reaction.get("First_Element") == s.get("Applied_Element"):
				CardAppliedElement.tooltip_text += reaction.get("Second_Element")+" - "+split_at_space_after_limit(reaction.get("Effect"), 100)+"\n \n"
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
