extends Control
const PARTY_KEYS = ["Party_Member_1", "Party_Member_2", "Party_Member_3", "Party_Member_4"]
const TURN_KEYS  = ["First_Turn", "Second_Turn", "Third_Turn", "Fourth_Turn"]

@onready var PartyRow   : HBoxContainer  = $Root/PartyRow
@onready var PartyTpl    = $Root/PartyRow/PartyMemberTemplate
@onready var TurnList   : ItemList       = $Root/Body/TurnList
@onready var EnemyFlow  : GridContainer  = $Root/Body/EnemyScroll/EnemyFlow
@onready var EnemyTpl    = preload("res://Scenes/enemy_card_template.tscn")
@onready var RefreshTimer: Timer         = $RefreshTimer

const COL_NEXT    : Color = Color(0.545, 0.827, 0.867, 0.18)
const COL_CURRENT : Color = Color(0.886, 0.761, 0.564, 0.28)

func _ready() -> void:
	_refresh_all()

func _refresh_all() -> void:
	_refresh_party()
	_refresh_enemies()
	_refresh_turns()

func _refresh_party() -> void:
	for c in PartyRow.get_children():
		if c != PartyTpl:
			c.queue_free()
	for key in PARTY_KEYS:
		var name = str(Global.Current_Party[key])
		if name == "" or name == "COMPANION":
			continue
		var s = Global.CHARACTERS[Global.CHARACTERS_NAME[name]]
		var hp_cur: float = s.get("Current_Health")
		var hp_max: float = s.get("Max_Health")
		var pct: float = (hp_cur / hp_max) * 100.0 if hp_max > 0.0 else 0.0
		var row = PartyTpl.duplicate()
		row.visible = true
		PartyRow.add_child(row)
		(row.get_node("PM_Name") as Label).text = name
		(row.get_node("PM_Element") as Label).text = str(s.get("Element","—"))
		(row.get_node("PM_Weapon") as Label).text = str(s.get("Weapon_Type","—"))
		var bar: ProgressBar = row.get_node("PM_Bar") as ProgressBar
		bar.value = pct
		bar.tooltip_text = str(int(hp_cur)) + " / " + str(int(hp_max))
		(row.get_node("PM_Downed") as Label).text = "DOWNED" if hp_cur <= 0.0 else ""

func _refresh_enemies() -> void:
	for c in EnemyFlow.get_children():
		if c != EnemyTpl:
			c.queue_free()
	for e in Global.BATTLEENEMIES.values():
		var card = EnemyTpl.instantiate()
		card.visible = true
		EnemyFlow.add_child(card)
		card.set_card(str(e.get("id")))
		


func _refresh_turns() -> void:
	TurnList.clear()
	var ordered: Array = []
	var Active_Party = []
	for member in PARTY_KEYS:
		if Global.Current_Party[member] != "COMPANION":
			Active_Party.append(Global.Current_Party[member])
	for k in TURN_KEYS:
		var n := str(Global.Current_Party[k])
		if Active_Party.has(n) == false:
			ordered.append(n)
		elif float(Global.CHARACTERS[Global.CHARACTERS_NAME[n]]["Current_Health"]) > 0.0:
			ordered.append(n)
	for e in Global.BATTLEENEMIES.values():
		if not e.get("Killed", false):
			ordered.append(str(e["EnemyName"])+" "+str(int(e["id"])))
	var current = str(Global.Current_Party.get("Current_Turn"))
	var idx := ordered.find(current)
	if idx >= 0:
		var rot := []
		for i in range(idx, ordered.size()):
			rot.append(ordered[i])
		for j in range(0, idx):
			rot.append(ordered[j])
		ordered = rot
	var preview_len = min(14, ordered.size() * 2)
	for i in range(preview_len):
		var nm := str(ordered[i % ordered.size()])
		var prefix := ("▶ " if i == 0 else ("⟶ " if i == 1 else ""))
		var ii := TurnList.add_item(prefix + nm)
		if i == 0: TurnList.set_item_custom_bg_color(ii, COL_CURRENT)
		elif i == 1: TurnList.set_item_custom_bg_color(ii, COL_NEXT)
	TurnList.select(-1)
