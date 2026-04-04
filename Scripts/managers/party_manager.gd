extends Node
## Manages party composition, companions, and food buffs.

signal party_changed

func get_party() -> PartySaveData:
	return SaveManager.get_party()

func get_members() -> Array:
	var party = get_party()
	if party:
		return party.members
	# Client fallback: read from _synced Party record
	var pd = Global.Current_Party
	var members = []
	for i in range(1, 5):
		var m = pd.get("Party_Member_%d" % i, "")
		if m != "" and m != "COMPANION":
			members.append(m)
	return members

func get_turn_order() -> Array:
	var party = get_party()
	if party:
		return party.turn_order
	var to = Global.Current_Party.get("Turn_Order", [])
	return to if to is Array else []

func get_current_turn() -> String:
	var party = get_party()
	if party:
		return party.current_turn
	return str(Global.Current_Party.get("Current_Turn", ""))

func get_mora() -> int:
	var party = get_party()
	if party:
		return party.mora
	return int(Global.Current_Party.get("Mora", 0))

## Get active player character names (not companions, not enemies).
func get_player_names() -> Array:
	var result = []
	for pname in get_members():
		if SaveManager.get_player(pname) != null:
			result.append(pname)
			continue
		# Client fallback: check _synced Characters
		if Global.CHARACTERS_NAME.has(pname):
			result.append(pname)
	return result

## Get active companion names.
func get_companion_names() -> Array:
	var result = []
	if SaveManager.data != null:
		for comp in SaveManager.get_all_companions():
			if comp.active:
				result.append(comp.name)
	else:
		# Client fallback: read from _synced Companions
		for comp in Global.COMPANIONS.values():
			if comp.get("Active") == true:
				result.append(comp.get("Name", ""))
	return result

## Check if a name is a player character.
func is_player(name: String) -> bool:
	if SaveManager.get_player(name) != null:
		return true
	return Global.CHARACTERS_NAME.has(name)

## Check if a name is a companion.
func is_companion(name: String) -> bool:
	return SaveManager.get_companion(name) != null

## Set food buff.
func set_food_buff(buff_name: String, battles: int) -> void:
	var party = get_party()
	if party:
		party.active_food_buff = buff_name
		party.buff_battles_left = battles
		SaveManager.mark_dirty()

## Advance turn to next battler.
func advance_turn(next_battler: String) -> void:
	var party = get_party()
	if party:
		party.current_turn = next_battler
		SaveManager.mark_dirty()
		emit_signal("party_changed")

## Update mora.
func add_mora(amount: int) -> void:
	var party = get_party()
	if party:
		party.mora += amount
		SaveManager.mark_dirty()
