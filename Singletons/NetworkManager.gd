extends Node
## ENet multiplayer manager. DM hosts, players connect.
## Handles: hosting, joining, LAN discovery, UPNP, RPC sync, pause-on-disconnect.

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded
signal connection_failed
signal all_data_received  # fired on client after initial sync completes
signal host_ready         # fired on host after data loaded from disk
signal combat_log_received(payload: Dictionary)  # fired on host when a combat log arrives
signal battle_summary_received(summary: Dictionary)  # fired on clients when host sends summary
signal notes_file_ack_received(success: bool)

const DEFAULT_PORT = 7777
const DISCOVERY_PORT = 7778
const MAX_CLIENTS = 8
const BEACON_INTERVAL = 0.5

var is_host = false
var is_connected_to_host = false
var peer: ENetMultiplayerPeer = null

# Host tracks connected players: peer_id -> { "name": String, "character_id": String }
var connected_players = {}

# LAN discovery
var _beacon_timer: Timer = null
var _discovery_socket: PacketPeerUDP = null
var _beacon_socket: PacketPeerUDP = null
var discovered_hosts = []  # Array of { "ip": String, "port": int, "name": String, "players": int }

# UPNP
var upnp: UPNP = null
var public_ip = ""
var _upnp_mapped = false

# Pause on disconnect
var _paused_for_disconnect = false
var _missing_peers = []

# Initial sync tracking (client side)
var _sync_tables_received = {}
var _sync_total_expected = 0
var _initial_sync_complete = false

var _last_host_ip: String = ""
var _last_host_port: int = DEFAULT_PORT

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# ─── HOSTING ───

