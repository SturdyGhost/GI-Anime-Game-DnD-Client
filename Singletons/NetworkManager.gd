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
signal map_markers_updated(all_markers: Dictionary)
signal map_ping_received(ping_json: String)

const DEFAULT_PORT = 7777
const DISCOVERY_PORT = 7778
const MAX_CLIENTS = 8
const BEACON_INTERVAL = 0.5

# ─── ENet connection hardening ──────────────────────────────────────────────
# 3 channels: 0=state sync (Updates/Tables/Inserts), 1=logs/UI (combat log,
# damage breakdown, heartbeat), 2=one-shot end-of-battle summary. Separating
# logs from state sync prevents a chatty log RPC from head-of-line-blocking a
# critical state update during packet loss.
const ENET_CHANNELS = 3
# Lenient peer timeouts so brief drops don't disconnect everyone.
# Defaults: limit=32, min=5000ms, max=30000ms (very aggressive for flaky home wifi).
const ENET_TIMEOUT_LIMIT = 64
const ENET_TIMEOUT_MIN_MS = 10000
const ENET_TIMEOUT_MAX_MS = 60000
# LAN bandwidth caps. Setting explicit non-zero values signals ENet to use
# throughput-friendly pacing instead of its conservative defaults. 100 MB/s
# is well within any LAN. 0 would be "unlimited" but in practice non-zero
# values give better congestion behavior.
const ENET_IN_BANDWIDTH = 104857600   # 100 MB/s
const ENET_OUT_BANDWIDTH = 104857600  # 100 MB/s

# ─── Heartbeat (app-level liveness) ─────────────────────────────────────────
# Host pings every HEARTBEAT_INTERVAL. Clients ack. If no ack for STALE_MS,
# log a warning so we know which peer is silently stalling — ENet's own
# timeout (up to 60s) still owns actual disconnect.
const HEARTBEAT_INTERVAL_SEC: float = 3.0
const HEARTBEAT_STALE_MS: int = 9000
var _heartbeat_timer: Timer = null
var _last_pong_ms: Dictionary = {}  # peer_id -> Time.get_ticks_msec() of last pong

# ─── Reconnect (LAN-aggressive) ─────────────────────────────────────────────
const RECONNECT_FAST_INTERVAL_SEC: float = 1.0
const RECONNECT_FAST_ATTEMPTS: int = 30      # ~30s of rapid retries
const RECONNECT_SLOW_INTERVAL_SEC: float = 5.0
const RECONNECT_TOTAL_DURATION_SEC: float = 300.0  # cap at 5 min
const RECONNECT_HANDSHAKE_WAIT_SEC: float = 3.0
var _reconnecting: bool = false

# ─── Backup distribution (Phase 4) ─────────────────────────────────────────
# Host broadcasts the full canonical save to every connected client every N
# seconds on channel 1 (bulk channel). Clients persist it to disk passively as
# canonical_save_backup.json — only used if they later enter offline mode.
const BACKUP_BROADCAST_INTERVAL_SEC: float = 300.0
const CLIENT_BACKUP_PATH: String = "user://canonical_save_backup.json"
const CLIENT_BACKUP_TMP: String = "user://canonical_save_backup.json.tmp"
var _backup_timer: Timer = null
# Client-side: fingerprint of the most recent canonical save we received from
# the host. Compared against incoming hash pings to decide whether to request
# a full payload. Empty string = no backup received yet (always treat as stale).
var _last_received_backup_hash: String = ""

var is_host = false
var is_connected_to_host = false
var peer: ENetMultiplayerPeer = null

# Host tracks connected players: peer_id -> { "name": String, "character_id": String }
var connected_players = {}

