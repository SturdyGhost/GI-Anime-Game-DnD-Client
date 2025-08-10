extends Panel

@onready var WeaponNameLabel = $WeaponName
@onready var WeaponEffectLabel = $WeaponDescription
@onready var Stat1Label = $WeaponStatsContainer/Stat1Info
@onready var Stat2Label = $WeaponStatsContainer/Stat2Info
@onready var Stat3Label = $WeaponStatsContainer/Stat3Info
@onready var WeaponIcon = $WeaponIcon
@onready var CurrentHealthLabel = $CurrentStatsContainer/Health
@onready var CurrentAttackLabel = $CurrentStatsContainer/Attack
@onready var CurrentDefenseLabel = $CurrentStatsContainer/Defense
@onready var CurrentElementalMasteryLabel = $CurrentStatsContainer/Elemental_Mastery
@onready var CurrentEnergyRechargeLabel = $CurrentStatsContainer/Energy_Recharge
@onready var CurrentCriticalDamageLabel = $CurrentStatsContainer/Critical_Damage

const HIGHLIGHT_COLOR := "#E2C290" # your pale gold



func set_stats(weapon):
	WeaponNameLabel.text = weapon["Weapon"]
	WeaponEffectLabel.text = weapon["Effect"]
	var Stat1Type = weapon["Stat_1_Type"]
	var Stat2Type = weapon["Stat_2_Type"]
	var Stat3Type = weapon["Stat_3_Type"]
	var Stat1Value = weapon["Stat_1_Value"]
	var Stat2Value = weapon["Stat_2_Value"]
	var Stat3Value = weapon["Stat_3_Value"]
	if Stat1Type != null:
		Stat1Label.text = Stat1Type+": "+ str(Stat1Value)
	else:
		Stat1Label.text = ""
	if Stat2Type != null:
		Stat2Label.text = Stat2Type+": "+ str(Stat2Value)
	else:
		Stat2Label.text = ""
	if Stat3Type != null:
		Stat3Label.text = Stat3Type+": "+ str(Stat3Value)
	else:
		Stat3Label.text = ""
	var hyphen_name = Global.normalize_text_filename(weapon["Weapon"])
	WeaponIcon.texture = load("res://UI/Weapon Icons/"+hyphen_name)
	if self.name == "CurrentWeaponPreview":
		CurrentHealthLabel.text = "Health: "+str(Global.Current_Health)
		CurrentAttackLabel.text = "Attack: "+str(Global.Current_Attack)
		CurrentDefenseLabel.text = "Defense: "+str(Global.Current_Defense)
		CurrentElementalMasteryLabel.text = "Elemental_Mastery: "+str(Global.Current_Elemental_Mastery)
		CurrentEnergyRechargeLabel.text = "Energy_Recharge: "+str(Global.Current_Energy_Recharge)
		CurrentCriticalDamageLabel.text = "Critical_Damage: "+str(Global.Current_Critical_Damage)
	else:
		var NewHealth = Global.Current_Health
		var NewAttack = Global.Current_Attack
		var NewDefense = Global.Current_Defense
		var NewElementalMastery = Global.Current_Elemental_Mastery
		var NewEnergyRecharge = Global.Current_Energy_Recharge
		var NewCriticalDamage = Global.Current_Critical_Damage
		match Global.Current_Weapon["Stat_1_Type"]:
			"Health":
				NewHealth -= Global.Current_Weapon["Stat_1_Value"]
			"Attack":
				NewAttack -= Global.Current_Weapon["Stat_1_Value"]
			"Defense":
				NewDefense -= Global.Current_Weapon["Stat_1_Value"]
			"Elemental_Mastery":
				NewElementalMastery -= Global.Current_Weapon["Stat_1_Value"]
			"Energy_Recharge":
				NewEnergyRecharge -= Global.Current_Weapon["Stat_1_Value"]
			"Critical_Damage":
				NewCriticalDamage -= Global.Current_Weapon["Stat_1_Value"]
		match Global.Current_Weapon["Stat_2_Type"]:
			"Health":
				NewHealth -= Global.Current_Weapon["Stat_2_Value"]
			"Attack":
				NewAttack -= Global.Current_Weapon["Stat_2_Value"]
			"Defense":
				NewDefense -= Global.Current_Weapon["Stat_2_Value"]
			"Elemental_Mastery":
				NewElementalMastery -= Global.Current_Weapon["Stat_2_Value"]
			"Energy_Recharge":
				NewEnergyRecharge -= Global.Current_Weapon["Stat_2_Value"]
			"Critical_Damage":
				NewCriticalDamage -= Global.Current_Weapon["Stat_2_Value"]
		match Global.Current_Weapon["Stat_3_Type"]:
			"Health":
				NewHealth -= Global.Current_Weapon["Stat_3_Value"]
			"Attack":
				NewAttack -= Global.Current_Weapon["Stat_3_Value"]
			"Defense":
				NewDefense -= Global.Current_Weapon["Stat_3_Value"]
			"Elemental_Mastery":
				NewElementalMastery -= Global.Current_Weapon["Stat_3_Value"]
			"Energy_Recharge":
				NewEnergyRecharge -= Global.Current_Weapon["Stat_3_Value"]
			"Critical_Damage":
				NewCriticalDamage -= Global.Current_Weapon["Stat_3_Value"]
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
		match Stat3Type:
			"Health":
				NewHealth += Stat3Value
			"Attack":
				NewAttack += Stat3Value
			"Defense":
				NewDefense += Stat3Value
			"Elemental_Mastery":
				NewElementalMastery += Stat3Value
			"Energy_Recharge":
				NewEnergyRecharge += Stat3Value
			"Critical_Damage":
				NewCriticalDamage += Stat3Value
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
