class_name MinigameResult extends Resource
## A minigame play result. Lives in the save file.

@export var id: int = 0
@export var minigame_id: String = ""  # FK to MinigameData.key in GameDB
@export var player_name: String = ""  # Character name
@export var score: int = 0
@export var rewards: String = ""      # JSON string of rewards dict
