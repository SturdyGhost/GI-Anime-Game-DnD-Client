extends Control
## Lobby scene: Host or Join a game session.
## Has a waiting room where everyone can see who has joined.

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var character_list: ItemList = $VBoxContainer/CharacterList
@onready var host_list: ItemList = $VBoxContainer/HostList
@onready var ip_field: LineEdit = $VBoxContainer/IPField
@onready var connect_button: Button = $VBoxContainer/ConnectButton
@onready var player_list: ItemList = $VBoxContainer/PlayerList
@onready var start_button: Button = $VBoxContainer/StartButton

enum State { MAIN_MENU, JOIN_SELECT, WAITING_ROOM }
var current_state: State = State.MAIN_MENU

var _available_characters: Array = []
var _dm_character = null

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	start_button.pressed.connect(_on_start_pressed)
	character_list.item_selected.connect(_on_character_selected)
	host_list.item_selected.connect(_on_host_selected)

	NetworkManager.connection_succeeded.connect(_on_connection_succeeded)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.all_data_received.connect(_on_all_data_received)
	NetworkManager.player_connected.connect(_on_lobby_player_changed)
	NetworkManager.player_disconnected.connect(_on_lobby_player_changed)

	_load_characters_from_json()
	_show_main_menu()

func _process(_delta: float) -> void:
	if current_state == State.JOIN_SELECT:
		NetworkManager.poll_discovery()
		_refresh_host_list()
	elif current_state == State.WAITING_ROOM:
		_refresh_player_list()

func _load_characters_from_json() -> void:
	var records := DataStore.load_table("Characters")
	_available_characters.clear()
	_dm_character = null
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		if record.get("UserType") == "Dungeon Master":
			_dm_character = record
		else:
			_available_characters.append(record)

# ─── STATE DISPLAY ───

func _hide_all() -> void:
	host_button.visible = false
	join_button.visible = false
	back_button.visible = false
	character_list.visible = false
	host_list.visible = false
	ip_field.visible = false
	connect_button.visible = false
	player_list.visible = false
	start_button.visible = false

func _show_main_menu() -> void:
	current_state = State.MAIN_MENU
	_hide_all()
	host_button.visible = true
	join_button.visible = true
	status_label.text = "Genshin DnD"

func _show_join_select() -> void:
	current_state = State.JOIN_SELECT
	_hide_all()
	back_button.visible = true
	character_list.visible = true
	host_list.visible = true
	ip_field.visible = true
	connect_button.visible = true
	status_label.text = "Select your character, then pick a host or enter IP"

	character_list.clear()
	for ch in _available_characters:
		character_list.add_item("%s (Lv%s %s)" % [ch.get("Name", "???"), str(ch.get("Level", "?")), str(ch.get("Element", ""))])

	NetworkManager.start_discovery()

func _show_waiting_room() -> void:
	current_state = State.WAITING_ROOM
	_hide_all()
	back_button.visible = true
	player_list.visible = true
	if NetworkManager.is_host:
		start_button.visible = true
		status_label.text = "Waiting for players... Press Start when ready."
	else:
		status_label.text = "Waiting for host to start the game..."
	_refresh_player_list()

func _refresh_host_list() -> void:
	host_list.clear()
	for h in NetworkManager.discovered_hosts:
		host_list.add_item("%s (%s) - %d players" % [h["name"], h["ip"], h["players"]])

func _refresh_player_list() -> void:
	player_list.clear()
	# Always show the host (DM)
	if NetworkManager.is_host:
		player_list.add_item("[HOST] %s (Dungeon Master)" % Global.ACTIVE_USER_NAME)
	else:
		player_list.add_item("[HOST] DM")

	# Show connected players
	for peer_id in NetworkManager.connected_players.keys():
		var info: Dictionary = NetworkManager.connected_players[peer_id]
		player_list.add_item("  %s" % info.get("name", "Unknown"))

	# If we're a client and not yet registered, show ourselves
	if not NetworkManager.is_host and NetworkManager.is_connected_to_host:
		var found := false
		for info in NetworkManager.connected_players.values():
			if info.get("name") == Global.ACTIVE_USER_NAME:
				found = true
				break
		if not found:
			player_list.add_item("  %s (you, syncing...)" % Global.ACTIVE_USER_NAME)

