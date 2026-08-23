extends Node
## Automatic diagnostic log collection for play sessions.
##
## WHY: sessions run as four exported builds on four laptops once a month. When
## something breaks there is currently nothing to look at — no console window
## (export_console_wrapper=0) and, until now, no log file. Diagnosing the battle
## desync cost a whole session of static analysis for want of one log line.
## Asking players to find and send a file is friction they shouldn't have to
## absorb, so this collects everything on the host automatically.
##
## HOW: `debug/file_logging` is enabled in project.godot, so every machine already
## writes an engine log to user://logs/godot.log. That file captures things
## GDScript cannot intercept — SCRIPT ERRORs, RPC failures, engine warnings —
## as well as every push_error/push_warning/print in the project. Each client
## tails its own log and streams the new bytes to the host on channel 1 (the
## logs/UI channel, so it can never head-of-line-block state sync on channel 0).
## The host writes each player's stream to its own file under
## user://session_logs/<session>/ alongside its own log.
##
## Nobody has to send anyone anything; the host just has the folder afterwards.

const LOG_PATH := "user://logs/godot.log"
const SESSIONS_DIR := "user://session_logs/"

## How often to ship new log content. Sessions are long and low-stakes, so this
## favours low chatter over low latency.
const FLUSH_INTERVAL_SEC := 15.0
## Cap per flush so a burst of errors can't produce an oversized reliable packet.
## Anything beyond this is picked up on the next tick.
const MAX_CHUNK_BYTES := 48 * 1024
## On connect, ship at most this much backlog so the host still gets startup
## errors (GameDB load failures, sync problems) without shipping a whole day.
const MAX_BACKLOG_BYTES := 256 * 1024
## Keep only the most recent N session folders on the host.
const MAX_SESSIONS_KEPT := 20

## Host: absolute-ish path of the folder for the current session. Empty when not hosting.
var _session_dir: String = ""
## Tail position in our own godot.log.
var _offset: int = 0
var _timer: Timer = null
var _started := false


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = FLUSH_INTERVAL_SEC
	_timer.one_shot = false
	_timer.timeout.connect(_on_flush_tick)
	add_child(_timer)

	# The host opens a session folder as soon as it is ready; clients begin
	# tailing once they have successfully connected and registered a name.
	NetworkManager.host_ready.connect(_on_host_ready)
	NetworkManager.connection_succeeded.connect(_on_connected)


# ─── Session lifecycle (host) ───────────────────────────────────────────────

func _on_host_ready() -> void:
	start_session()


