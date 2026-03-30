extends Node
## Manages player inventory: weapons, artifacts, items.

signal inventory_changed(owner: String)

# ── Weapons ──────────────────────────────────────────────────────────────────

func get_weapons_for(owner: String) -> Array:
	var result = []
	for w in SaveManager.get_all_owned_weapons():
		if w.owner == owner:
			result.append(w)
	return result

func get_equipped_weapon(owner: String) -> OwnedWeapon:
	return SaveManager.get_equipped_weapon(owner)

func equip_weapon(owner: String, weapon: OwnedWeapon) -> void:
	CharacterManager.equip_weapon(owner, weapon)
	emit_signal("inventory_changed", owner)

func transfer_weapon(weapon: OwnedWeapon, new_owner: String) -> void:
	weapon.owner = new_owner
	weapon.equipped = false
	SaveManager.mark_dirty()
	emit_signal("inventory_changed", new_owner)

# ── Artifacts ────────────────────────────────────────────────────────────────

func get_artifacts_for(owner: String) -> Array:
	var result = []
	for a in SaveManager.get_all_owned_artifacts():
		if a.owner == owner:
			result.append(a)
	return result

func get_equipped_artifacts(owner: String) -> Array:
	return SaveManager.get_equipped_artifacts(owner)

func equip_artifact(owner: String, artifact: OwnedArtifact) -> void:
	artifact.owner = owner
	artifact.equipped = true
	CharacterManager.calculate_stats(owner)
	SaveManager.mark_dirty()
	emit_signal("inventory_changed", owner)

func unequip_artifact(artifact: OwnedArtifact) -> void:
	var prev_owner = artifact.owner
	artifact.equipped = false
	CharacterManager.calculate_stats(prev_owner)
	SaveManager.mark_dirty()
	emit_signal("inventory_changed", prev_owner)

func transfer_artifact(artifact: OwnedArtifact, new_owner: String) -> void:
	var prev_owner = artifact.owner
	artifact.owner = new_owner
	artifact.equipped = false
	CharacterManager.calculate_stats(prev_owner)
	SaveManager.mark_dirty()
	emit_signal("inventory_changed", prev_owner)
	emit_signal("inventory_changed", new_owner)

# ── Items ────────────────────────────────────────────────────────────────────

func get_items_for(owner: String) -> Array:
	return SaveManager.get_items_for(owner)

func get_consumables_for(owner: String) -> Array:
	var result = []
	for item in get_items_for(owner):
		var def = item.get_definition()
		if def and def.type == "Consumable":
			result.append(item)
	return result

func consume_item(item: OwnedItem, amount: int = 1) -> void:
	item.quantity -= amount
	if item.quantity < 0:
		item.quantity = 0
	SaveManager.mark_dirty()
	emit_signal("inventory_changed", item.owner)

func add_item(owner: String, item_name: String, quantity: int) -> void:
	# Check if already owns this item
	for item in SaveManager.get_all_owned_items():
		if item.owner == owner and item.item_name == item_name:
			item.quantity += quantity
			SaveManager.mark_dirty()
			emit_signal("inventory_changed", owner)
			return
	# Create new
	var new_item = OwnedItem.new()
	new_item.id = _next_item_id()
	new_item.item_name = item_name
	new_item.owner = owner
	new_item.quantity = quantity
	var def = GameDB.get_item_by_name(item_name)
	if def:
		new_item.rarity = def.rarity
		new_item.type = def.type
	SaveManager.data.owned_items.append(new_item)
	SaveManager.mark_dirty()
	emit_signal("inventory_changed", owner)

func _next_item_id() -> int:
	var max_id = 0
	for item in SaveManager.get_all_owned_items():
		if item.id > max_id:
			max_id = item.id
	return max_id + 1
