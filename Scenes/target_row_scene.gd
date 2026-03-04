extends Panel

@onready var NameLabel = $NameLabel
@onready var RollEdit = $RollEdit
@onready var HitsEdit = $HitsEdit
@onready var DamageEdit = $DamageEdit
@onready var AttackType = $AttackType
@onready var AppliedElement = $AppliedElement
@onready var KilledStatus = $KilledBox
@onready var ShieldHit = $HitShieldBox

var TargetID
var TargetTable
var TargetShieldAmount = 0

func _process(delta: float) -> void:
	if TargetShieldAmount > 0:
		ShieldHit.disabled = false
	else:
		ShieldHit.disabled = true
		
