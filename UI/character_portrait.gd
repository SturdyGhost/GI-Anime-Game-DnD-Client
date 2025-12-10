extends TextureButton

@onready var ElementIcon = $ElementTexture
@onready var PortraitIcon = $PortraitTexture
@onready var NameLabel = $NameLabel

var PlayerData
var CompanionData


func set_character(name):
	NameLabel.text = name
	if Global.CHARACTERS_NAME.has(name):
		PlayerData = Global.CHARACTERS[Global.CHARACTERS_NAME[name]]
		var PlayerElement = PlayerData.get("Element")
		ElementIcon.texture = load("res://UI/Element Icons/"+PlayerElement+".png")
		var PlayerPortrait = PlayerData.get("Portrait")
		PortraitIcon.texture = load("res://UI/Emotes/"+str(PlayerPortrait))
	else:
		CompanionData = Global.COMPANIONS[Global.COMPANIONS_NAME[name]]
		var CompanionElement = CompanionData.get("Element")
		var hyphen = CompanionData.get("Name").to_lower().replace(" ","-")
		ElementIcon.texture = load("res://UI/Element Icons/"+CompanionElement+".png")
		PortraitIcon.texture = load("res://UI/Character Portaits/ui-avataricon-"+hyphen+".png")
		
	
