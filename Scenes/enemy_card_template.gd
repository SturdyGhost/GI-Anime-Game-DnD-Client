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
var eid
var status

@onready var CardName = $EC_Name
@onready var CardPortrait = $EC_Portrait
@onready var CardHealthText = $EC_HealthText
@onready var CardSubText = $EC_Sub
@onready var CardHealthBar = $EC_Bar
@onready var CardElement = $EC_AppliedElement
@onready var CardTier = $EC_TierText


func _process(delta: float) -> void:
	if eid != null:
		if eid > 0:
			set_card(str(eid))


func set_card(id):
	e = Global.BATTLEENEMIES[id]
	ename = str(e["EnemyName"])
	eid = e["id"]
	enemyid = e["EnemyID"]
	elem = str(e.get("AppliedElement","—"))
	tier = str(Global.ENEMIES[str(float(enemyid))].get("tier"))
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
	if elem != "None":
		CardElement.texture = load("res://UI/Element Icons/"+str(elem)+".png")
		CardElement.tooltip_text = ""
		for reaction in Global.REACTIONS.values():
			if reaction.get("First_Element") == elem:
				CardElement.tooltip_text += reaction.get("Second_Element")+" - "+split_at_space_after_limit(reaction.get("Effect"), 100)+"\n \n"
	if e.get("Killed", false):
		self.modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		self.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var path = str("res://UI/Enemy Portraits/" + ename + ".png")
	if path != "":
		var tex = load(path)
		if tex is Texture2D:
			CardPortrait.texture = tex



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
