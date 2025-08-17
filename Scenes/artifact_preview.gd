extends Panel

@onready var WeaponNameLabel = $WeaponName
@onready var Effect2PieceLabel = $Artifact2PieceEffectLabel
@onready var Effect4PieceLabel = $Artifact4PieceEffectLabel
@onready var Stat1Label = $WeaponStatsContainer/Stat1Info
@onready var Stat2Label = $WeaponStatsContainer/Stat2Info
@onready var WeaponIcon = $WeaponIcon
@onready var CurrentHealthLabel = $CurrentStatsContainer/Health
@onready var CurrentAttackLabel = $CurrentStatsContainer/Attack
@onready var CurrentDefenseLabel = $CurrentStatsContainer/Defense
@onready var CurrentElementalMasteryLabel = $CurrentStatsContainer/Elemental_Mastery
@onready var CurrentEnergyRechargeLabel = $CurrentStatsContainer/Energy_Recharge
@onready var CurrentCriticalDamageLabel = $CurrentStatsContainer/Critical_Damage
var original_artifact

const HIGHLIGHT_COLOR := "#E2C290" # your pale gold



func set_stats(weapon: Dictionary) -> void:
	# --- Empty artifact: clear everything and bail ---
	if typeof(weapon) == TYPE_DICTIONARY and weapon.size() == 0:
		WeaponNameLabel.text = ""
		Effect2PieceLabel.text = ""
		Effect4PieceLabel.text = ""
		Stat1Label.text = ""
		Stat2Label.text = ""
		WeaponIcon.texture = null

		CurrentHealthLabel.text = ""
		CurrentAttackLabel.text = ""
		CurrentDefenseLabel.text = ""
		CurrentElementalMasteryLabel.text = ""
		CurrentEnergyRechargeLabel.text = ""
		CurrentCriticalDamageLabel.text = ""
		return

	# --- Non-empty: proceed safely ---
	if weapon.has("Name"):
		WeaponNameLabel.text = weapon["Name"]
	else:
		WeaponNameLabel.text = ""

	if weapon.has("TwoPiece"):
		Effect2PieceLabel.text = "2-Piece: " + str(weapon["TwoPiece"])
	else:
		Effect2PieceLabel.text = ""

	if weapon.has("FourPiece"):
		Effect4PieceLabel.text = "4-Piece: " + str(weapon["FourPiece"])
	else:
		Effect4PieceLabel.text = ""

	var Stat1Type = null
	if weapon.has("Stat1"):
		Stat1Type = weapon["Stat1"]

	var Stat2Type = null
	if weapon.has("Stat2"):
		Stat2Type = weapon["Stat2"]

	var Stat1Value = null
	if weapon.has("Stat1Value"):
		Stat1Value = weapon["Stat1Value"]

	var Stat2Value = null
	if weapon.has("Stat2Value"):
		Stat2Value = weapon["Stat2Value"]

	if Stat1Type != null:
		Stat1Label.text = str(Stat1Type) + ": " + str(Stat1Value)
	else:
		Stat1Label.text = ""

	if Stat2Type != null:
		Stat2Label.text = str(Stat2Type) + ": " + str(Stat2Value)
	else:
		Stat2Label.text = ""

	# Icon
	WeaponIcon.texture = null
	if weapon.has("Type") and weapon.has("Name"):
		var artifacttype = ""
		match weapon["Type"]:
			"Feather of Death":
				artifacttype = "plume"
			"Flower of Life":
				artifacttype = "flower"
			"Sands of Time":
				artifacttype = "sands"
			"Goblet of Space":
				artifacttype = "goblet"
			"Circlet of Principles":
				artifacttype = "circlet"

		if artifacttype != "":
			var hyphen_name = Global.normalize_text_filename(weapon["Name"] + " " + artifacttype)
			WeaponIcon.texture = load("res://UI/Artifact Icons/" + hyphen_name)

	# Current vs Selected preview
	if self.name == "CurrentArtifactPreview":
		CurrentHealthLabel.text = "Health: " + str(Global.Current_Health)
		CurrentAttackLabel.text = "Attack: " + str(Global.Current_Attack)
		CurrentDefenseLabel.text = "Defense: " + str(Global.Current_Defense)
		CurrentElementalMasteryLabel.text = "Elemental_Mastery: " + str(Global.Current_Elemental_Mastery)
		CurrentEnergyRechargeLabel.text = "Energy_Recharge: " + str(Global.Current_Energy_Recharge)
		CurrentCriticalDamageLabel.text = "Critical_Damage: " + str(Global.Current_Critical_Damage)
	else:
		var NewHealth = Global.Current_Health
		var NewAttack = Global.Current_Attack
		var NewDefense = Global.Current_Defense
		var NewElementalMastery = Global.Current_Elemental_Mastery
		var NewEnergyRecharge = Global.Current_Energy_Recharge
		var NewCriticalDamage = Global.Current_Critical_Damage

		if typeof(original_artifact) == TYPE_DICTIONARY and original_artifact.size() > 0:
			if original_artifact.has("Stat1"):
				match original_artifact["Stat1"]:
					"Health":
						NewHealth -= original_artifact.get("Stat1Value", 0)
					"Attack":
						NewAttack -= original_artifact.get("Stat1Value", 0)
					"Defense":
						NewDefense -= original_artifact.get("Stat1Value", 0)
					"Elemental_Mastery":
						NewElementalMastery -= original_artifact.get("Stat1Value", 0)
					"Energy_Recharge":
						NewEnergyRecharge -= original_artifact.get("Stat1Value", 0)
					"Critical_Damage":
						NewCriticalDamage -= original_artifact.get("Stat1Value", 0)

			if original_artifact.has("Stat2"):
				match original_artifact["Stat2"]:
					"Health":
						NewHealth -= original_artifact.get("Stat2Value", 0)
					"Attack":
						NewAttack -= original_artifact.get("Stat2Value", 0)
					"Defense":
						NewDefense -= original_artifact.get("Stat2Value", 0)
					"Elemental_Mastery":
						NewElementalMastery -= original_artifact.get("Stat2Value", 0)
					"Energy_Recharge":
						NewEnergyRecharge -= original_artifact.get("Stat2Value", 0)
					"Critical_Damage":
						NewCriticalDamage -= original_artifact.get("Stat2Value", 0)

		if Stat1Type != null:
			match Stat1Type:
				"Health":
					NewHealth += Stat1Value
				"Attack":
					NewAttack += Stat1Value
				"Defense":
					NewDefense += Stat1Value
				"Elemental_Mastery":
					NewElementalMastery += Stat1Value
				"Energy_Recharge":
					NewEnergyRecharge += Stat1Value
				"Critical_Damage":
					NewCriticalDamage += Stat1Value

		if Stat2Type != null:
			match Stat2Type:
				"Health":
					NewHealth += Stat2Value
				"Attack":
					NewAttack += Stat2Value
				"Defense":
					NewDefense += Stat2Value
				"Elemental_Mastery":
					NewElementalMastery += Stat2Value
				"Energy_Recharge":
					NewEnergyRecharge += Stat2Value
				"Critical_Damage":
					NewCriticalDamage += Stat2Value

		set_stat_label(CurrentHealthLabel, "Health", NewHealth, Global.Current_Health)
		set_stat_label(CurrentAttackLabel, "Attack", NewAttack, Global.Current_Attack)
		set_stat_label(CurrentDefenseLabel, "Defense", NewDefense, Global.Current_Defense)
		set_stat_label(CurrentElementalMasteryLabel, "Elemental Mastery", NewElementalMastery, Global.Current_Elemental_Mastery)
		set_stat_label(CurrentEnergyRechargeLabel, "Energy Recharge", NewEnergyRecharge, Global.Current_Energy_Recharge)
		set_stat_label(CurrentCriticalDamageLabel, "Critical Damage", NewCriticalDamage, Global.Current_Critical_Damage)




func set_stat_label(label: RichTextLabel, stat_name: String, new_value, current_value):
	label.bbcode_enabled = true
	if new_value != current_value:
		label.text = "[color=%s]%s: %s[/color]" % [HIGHLIGHT_COLOR,stat_name, str(new_value)]
	else:
		label.text = "%s: %s" % [stat_name, str(new_value)]
