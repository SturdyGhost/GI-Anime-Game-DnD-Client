class_name SaveData extends Resource
## The host's save file. Stores ONLY mutable runtime state — overrides on top of
## the base .tres resources that live in data/resources/.
##
## Base data (stats, names, equipment specs) → .tres files in project
## Mutable state (health, burst charges, mora, chosen talents) → this save file

# ── Player combat state overrides (player_name → dict of mutable fields) ────
@export var player_state: Dictionary = {}
# e.g. { "Dylan": { "current_health": 45, "burst_charges": 8, "applied_element": "Fire", ... } }

# ── Companion combat state overrides ────────────────────────────────────────
@export var companion_state: Dictionary = {}

# ── Party runtime state ─────────────────────────────────────────────────────
@export var party_mora: int = 0
@export var party_current_turn: String = ""
@export var party_active_food_buff: String = "None"
@export var party_buff_battles_left: int = 0
@export var party_gambles: int = 0
@export var party_active_battle_id: String = ""
@export var party_turn_order: Array = []

# ── Progression choices ─────────────────────────────────────────────────────
@export var talents_chosen: Array = []        # Array of int (Talent IDs)
@export var constellations_chosen: Array = [] # Array of int (Constellation IDs)

# ── Game config overrides ───────────────────────────────────────────────────
@export var game_config: Dictionary = {}

# ── Minigame results ────────────────────────────────────────────────────────
@export var minigame_results: Array = []  # Array of MinigameResult

# ── Inventory ownership/state (which items are equipped, quantities, owners) ─
# These override the base .tres data. Key = resource filename (slug).
@export var weapon_overrides: Dictionary = {}
# e.g. { "dylans_skyward_spine": { "equipped": true, "owner": "Dylan" } }
@export var artifact_overrides: Dictionary = {}
@export var item_quantities: Dictionary = {}
# e.g. { "dylan_iron_chunk": { "quantity": 15, "owner": "Dylan" } }

# ── Map markers (player_name → Array of marker dicts) ─────────────────────
@export var map_markers: Dictionary = {}
# e.g. { "Dylan": [ { "id": "abc", "position_x": 100.0, "position_y": 200.0, "shape": "circle", "note": "..." }, ... ] }
