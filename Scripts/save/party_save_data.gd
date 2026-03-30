class_name PartySaveData extends Resource
## Party configuration. Lives in the save file.

@export var id: int = 0
@export var members: Array = []        # Array of character names [String]
@export var turn_order: Array = []     # Array of battler labels [String]
@export var current_turn: String = ""
@export var mora: int = 0
@export var dungeon_master: String = ""
@export var active_food_buff: String = "None"
@export var buff_battles_left: int = 0
@export var gambles: int = 0
@export var companion_limit: int = 1
@export var active_battle_id: String = ""
@export var current_region: String = "Mondstadt"
