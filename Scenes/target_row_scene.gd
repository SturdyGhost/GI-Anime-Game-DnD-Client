extends Panel

@onready var NameLabel = $NameLabel
@onready var RollEdit = $RollEdit
@onready var HitsEdit = $HitsEdit
@onready var DamageEdit = $DamageEdit
@onready var AttackType = $AttackType
@onready var AppliedElement = $AppliedElement
@onready var KilledStatus = $KilledBox

var TargetID
var TargetTable