func host_game(port: int = DEFAULT_PORT) -> Error:
	is_host = true
	DataStore.set_host(true)

	# UPNP port forwarding
	_setup_upnp(port)

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		push_error("NetworkManager: Failed to create server on port %d: %s" % [port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	print("NetworkManager: Hosting on port %d" % port)

	# Start LAN beacon
	_start_beacon(port)

	# Load data from disk (legacy tables + new save system)
	var all_data = DataStore.load_all_tables()
	for table_name in all_data.keys():
		Global._process_table(table_name, all_data[table_name])

	# Load or migrate the save file
	SaveManager.set_host(true)
	SaveManager.load_save()

	if Global.ACTIVE_USER_TYPE == "Player":
		Global.calculate_all_stats()

	Global.Current_Region = Global.Current_Party.get("Current_Region", "Mondstadt")
	emit_signal("host_ready")
	Global.emit_signal("data_load_complete")
	return OK

func _setup_upnp(port: int) -> void:
	upnp = UPNP.new()
	var discover_result = upnp.discover(2000, 2, "InternetGatewayDevice")
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		push_warning("NetworkManager: UPNP discovery failed (%s) — LAN-only mode" % str(discover_result))
		return

	# Try to get external IP even if mapping fails
	var ext = upnp.query_external_address()
	if ext != null and str(ext) != "":
		public_ip = str(ext)
		Global.PublicIP = public_ip

	if upnp.get_device_count() == 0:
		push_warning("NetworkManager: No UPNP devices found — LAN-only mode")
		return

	var dev = upnp.get_device(0)
	if dev == null:
		push_warning("NetworkManager: UPNP device is null — LAN-only mode")
		return

	var map_result = dev.add_port_mapping(port, port, "GenshinDnD", "UDP")
	if map_result == UPNP.UPNP_RESULT_SUCCESS:
		_upnp_mapped = true
		print("NetworkManager: UPNP port %d mapped successfully" % port)
	else:
		push_warning("NetworkManager: UPNP port mapping failed (%s) — LAN still works" % str(map_result))

# ─── JOINING ───

func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	is_host = false
	DataStore.set_host(false)
	SaveManager.set_host(false)
	_last_host_ip = ip
	_last_host_port = port

	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("NetworkManager: Failed to connect to %s:%d: %s" % [ip, port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	print("NetworkManager: Connecting to %s:%d" % [ip, port])
	return OK

# ─── DISCONNECT ───

func disconnect_from_game() -> void:
	_stop_beacon()
	_stop_discovery()

	if _upnp_mapped and upnp and upnp.get_device_count() > 0:
		var dev = upnp.get_device(0)
		if dev:
			dev.delete_port_mapping(DEFAULT_PORT, "UDP")
		_upnp_mapped = false

	if peer:
		peer.close()
		peer = null

	multiplayer.multiplayer_peer = null
	is_host = false
	is_connected_to_host = false
	connected_players.clear()
	discovered_hosts.clear()

# ─── LAN DISCOVERY ───

func start_discovery() -> void:
	_stop_discovery()
	discovered_hosts.clear()

	_discovery_socket = PacketPeerUDP.new()
	_discovery_socket.set_broadcast_enabled(true)
	var err = _discovery_socket.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("NetworkManager: Could not bind discovery socket: %s" % error_string(err))
		return

	print("NetworkManager: Listening for LAN beacons on port %d" % DISCOVERY_PORT)

func poll_discovery() -> void:
	if _discovery_socket == null:
		return

	while _discovery_socket.get_available_packet_count() > 0:
		var data = _discovery_socket.get_packet().get_string_from_utf8()
		var ip = _discovery_socket.get_packet_ip()
		var parsed = JSON.parse_string(data)
		if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
			continue
		if not parsed.has("game") or parsed["game"] != "GenshinDnD":
			continue

		var entry = {
			"ip": ip,
			"port": int(parsed.get("port", DEFAULT_PORT)),
			"name": str(parsed.get("host_name", "Unknown")),
			"players": int(parsed.get("player_count", 0)),
			"_last_seen": Time.get_ticks_msec()
		}

		# Update or add
		var found = false
		for i in discovered_hosts.size():
			if discovered_hosts[i]["ip"] == ip:
				discovered_hosts[i] = entry
				found = true
				break
		if not found:
			discovered_hosts.append(entry)

	# Expire hosts that haven't sent a beacon in 3 seconds
	var now = Time.get_ticks_msec()
	for i in range(discovered_hosts.size() - 1, -1, -1):
		if now - discovered_hosts[i].get("_last_seen", 0) > 3000:
			discovered_hosts.remove_at(i)

func _stop_discovery() -> void:
	if _discovery_socket:
		_discovery_socket.close()
		_discovery_socket = null

func _start_beacon(port: int) -> void:
	_beacon_socket = PacketPeerUDP.new()
	_beacon_socket.set_broadcast_enabled(true)
	_beacon_socket.set_dest_address("255.255.255.255", DISCOVERY_PORT)

	_beacon_timer = Timer.new()
	add_child(_beacon_timer)
	_beacon_timer.wait_time = BEACON_INTERVAL
	_beacon_timer.timeout.connect(_send_beacon.bind(port))
	_beacon_timer.start()
	_send_beacon(port)

func _send_beacon(port: int) -> void:
	if _beacon_socket == null:
		return
	var payload = JSON.stringify({
		"game": "GenshinDnD",
		"port": port,
		"host_name": Global.ACTIVE_USER_NAME,
		"player_count": connected_players.size()
	})
	_beacon_socket.put_packet(payload.to_utf8_buffer())

func _stop_beacon() -> void:
	if _beacon_timer:
		_beacon_timer.stop()
		_beacon_timer.queue_free()
		_beacon_timer = null
	if _beacon_socket:
		_beacon_socket.close()
		_beacon_socket = null

# ─── CONNECTION CALLBACKS ───

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected: %d" % id)
	if is_host:
		# Send full data sync to the new peer, table by table
		_send_full_sync_to_peer(id)
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected: %d" % id)
	if is_host:
		var player_name = connected_players.get(id, {}).get("name", "Peer %d" % id)
		connected_players.erase(id)
		_missing_peers.append(id)
		print("NetworkManager: Peer %d disconnected (%d remaining)" % [id, connected_players.size()])
		Toast.notify("%s disconnected" % player_name, Toast.WARNING)
	emit_signal("player_disconnected", id)

func _on_connected_to_server() -> void:
	print("NetworkManager: Connected to host!")
	is_connected_to_host = true
	# Submit offline changes before registration if they exist
	if OfflineChanges.has_changes():
		print("NetworkManager: Submitting offline changes to host")
		_submit_offline_changes.rpc_id(1, Global.ACTIVE_USER_NAME, OfflineChanges.get_changes_json())
	_register_with_host.rpc_id(1, Global.ACTIVE_USER_NAME, str(Global.ACTIVE_USER_RECORD_ID))
	Toast.notify("Connected to host", Toast.SUCCESS)
	emit_signal("connection_succeeded")

func _on_connection_failed() -> void:
	print("NetworkManager: Connection failed!")
	is_connected_to_host = false
	Toast.notify("Connection failed", Toast.ERROR)
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	print("NetworkManager: Lost connection to host — attempting reconnect to %s:%d" % [_last_host_ip, _last_host_port])
	is_connected_to_host = false
	Toast.notify("Lost connection to host — reconnecting...", Toast.WARNING, 5.0)
	if _last_host_ip != "":
		_attempt_reconnect()

func _attempt_reconnect() -> void:
	for attempt in range(5):
		print("NetworkManager: Reconnect attempt %d/5" % (attempt + 1))
		peer = ENetMultiplayerPeer.new()
		var err = peer.create_client(_last_host_ip, _last_host_port)
		if err != OK:
			await get_tree().create_timer(1.0).timeout
			continue
		multiplayer.multiplayer_peer = peer
		# Wait up to 3 seconds for connection
		await get_tree().create_timer(3.0).timeout
		if is_connected_to_host:
			print("NetworkManager: Reconnected successfully!")
			Toast.notify("Reconnected to host", Toast.SUCCESS)
			return
	Toast.notify("Failed to reconnect — returning to lobby", Toast.ERROR, 5.0)
	push_warning("NetworkManager: Failed to reconnect after 5 attempts — returning to lobby")
	_return_to_lobby()

func _return_to_lobby() -> void:
	is_connected_to_host = false
	if peer:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Lobby.tscn")

# ─── PLAYER REGISTRATION ───

@rpc("any_peer", "reliable")
func _register_with_host(player_name: String, character_id: String) -> void:
	if not is_host:
		return
	var sender = multiplayer.get_remote_sender_id()
	connected_players[sender] = { "name": player_name, "character_id": character_id }
	print("NetworkManager: Player '%s' registered (peer %d)" % [player_name, sender])
	Toast.notify("%s joined" % player_name, Toast.SUCCESS)

	# Check if this was a reconnecting player
	if _missing_peers.has(sender):
		_missing_peers.erase(sender)
	# Also check by name for reconnects on a different peer id
	for missing_id in _missing_peers.duplicate():
		# If the old peer had the same name, consider them reconnected
		if connected_players.has(missing_id) and connected_players[missing_id]["name"] == player_name:
			_missing_peers.erase(missing_id)
			connected_players.erase(missing_id)

	if _paused_for_disconnect and _missing_peers.is_empty():
		_paused_for_disconnect = false
		get_tree().paused = false
		print("NetworkManager: All players reconnected — game resumed")

	# Send full sync to the reconnecting player
	print("NetworkManager: Sending full sync to reconnected peer %d" % sender)
	_send_full_sync_to_peer(sender)

# ─── FULL SYNC (Host -> Client, chunked per table) ───

func _send_full_sync_to_peer(peer_id: int) -> void:
	# Tell client how many tables to expect
	_receive_sync_start.rpc_id(peer_id, Global.TABLES.size())

	for table_name in Global.TABLES:
		var records = DataStore.get_table_as_array(table_name)
		var json_str = JSON.stringify(records)
		_receive_table_sync.rpc_id(peer_id, table_name, json_str)

@rpc("authority", "reliable")
func _receive_sync_start(table_count: int) -> void:
	_sync_total_expected = table_count
	_sync_tables_received.clear()
	print("NetworkManager: Expecting %d tables from host" % table_count)

@rpc("authority", "reliable")
func _receive_table_sync(table_name: String, json_str: String) -> void:
	var records = JSON.parse_string(json_str)
	if records == null:
		push_error("NetworkManager: Failed to parse sync data for '%s'" % table_name)
		records = []

	Global._process_table(table_name, records)
	_sync_tables_received[table_name] = true
	Global.emit_signal("table_loaded", table_name, records.size())
	print("NetworkManager: Synced table '%s' (%d records) [%d/%d]" % [table_name, records.size(), _sync_tables_received.size(), _sync_total_expected])

	var _initial_sync_done = _sync_tables_received.size() >= _sync_total_expected
	if not _initial_sync_done:
		# Still waiting for more tables during initial sync
		return

	if not _initial_sync_complete:
		# First time all tables arrived — initial sync finished
		_initial_sync_complete = true
		print("NetworkManager: All tables synced!")
		if Global.ACTIVE_USER_TYPE == "Player":
			Global.calculate_all_stats()
		Global.Current_Region = Global.Current_Party.get("Current_Region", "Mondstadt")
		emit_signal("all_data_received")
		Global.save_synced_snapshot()
		if Global.is_offline:
			Global.is_offline = false
			print("NetworkManager: Exited offline mode after successful sync")

	# Post-sync broadcasts only (not during initial sync) — recalculate if relevant
	if _initial_sync_complete:
		var stat_tables = ["Characters", "Character_Weapons", "Character_Artifacts", "Companions"]
		if table_name in stat_tables:
			CharacterManager.recalculate_all()
		Global.emit_signal("data_load_complete")

# ─── DELTA SYNC (Host -> All Clients) ───

## Called by host after a mutation. Broadcasts only the changed table.
func broadcast_table_update(table_name: String) -> void:
	if not is_host:
		return
	var records = DataStore.get_table_as_array(table_name)
	var json_str = JSON.stringify(records)
	_receive_table_sync.rpc(table_name, json_str)

## Broadcast a single record update (more efficient for field changes).
func broadcast_record_update(table_name: String, record_id: String, data: Dictionary) -> void:
	if not is_host:
		return
	var json_str = JSON.stringify(data)
	_receive_record_update.rpc(table_name, record_id, json_str)

@rpc("authority", "reliable")
func _receive_record_update(table_name: String, record_id: String, json_str: String) -> void:
	var data = JSON.parse_string(json_str)
	if data == null:
		return
	Global._apply_record_update(table_name, record_id, data)

## Broadcast individual field changes (most efficient for Update_Records calls).
func broadcast_field_updates(updates: Array) -> void:
	if not is_host:
		return
	var json_str = JSON.stringify(updates)
	print("NetworkManager: broadcasting %d field updates (%d bytes)" % [updates.size(), json_str.length()])
	_receive_field_updates.rpc(json_str)

@rpc("authority", "reliable")
func _receive_field_updates(json_str: String) -> void:
	print("NetworkManager: received field updates (%d bytes)" % json_str.length())
	var updates = JSON.parse_string(json_str)
	if updates == null or typeof(updates) != TYPE_ARRAY:
		push_error("NetworkManager: failed to parse field updates")
		return
	for u in updates:
		Global._apply_update_to_save(u)
	CharacterManager.recalculate_all()
	Global.emit_signal("data_load_complete")

# ─── CLIENT -> HOST REQUESTS ───

## Client submits offline changes to host on reconnect. Host applies them before full sync.
@rpc("any_peer", "reliable")
func _submit_offline_changes(player_name: String, changes_json: String) -> void:
	if not is_host:
		return
	var sender = multiplayer.get_remote_sender_id()
	var changes = JSON.parse_string(changes_json)
	if changes == null or not changes is Array:
		push_warning("NetworkManager: Invalid offline changes from peer %d" % sender)
		_ack_offline_changes.rpc_id(sender, true)
		return

	print("NetworkManager: Applying %d offline changes from %s (peer %d)" % [changes.size(), player_name, sender])

	# Track offline→host ID remapping so deletes/updates on locally-inserted
	# records target the correct host-assigned ID
	var id_remap: Dictionary = {}  # "table:offline_id" → host_id

	for change in changes:
		var action = str(change.get("action", ""))
		var table = str(change.get("table", ""))
		match action:
			"update":
				var record_id = str(int(change.get("record_id", 0)))
				var remap_key = "%s:%s" % [table, record_id]
				if id_remap.has(remap_key):
					record_id = str(id_remap[remap_key])
				var field = str(change.get("field", ""))
				var value = change.get("value")
				# Mora conflict resolution: highest value wins
				if table == "Party" and field == "Mora":
					var current_mora = 0
					if Global._synced.has("Party") and Global._synced["Party"].has(record_id):
						current_mora = int(Global._synced["Party"][record_id].get("Mora", 0))
					if int(value) <= current_mora:
						continue  # Keep the higher value
				Global._apply_local_update(table, record_id, field, value)
				DataStore.persist_table(table)
			"insert":
				var data = change.get("data", {})
				var offline_id = int(data.get("id", 0))
				var new_id = _next_id_for_table(table)
				var remap_key = "%s:%d" % [table, offline_id]
				id_remap[remap_key] = new_id
				data["id"] = new_id
				Global._insert_record(table, str(new_id), data)
				DataStore.persist_table(table)
			"delete":
				var record_id = str(int(change.get("record_id", 0)))
				var remap_key = "%s:%s" % [table, record_id]
				if id_remap.has(remap_key):
					record_id = str(id_remap[remap_key])
				Global._remove_record(table, record_id)
				DataStore.persist_table(table)

	Toast.notify("Applied offline changes from %s" % player_name, Toast.SUCCESS)
	_ack_offline_changes.rpc_id(sender, true)

@rpc("authority", "reliable")
func _ack_offline_changes(success: bool) -> void:
	if success:
		print("NetworkManager: Host acknowledged offline changes — clearing local log")
		OfflineChanges.clear()
		Toast.notify("Offline changes merged successfully", Toast.SUCCESS)
	else:
		Toast.notify("Failed to merge offline changes", Toast.ERROR)

## Client requests a field update. Host validates, applies, saves, broadcasts.
@rpc("any_peer", "reliable")
func request_update(updates_json: String) -> void:
	if not is_host:
		return
	print("NetworkManager: host received request_update from peer %d" % multiplayer.get_remote_sender_id())
	var updates = JSON.parse_string(updates_json)
	if updates == null or typeof(updates) != TYPE_ARRAY:
		push_error("NetworkManager: failed to parse request_update")
		return

	var changed_tables = {}
	for u in updates:
		var table: String = str(u.get("table", ""))
		var record_id: String = str(int(u.get("record_id", 0)))
		var field: String = str(u.get("field", ""))
		var value = u.get("value")

		Global._apply_local_update(table, record_id, field, value)
		changed_tables[table] = true

	for table_name in changed_tables.keys():
		DataStore.persist_table(table_name)
	broadcast_field_updates(updates)

	# Host doesn't receive its own RPC — emit locally so host UI refreshes
	var stat_tables2 = ["Characters", "Character_Weapons", "Character_Artifacts", "Companions"]
	for t in changed_tables.keys():
		if t in stat_tables2:
			CharacterManager.recalculate_all()
			break
	Global.emit_signal("data_load_complete")

## Client requests a record insertion.
@rpc("any_peer", "reliable")
func request_insert(table: String, record_json: String, correlation_id: String) -> void:
	if not is_host:
		return
	var record = JSON.parse_string(record_json)
	if record == null:
		return

	# Generate a new ID
	var new_id = _next_id_for_table(table)
	record["id"] = new_id

	# Insert into Global dict
	Global._insert_record(table, str(new_id), record)

	# Save and broadcast
	DataStore.persist_table(table)
	broadcast_table_update(table)

	# Notify the requesting peer
	var sender = multiplayer.get_remote_sender_id()
	_receive_insert_result.rpc_id(sender, correlation_id, table, new_id, record_json, true)

@rpc("authority", "reliable")
func _receive_insert_result(correlation_id: String, table: String, record_id: int, payload_json: String, ok: bool) -> void:
	var payload = JSON.parse_string(payload_json)
	if payload == null:
		payload = {}
	Global.emit_signal("insert_finished", correlation_id, table, record_id, payload, ok)

## Client requests a record removal.
@rpc("any_peer", "reliable")
func request_remove(table: String, record_id: int) -> void:
	if not is_host:
		return

	Global._remove_record(table, str(record_id))
	DataStore.persist_table(table)
	broadcast_table_update(table)

func _next_id_for_table(table_name: String) -> int:
	var dict: Dictionary = DataStore._get_global_dict(table_name)
	var max_id = 0
	for key in dict.keys():
		var id_val = int(key)
		if id_val > max_id:
			max_id = id_val
	return max_id + 1

# ─── HOST-SIDE DIRECT OPERATIONS (called by Global) ───

## Host applies updates locally, saves, and broadcasts.
func host_update_records(updates: Array) -> void:
	var changed_tables = {}
	for u in updates:
		var table: String = str(u.get("table", ""))
		var record_id: String = str(int(u.get("record_id", 0)))
		var field: String = str(u.get("field", ""))
		var value = u.get("value")

		Global._apply_local_update(table, record_id, field, value)
		changed_tables[table] = true

	for table_name in changed_tables.keys():
		DataStore.persist_table(table_name)
	broadcast_field_updates(updates)

	# Host doesn't receive its own RPC — emit locally so host UI refreshes
	var stat_tables = ["Characters", "Character_Weapons", "Character_Artifacts", "Companions"]
	for t in changed_tables.keys():
		if t in stat_tables:
			CharacterManager.recalculate_all()
			break
	Global.emit_signal("data_load_complete")

## Host inserts a record locally, saves, and broadcasts.
func host_insert(table: String, columns: Array, values: Array) -> int:
	var new_id = _next_id_for_table(table)
	var record = { "id": new_id }
	for i in columns.size():
		record[columns[i]] = values[i]

	Global._insert_record(table, str(new_id), record)
	DataStore.persist_table(table)
	broadcast_table_update(table)
	Global.emit_signal("data_load_complete")
	return new_id

## Host removes a record locally, saves, and broadcasts.
func host_remove(table: String, record_id: int) -> void:
	Global._remove_record(table, str(record_id))
	DataStore.persist_table(table)
	broadcast_table_update(table)
	Global.emit_signal("data_load_complete")

# ─── LOG OPERATIONS (host-only, saved to JSON) ───

func host_log(payload: Dictionary) -> void:
	if not is_host:
		# Client sends log to host
		_request_log.rpc_id(1, JSON.stringify(payload))
		return

	# Load existing log, append, save
	var log_records = DataStore.load_table("log")
	var new_id = log_records.size() + 1
	payload["id"] = new_id
	payload["created_at"] = Time.get_datetime_string_from_system()
	log_records.append(payload)
	DataStore.save_table("log", log_records)

func host_combat_log(payload: Dictionary) -> void:
	if not is_host:
		_request_combat_log.rpc_id(1, JSON.stringify(payload))
		return

	var log_records = DataStore.load_table("battle_log")
	var new_id = log_records.size() + 1
	payload["id"] = new_id
	payload["created_at"] = Time.get_datetime_string_from_system()
	log_records.append(payload)
	DataStore.save_table("battle_log", log_records)
	combat_log_received.emit(payload)


func broadcast_battle_summary(summary: Dictionary) -> void:
	if not is_host:
		return
	var json = JSON.stringify(summary)
	_receive_battle_summary.rpc(json)

@rpc("authority", "reliable", "call_remote")
func _receive_battle_summary(summary_json: String) -> void:
	var summary = JSON.parse_string(summary_json)
	if summary and summary is Dictionary:
		battle_summary_received.emit(summary)

@rpc("any_peer", "reliable")
func _request_log(payload_json: String) -> void:
	if not is_host:
		return
	var payload = JSON.parse_string(payload_json)
	if payload:
		host_log(payload)

@rpc("any_peer", "reliable")
func _request_combat_log(payload_json: String) -> void:
	if not is_host:
		return
	var payload = JSON.parse_string(payload_json)
	if payload:
		host_combat_log(payload)

# ─── NOTES FILE BACKUP (Brian F. → Host) ───

@rpc("any_peer", "reliable")
func send_notes_file(filename: String, file_bytes: PackedByteArray) -> void:
	if not is_host:
		return
	var sender = multiplayer.get_remote_sender_id()
	var player_name = connected_players.get(sender, {}).get("name", "unknown")
	print("NetworkManager: Received notes file '%s' from %s (%d bytes)" % [filename, player_name, file_bytes.size()])

	# Save the file
	var save_path = "user://%s" % filename
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("NetworkManager: Failed to save notes file: %s" % error_string(FileAccess.get_open_error()))
		_notes_file_ack.rpc_id(sender, false)
		return
	file.store_buffer(file_bytes)
	file.close()
	print("NetworkManager: Notes file saved to %s" % save_path)
	Toast.notify("Saved %s's notes file" % player_name, Toast.SUCCESS)
	_notes_file_ack.rpc_id(sender, true)

@rpc("authority", "reliable")
func _notes_file_ack(success: bool) -> void:
	# Received by the client — Global handles the response
	notes_file_ack_received.emit(success)
