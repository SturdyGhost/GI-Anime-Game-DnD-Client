class_name OwnedItem extends Resource
## An item instance owned by a character. FK to GameDB.items via item_name.

@export var id: int = 0
@export var item_name: String = ""  # FK to ItemData.item_name in GameDB
@export var owner: String = ""      # Character name
@export var quantity: int = 0
@export var rarity: String = ""
@export var type: String = ""       # Consumable, Ore, Herbs, etc.

## Get the ItemData definition from GameDB.
func get_definition() -> ItemData:
	return GameDB.get_item_by_name(item_name)
