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

@onready var CardName = $EC_Name
@onready var CardPortrait = $EC_Portrait
@onready var CardHealthText = $EC_HealthText
@onready var CardSubText = $EC_Sub
@onready var CardHealthBar = $EC_Bar


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
	tier = str(e.get("Tier","—"))
	phase = str(e.get("Phase","—"))
	hp_cur = float(e.get("HP_Current",0.0))
	hp_max= float(e.get("HP_Max",0.0))
	pct = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
	CardName.text = str(str(ename)+" "+str(int(eid)))
	CardSubText.text = "Phase: "+ phase
	CardHealthBar.value = pct
	CardHealthText.text = ( "Doing great" if pct >= 75.0 else ("Hurting a bit" if pct >= 50.0 else ("In trouble" if pct >= 25.0 else "On last legs")) )
	if e.get("Killed", false):
		self.modulate = Color(0.6, 0.6, 0.6, 0.8)
	else:
		self.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var path = str("res://UI/Enemy Portraits/" + ename + ".png")
	if path != "":
		var tex = load(path)
		if tex is Texture2D:
			CardPortrait.texture = tex
