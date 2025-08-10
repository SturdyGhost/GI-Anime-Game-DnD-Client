extends Node2D

@onready var http = $HTTPRequest
var UserType 

func _ready():
	ping_airtable_startup()
	# Capture Enter key for login
	set_process_input(true)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			$Container/LoginButton.emit_signal("pressed")

func ping_airtable_startup():
	var URL = Global.API_BASE+"/ping"
	var error = $PingRequest.request(URL)
	


func get_airtable_data(hashed_email):
	var email = $Container/UserEmailField.text.strip_edges().to_lower()
	var table = "Characters"  # Replace with your actual target table
	var url = Global.API_BASE+"/get_table?table=%s&email=%s" % [table, hashed_email]
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
				if record["Email"] == hash_email($Container/UserEmailField.text.strip_edges().to_lower()):
					UserType = record["UserType"]
					match UserType:
						"Player":
							Global.ACTIVE_USER_EMAIL = hash_email($Container/UserEmailField.text.strip_edges().to_lower())
							Global.ACTIVE_USER_NAME = record["Name"]
							get_tree().change_scene_to_file("res://Scene's/player_hub_loading.tscn")
						"Dungeon Master":
							Global.ACTIVE_USER_EMAIL = hash_email($Container/UserEmailField.text.strip_edges().to_lower())
							Global.ACTIVE_USER_NAME = record["Name"]
							get_tree().change_scene_to_file("res://Scene's/dungeon_master_hub.tscn")
						_:
							$Container/ErrorMessageLabel.text = "Unknown user type."
				#print("✔ Record: ", record)
				
		else:
			print("⚠ Failed to parse JSON")
	elif response_code == 403:
		print("❌ Invalid email – not in Characters table")
		$Container/ErrorMessageLabel.text = "Email not recognized."
		$Container/LoginButton.disabled = false

		
	else:
		print("❌ Request failed with code: ", response_code)
		$Container/LoginButton.disabled = false

func hash_email(email: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(email.to_utf8_buffer())
	var digest := ctx.finish()
	return digest.hex_encode()

func _on_login_button_pressed() -> void:
	$Container/LoginButton.disabled = true
	var input_email = $Container/UserEmailField.text.strip_edges().to_lower()
	var hashed_email = hash_email(input_email)
	print (hashed_email)
	get_airtable_data(hashed_email)
	pass # Replace with function body.


func _on_ping_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Startup Ping Successful")
	pass # Replace with function body.
