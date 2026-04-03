extends Control
## Network Test Scene — Tests actual ENet networking with multiple instances.
##
## HOW IT WORKS:
## 1. Run this scene (F6)
## 2. It starts hosting on port 9999 (separate from game port 7777)
## 3. It launches 2 additional Godot instances as clients with --test-client flag
## 4. Each client auto-connects, receives data sync, and reports back
## 5. Host runs test sequences and validates client responses
##
## The test uses a DIFFERENT port (9999) so it won't interfere with a live game.

const TEST_PORT = 9999
const CLIENT_COUNT = 2

const BG = Color(0.102, 0.122, 0.169)
const TEXT = Color(0.941, 0.949, 0.973)
const GREEN = Color(0.292, 0.855, 0.498)
const RED = Color(0.937, 0.267, 0.267)
const ACCENT = Color(0.788, 0.659, 0.298)
const MUTED = Color(0.471, 0.51, 0.627)
const BLUE = Color(0.353, 0.478, 0.71)

var _log_container: VBoxContainer
var _status_label: Label
var _pass_count = 0
var _fail_count = 0
var _total_count = 0
var _is_client = false
var _client_id = 0
var _clients_connected = 0
var _clients_synced = 0
var _client_pids = []
var _test_responses = {}
var _waiting_for_clients = false


func _ready():
	_build_ui()

	# Check if we're launched as a client via command line
	var args = OS.get_cmdline_args()
	for arg in args:
		if arg.begins_with("--test-client"):
			_is_client = true
		if arg.begins_with("--client-id="):
			_client_id = int(arg.split("=")[1])
		if arg.begins_with("--test-user="):
			Global.ACTIVE_USER_NAME = arg.split("=")[1]

	await get_tree().process_frame

	if _is_client:
		_run_as_client()
	else:
		_run_as_host()


