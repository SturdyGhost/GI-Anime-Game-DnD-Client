extends TextureButton

@onready var ElementIcon = $ElementTexture
@onready var PortraitIcon = $PortraitTexture
@onready var NameLabel = $NameLabel

var PlayerData


func set_character(name):
	NameLabel.text = name
	if Global.CHARACTERS_NAME.has(name):
		PlayerData = Global.CHARACTERS[Global.CHARACTERS_NAME[name]]
		var PlayerElement = PlayerData.get("Element")
		ElementIcon.texture = load("res://UI/Element Icons/"+PlayerElement+".png")
		var PlayerPortrait = PlayerData.get("Portrait")
		PortraitIcon.texture = load("res://UI/Emotes/"+str(PlayerPortrait))
	else:
		var PlayerData = Global.CHARACTERS[Global.CHARACTERS_NAME[Global.ACTIVE_USER_NAME]]
		var CompanionElement = PlayerData.get("Companion_Element")
		ElementIcon.texture = load("res://UI/Element Icons/"+CompanionElement+".png")
		PortraitIcon.texture = load("res://UI/Character Portaits/ui-avataricon-"+PlayerData.get("Companion_Name").to_lower()+".png")
		
	
