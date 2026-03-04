extends Panel

var TableType = ""
var PlayerTalents = []
var PlayerConstellations = []
var PlayerAbilities = []
var weapontype
var Ability_Data = []
var TalentTabKeys = {
	"Wind": "b4fcd4",
	"Earth": "f4d563",
	"Electric": "d092fc",
	"Nature": "b1ea29",
	"Water": "00c0fe",
	"Fire": "ffa971",
	"Nod Krai": "252525",
	"Ice": "ccffff"}
var ConstellationTabKeys = {
	"Weak": "e0e0e0",
	"Medium":"4374b6",
	"Strong":"fdd22e"
}
var Ability_Keys = ["Basic Attack", "Charged Attack","Skill","Burst","Passive"]
@onready var Tables = $TabContainer
@onready var TalentTableScene = load("res://UI/TalentTable.tscn")
@onready var TalentTableRowScene = load("res://UI/TalentTableRow.tscn")
@onready var AbilityTableScene = load("res://UI/AbilityTable.tscn")
@onready var AbilityTableRowScene = load("res://UI/AbilityTableRow.tscn")


func _ready() -> void:
	get_data()
	init_tables()
	init_rowes()


func get_data():
	for talent in Global.TALENTS.values():
		if talent.get("Name") == Global.ACTIVE_USER_NAME:
			PlayerTalents.append(talent)
	for constellation in Global.CONSTELLATIONS.values():
		if constellation.get("Name") == Global.ACTIVE_USER_NAME:
			PlayerConstellations.append(constellation)
	for ability in Global.ACTIVE_ABILITIES.values():
		if ability.get("Entity_ID") == Global.ACTIVE_USER_RECORD_ID and ability.get("Entity_Type") == "Character":
			PlayerAbilities.append(ability)
			pass


func _on_exit_button_pressed() -> void:
	var p := get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()
	pass # Replace with function body.


func init_tables():
	match TableType:
		"Talents":
			for key in TalentTabKeys.keys():
				var NewTable = TalentTableScene.instantiate()
				Tables.add_child(NewTable)
				NewTable.name = key
				NewTable.HeaderBackground.color = Color(TalentTabKeys[key])
				NewTable.TableHeaderLabel.text = str(key +" Kit Talents")
		"Constellations":
			for key in ConstellationTabKeys.keys():
				var NewTable = TalentTableScene.instantiate()
				Tables.add_child(NewTable)
				NewTable.name = key
				NewTable.HeaderBackground.color = Color(ConstellationTabKeys[key])
				NewTable.TableHeaderLabel.text = str(key +" Constellations")
		"Abilities":
			for key in TalentTabKeys.keys():
				var NewTable = AbilityTableScene.instantiate()
				Tables.add_child(NewTable)
				NewTable.name = key
				NewTable.HeaderBackground.color = Color(TalentTabKeys[key])
				for weapon in Global.CHARACTER_WEAPONS.values():
					if weapon.get("Owner") == Global.ACTIVE_USER_NAME and weapon.get("Equipped") == true:
						weapontype = weapon.get("Type")
				NewTable.TableHeaderLabel.text = str(key +" "+weapontype+" Abilities")

func init_rowes():
	for child in Tables.get_children():
		if TableType == "Talents":
			var UnlockedElement = false
			for talent in PlayerTalents:
				if talent.get("Element") == child.name and talent.get("Chosen") == true:
					UnlockedElement = true
			if UnlockedElement == true:
				for talent in PlayerTalents:
					if talent.get("Element") == child.name:
						var NewRow = TalentTableRowScene.instantiate()
						child.Rows.add_child(NewRow)
						NewRow.DescriptionLabel.text = System.db_richtext_to_bbcode(talent.get("Talent"))
						if talent.get("Chosen") == true:
							NewRow.Check.button_pressed = talent.get("Chosen")
		elif TableType == "Constellations":
			for constellation in PlayerConstellations:
				if constellation.get("Tier") == child.name:
					var NewRow = TalentTableRowScene.instantiate()
					child.Rows.add_child(NewRow)
					NewRow.DescriptionLabel.text = System.db_richtext_to_bbcode(constellation.get("Constellation"))
					if constellation.get("Chosen") == true:
						NewRow.Check.button_pressed = constellation.get("Chosen")
		elif TableType == "Abilities":
			var UnlockedElement = false
			for talent in PlayerTalents:
				if talent.get("Element") == child.name and talent.get("Chosen") == true:
					UnlockedElement = true
			for ability_key in Ability_Keys:
				for ability in PlayerAbilities:
					if ability.get("Element") == child.name and ability.get("Weapon_Type") == weapontype and UnlockedElement == true and ability.get("Ability_Type") == ability_key:
						var ability_data = Global.ABILITIES[str(ability.get("Ability_ID"))]
						Ability_Data.append({ability.get("id"): ability_data})
						var NewRow = AbilityTableRowScene.instantiate()
						child.Rows.add_child(NewRow)
						if ability_data.get("description") != null:
							NewRow.DescriptionLabel.text = System.db_richtext_to_bbcode(ability_data.get("description"))
						else:
							NewRow.DescriptionLabel.text = ""
						if ability.get("Ability_Type") != null:
							NewRow.AbilityLabel.text = ability.get("Ability_Type")
						else:
							NewRow.AbilityLabel.text = ""
						if ability_data.get("element") != null:
							NewRow.TypeLabel.text = ability_data.get("element")
						else:
							NewRow.TypeLabel.text = ""
						if ability_data.get("movement") != null:
							NewRow.MovementLabel.text = str(ability_data.get("movement"))
						else:
							NewRow.MovementLabel.text = ""
						if ability_data.get("targeting_length") != null:
							NewRow.RangeLabel.text = str(ability_data.get("targeting_length"))
						else:
							NewRow.RangeLabel.text = ""
						if ability_data.get("cooldown") != null:
							NewRow.CDLabel.text = str(ability_data.get("cooldown"))
						else:
							NewRow.CDLabel.text = ""
						if ability_data.get("charge_cost") != null:
							NewRow.ChargeLabel.text = str(ability_data.get("charge_cost"))
						else:
							NewRow.ChargeLabel.text = ""
			#var NewRow = AbilityTableRowScene.instantiate()
			#child.Rows.add_child(NewRow)
						
			pass
	pass
