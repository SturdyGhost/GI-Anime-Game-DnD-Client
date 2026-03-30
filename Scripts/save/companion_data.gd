class_name CompanionSaveData extends Resource
## Persistent companion data. Lives in the save file.

@export var id: int = 0
@export var name: String = ""
@export var element: String = ""
@export var weapon: String = ""
@export var region: String = ""
@export var lore: String = ""
@export var unlocked: bool = false
@export var active: bool = false
@export var met: bool = false
@export var player_chosen: bool = false
@export var owner: String = ""

# ── Stats ────────────────────────────────────────────────────────────────────
@export var stats: EntityStats = null

# ── Combat State ─────────────────────────────────────────────────────────────
@export var current_health: int = 0
@export var max_health: int = 0
@export var burst_charges: int = 0
@export var shield_health: int = 0
@export var shield_duration: int = 0
@export var applied_element: String = "None"
@export var skipped: bool = false
@export var skip_duration: int = 0

func _init() -> void:
	if stats == null:
		stats = EntityStats.new()
