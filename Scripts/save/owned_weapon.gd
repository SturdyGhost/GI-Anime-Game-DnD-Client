class_name OwnedWeapon extends Resource
## A weapon instance owned by a character. FK to GameDB.weapons via weapon_id.

@export var id: int = 0
@export var weapon_id: int = 0       # FK to WeaponData.id in GameDB
@export var weapon_name: String = "" # Denormalized for display convenience
@export var owner: String = ""       # Character name
@export var equipped: bool = false
@export var refinement: int = 0
@export var quantity: int = 1
@export var rarity: String = ""
@export var region: String = ""
@export var weapon_type: String = "" # Sword, Claymore, Polearm, Bow, Catalyst

# ── Instance stats (rolled/assigned per owned copy) ──────────────────────────
@export var stat_1_type: String = ""
@export var stat_1_value: float = 0.0
@export var stat_2_type: String = ""
@export var stat_2_value: float = 0.0
@export var stat_3_type: String = ""
@export var stat_3_value: float = 0.0

## Get the WeaponData definition from GameDB.
func get_definition() -> WeaponData:
	return GameDB.get_weapon(weapon_id)