# LAN discovery
var _beacon_timer: Timer = null
var _discovery_socket: PacketPeerUDP = null
var _beacon_sockets: Array = []  # Array of PacketPeerUDP, one per broadcast address
var discovered_hosts = []  # Array of { "ip": String, "port": int, "name": String, "players": int }
var local_ip: String = ""  # LAN IP for display in waiting room

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
	var err = peer.create_server(port, MAX_CLIENTS, ENET_CHANNELS, ENET_IN_BANDWIDTH, ENET_OUT_BANDWIDTH)
	if err != OK:
		push_error("NetworkManager: Failed to create server on port %d: %s" % [port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	print("NetworkManager: Hosting on port %d (channels=%d, bw=%d/%d)" % [port, ENET_CHANNELS, ENET_IN_BANDWIDTH, ENET_OUT_BANDWIDTH])
	_start_heartbeat()

	# Start LAN beacon
	_start_beacon(port)

	# Load the canonical save (one consolidated JSON file). Three paths:
	#   1) canonical_save.json exists -> load it directly.
	#   2) Legacy user://data/*.json files existed -> migration above already
	#      consolidated them and wrote canonical_save.json -> path (1) applies.
	#   3) Fresh install, no legacy data -> fall through to bundled defaults
	#      in res://data/, populate CanonicalSave.tables, then flush to disk
	#      so subsequent launches use path (1) instead of re-bootstrapping.
	if FileAccess.file_exists(CanonicalSave.SAVE_PATH):
		CanonicalSave.load_from_disk()
	else:
		var all_data = DataStore.load_all_tables()
		for table_name in all_data.keys():
			Global._process_table(table_name, all_data[table_name])
		# Persist the bundled-default state immediately so a host restart
		# before any mutation doesn't re-run the bootstrap.
		CanonicalSave.save_to_disk()

	# Rebuild the _synced_name lookup index from whatever CanonicalSave loaded.
	Global._rebuild_synced_name_index()

	# Load the audit/change log so per-field LWW reconciliation has the host's
	# history available for incoming offline-change merges.
	ChangeLog.load_from_disk()

	# Load or migrate the save file (typed-resource view; reads through
	# CanonicalSave for state now, base resources are still loaded from res://).
	SaveManager.set_host(true)
	SaveManager.load_save()

	if Global.ACTIVE_USER_TYPE == "Player":
		Global.calculate_all_stats()

	Global.Current_Region = Global.Current_Party.get("Current_Region", "Mondstadt")

	# Flush the offline snapshot directly (bypass the debounce timer) so that
	# if the host's own session glitches and re-reads from disk, the snapshot
	# already reflects what was loaded. The debounce is for the steady-state
	# sync stream — host startup is a single deterministic event.
	Global.save_synced_snapshot()

	# Start periodic backup distribution (broadcast full canonical save to all
	# clients every minute so they have an up-to-date snapshot for offline use).
	_start_backup_broadcast()

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
	var err = peer.create_client(ip, port, ENET_CHANNELS, ENET_IN_BANDWIDTH, ENET_OUT_BANDWIDTH)
	if err != OK:
		push_error("NetworkManager: Failed to connect to %s:%d: %s" % [ip, port, error_string(err)])
		return err

	multiplayer.multiplayer_peer = peer
	print("NetworkManager: Connecting to %s:%d (channels=%d, bw=%d/%d)" % [ip, port, ENET_CHANNELS, ENET_IN_BANDWIDTH, ENET_OUT_BANDWIDTH])
	return OK

# ─── DISCONNECT ───

func disconnect_from_game() -> void:
	_stop_beacon()
	_stop_discovery()
	_stop_heartbeat()
	_stop_backup_broadcast()
	_reconnecting = false  # Cancel any in-flight reconnect loop

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
	_last_pong_ms.clear()

# ─── HEARTBEAT (app-level liveness) ──────────────────────────────────────
# Host pings every HEARTBEAT_INTERVAL_SEC; clients pong back. The reliable
# RPC traffic itself keeps NAT/router state warm AND lets us proactively
# detect a peer that's silently stalling (no pong for HEARTBEAT_STALE_MS)
# well before ENet's longer timeout would notice.

func _start_heartbeat() -> void:
	if _heartbeat_timer != null:
		return  # Already running
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.wait_time = HEARTBEAT_INTERVAL_SEC
	_heartbeat_timer.timeout.connect(_on_heartbeat_tick)
	add_child(_heartbeat_timer)
	_heartbeat_timer.start()

func _stop_heartbeat() -> void:
	if _heartbeat_timer != null:
		_heartbeat_timer.stop()
		_heartbeat_timer.queue_free()
		_heartbeat_timer = null

func _on_heartbeat_tick() -> void:
	if not is_host:
		return
	if connected_players.is_empty():
		return
	var now_ms: int = Time.get_ticks_msec()
	# Broadcast ping (clients all respond).
	_heartbeat_ping.rpc(now_ms)
	# Check pong freshness; log (don't disconnect — ENet's longer timeout owns
	# real disconnection so a brief network blip doesn't kick someone).
	for peer_id in connected_players.keys():
		var last: int = int(_last_pong_ms.get(peer_id, now_ms))
		var age_ms: int = now_ms - last
		if age_ms > HEARTBEAT_STALE_MS:
			var pname: String = connected_players.get(peer_id, {}).get("name", "peer %d" % peer_id)
			print("NetworkManager: heartbeat stale for %s (no pong in %dms)" % [pname, age_ms])

@rpc("authority", "reliable", "call_remote", 1)
func _heartbeat_ping(host_ms: int) -> void:
	if is_host:
		return
	# Client echoes the host's timestamp back so host can measure roundtrip
	# AND confirm peer liveness (the reliable ACK alone proves we're alive).
	_heartbeat_pong.rpc_id(1, host_ms)

@rpc("any_peer", "reliable", "call_remote", 1)
func _heartbeat_pong(_host_ms: int) -> void:
	if not is_host:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_last_pong_ms[sender] = Time.get_ticks_msec()

# ─── Periodic backup distribution (Phase 4) ──────────────────────────────
# Host broadcasts the entire canonical save to all clients every
# BACKUP_BROADCAST_INTERVAL_SEC. Clients receive and write to disk passively;
# they never read from this file during normal online play — it's only loaded
# if they later go into offline mode.

func _start_backup_broadcast() -> void:
	if _backup_timer != null:
		return
	_backup_timer = Timer.new()
	_backup_timer.wait_time = BACKUP_BROADCAST_INTERVAL_SEC
	_backup_timer.timeout.connect(_on_backup_broadcast_tick)
	add_child(_backup_timer)
	_backup_timer.start()

func _stop_backup_broadcast() -> void:
	if _backup_timer != null:
		_backup_timer.stop()
		_backup_timer.queue_free()
		_backup_timer = null

func _on_backup_broadcast_tick() -> void:
	if not is_host:
		return
	if connected_players.is_empty():
		return  # No one to send to
	# Ping the canonical content hash to every client. Clients whose stored
	# backup hash matches will silently skip; clients that are out of date
	# will call back via _request_canonical_backup and receive the full
	# payload individually. Avoids broadcasting megabytes of JSON when the
	# delta-update path has already kept everyone in sync.
	_ping_canonical_hash.rpc(CanonicalSave.get_content_hash())

## Serialize CanonicalSave and broadcast to every connected client on channel 1.
## Kept for explicit "force-sync everyone now" use cases; the periodic tick
## uses the hash-ping path instead.
func _broadcast_canonical_save_to_all() -> void:
	if not is_host:
		return
	var payload: Dictionary = CanonicalSave.snapshot()
	var json_str: String = JSON.stringify(payload)
	var content_hash: String = CanonicalSave.get_content_hash()
	_receive_canonical_backup.rpc(json_str, content_hash)

## Send the canonical save to a specific peer (used right after they connect
## so they have a backup immediately without waiting for the next tick).
func _send_canonical_backup_to_peer(peer_id: int) -> void:
	if not is_host:
		return
	var payload: Dictionary = CanonicalSave.snapshot()
	var json_str: String = JSON.stringify(payload)
	var content_hash: String = CanonicalSave.get_content_hash()
	_receive_canonical_backup.rpc_id(peer_id, json_str, content_hash)

@rpc("authority", "reliable", "call_remote", 1)
func _receive_canonical_backup(json_str: String, content_hash: String = "") -> void:
	# Atomic write: tmp + rename so a crash mid-write doesn't corrupt the
	# backup. We never read this during normal play — only on offline-mode
	# entry — so it can be overwritten freely each tick.
	var tmp = FileAccess.open(CLIENT_BACKUP_TMP, FileAccess.WRITE)
	if tmp == null:
		push_error("NetworkManager: cannot write canonical backup tmp file")
		return
	tmp.store_string(json_str)
	tmp.close()
	var err = DirAccess.copy_absolute(CLIENT_BACKUP_TMP, CLIENT_BACKUP_PATH)
	if err != OK:
		push_error("NetworkManager: failed to promote canonical backup (error %d)" % err)
		return
	DirAccess.remove_absolute(CLIENT_BACKUP_TMP)
	_last_received_backup_hash = content_hash

## Host pings every client with the current canonical content hash. Clients
## compare locally and only request a full payload if it differs.
@rpc("authority", "reliable", "call_remote", 1)
func _ping_canonical_hash(host_hash: String) -> void:
	if host_hash == _last_received_backup_hash:
		return  # Already up to date — skip the full transfer.
	_request_canonical_backup.rpc_id(1)

## Client → host: "my backup is stale, please send the full canonical save."
## Sent in response to a hash-ping mismatch.
@rpc("any_peer", "reliable", "call_remote", 1)
func _request_canonical_backup() -> void:
	if not is_host:
		return
	var sender_peer: int = multiplayer.get_remote_sender_id()
	_send_canonical_backup_to_peer(sender_peer)

# ─── LAN DISCOVERY ───

func start_discovery() -> void:
	_stop_discovery()
	discovered_hosts.clear()
	_discovery_no_beacon_logged = false
	_discovery_start_time = Time.get_ticks_msec()

	_discovery_socket = PacketPeerUDP.new()
	_discovery_socket.set_broadcast_enabled(true)
	var err = _discovery_socket.bind(DISCOVERY_PORT)
	if err != OK:
		push_warning("NetworkManager: Could not bind discovery socket on port %d: %s — another app may be using this port" % [DISCOVERY_PORT, error_string(err)])
		return

	print("NetworkManager: Listening for LAN beacons on port %d" % DISCOVERY_PORT)
	# Log local addresses so we can verify client is on the same subnet as host
	var local_addrs = []
	for addr in IP.get_local_addresses():
		var s = str(addr)
		if ":" not in s and not s.begins_with("127."):
			local_addrs.append(s)
	print("NetworkManager: Client local IPs: %s" % str(local_addrs))

var _discovery_no_beacon_logged: bool = false
var _discovery_start_time: int = 0

func poll_discovery() -> void:
	if _discovery_socket == null:
		return

	# Log a warning if no beacons received after 5 seconds
	if not _discovery_no_beacon_logged and discovered_hosts.is_empty():
		var elapsed = Time.get_ticks_msec() - _discovery_start_time
		if elapsed > 5000:
			_discovery_no_beacon_logged = true
			push_warning("NetworkManager: No beacons received after 5s — host may be on a different subnet, or firewall is blocking UDP port %d" % DISCOVERY_PORT)

	while _discovery_socket.get_available_packet_count() > 0:
		var data = _discovery_socket.get_packet().get_string_from_utf8()
		var ip = _discovery_socket.get_packet_ip()
		var parsed = JSON.parse_string(data)
		if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
			push_warning("NetworkManager: Received malformed beacon from %s" % ip)
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
			print("NetworkManager: Discovered host '%s' at %s:%d" % [entry["name"], ip, entry["port"]])
			discovered_hosts.append(entry)

	# Expire hosts that haven't sent a beacon in 3 seconds
	var now = Time.get_ticks_msec()
	for i in range(discovered_hosts.size() - 1, -1, -1):
		if now - discovered_hosts[i].get("_last_seen", 0) > 3000:
			print("NetworkManager: Host '%s' at %s timed out (no beacon for 3s)" % [discovered_hosts[i]["name"], discovered_hosts[i]["ip"]])
			discovered_hosts.remove_at(i)

func _stop_discovery() -> void:
	if _discovery_socket:
		_discovery_socket.close()
		_discovery_socket = null

func _start_beacon(port: int) -> void:
	_stop_beacon()
	_beacon_sockets.clear()

	# Collect broadcast addresses from all local network interfaces
	var broadcast_addresses: Array = ["255.255.255.255"]
	var local_addresses = IP.get_local_addresses()
	for addr in local_addresses:
		var s = str(addr)
		# Skip IPv6, loopback, and link-local
		if ":" in s or s.begins_with("127.") or s.begins_with("169.254."):
			continue
		# Derive /24 subnet broadcast (e.g., 192.168.1.123 -> 192.168.1.255)
		var parts = s.split(".")
		if parts.size() == 4:
			var subnet_broadcast = "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if subnet_broadcast not in broadcast_addresses:
				broadcast_addresses.append(subnet_broadcast)
			# Track our LAN IP for display
			if local_ip == "" or s.begins_with("192.168.") or s.begins_with("10."):
				local_ip = s

	# Create one socket per broadcast address
	for bcast in broadcast_addresses:
		var sock = PacketPeerUDP.new()
		sock.set_broadcast_enabled(true)
		sock.set_dest_address(bcast, DISCOVERY_PORT)
		_beacon_sockets.append(sock)

	print("NetworkManager: Broadcasting beacons to %s (local IP: %s)" % [str(broadcast_addresses), local_ip])

	_beacon_timer = Timer.new()
	add_child(_beacon_timer)
	_beacon_timer.wait_time = BEACON_INTERVAL
	_beacon_timer.timeout.connect(_send_beacon.bind(port))
	_beacon_timer.start()
	_send_beacon(port)

func _send_beacon(port: int) -> void:
	if _beacon_sockets.is_empty():
		return
	var payload = JSON.stringify({
		"game": "GenshinDnD",
		"port": port,
		"host_name": Global.ACTIVE_USER_NAME,
		"player_count": connected_players.size()
	})
	var buf = payload.to_utf8_buffer()
	for sock in _beacon_sockets:
		var err = sock.put_packet(buf)
		if err != OK:
			push_warning("NetworkManager: Beacon send failed on %s: %s" % [sock.get_dest_address(), error_string(err)])

func _stop_beacon() -> void:
	if _beacon_timer:
		_beacon_timer.stop()
		_beacon_timer.queue_free()
		_beacon_timer = null
	for sock in _beacon_sockets:
		sock.close()
	_beacon_sockets.clear()

# ─── CONNECTION CALLBACKS ───

## Apply lenient ENet timeouts to a connected peer so brief packet loss or
## stalled wifi doesn't trigger an immediate disconnect.
func _harden_peer_timeouts(peer_id: int) -> void:
	if peer == null:
		return
	var enet_host = peer.host
	if enet_host == null:
		return
	if not enet_host.has_method("get_peer"):
		return
	var pp = enet_host.get_peer(peer_id)
	if pp != null and pp.has_method("set_timeout"):
		pp.set_timeout(ENET_TIMEOUT_LIMIT, ENET_TIMEOUT_MIN_MS, ENET_TIMEOUT_MAX_MS)
		print("NetworkManager: Hardened timeouts for peer %d (limit=%d, min=%dms, max=%dms)" % [
			peer_id, ENET_TIMEOUT_LIMIT, ENET_TIMEOUT_MIN_MS, ENET_TIMEOUT_MAX_MS
		])

func _on_peer_connected(id: int) -> void:
	print("NetworkManager: Peer connected: %d" % id)
	_harden_peer_timeouts(id)
	if is_host:
		# Send full data sync to the new peer, table by table
		_send_full_sync_to_peer(id)
		# Also send a canonical-save backup so they have one immediately for
		# offline mode without waiting up to BACKUP_BROADCAST_INTERVAL_SEC.
		_send_canonical_backup_to_peer(id)
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int) -> void:
	print("NetworkManager: Peer disconnected: %d" % id)
	_last_pong_ms.erase(id)  # Drop heartbeat tracking for the gone peer
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
	# Harden the server peer (always peer_id 1 from a client's perspective).
	_harden_peer_timeouts(1)
	# Clients also start the heartbeat timer — they're a no-op as host (return
	# early in _on_heartbeat_tick) but it means clients are ready to respond to
	# pings without needing a separate state machine.
	_start_heartbeat()
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
	# Stop pinging into the void; reconnect will restart it on success.
	_stop_heartbeat()
	Toast.notify("Lost connection to host — reconnecting...", Toast.WARNING, 5.0)
	if _last_host_ip != "":
		_attempt_reconnect()

## LAN-aggressive reconnect: fast retries for the first 30s, then slow retries
## for up to 5 minutes total. Cancellable by setting _reconnecting = false from
## a UI action (lobby return, etc.).
func _attempt_reconnect() -> void:
	if _reconnecting:
		return  # Already in progress
	_reconnecting = true
	var start_ms: int = Time.get_ticks_msec()
	var attempt: int = 0
	while _reconnecting:
		attempt += 1
		var elapsed_ms: int = Time.get_ticks_msec() - start_ms
		if elapsed_ms > int(RECONNECT_TOTAL_DURATION_SEC * 1000):
			break
		print("NetworkManager: Reconnect attempt %d (elapsed=%ds)" % [attempt, elapsed_ms / 1000])

		# Build a fresh peer for each attempt — reusing a failed peer can stick.
		peer = ENetMultiplayerPeer.new()
		var err = peer.create_client(_last_host_ip, _last_host_port, ENET_CHANNELS, ENET_IN_BANDWIDTH, ENET_OUT_BANDWIDTH)
		if err == OK:
			multiplayer.multiplayer_peer = peer
			# Wait up to RECONNECT_HANDSHAKE_WAIT_SEC for the connection event.
			var deadline_ms: int = Time.get_ticks_msec() + int(RECONNECT_HANDSHAKE_WAIT_SEC * 1000)
			while Time.get_ticks_msec() < deadline_ms and _reconnecting:
				await get_tree().process_frame
				if is_connected_to_host:
					_reconnecting = false
					print("NetworkManager: Reconnected after %d attempts (%ds)" % [attempt, (Time.get_ticks_msec() - start_ms) / 1000])
					Toast.notify("Reconnected to host", Toast.SUCCESS)
					return

		# Failed this attempt — pick delay based on phase.
		var delay: float = RECONNECT_FAST_INTERVAL_SEC if attempt <= RECONNECT_FAST_ATTEMPTS else RECONNECT_SLOW_INTERVAL_SEC
		if attempt == RECONNECT_FAST_ATTEMPTS + 1:
			Toast.notify("Still trying to reach host... (will keep retrying)", Toast.WARNING, 3.0)
		await get_tree().create_timer(delay).timeout

	_reconnecting = false
	if not is_connected_to_host:
		Toast.notify("Could not reconnect after 5 minutes — returning to lobby", Toast.ERROR, 5.0)
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
	# Mirror to offline snapshot so a mid-session drop preserves online progress.
	Global._queue_offline_snapshot_save()
	Global.emit_signal("data_load_complete")

# ─── CLIENT -> HOST REQUESTS ───

## Client submits offline changes to host on reconnect. Host reconciles each
## entry against its ChangeLog using per-field last-write-wins by timestamp.
## An offline change at ts T wins over the host's value only if T is newer
## than the host's latest entry for that same (table, record, field).
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

	print("NetworkManager: Reconciling %d offline changes from %s (peer %d)" % [changes.size(), player_name, sender])

	# Sort by timestamp so insert-then-update on the same record applies in
	# the right order (insert assigns the new host ID; the update then targets it).
	changes.sort_custom(func(a, b): return int(a.get("ts", 0)) < int(b.get("ts", 0)))

	# Track offline→host ID remapping for records created offline. The client's
	# id (assigned locally while offline) won't match the host's next free id.
	var id_remap: Dictionary = {}  # "table:offline_id" -> host_id
	var changed_tables: Dictionary = {}
	var applied: int = 0
	var discarded: int = 0

	for change in changes:
		# Tolerate either the new (op/ts/value) or legacy (action/timestamp/data) keys.
		var op: String = str(change.get("op", change.get("action", "")))
		var table: String = str(change.get("table", ""))
		var ts: int = int(change.get("ts", 0))
		var actor: String = str(change.get("actor", player_name))

		match op:
			"update":
				var record_id_int: int = int(change.get("record_id", 0))
				var remap_key = "%s:%d" % [table, record_id_int]
				if id_remap.has(remap_key):
					record_id_int = int(id_remap[remap_key])
				var record_id: String = str(record_id_int)
				var field: String = str(change.get("field", ""))
				var value = change.get("value")

				# Per-field LWW: discard if host's latest entry beats us.
				var latest = ChangeLog.latest_for(table, record_id_int, field)
				if latest != null and int(latest.get("ts", 0)) >= ts:
					discarded += 1
					continue

				# Discard if the record was removed on the host while offline.
				if not Global._synced.get(table, {}).has(record_id):
					discarded += 1
					continue

				var old_value = Global._synced.get(table, {}).get(record_id, {}).get(field, null)
				Global._apply_local_update(table, record_id, field, value)
				ChangeLog.append_update(actor, table, record_id_int, field, value, old_value)
				changed_tables[table] = true
				applied += 1
			"insert":
				var data = change.get("value", change.get("data", {}))
				if typeof(data) != TYPE_DICTIONARY:
					discarded += 1
					continue
				var offline_id: int = int(data.get("id", change.get("record_id", 0)))
				var new_id: int = _next_id_for_table(table)
				id_remap["%s:%d" % [table, offline_id]] = new_id
				data["id"] = new_id
				Global._insert_record(table, str(new_id), data)
				ChangeLog.append_insert(actor, table, new_id, data)
				changed_tables[table] = true
				applied += 1
			"remove", "delete":
				var record_id_int: int = int(change.get("record_id", 0))
				var remap_key = "%s:%d" % [table, record_id_int]
				if id_remap.has(remap_key):
					record_id_int = int(id_remap[remap_key])
				var record_id: String = str(record_id_int)
				if not Global._synced.get(table, {}).has(record_id):
					discarded += 1
					continue
				Global._remove_record(table, record_id)
				ChangeLog.append_remove(actor, table, record_id_int)
				changed_tables[table] = true
				applied += 1

	# Persist + broadcast tables that changed during reconciliation.
	for table_name in changed_tables.keys():
		DataStore.persist_table(table_name)
		broadcast_table_update(table_name)

	print("NetworkManager: Reconciliation done — %d applied, %d discarded" % [applied, discarded])
	Toast.notify("Merged %d offline changes from %s (%d discarded)" % [applied, player_name, discarded], Toast.SUCCESS)
	_ack_offline_changes.rpc_id(sender, true)

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

## Damage breakdown sent from host to acting player after a turn.
signal damage_breakdown_received(turn_input: Dictionary)

# Channel 1: independent UI/log RPC, won't block state sync on channel 0.
@rpc("authority", "reliable", "call_remote", 1)
func _send_damage_breakdown(json_str: String) -> void:
	var input = JSON.parse_string(json_str)
	if input != null and input is Dictionary:
		damage_breakdown_received.emit(input)

## Client requests a field update. Host validates, applies, saves, broadcasts.
@rpc("any_peer", "reliable")
func request_update(updates_json: String) -> void:
	if not is_host:
		return
	var sender_peer: int = multiplayer.get_remote_sender_id()
	var actor: String = _actor_for_peer(sender_peer)
	print("NetworkManager: host received request_update from %s (peer %d)" % [actor, sender_peer])
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

		var old_value = Global._synced.get(table, {}).get(record_id, {}).get(field, null)
		Global._apply_local_update(table, record_id, field, value)
		ChangeLog.append_update(actor, table, int(record_id), field, value, old_value)
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

## Resolve a peer_id to an actor string for ChangeLog auditing.
##   1 (host) -> "host"
##   any other -> the player's name as registered in connected_players, or "peer N"
func _actor_for_peer(peer_id: int) -> String:
	if peer_id == 1:
		return "host"
	var pname: String = connected_players.get(peer_id, {}).get("name", "")
	if pname != "":
		return pname
	return "peer %d" % peer_id

## Client requests a record insertion.
@rpc("any_peer", "reliable")
func request_insert(table: String, record_json: String, correlation_id: String) -> void:
	if not is_host:
		return
	var record = JSON.parse_string(record_json)
	if record == null:
		return

	var sender = multiplayer.get_remote_sender_id()
	var actor: String = _actor_for_peer(sender)

	# Generate a new ID
	var new_id = _next_id_for_table(table)
	record["id"] = new_id

	# Insert into Global dict
	Global._insert_record(table, str(new_id), record)
	ChangeLog.append_insert(actor, table, new_id, record)

	# Save and broadcast
	DataStore.persist_table(table)
	broadcast_table_update(table)

	# Notify the requesting peer
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

	var sender = multiplayer.get_remote_sender_id()
	var actor: String = _actor_for_peer(sender)

	Global._remove_record(table, str(record_id))
	ChangeLog.append_remove(actor, table, record_id)
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

		var old_value = Global._synced.get(table, {}).get(record_id, {}).get(field, null)
		Global._apply_local_update(table, record_id, field, value)
		ChangeLog.append_update("host", table, int(record_id), field, value, old_value)
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
	ChangeLog.append_insert("host", table, new_id, record)
	DataStore.persist_table(table)
	broadcast_table_update(table)
	Global.emit_signal("data_load_complete")
	return new_id

## Host removes a record locally, saves, and broadcasts.
func host_remove(table: String, record_id: int) -> void:
	Global._remove_record(table, str(record_id))
	ChangeLog.append_remove("host", table, record_id)
	DataStore.persist_table(table)
	broadcast_table_update(table)
	Global.emit_signal("data_load_complete")

# ─── TRANSACTIONAL ITEM TRANSFER (2PC) ─────────────────────────────────────
# Flow: giver -> host. Host validates, stages add on receiver, broadcasts table
# sync, notifies receiver and waits for ack. On ack, host subtracts from giver
# and broadcasts. On timeout, host rolls back receiver's addition. The giver
# never loses items unless the receiver visibly acknowledged receipt.
#
# Edge cases:
#  - Receiver offline: commit immediately (host has the data; receiver syncs on
#    reconnect). The giver gets confirmation right away.
#  - Receiver is host (giver is client giving to DM): no RPC roundtrip; commit
#    immediately. rpc_id(1) to self is silently dropped.
#  - Giver is host: skip RPC by calling _handle_transfer_request directly.

signal transfer_result(corr_id: String, success: bool, message: String)

# corr_id -> { giver_name, giver_peer, receiver_name, item_name, qty,
#              giver_record_id, receiver_record_id, receiver_had_existing,
#              started_at_ms }
var _pending_transfers: Dictionary = {}
const TRANSFER_TIMEOUT_SEC: float = 15.0

## Public entry: giver calls this to start a transfer. Routes correctly whether
## giver is host or client.
func request_item_transfer(corr_id: String, receiver_name: String, item_name: String, qty: int) -> void:
	if is_host:
		_handle_transfer_request(1, corr_id, receiver_name, item_name, qty)
	else:
		_rpc_request_item_transfer.rpc_id(1, corr_id, receiver_name, item_name, qty)

@rpc("any_peer", "reliable")
func _rpc_request_item_transfer(corr_id: String, receiver_name: String, item_name: String, qty: int) -> void:
	if not is_host:
		return
	var sender_peer: int = multiplayer.get_remote_sender_id()
	_handle_transfer_request(sender_peer, corr_id, receiver_name, item_name, qty)

## Host-side: validate, stage on receiver, expect ack (or skip ack if offline/self).
func _handle_transfer_request(giver_peer: int, corr_id: String, receiver_name: String, item_name: String, qty: int) -> void:
	# Resolve giver name from peer_id (defends against spoofed sender name).
	var giver_name: String = ""
	if giver_peer == 1:
		giver_name = Global.ACTIVE_USER_NAME
	else:
		giver_name = connected_players.get(giver_peer, {}).get("name", "")

	# ── Validate ────────────────────────────────────────────────────────
	if giver_name == "" or str(receiver_name).strip_edges() == "" or str(item_name).strip_edges() == "":
		_send_transfer_result(giver_peer, corr_id, false, "Invalid transfer arguments")
		return
	if qty <= 0:
		_send_transfer_result(giver_peer, corr_id, false, "Quantity must be at least 1")
		return
	if giver_name == receiver_name:
		_send_transfer_result(giver_peer, corr_id, false, "Cannot give to yourself")
		return

	var giver_record = _find_item_record(giver_name, item_name)
	if giver_record == null:
		_send_transfer_result(giver_peer, corr_id, false, "You don't have %s" % item_name)
		return
	var giver_qty: int = int(giver_record.get("Quantity", 0))
	if giver_qty < qty:
		_send_transfer_result(giver_peer, corr_id, false, "You only have %d %s" % [giver_qty, item_name])
		return

	var actor_for_log: String = _actor_for_peer(giver_peer)

	# ── Phase 1: stage addition on receiver (don't touch giver yet) ────
	var receiver_record = _find_item_record(receiver_name, item_name)
	var receiver_record_id: int = -1
	var receiver_had_existing: bool = (receiver_record != null)
	if receiver_had_existing:
		receiver_record_id = int(receiver_record.get("id"))
		var old_qty: int = int(receiver_record.get("Quantity", 0))
		var new_qty: int = old_qty + qty
		Global._apply_local_update("Character_Items", str(receiver_record_id), "Quantity", new_qty)
		ChangeLog.append_update(actor_for_log, "Character_Items", receiver_record_id, "Quantity", new_qty, old_qty)
	else:
		var item_def = _find_master_item_def(item_name)
		if item_def == null:
			_send_transfer_result(giver_peer, corr_id, false, "Item definition missing for %s" % item_name)
			return
		receiver_record_id = _next_id_for_table("Character_Items")
		var new_record := {
			"id": receiver_record_id,
			"Owner": receiver_name,
			"Name": item_name,
			"Quantity": qty,
			"Type": item_def.get("Type", ""),
			"Rarity": item_def.get("Rarity", ""),
			"Description": item_def.get("Description", ""),
		}
		Global._insert_record("Character_Items", str(receiver_record_id), new_record)
		ChangeLog.append_insert(actor_for_log, "Character_Items", receiver_record_id, new_record)
	DataStore.persist_table("Character_Items")
	broadcast_table_update("Character_Items")

	# Track pending. Even if we commit immediately below, _commit_transfer expects this.
	_pending_transfers[corr_id] = {
		"giver_name": giver_name,
		"giver_peer": giver_peer,
		"receiver_name": receiver_name,
		"item_name": item_name,
		"qty": qty,
		"giver_record_id": int(giver_record.get("id")),
		"receiver_record_id": receiver_record_id,
		"receiver_had_existing": receiver_had_existing,
		"started_at_ms": Time.get_ticks_msec(),
	}

	var receiver_peer: int = _peer_id_for_player(receiver_name)
	if receiver_peer == -1:
		# Receiver offline — items held by host, will sync on their reconnect.
		_commit_transfer(corr_id, "%s offline — items will sync when they reconnect" % receiver_name)
		return
	if receiver_peer == 1:
		# Receiver is host (giver is a client giving to DM). No RPC roundtrip needed.
		_commit_transfer(corr_id, "Transfer complete")
		return

	# ── Phase 2: notify receiver, await ack with timeout ───────────────
	_notify_received_transfer.rpc_id(receiver_peer, corr_id, item_name, qty, giver_name)
	var timer := get_tree().create_timer(TRANSFER_TIMEOUT_SEC)
	timer.timeout.connect(_on_transfer_timeout.bind(corr_id))

## Receiver's client: show feedback and ack the host.
@rpc("authority", "reliable")
func _notify_received_transfer(corr_id: String, item_name: String, qty: int, giver_name: String) -> void:
	Toast.notify("Received %d %s from %s" % [qty, item_name, giver_name], Toast.SUCCESS)
	_ack_received_transfer.rpc_id(1, corr_id)

@rpc("any_peer", "reliable")
func _ack_received_transfer(corr_id: String) -> void:
	if not is_host:
		return
	_commit_transfer(corr_id, "Transfer complete")

## Host: subtract from giver, broadcast, clean up.
func _commit_transfer(corr_id: String, message: String) -> void:
	if not _pending_transfers.has(corr_id):
		return  # Already committed or rolled back
	var pending: Dictionary = _pending_transfers[corr_id]
	_pending_transfers.erase(corr_id)

	var giver_record_id: int = int(pending.get("giver_record_id", -1))
	var qty: int = int(pending.get("qty", 0))
	var actor_for_log: String = _actor_for_peer(int(pending.get("giver_peer", 0)))
	var items_dict: Dictionary = Global._synced.get("Character_Items", {})
	var giver_record = items_dict.get(str(giver_record_id), null)
	if giver_record == null:
		_send_transfer_result(pending.get("giver_peer", 0), corr_id, false, "Giver record disappeared during transfer")
		return
	var old_giver_qty: int = int(giver_record.get("Quantity", 0))
	var new_giver_qty: int = max(0, old_giver_qty - qty)
	Global._apply_local_update("Character_Items", str(giver_record_id), "Quantity", new_giver_qty)
	ChangeLog.append_update(actor_for_log, "Character_Items", giver_record_id, "Quantity", new_giver_qty, old_giver_qty)
	DataStore.persist_table("Character_Items")
	broadcast_field_updates([{
		"table": "Character_Items",
		"record_id": giver_record_id,
		"field": "Quantity",
		"value": new_giver_qty,
	}])

	_send_transfer_result(pending.get("giver_peer", 0), corr_id, true, message)

## Host: receiver never acked. Undo the receiver-side stage, notify giver.
func _on_transfer_timeout(corr_id: String) -> void:
	if not _pending_transfers.has(corr_id):
		return  # Already committed
	var pending: Dictionary = _pending_transfers[corr_id]
	_pending_transfers.erase(corr_id)

	var receiver_record_id: int = int(pending.get("receiver_record_id", -1))
	var qty: int = int(pending.get("qty", 0))
	if pending.get("receiver_had_existing", false):
		var items_dict: Dictionary = Global._synced.get("Character_Items", {})
		var rec = items_dict.get(str(receiver_record_id), null)
		if rec != null:
			var current: int = int(rec.get("Quantity", 0))
			Global._apply_local_update("Character_Items", str(receiver_record_id), "Quantity", max(0, current - qty))
	else:
		Global._remove_record("Character_Items", str(receiver_record_id))
	DataStore.persist_table("Character_Items")
	broadcast_table_update("Character_Items")

	_send_transfer_result(
		pending.get("giver_peer", 0),
		corr_id,
		false,
		"%s didn't confirm receipt — transfer cancelled" % str(pending.get("receiver_name", "Receiver"))
	)

func _send_transfer_result(giver_peer: int, corr_id: String, success: bool, message: String) -> void:
	if giver_peer == 1:
		_show_transfer_result(corr_id, success, message)
	else:
		_rpc_transfer_result.rpc_id(giver_peer, corr_id, success, message)

@rpc("authority", "reliable")
func _rpc_transfer_result(corr_id: String, success: bool, message: String) -> void:
	_show_transfer_result(corr_id, success, message)

## Universal giver feedback. Toast survives scene refresh (PlayerInventory
## auto-rebuilds on data_load_complete, so its own signal handlers can vanish
## between staging and ack — Toast is on a singleton and persists).
func _show_transfer_result(corr_id: String, success: bool, message: String) -> void:
	transfer_result.emit(corr_id, success, message)
	Toast.notify(message, Toast.SUCCESS if success else Toast.ERROR)

## Find peer_id by player name. Returns 1 for host's own player, -1 if unknown.
func _peer_id_for_player(player_name: String) -> int:
	for peer_id in connected_players:
		if connected_players[peer_id].get("name", "") == player_name:
			return peer_id
	if is_host and Global.ACTIVE_USER_NAME == player_name:
		return 1
	return -1

## Find a Character_Items record by owner+item name. Returns null if absent.
func _find_item_record(owner_name: String, item_name: String) -> Variant:
	var items: Dictionary = Global._synced.get("Character_Items", {})
	for rid in items:
		var rec = items[rid]
		if rec.get("Owner") == owner_name and rec.get("Name") == item_name:
			return rec
	return null

## Find a master item definition in Global.ITEMS (catalog uses "Item" as name field).
func _find_master_item_def(item_name: String) -> Variant:
	for i in Global.ITEMS.values():
		if i.get("Item") == item_name or i.get("Name") == item_name:
			return i
	return null

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

# Channel 1: chatty client→host logs, won't block state sync on channel 0.
@rpc("any_peer", "reliable", "call_remote", 1)
func _request_log(payload_json: String) -> void:
	if not is_host:
		return
	var payload = JSON.parse_string(payload_json)
	if payload:
		host_log(payload)

@rpc("any_peer", "reliable", "call_remote", 1)
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

# ─── MAP MARKER SYNC ───

## Client sends its markers to the host after placing/editing/deleting.
func send_markers_to_host(player_name: String, markers: Array) -> void:
	if is_host:
		# Host updates directly
		SaveManager.set_player_markers(player_name, markers)
		_broadcast_all_markers()
		return
	var json = JSON.stringify(markers)
	_sync_markers_to_host.rpc_id(1, player_name, json)

@rpc("any_peer", "reliable")
func _sync_markers_to_host(player_name: String, markers_json: String) -> void:
	if not is_host:
		return
	var markers = JSON.parse_string(markers_json)
	if markers == null or not markers is Array:
		return
	SaveManager.set_player_markers(player_name, markers)
	_broadcast_all_markers()

func _broadcast_all_markers() -> void:
	var all = SaveManager.get_map_markers()
	var json = JSON.stringify(all)
	_receive_markers_sync.rpc(json)
	# Also emit locally for the host
	map_markers_updated.emit(all)

@rpc("authority", "reliable")
func _receive_markers_sync(all_markers_json: String) -> void:
	var all = JSON.parse_string(all_markers_json)
	if all == null or not all is Dictionary:
		return
	SaveManager.set_all_markers(all)
	map_markers_updated.emit(all)

# ─── MAP PING (temporary indicator visible to all) ───

func broadcast_map_ping(ping_json: String) -> void:
	_receive_map_ping.rpc(ping_json)

@rpc("any_peer", "reliable", "call_remote")
func _receive_map_ping(ping_json: String) -> void:
	map_ping_received.emit(ping_json)