func _on_lobby_player_changed(_peer_id: int) -> void:
	if current_state == State.WAITING_ROOM:
		_refresh_player_list()

# ─── BUTTON HANDLERS ───

func _on_host_pressed() -> void:
	if _dm_character == null:
		status_label.text = "No DM character found in data!"
		return

	Global.ACTIVE_USER_NAME = _dm_character.get("Name", "Chase")
	Global.ACTIVE_USER_RECORD_ID = _dm_character.get("id", 0)
	Global.ACTIVE_USER_TYPE = "Dungeon Master"
	Global.ACTIVE_USER_EMAIL = ""

	status_label.text = "Starting host..."

	var err := NetworkManager.host_game()
	if err != OK:
		status_label.text = "Failed to start host: %s" % error_string(err)
		return

	_show_waiting_room()

func _on_join_pressed() -> void:
	_show_join_select()

func _on_back_pressed() -> void:
	NetworkManager.disconnect_from_game()
	NetworkManager._stop_discovery()
	_show_main_menu()

func _on_character_selected(index: int) -> void:
	if index < 0 or index >= _available_characters.size():
		return
	var ch = _available_characters[index]
	Global.ACTIVE_USER_NAME = ch.get("Name", "")
	Global.ACTIVE_USER_RECORD_ID = ch.get("id", 0)
	Global.ACTIVE_USER_TYPE = "Player"
	Global.ACTIVE_USER_EMAIL = ""
	status_label.text = "Selected: %s — now pick a host or enter IP" % Global.ACTIVE_USER_NAME

func _on_host_selected(index: int) -> void:
	if Global.ACTIVE_USER_NAME == "":
		status_label.text = "Select your character first!"
		return
	if index < 0 or index >= NetworkManager.discovered_hosts.size():
		return
	var h = NetworkManager.discovered_hosts[index]
	_connect_to(h["ip"], h["port"])

func _on_connect_pressed() -> void:
	if Global.ACTIVE_USER_NAME == "":
		status_label.text = "Select your character first!"
		return
	var ip := ip_field.text.strip_edges()
	if ip == "":
		status_label.text = "Enter a host IP address"
		return
	_connect_to(ip, NetworkManager.DEFAULT_PORT)

func _on_start_pressed() -> void:
	if not NetworkManager.is_host:
		return
	# Tell all clients to proceed
	_receive_game_start.rpc()
	# Host proceeds too
	_go_to_game()

func _connect_to(ip: String, port: int) -> void:
	status_label.text = "Connecting to %s:%d..." % [ip, port]
	_hide_all()
	back_button.visible = true

	NetworkManager._stop_discovery()
	var err := NetworkManager.join_game(ip, port)
	if err != OK:
		status_label.text = "Connection error: %s" % error_string(err)
		_show_join_select()

# ─── NETWORK CALLBACKS ───

func _on_connection_succeeded() -> void:
	status_label.text = "Connected! Receiving data..."

func _on_connection_failed() -> void:
	status_label.text = "Connection failed. Try again."
	_show_join_select()

func _on_all_data_received() -> void:
	# Client received all tables from host — show waiting room
	_show_waiting_room()

@rpc("authority", "reliable")
func _receive_game_start() -> void:
	_go_to_game()

func _go_to_game() -> void:
	if Global.ACTIVE_USER_TYPE == "Player":
		get_tree().change_scene_to_file("res://Scenes/player_hub.tscn")
	elif Global.ACTIVE_USER_TYPE == "Dungeon Master":
		get_tree().change_scene_to_file("res://Scenes/DMHub.tscn")
