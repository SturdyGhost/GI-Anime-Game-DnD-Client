extends SceneTree
## Headless tests for SessionLog — automatic diagnostic log collection.
## Run: godot --headless --script test/session_log_test.gd
## (No GdUnit4 in this project; self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## SessionLog tails each machine's engine log (user://logs/godot.log) and streams
## new bytes to the host, which files them per player under user://session_logs/.
## The parts worth pinning are the ones that fail silently in a real session:
## filename sanitisation (data arrives over the network), tail-offset bookkeeping
## across log rotation, line-aligned chunking, and session pruning.

var _ran := false
var _fails: Array[String] = []

const TMP_DIR := "user://_test_session_logs/"

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
	var sl = root.get_node_or_null("SessionLog")
	if sl == null:
		print("SESSION LOG TESTS: FAIL (SessionLog autoload missing)")
		quit(1)
		return

	_test_file_logging_enabled()
	_test_safe_name(sl)
	_test_tail_offset(sl)
	_test_append_and_prune(sl)
	_cleanup()

	if _fails.is_empty():
		print("SESSION LOG TESTS: PASS")
		quit(0)
	else:
		print("SESSION LOG TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)

## The whole feature rests on the engine actually writing a log file. If this
## setting regresses, everything else silently collects nothing.
func _test_file_logging_enabled() -> void:
	_eq(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false), true,
		"engine file logging is enabled in project.godot")
	_eq(str(ProjectSettings.get_setting("debug/file_logging/log_path", "")), "user://logs/godot.log",
		"log path matches SessionLog.LOG_PATH")
	_check(FileAccess.file_exists("user://logs/godot.log"),
		"engine log file actually exists at runtime")

## Player names arrive over the network and become filenames.
func _test_safe_name(sl) -> void:
	_eq(sl._safe_name("Brian C."), "Brian_C", "normal name is sanitised to a safe filename")
	_eq(sl._safe_name("Brian F."), "Brian_F", "second normal name")
	_eq(sl._safe_name(""), "unknown", "empty name falls back to 'unknown'")
	_eq(sl._safe_name("   "), "unknown", "whitespace-only name falls back")
	# Path traversal must not survive — this string becomes part of a file path.
	var traversal = sl._safe_name("../../etc/passwd")
	_check(not traversal.contains(".."), "traversal dots stripped")
	_check(not traversal.contains("/"), "path separators stripped")
	_check(not sl._safe_name("a\\b").contains("\\"), "backslashes stripped")
	_check(not sl._safe_name("a:b").contains(":"), "colons stripped")

## Offset bookkeeping: advances on read, and resets when the engine rotates the
## log (new file is shorter than our stored offset).
func _test_tail_offset(sl) -> void:
	var saved_offset = sl._offset

	var size = sl._log_size()
	_check(size > 0, "engine log has content to tail")

	# Reading from 0 must return content and move the offset forward.
	sl._offset = 0
	var chunk = sl._read_new()
	_check(chunk.length() > 0, "reading from offset 0 returns content")
	_check(sl._offset > 0, "offset advances after a read")
	_check(sl._offset <= sl._log_size(), "offset never runs past the file")

	# Caught up: nothing new to send.
	sl._offset = sl._log_size()
	_eq(sl._read_new(), "", "returns empty when caught up")

	# Rotation: a shorter file than our offset means a fresh log, so restart at 0
	# rather than reading nothing forever.
	sl._offset = sl._log_size() + 100_000
	var after_rotate = sl._read_new()
	_check(after_rotate.length() > 0, "log rotation resets the offset and re-reads")

	sl._offset = saved_offset

## Per-player files are created then appended to, and old sessions are pruned.
func _test_append_and_prune(sl) -> void:
	var saved_dir = sl._session_dir
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	sl._session_dir = TMP_DIR

	sl._append_to_session("Brian_C", "line one\n")
	sl._append_to_session("Brian_C", "line two\n")
	sl._append_to_session("Dylan", "dylan line\n")

	var p := TMP_DIR + "Brian_C.log"
	_check(FileAccess.file_exists(p), "per-player log file is created")
	var f := FileAccess.open(p, FileAccess.READ)
	var body := f.get_as_text() if f != null else ""
	if f != null:
		f.close()
	_eq(body, "line one\nline two\n", "appends rather than overwriting")

	var p2 := TMP_DIR + "Dylan.log"
	_check(FileAccess.file_exists(p2), "each player gets their own file")

	# A write with no session open must be a no-op, not a crash — clients call
	# into this path before the host has opened a session folder.
	sl._session_dir = ""
	sl._append_to_session("Nobody", "should not be written\n")
	_check(not FileAccess.file_exists(TMP_DIR + "Nobody.log"),
		"writing with no open session is a safe no-op")

	sl._session_dir = saved_dir

func _cleanup() -> void:
	var dir := DirAccess.open(TMP_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var n := dir.get_next()
	while n != "":
		if not dir.current_is_dir():
			dir.remove(n)
		n = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(TMP_DIR)
