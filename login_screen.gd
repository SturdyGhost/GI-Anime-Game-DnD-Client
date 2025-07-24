extends Node2D

@onready var http = $HTTPRequest

func _ready():
	# Capture Enter key for login
	set_process_input(true)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			$Container/LoginButton.emit_signal("pressed")

func get_airtable_data():
	var email = $Container/UserEmailField.text.strip_edges().to_lower()
	var table = "Items"  # Replace with your actual target table
	var url = "https://godot-airtable-backend.onrender.com/get_table?table=%s&email=%s" % [table, email]
	var error = http.request(url)
	if error != OK:
		print("Request failed with error: ", error)

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Response code: ", response_code)
	var raw = body.get_string_from_utf8()

	if response_code == 200:
		var response = JSON.parse_string(raw)
		if response:
			var records = response["records"]
			$Container/ErrorMessageLabel.text = ""
			for record in records:
				print("✔ Record: ", record)
		else:
			print("⚠ Failed to parse JSON")
	elif response_code == 403:
		print("❌ Invalid email – not in Characters table")
		$Container/ErrorMessageLabel.text = "Email not recognized."
	else:
		print("❌ Request failed with code: ", response_code)


func _on_login_button_pressed() -> void:
	get_airtable_data()
	pass # Replace with function body.
