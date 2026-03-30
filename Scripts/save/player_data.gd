class_name PlayerData extends Resource
## Persistent player character data. Lives in the save file.

@export var id: int = 0
@export var name: String = ""
@export var email: String = ""
@export var user_type: String = "Player"  # "Player" or "Dungeon Master"
@export var portrait: String = ""

# ── Progression ──────────────────────────────────────────────────────────────
@export var level: int = 1
@export var level_cap: int = 20
@export var ascension_rank: int = 0
@export var ascension_material: String = ""
@export var element: String = "Physical"
@export var role: String = ""
@export var current_region: String = "Mondstadt"
@export var daily_luck: int = 50

# ── Stats (persistent base + skill points) ──────────────────────────────────
@export var stats: EntityStats = null

# ── Combat State (persists between sessions for mid-battle saves) ────────────
@export var current_health: int = 0
@export var max_health: int = 0
@export var burst_charges: int = 0
@export var shield_health: int = 0
@export var shield_duration: int = 0
@export var applied_element: String = "None"
@export var skipped: bool = false
@export var skip_duration: int = 0
@export var ready: bool = false

# ── DM Overrides (simple key-value for DM tweaking) ─────────────────────────
@export var dm_overrides: Dictionary = {}

func _init() -> void:
	if stats == null:
		stats = EntityStats.new()