## Host: open a new session folder and begin capturing. Safe to call twice.
func start_session() -> void:
	if not NetworkManager.is_host or _started:
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_session_dir = SESSIONS_DIR + stamp + "/"
	var err := DirAccess.make_dir_recursive_absolute(_session_dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("SessionLog: could not create %s (error %d)" % [_session_dir, err])
		_session_dir = ""
		return
	_prune_old_sessions()
	_begin_tailing(MAX_BACKLOG_BYTES)
	print("SessionLog: collecting session logs in %s" % _session_dir)


# ─── Client lifecycle ───────────────────────────────────────────────────────

func _on_connected() -> void:
	if NetworkManager.is_host:
		return
	_begin_tailing(MAX_BACKLOG_BYTES)


func _begin_tailing(backlog_bytes: int) -> void:
	if _started:
		return
	_started = true
	var size := _log_size()
	_offset = maxi(0, size - backlog_bytes)
	_timer.start()
	# Ship the backlog immediately rather than waiting a full interval — startup
	# errors are the most valuable thing in the file.
	_on_flush_tick()


func stop() -> void:
	_started = false
	if _timer != null:
		_timer.stop()


# ─── Tailing ────────────────────────────────────────────────────────────────

func _log_size() -> int:
	if not FileAccess.file_exists(LOG_PATH):
		return 0
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return 0
	var size := int(f.get_length())
	f.close()
	return size


## Read up to MAX_CHUNK_BYTES of new content and advance the offset.
func _read_new() -> String:
	if not FileAccess.file_exists(LOG_PATH):
		return ""
	var f := FileAccess.open(LOG_PATH, FileAccess.READ)
	if f == null:
		return ""
	var size := int(f.get_length())
	# The engine rotates logs between runs; a shrunken file means a new one.
	if size < _offset:
		_offset = 0
	if size <= _offset:
		f.close()
		return ""
	f.seek(_offset)
	var want: int = mini(size - _offset, MAX_CHUNK_BYTES)
	var capped: bool = want < (size - _offset)
	var bytes := f.get_buffer(want)
	f.close()

	# When we hit the cap, cut back to the last newline. Slicing at an arbitrary
	# byte can split a multi-byte UTF-8 sequence — mangling that character and the
	# start of the next chunk — and it also leaves half-lines in the written file.
	# The remainder is picked up on the next tick.
	if capped and bytes.size() > 0:
		var cut := -1
		for i in range(bytes.size() - 1, -1, -1):
			if bytes[i] == 10:  # \n
				cut = i + 1
				break
		if cut > 0:
			bytes = bytes.slice(0, cut)

	_offset += bytes.size()
	return bytes.get_string_from_utf8()


func _on_flush_tick() -> void:
	if not _started:
		return
	var chunk := _read_new()
	if chunk == "":
		return
	if NetworkManager.is_host:
		_append_to_session("host", chunk)
	elif NetworkManager.is_connected_to_host:
		var who := str(Global.ACTIVE_USER_NAME)
		if who == "":
			who = "unknown"
		_receive_log_chunk.rpc_id(1, who, chunk)


# ─── Transport ──────────────────────────────────────────────────────────────

## Client -> host: a slice of that client's engine log.
## Channel 1 is the logs/UI channel, so a chatty client can never delay state
## sync on channel 0. Unreliable would be wrong here — a dropped chunk is a
## permanent hole in the log, and the whole point is post-hoc diagnosis.
@rpc("any_peer", "reliable", "call_remote", 1)
func _receive_log_chunk(player_name: String, text: String) -> void:
	if not NetworkManager.is_host:
		return
	_append_to_session(_safe_name(player_name), text)


# ─── Writing ────────────────────────────────────────────────────────────────

## Strip anything that can't safely be part of a filename. Player names are
## host-supplied in practice, but this is data arriving over the network.
func _safe_name(raw: String) -> String:
	var s := raw.strip_edges()
	var out := ""
	for c in s:
		if c.to_lower() >= "a" and c.to_lower() <= "z":
			out += c
		elif c >= "0" and c <= "9":
			out += c
		elif c == " " or c == "_" or c == "-":
			out += "_"
	out = out.strip_edges()
	return out if out != "" else "unknown"


func _append_to_session(who: String, text: String) -> void:
	if _session_dir == "":
		return
	var path := _session_dir + who + ".log"
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SessionLog: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()


## Keep the session folder count bounded — this runs on the DM's laptop forever.
func _prune_old_sessions() -> void:
	var dir := DirAccess.open(SESSIONS_DIR)
	if dir == null:
		return
	var names: Array = []
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if dir.current_is_dir() and n != "." and n != "..":
			names.append(n)
		n = dir.get_next()
	dir.list_dir_end()
	if names.size() <= MAX_SESSIONS_KEPT:
		return
	# Folder names are timestamps, so lexicographic order is chronological.
	names.sort()
	for i in range(names.size() - MAX_SESSIONS_KEPT):
		_remove_dir_recursive(SESSIONS_DIR + names[i] + "/")


func _remove_dir_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir():
			dir.remove(n)
		n = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


## Absolute path of the current session folder, for surfacing in the UI.
func current_session_path() -> String:
	if _session_dir == "":
		return ""
	return ProjectSettings.globalize_path(_session_dir)
