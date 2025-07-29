extends Node

var ACTIVE_USER_EMAIL: String = ""
var ACTIVE_USER_NAME: String = ""
var TABLES: Array = ["Artifacts","Reactions","Weapons","Abilities","Companions","Crafting Recipes","Items","Enemies","Characters","BattleEnemies","Character Items","Character Weapons", "Character Artifacts","Battle Log","Talents","Constellations"]
var ARTIFACTS: Dictionary = {}
var REACTIONS: Dictionary = {}
var WEAPONS: Dictionary = {}
var ABILITIES: Dictionary = {}
var COMPANIONS: Dictionary = {}
var CRAFTINGRECIPES: Dictionary = {}
var ITEMS: Dictionary = {}
var ENEMIES: Dictionary = {}
var CHARACTERS: Dictionary = {}
var BATTLEENEMIES: Dictionary = {}
var CHARACTER_ITEMS: Dictionary = {}
var CHARACTER_WEAPONS: Dictionary = {}
var CHARACTER_ARTIFACTS: Dictionary = {}
var BATTLE_LOG: Dictionary = {}
var ARTIFACTS_NAME = {}
var WEAPONS_NAME = {}
var COMPANIONS_NAME = {}
var CRAFTINGRECIPES_NAME = {}
var ITEMS_NAME = {}
var ENEMIES_NAME = {}
var CHARACTERS_NAME = {}
var BATTLEENEMIES_NAME = {}
var CHARACTER_WEAPONS_NAME = {}
var CHARACTER_ITEMS_NAME = {}
var TABLES_TO_SAVE = ["Characters","BattleEnemies","Character Items","Character Weapons", "Character Artifacts","Battle Log", "Companions"] #When you save also force a manual re-sync
var TABLES_TO_SYNC_OFTEN = ["Characters","BattleEnemies"] #Resycnc often while in battles.
var BATTLE_TURN_ORDER = []
var Current_Region = "Sumeru"





#When downloading/referencing files downloaded from online they sometimes contain hidden symbols or charaacters in their name, this function removes any hidden characters
#For scenarios where you encounter them.
func normalize_text_filename(weapon_name: String) -> String:
	var cleaned := weapon_name.strip_edges().to_lower()

	# Handle known invisible/Unicode-breaking characters
	cleaned = cleaned.replace(" ", " ")  # U+00A0 non-breaking space
	cleaned = cleaned.replace("­", "")   # U+00AD soft hyphen
	cleaned = cleaned.replace("’", "")   # curly apostrophe
	cleaned = cleaned.replace(" ", "-")

	# Compile a regex to remove any non a–z, 0–9, or dash
	var regex := RegEx.new()
	regex.compile("[^a-z0-9-]")

	cleaned = regex.sub(cleaned, "", true)

	return cleaned + ".png"