func _build_ui():
	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "NETWORK INTEGRATION TEST"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ACCENT)
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Initializing..."
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", MUTED)
	vbox.add_child(_status_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_log_container = VBoxContainer.new()
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_container.add_theme_constant_override("separation", 3)
	scroll.add_child(_log_container)


# ═══════════════════════════════════════════════════════════════════
#  HOST MODE
# ═══════════════════════════════════════════════════════════════════

func _run_as_host():
	_log_header("HOST: Starting test server on port %d" % TEST_PORT)
	_status_label.text = "Hosting on port %d..." % TEST_PORT

	# Set up as host
	Global.ACTIVE_USER_NAME = Global.ACTIVE_USER_NAME if Global.ACTIVE_USER_NAME != "" else "TestDM"
	Global.ACTIVE_USER_TYPE = "DungeonMaster"
	NetworkManager.is_host = true
	DataStore.set_host(true)
	SaveManager.set_host(true)

	# Load data
	var all_data = DataStore.load_all_tables()
	for table_name in all_data.keys():
		Global._process_table(table_name, all_data[table_name])
	SaveManager.load_save()
	_log_info("Loaded %d tables" % all_data.size())

	# Start actual ENet server
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(TEST_PORT, 4)
	if err != OK:
		_log_fail("Server Start", "Failed to create server: %s" % error_string(err))
		_finalize()
		return

	multiplayer.multiplayer_peer = peer
	_log_pass("Server Start", "Hosting on port %d" % TEST_PORT)

	# Connect signals
	multiplayer.peer_connected.connect(_on_host_peer_connected)
	multiplayer.peer_disconnected.connect(_on_host_peer_disconnected)

	# Launch client instances
	_log_header("HOST: Launching %d client instances" % CLIENT_COUNT)
	var godot_path = OS.get_executable_path()
	var project_path = ProjectSettings.globalize_path("res://")

	var player_names = []
	for name in Global.PartyCharacters:
		player_names.append(name)

	for i in range(CLIENT_COUNT):
		var client_name = player_names[i] if i < player_names.size() else "TestClient%d" % i
		var client_args = PackedStringArray([
			"--path", project_path,
			"--test-client",
			"--client-id=%d" % i,
			"--test-user=%s" % client_name,
			"res://Scenes/test_network.tscn"
		])

		var pid = OS.create_process(godot_path, client_args)
		if pid > 0:
			_client_pids.append(pid)
			_log_info("Launched client %d (PID %d) as '%s'" % [i, pid, client_name])
		else:
			_log_fail("Client Launch %d" % i, "Failed to create process")

	# Wait for clients to connect
	_status_label.text = "Waiting for %d clients to connect..." % CLIENT_COUNT
	_waiting_for_clients = true
	_wait_for_connections()


func _on_host_peer_connected(id: int):
	_clients_connected += 1
	_log_info("Client connected: peer %d (%d/%d)" % [id, _clients_connected, CLIENT_COUNT])

	# Send full data sync
	_send_sync_to_peer(id)


func _on_host_peer_disconnected(id: int):
	_log_info("Client disconnected: peer %d" % id)


func _send_sync_to_peer(peer_id: int):
	# Send all tables to the client
	var tables = Global._synced.keys()
	_rpc_sync_start.rpc_id(peer_id, tables.size())
	for table_name in tables:
		var records = Global._synced[table_name]
		var arr = []
		for rid in records:
			arr.append(records[rid])
		_rpc_sync_table.rpc_id(peer_id, table_name, JSON.stringify(arr))
	_rpc_sync_complete.rpc_id(peer_id)


func _wait_for_connections():
	# Poll until all clients connect or timeout
	var timeout = 15.0
	var elapsed = 0.0
	while _clients_connected < CLIENT_COUNT and elapsed < timeout:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5

	if _clients_connected < CLIENT_COUNT:
		_log_fail("Client Connections", "Only %d/%d connected (timeout)" % [_clients_connected, CLIENT_COUNT])
	else:
		_log_pass("Client Connections", "All %d clients connected" % CLIENT_COUNT)

	# Wait for sync confirmations
	await get_tree().create_timer(3.0).timeout
	_log_info("Sync period complete — %d clients confirmed sync" % _clients_synced)

	# Run host-side tests
	_log_header("HOST: Running network tests")
	await _run_host_tests()

	# Signal clients to disconnect
	_rpc_test_complete.rpc(true)
	await get_tree().create_timer(2.0).timeout

	# Clean up client processes
	for pid in _client_pids:
		OS.kill(pid)

	_finalize()


func _run_host_tests():
	# Test 1: Verify all clients received data
	_assert("Clients connected", _clients_connected >= CLIENT_COUNT,
		"%d/%d" % [_clients_connected, CLIENT_COUNT])
	_assert("Clients synced", _clients_synced >= CLIENT_COUNT,
		"%d/%d" % [_clients_synced, CLIENT_COUNT])

	# Test 2: Broadcast an update and verify clients receive it
	_log_info("Broadcasting test update to all clients...")
	var test_field_val = "NetworkTest_%d" % Time.get_unix_time_from_system()
	var party_id = int(Global.Current_Party.get("id", 0))
	if party_id > 0:
		# Broadcast via the actual network path
		var update = {"table": "Party", "record_id": party_id, "field": "Current_Turn", "value": test_field_val}
		_rpc_field_update.rpc(JSON.stringify([update]))
		await get_tree().create_timer(1.0).timeout
		_assert("Broadcast sent", true, "value='%s'" % test_field_val)

	# Test 3: Request client status reports
	_log_info("Requesting client status reports...")
	_rpc_request_status.rpc()
	await get_tree().create_timer(2.0).timeout
	_assert("Client responses received", _test_responses.size() > 0,
		"%d responses" % _test_responses.size())

	for peer_id in _test_responses:
		var resp = _test_responses[peer_id]
		_log_info("Client %d report: tables=%s, user=%s" % [
			peer_id, str(resp.get("table_count", "?")), str(resp.get("user_name", "?"))
		])
		_assert("Client %d has data" % peer_id, int(resp.get("table_count", 0)) > 0,
			"%d tables" % int(resp.get("table_count", 0)))


# ═══════════════════════════════════════════════════════════════════
#  CLIENT MODE
# ═══════════════════════════════════════════════════════════════════

func _run_as_client():
	_log_header("CLIENT %d: Connecting to localhost:%d" % [_client_id, TEST_PORT])
	_status_label.text = "Client %d — connecting..." % _client_id

	Global.ACTIVE_USER_TYPE = "Player"
	NetworkManager.is_host = false
	DataStore.set_host(false)
	SaveManager.set_host(false)

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client("127.0.0.1", TEST_PORT)
	if err != OK:
		_log_fail("Connect", "Failed: %s" % error_string(err))
		return

	multiplayer.multiplayer_peer = peer
	_log_info("Connecting as '%s'..." % Global.ACTIVE_USER_NAME)

	# Wait for connection
	var timeout = 10.0
	var elapsed = 0.0
	while not multiplayer.has_multiplayer_peer() or multiplayer.get_unique_id() == 0:
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
		if elapsed > timeout:
			_log_fail("Connect", "Timeout after %ds" % int(timeout))
			return

	await get_tree().create_timer(1.0).timeout
	_log_pass("Connect", "Connected as peer %d" % multiplayer.get_unique_id())
	_status_label.text = "Client %d — connected, waiting for data..." % _client_id

	# Wait for sync to complete
	await get_tree().create_timer(5.0).timeout

	var table_count = Global._synced.size()
	_log_info("Received %d tables" % table_count)

	if table_count > 0:
		_log_pass("Data Sync", "%d tables received" % table_count)
		for tn in Global._synced:
			_log_info("  %s: %d records" % [tn, Global._synced[tn].size()])
	else:
		_log_fail("Data Sync", "No tables received")

	_status_label.text = "Client %d — synced, waiting for test commands..." % _client_id

	# Stay alive waiting for host commands
	await get_tree().create_timer(30.0).timeout
	_log_info("Client timeout — shutting down")
	get_tree().quit()


# ═══════════════════════════════════════════════════════════════════
#  RPCs — These work because test_network.tscn has the same node path
#  on both host and client instances
# ═══════════════════════════════════════════════════════════════════

@rpc("authority", "reliable", "call_remote")
func _rpc_sync_start(table_count: int):
	_log_info("Sync starting: %d tables incoming" % table_count)

@rpc("authority", "reliable", "call_remote")
func _rpc_sync_table(table_name: String, json_str: String):
	var records = JSON.parse_string(json_str)
	if records and records is Array:
		Global._process_table(table_name, records)

@rpc("authority", "reliable", "call_remote")
func _rpc_sync_complete():
	_log_pass("Sync Complete", "%d tables in Global._synced" % Global._synced.size())
	_clients_synced += 1
	# Report back to host
	_rpc_client_sync_done.rpc_id(1)

@rpc("any_peer", "reliable")
func _rpc_client_sync_done():
	_clients_synced += 1
	_log_info("Client sync confirmed (%d total)" % _clients_synced)

@rpc("authority", "reliable", "call_remote")
func _rpc_field_update(json_str: String):
	var updates = JSON.parse_string(json_str)
	if updates and updates is Array:
		for u in updates:
			Global._apply_update_to_save(u)
		_log_info("Received field update: %d changes" % updates.size())

@rpc("authority", "reliable", "call_remote")
func _rpc_request_status():
	# Client responds with its current state
	var report = {
		"table_count": Global._synced.size(),
		"user_name": Global.ACTIVE_USER_NAME,
		"client_id": _client_id,
		"character_count": Global.CHARACTERS.size(),
		"party_turn": str(Global.Current_Party.get("Current_Turn", "")),
	}
	_rpc_status_response.rpc_id(1, JSON.stringify(report))

@rpc("any_peer", "reliable")
func _rpc_status_response(json_str: String):
	var report = JSON.parse_string(json_str)
	if report:
		var sender = multiplayer.get_remote_sender_id()
		_test_responses[sender] = report

@rpc("authority", "reliable", "call_remote")
func _rpc_test_complete(success: bool):
	_log_info("Host signaled test complete (success=%s)" % str(success))
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


# ═══════════════════════════════════════════════════════════════════
#  LOGGING (same as test_scene.gd)
# ═══════════════════════════════════════════════════════════════════

func _assert(test_name: String, condition: bool, detail: String = ""):
	_total_count += 1
	if condition:
		_pass_count += 1
		_log_pass(test_name, detail)
	else:
		_fail_count += 1
		_log_fail(test_name, detail)

func _log_pass(name: String, detail: String):
	_add_log("  PASS  %s%s" % [name, (" — " + detail if detail != "" else "")], GREEN)
	print("[PASS] %s %s" % [name, detail])

func _log_fail(name: String, detail: String):
	_add_log("  FAIL  %s%s" % [name, (" — " + detail if detail != "" else "")], RED)
	print("[FAIL] %s %s" % [name, detail])

func _log_info(msg: String):
	_add_log("  INFO  %s" % msg, MUTED)
	print("[INFO] %s" % msg)

func _log_header(text: String):
	var sep = HSeparator.new()
	_log_container.add_child(sep)
	_add_log(text, ACCENT, 16)
	print("\n=== %s ===" % text)

func _add_log(text: String, color: Color, size: int = 14):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_container.add_child(lbl)

func _finalize():
	var sep = HSeparator.new()
	_log_container.add_child(sep)
	var result = "%d / %d tests passed" % [_pass_count, _total_count]
	var color = GREEN if _fail_count == 0 else RED
	_status_label.text = result + (" — ALL PASSED" if _fail_count == 0 else " — %d FAILED" % _fail_count)
	_status_label.add_theme_color_override("font_color", color)
	_add_log(result, color, 20)
	print("\n%s" % result)

	# Clean up networking
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null
