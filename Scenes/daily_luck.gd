extends Control

@onready var LuckEdit = $LineEdit

func _on_button_pressed() -> void:
	Global.Update_Records([{"table": "Characters",
	"record_id": str(int(Global.ACTIVE_USER_RECORD_ID)),  # Must be the Party's record id
	"field": "Daily_Luck",
	"value": int(LuckEdit.text)}])
	Market.Set_Daily_Luck(int(LuckEdit.text))
	Market.Refresh_Stock(Global.Current_Region)
	self.queue_free()
	pass # Replace with function body.
