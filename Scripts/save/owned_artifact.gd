class_name OwnedArtifact extends Resource
## An artifact instance owned by a character. FK to GameDB.artifact_sets via set name.

@export var id: int = 0
@export var artifact_set: String = ""  # FK to ArtifactSetData.artifact_set in GameDB
@export var owner: String = ""         # Character name
@export var type: String = ""          # Flower of Life, Feather of Death, Sands of Time, Goblet of Space, Circlet of Principles
@export var equipped: bool = false
@export var rarity: int = 0

# ── Instance stats (rolled per artifact) ─────────────────────────────────────
@export var stat_1_type: String = ""
@export var stat_1_value: float = 0.0
@export var stat_2_type: String = ""
@export var stat_2_value: float = 0.0
