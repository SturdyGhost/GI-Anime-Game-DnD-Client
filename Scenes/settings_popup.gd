extends AcceptDialog

@onready var server_field: LineEdit = $VBoxContainer/ServerField

func _ready() -> void:
	title = "Settings"
	# Show current connection info
	if NetworkManager.is_host:
		server_field.text = "Hosting on port %d" % NetworkManager.DEFAULT_PORT
		if NetworkManager.public_ip != "":
			server_field.text += " (Public IP: %s)" % NetworkManager.public_ip
	elif NetworkManager.is_connected_to_host:
		server_field.text = "Connected to host"
	else:
		server_field.text = "Not connected"

	server_field.editable = false
	confirmed.connect(_on_confirmed)

func _on_confirmed() -> void:
	pass
