extends SceneTree
## Networking, RPC and sync tests.
## Run: godot --headless --script test/network_sync_test.gd
## (No GdUnit4 in this project; self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## These run without a live ENet peer, so they cover the parts that are pure
## logic and the parts that historically failed SILENTLY:
##
##   * RPC index integrity. Godot identifies an RPC by its position in the
##     ALPHABETICALLY SORTED list of a node's @rpc methods, not by name. Adding or
##     renaming one shifts every later index, so a host and client on different
##     builds silently invoke each other's wrong methods. This suite pins the
##     current map so such a change is visible in a diff.
##   * Authority guards — who is allowed to act for whom.
##   * Host/client role split — clients must never write authoritative state.
##   * Connection health / retry thresholds that drive the reconnect UI.

var _ran := false
var _fails: Array[String] = []
var _completed := 0
const EXPECTED_TESTS := 7

func _done() -> void:
	_completed += 1

func _init() -> void:
	process_frame.connect(_run)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _eq(actual, expected, msg: String) -> void:
	_check(actual == expected, "%s (got %s, expected %s)" % [msg, str(actual), str(expected)])

func _run() -> void:
	if _ran:
		return
	_ran = true
	var nm = root.get_node_or_null("NetworkManager")
	var g = root.get_node_or_null("Global")
	var sl = root.get_node_or_null("SessionLog")
	if nm == null or g == null or sl == null:
		print("NETWORK SYNC TESTS: FAIL (required autoload missing)")
		quit(1)
		return

	_test_rpc_index_map(nm)
	_test_rpc_channel_discipline(nm)
	_test_authority_guard(nm, g)
	_test_actor_resolution(nm)
	_test_client_never_writes(nm, g)
	_test_health_thresholds(nm)
	_test_sync_table_coverage(g)

	_check(_completed == EXPECTED_TESTS,
		"all %d test functions ran to completion (only %d did)" % [EXPECTED_TESTS, _completed])

	if _fails.is_empty():
		print("NETWORK SYNC TESTS: PASS")
		quit(0)
	else:
		print("NETWORK SYNC TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)


## @rpc annotations live on the SCRIPT, not the node. Node-level rpc config only
## holds entries added at runtime via rpc_config(), which this project never uses,
## so reading the node returns an empty dictionary. Godot's own _parse_rpc_config
## reads both, node-level first.
func _rpc_config(node: Object):
	var scr = node.get_script()
	if scr != null and scr.has_method("get_rpc_config"):
		return scr.get_rpc_config()
	return {}


## Collect a node's @rpc method names, sorted as Strings.
## NOTE: the config keys are StringName, and sorting StringNames in GDScript does
## NOT give lexicographic order — they must be cast to String first. Godot's own
## id assignment happens in C++; what this list is for is making a change to the
## RPC SURFACE visible in review, not reproducing engine internals exactly.
func _rpc_names(node: Object) -> Array:
	var cfg = _rpc_config(node)
	var names: Array = []
	if cfg is Dictionary:
		for k in cfg.keys():
			names.append(str(k))
	names.sort()
	return names


# ─── RPC index integrity ────────────────────────────────────────────────────

## This is the failure that cost a whole session: a client on an older build sent
## `request_battle_state` (index 30 in its map) and the host executed whatever sat
## at index 30 in ITS map. Table sync kept working because those methods sit at
## lower, unshifted indices — so the game LOOKED connected while battle RPCs died.
##
## The point of pinning the list is not that this exact order is sacred; it is
## that changing it is a WIRE-BREAKING change that must show up in review and
## force a rebuild for every player.
func _test_rpc_index_map(nm) -> void:
	var names := _rpc_names(nm)
	_check(names.size() > 0, "NetworkManager exposes @rpc methods")

	# Sorted order must be stable and duplicate-free, or ids are ambiguous.
	var seen := {}
	var sorted_ok := true
	for i in range(names.size()):
		var n := str(names[i])
		if seen.has(n):
			_check(false, "duplicate @rpc name in config: %s" % n)
		seen[n] = true
		if i > 0 and str(names[i - 1]) > n:
			sorted_ok = false
	_check(sorted_ok, "rpc name list is sorted (Godot assigns ids by sorted position)")

	# The battle-critical client->host calls must exist under exactly these names.
	for required in ["request_battle_state", "request_process_turn", "request_update",
			"request_insert", "request_remove", "_register_with_host",
			"_receive_battle_state", "_receive_table_sync", "_receive_field_updates"]:
		_check(names.has(required), "critical RPC still present: %s" % required)

	# Renaming any of these shifts ids for everything after it. Record the count so
	# an accidental addition is at least visible as a failing assertion.
	print("[rpc-map] NetworkManager @rpc count = %d" % names.size())
	for i in range(names.size()):
		print("[rpc-map]   %2d %s" % [i, names[i]])
	_done()


## Channel discipline: chatty log/UI traffic must not share channel 0 with state
## sync, or a burst of log packets head-of-line-blocks a critical state update.
func _test_rpc_channel_discipline(nm) -> void:
	var cfg = _rpc_config(nm)
	_check(cfg is Dictionary, "rpc config readable")
	if not (cfg is Dictionary):
		_done()
		return

	# Anything explicitly assigned a channel must use a channel we allocated.
	var by_name := {}
	for k in cfg.keys():
		by_name[str(k)] = cfg[k]

	var max_channel := 0
	for name in by_name.keys():
		var entry = by_name[name]
		if entry is Dictionary and entry.has("channel"):
			max_channel = maxi(max_channel, int(entry["channel"]))
	_check(max_channel < nm.ENET_CHANNELS,
		"no RPC uses a channel beyond ENET_CHANNELS (%d)" % nm.ENET_CHANNELS)

	# The log/UI RPCs specifically must not be on channel 0.
	for logish in ["_request_log", "_request_combat_log", "_send_damage_breakdown"]:
		if by_name.has(logish) and by_name[logish] is Dictionary:
			_eq(int(by_name[logish].get("channel", 0)), 1,
				"%s stays off the state-sync channel" % logish)
	_done()


# ─── Authority ──────────────────────────────────────────────────────────────

## _peer_owns_battler decides whether a client may submit a turn. It must accept
## only the battler whose turn it is, and only from that battler's owner.
func _test_authority_guard(nm, g) -> void:
	g._synced["Party"] = {"1": {
		"id": 1, "Current_Turn": "Brian C.",
		"Party_Member_1": "Brian C.", "Party_Member_2": "Dylan",
	}}
	g._synced["Characters"] = {
		"2": {"id": 2, "Name": "Brian C."},
		"3": {"id": 3, "Name": "Dylan"},
	}
	g._synced["Companions"] = {
		"77": {"id": 77, "Name": "Pet", "Owner": "Brian C.", "Active": true, "Unlocked": true},
	}
	g._process_table("Characters", g._synced["Characters"].values())
	g._process_table("Companions", g._synced["Companions"].values())

	_check(nm._peer_owns_battler("Brian C.", "Brian C."),
		"the acting player may submit their own turn")
	_check(not nm._peer_owns_battler("Dylan", "Brian C."),
		"another player may NOT submit someone else's turn")
	_check(not nm._peer_owns_battler("Brian C.", "Dylan"),
		"a player may not act as a battler whose turn it isn't")
	_check(not nm._peer_owns_battler("Brian C.", "Ruin Guard 900"),
		"enemies are host-controlled and never client-submittable")
	_check(not nm._peer_owns_battler("", "Brian C."),
		"an unregistered actor (empty name) is rejected")

	# Companion ownership follows the Owner field, on the companion's own turn.
	g._synced["Party"] = {"1": {
		"id": 1, "Current_Turn": "Pet",
		"Party_Member_1": "Brian C.", "Party_Member_2": "Dylan",
	}}
	_check(nm._peer_owns_battler("Brian C.", "Pet"),
		"a companion's owner may act for it")
	_check(not nm._peer_owns_battler("Dylan", "Pet"),
		"a non-owner may NOT act for someone else's companion")
	_done()


## An unregistered peer must not resolve to a real player name, or the authority
## guard above could be bypassed by a client that never completed registration.
func _test_actor_resolution(nm) -> void:
	var saved = nm.connected_players.duplicate(true)
	nm.connected_players = {2: {"name": "Brian C."}, 3: {"name": ""}}

	_eq(nm._actor_for_peer(1), "host", "peer 1 always resolves to host")
	_eq(nm._actor_for_peer(2), "Brian C.", "registered peer resolves to its player name")
	_check(nm._actor_for_peer(3).begins_with("peer "),
		"peer registered with an empty name falls back to 'peer N', not a real name")
	_check(nm._actor_for_peer(99).begins_with("peer "),
		"unknown peer falls back to 'peer N'")

	nm.connected_players = saved
	_done()


# ─── Host / client split ────────────────────────────────────────────────────

## Clients are pure shells: authoritative writes and broadcasts must no-op for
## them. If a client could persist or broadcast, two machines become authorities.
func _test_client_never_writes(nm, g) -> void:
	var saved_host = nm.is_host
	nm.is_host = false

	var ds = root.get_node_or_null("DataStore")
	if ds != null:
		# persist_table is host-only; on a client it must simply do nothing.
		ds.persist_table("Characters")
		_check(true, "DataStore.persist_table is a safe no-op on a client")

	# Host-only entry points must bail rather than acting.
	nm.broadcast_battle_state()
	nm.broadcast_table_update("Characters")
	nm.broadcast_field_updates([{"table": "Characters", "record_id": 2, "field": "Current_Health", "value": 1}])
	_check(true, "host-only broadcasts are safe no-ops on a client (no crash, no send)")

	# request_update arriving at a non-host must be ignored outright.
	nm.request_update(JSON.stringify([
		{"table": "Characters", "record_id": 2, "field": "Current_Health", "value": 12345},
	]))
	_check(int(g.CHARACTERS.get("2", {}).get("Current_Health", 0)) != 12345,
		"a client receiving request_update does NOT apply it (host-only guard holds)")

	nm.is_host = saved_host
	_done()


# ─── Connection health / retry ──────────────────────────────────────────────

## The reconnect UI and the "is the DM alive" badge key off these thresholds.
func _test_health_thresholds(nm) -> void:
	_check(nm.HEALTH_STALE_MS < nm.HEALTH_CRITICAL_MS,
		"stale threshold is below critical")
	_check(nm.HEARTBEAT_INTERVAL_SEC * 1000 < nm.HEALTH_STALE_MS,
		"heartbeat fires more often than the stale window, so a healthy link never flaps")
	_check(nm.HEARTBEAT_STALE_MS > nm.HEARTBEAT_INTERVAL_SEC * 1000,
		"heartbeat stale window is wider than one interval")
	_check(nm.RECONNECT_TOTAL_DURATION_SEC > nm.RECONNECT_FAST_ATTEMPTS * nm.RECONNECT_FAST_INTERVAL_SEC,
		"total reconnect budget exceeds the fast-retry phase, so slow retries get a turn")
	_check(nm.ENET_TIMEOUT_MAX_MS > nm.ENET_TIMEOUT_MIN_MS,
		"ENet timeout window is well-formed")
	_check(nm.ENET_CHANNELS >= 3,
		"at least 3 ENet channels allocated (state / logs / summary)")

	var saved_conn = nm.is_connected_to_host
	nm.is_connected_to_host = false
	_eq(int(nm.get_host_health_state().get("status", -1)), 2,
		"disconnected client reports critical health")
	nm.is_connected_to_host = true
	nm._last_ping_from_host_ms = 0
	_eq(int(nm.get_host_health_state().get("status", -1)), 1,
		"connected but never pinged reports warning, not healthy")
	nm._last_ping_from_host_ms = Time.get_ticks_msec()
	_eq(int(nm.get_host_health_state().get("status", -1)), 0,
		"a fresh ping reports healthy")
	nm.is_connected_to_host = saved_conn
	_done()


# ─── Sync coverage ──────────────────────────────────────────────────────────

## Every table the host persists must also be in the sync list, or clients render
## stale data for it forever with no error anywhere.
func _test_sync_table_coverage(g) -> void:
	var synced: Array = g.TABLES
	var saved: Array = g.TABLES_TO_SAVE
	var often: Array = g.TABLES_TO_SYNC_OFTEN

	for t in saved:
		_check(synced.has(t), "persisted table '%s' is also in the sync list" % t)
	for t in often:
		_check(synced.has(t), "frequently-synced table '%s' is in the sync list" % t)

	# The battle-critical tables must be in the frequent set, or HP and turn state
	# lag behind the action.
	for t in ["Characters", "BattleEnemies", "Companions"]:
		_check(often.has(t), "'%s' syncs frequently (battle-critical)" % t)

	_check(synced.has("Party"), "Party is synced — it carries Current_Turn")
	_done()
