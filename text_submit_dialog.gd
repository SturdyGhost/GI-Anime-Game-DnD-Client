extends AcceptDialog

@onready var Feedback = $VBoxContainer/Editor


func _on_canceled() -> void:
	queue_free()
	pass # Replace with function body.


func _on_confirmed() -> void:
	Global.Log("Feedback","Feedback Submitted","Player Feedback","Player Feedback",{},{"Player Feedback": Feedback.text})
	pass # Replace with function body.
