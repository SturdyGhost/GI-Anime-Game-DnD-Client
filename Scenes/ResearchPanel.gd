# res://ui/research/ResearchPanel.gd
extends Control
class_name ResearchPanel

@onready var timer_label: Label = $Margin/VBox/Header/TimerLabel
@onready var viewer_vbox: VBoxContainer = $Margin/VBox/ViewerScroll/ViewerVBox
@onready var notes: TextEdit = $Margin/VBox/Notes
@onready var CountdownBeep: AudioStreamPlayer = $CountdownBeep
@onready var CountdownTimer: Timer = $CountdownTimer

var session_id: String = ""
var poll_timer: Timer
var poll_interval_sec: float = 1.5
var discover_timer: Timer

var version_seen: int = -1
var last_items_count: int = 0

# --- local timer state ---
var _local_timer_active: bool = false
var _end_ms: int = 0
var _last_beep_second: int = -1
var ms_left: int
var timer_started = 0

func _ready() -> void:
	notes.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY

	poll_timer = Timer.new()
	poll_timer.wait_time = poll_interval_sec
	poll_timer.timeout.connect(_poll)
	add_child(poll_timer)

	discover_timer = Timer.new()
	discover_timer.wait_time = 1.5
	discover_timer.one_shot = false
	discover_timer.timeout.connect(_discover_current)
	add_child(discover_timer)

	# drive label + beeps locally when a countdown is running
	if not CountdownTimer.timeout.is_connected(_on_countdown_timeout):
		CountdownTimer.timeout.connect(_on_countdown_timeout)
	set_process(false)

func open_auto() -> void:
	await ready
	# players call this: it finds the current open session automatically
	version_seen = -1
	last_items_count = 0
	_clear_viewer()
	notes.text = ""
	timer_label.text = "00:00"
	session_id = ""

	# reset local timer state
	_local_timer_active = false
	_end_ms = 0
	_last_beep_second = -1
	CountdownTimer.stop()
	set_process(false)

	discover_timer.start()
	_discover_current()

func _discover_current() -> void:
	ResearchAPI.fetch_current(func(code: int, data: Dictionary):
		if code == 200 and data.get("ok", false):
			session_id = str(data.get("session_id", ""))
			discover_timer.stop()
			poll_timer.start()
			_apply_state(data)  # also renders items immediately
		else:
			# still waiting for DM to open one; keep polling /research/current
			pass
	)

func _poll() -> void:
	if session_id == "":
		return
	ResearchAPI.fetch_state(session_id, func(data: Dictionary):
		_apply_state(data)
	)

func _apply_state(data: Dictionary) -> void:
	var is_active = bool(data.get("is_active", false))
	var started_at = str(data.get("started_at", ""))
	var duration = int(data.get("duration_sec", 0))
	var items: Array = data.get("items", [])

	# --- LOCAL TIMER START (once) ---
	# If server advertises a positive duration and our local timer isn't running, start locally.
	if duration > 0 and not _local_timer_active and CountdownTimer.is_stopped():
		_start_local_timer(duration)

	# Close if DM ended the session explicitly
	var closed = bool(data.get("closed", false))
	if closed:
		_finish_and_close()
		return

	# Render new items when version increments
	var ver = int(data.get("version", 0))
	if ver != version_seen:
		version_seen = ver
		if items.size() > last_items_count:
			for i in range(last_items_count, items.size()):
				_render_item(items[i])
			last_items_count = items.size()

# ------------------ LOCAL TIMER ------------------

func _start_local_timer(total_seconds: int) -> void:
	_local_timer_active = true
	_last_beep_second = -1

	CountdownTimer.stop()
	CountdownTimer.one_shot = true
	CountdownTimer.wait_time = float(total_seconds)
	CountdownTimer.start()

	_end_ms = Time.get_ticks_msec() + total_seconds * 1000
	set_process(true)  # drive label + beeps from _process
	_update_label_from_seconds(float(total_seconds))  # immediate UI update

func _process(_delta: float) -> void:
	if not _local_timer_active:
		return
	ms_left = _end_ms - Time.get_ticks_msec()
	if ms_left <= 0:
		_on_countdown_timeout()
		return
	var s_left: float = float(ms_left) / 1000.0
	_update_label_from_seconds(s_left)
	_maybe_beep(s_left)

func _on_countdown_timeout() -> void:
	_local_timer_active = false
	_last_beep_second = -1
	CountdownTimer.stop()
	set_process(false)
	_set_label_mmss(0)
	_finish_and_close()

# ------------------ UI + BEEPS ------------------

func _update_timer(remaining: float) -> void:
	# kept for compatibility; now driven by local seconds
	var r = max(0, remaining)
	var m = r / 60
	var s = r % 60
	timer_label.text = "%02d:%02d" % [m, s]
	_maybe_beep(float(remaining))

func _update_label_from_seconds(s_left: float) -> void:
	var whole = int(ceil(s_left))
	_set_label_mmss(whole)

func _set_label_mmss(total_seconds: int) -> void:
	var m = total_seconds / 60
	var s = total_seconds % 60
	timer_label.text = "%02d:%02d" % [m, s]

func _maybe_beep(seconds_left: float) -> void:
	var s = int(ceil(seconds_left))
	if s <=5 and timer_started == 0:
		timer_started = 1
		_last_beep_second = s  # ensures a crisp re-trigger
		CountdownBeep.play()


func reset_countdown_beep() -> void:
	_last_beep_second = -1

# ------------------ RENDERING ------------------

func _render_item(item: Dictionary) -> void:
	var kind = str(item.get("kind", "text"))
	match kind:
		"text":
			var t = RichTextLabel.new()
			t.fit_content = true
			t.bbcode_enabled = false
			t.scroll_active = false
			t.text = str(item.get("text", ""))
			viewer_vbox.add_child(t)
		"markdown":
			var m = RichTextLabel.new()
			m.fit_content = true
			m.bbcode_enabled = true
			m.text = str(item.get("md", ""))
			viewer_vbox.add_child(m)
		"image":
			var url = str(item.get("url", ""))
			var caption = str(item.get("caption", ""))
			_add_image(url, caption)
		_:
			pass

func _add_image(url: String, caption: String) -> void:
	if url == "":
		return
	var req = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r, code, _h, bytes: PackedByteArray):
		if code != 200:
			req.queue_free()
			return
		var img = Image.new()
		var ok = img.load_png_from_buffer(bytes) == OK
		if not ok:
			ok = img.load_jpg_from_buffer(bytes) == OK
		if ok:
			var tex = ImageTexture.create_from_image(img)
			var tr = TextureRect.new()
			tr.texture = tex
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT   # keep aspect ratio
			tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL # fill the VBox row width
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER # don't force extra height
			viewer_vbox.add_child(tr)
			if caption != "":
				var cap = Label.new()
				cap.text = caption
				viewer_vbox.add_child(cap)
		req.queue_free()
	, CONNECT_ONE_SHOT)
	req.request(url)

# ------------------ CLOSE ------------------

func _finish_and_close() -> void:
	# copy notes and close like before
	DisplayServer.clipboard_set(notes.text)
	poll_timer.stop()
	discover_timer.stop()
	get_parent().queue_free()

func _clear_viewer() -> void:
	if viewer_vbox == null:
		return
	for c in viewer_vbox.get_children():
		c.queue_free()
