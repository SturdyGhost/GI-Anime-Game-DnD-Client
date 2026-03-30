extends Control

@onready var LuckEdit = $LineEdit

func _on_button_pressed() -> void:
	Global.Update_Records([{"table": "Characters",
	"record_id": int(Global.ACTIVE_USER_RECORD_ID),
	"field": "Daily_Luck",
	"value": int(LuckEdit.text)}])
	Market.Set_Daily_Luck(int(LuckEdit.text))
	# Defer market refresh to next frame so UI doesn't freeze
	call_deferred("_refresh_and_close")

func _refresh_and_close() -> void:
	Market.Refresh_Stock(Global.Current_Region)
	queue_free()
