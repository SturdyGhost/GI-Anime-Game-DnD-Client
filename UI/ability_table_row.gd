extends HBoxContainer

@onready var AbilityLabel = $Panel2/Ability
@onready var TypeLabel = $Panel3/Type
@onready var MovementLabel = $Panel4/Movement
@onready var RangeLabel = $Panel5/Range
@onready var CDLabel = $Panel6/CD
@onready var ChargeLabel = $Panel7/Charges
@onready var DescriptionLabel = $Panel/Description
@onready var DescriptionPanel = $Panel


func _process(delta: float) -> void:
	if DescriptionLabel.text != null:
		DescriptionPanel.custom_minimum_size = Vector2(1280,DescriptionLabel.size.y)
