extends Node2D

@onready var http = $HTTPRequest

const AIRTABLE_BASE_ID = Global.AIRTABLE_BASE_ID
const AIRTABLE_TOKEN = Global.AIRTABLE_TOKEN
const AIRTABLE_TABLE_NAME = "Characters"
const API_URL = "https://api.airtable.com/v0/" + AIRTABLE_BASE_ID + "/" + AIRTABLE_TABLE_NAME

func _ready():
	pass

func get_airtable_data():
	var headers = ["Authorization: Bearer " + AIRTABLE_TOKEN]
	var error = http.request(API_URL, headers)
	if error != OK:
		print("Request failed with error: ", error)

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		var matchingrecord = 0
		if response:
			for record in response["records"]:
				var fields = record["fields"]
				if fields.get("Email") == $Container/UserEmailField.text:
					$Container/ErrorMessageLabel.text = ""
					matchingrecord = 1
					print (record)
			if matchingrecord == 0:
				$Container/ErrorMessageLabel.text = "No Matching Records Found, please try again."
				print ("No Records match")
				#self.text = fields.get("Email")
		else:
			print("Failed to parse JSON")
	else:
		print("Error: ", response_code)


func _on_button_pressed() -> void:
	get_airtable_data()
	pass # Replace with function body.
