# Brian's Notes Backup on Exit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When Brian F. closes the client from any scene, intercept the close, prompt him to select his Word doc, send it to the host via RPC, wait for host acknowledgment, persist his chosen path, then quit.

**Architecture:** The close intercept lives in `Global.gd` (autoload — works from any scene). The popup is built dynamically (matching existing codebase patterns). File transfer uses two new RPCs in `NetworkManager.gd`. Path persistence uses `ConfigFile` at `user://brian_notes_path.cfg`.

**Tech Stack:** Godot 4.4, GDScript, ENet multiplayer RPC

---

### Task 1: Disable auto-quit in project settings

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Add auto_accept_quit setting**

In `project.godot`, add `auto_accept_quit=false` under the `[application]` section so that `NOTIFICATION_WM_CLOSE_REQUEST` can be intercepted instead of the engine auto-closing:

```ini
[application]

config/name="Genshin DnD Client"
config/version="0.0.8"
run/main_scene="res://Scenes/Lobby.tscn"
config/features=PackedStringArray("4.4", "GL Compatibility")
run/auto_accept_quit=false
```

- [ ] **Step 2: Commit**

```bash
git add project.godot
git commit -m "feat: disable auto_accept_quit for window close interception"
```

---

### Task 2: Add notes file RPC to NetworkManager

**Files:**
- Modify: `Singletons/NetworkManager.gd` (append after line 615, end of file)

- [ ] **Step 1: Add the two new RPCs**

Add a new section at the end of `NetworkManager.gd` with two RPCs — one for the client to send the file bytes to the host, and one for the host to acknowledge receipt:

```gdscript
# ─── NOTES FILE BACKUP (Brian F. → Host) ───

@rpc("any_peer", "reliable")
func send_notes_file(filename: String, file_bytes: PackedByteArray) -> void:
	if not is_host:
		return
	var sender = multiplayer.get_remote_sender_id()
	var player_name = connected_players.get(sender, {}).get("name", "unknown")
	print("NetworkManager: Received notes file '%s' from %s (%d bytes)" % [filename, player_name, file_bytes.size()])

	# Ensure backup directory exists
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("notes_backups"):
		dir.make_dir("notes_backups")

	# Save the file
	var save_path = "user://notes_backups/%s" % filename
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
```

- [ ] **Step 2: Add the signal declaration**

Add the signal at the top of `NetworkManager.gd`, after the existing signal declarations (after line 11):

```gdscript
signal notes_file_ack_received(success: bool)
```

- [ ] **Step 3: Commit**

```bash
git add Singletons/NetworkManager.gd
git commit -m "feat: add notes file backup RPCs to NetworkManager"
```

---

### Task 3: Add close intercept and backup popup to Global.gd

**Files:**
- Modify: `Singletons/Global.gd` (add `_notification` handler and popup methods)

- [ ] **Step 1: Add the `_notification` handler**

Add this function to `Global.gd`. It intercepts the window close request. For Brian F., it shows the notes backup popup. For everyone else (and for the DM), it quits immediately:

```gdscript
# ─── NOTES BACKUP (Brian F. exit intercept) ─────────────────────────────────

var _notes_popup_active: bool = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if ACTIVE_USER_NAME == "Brian F." and not _notes_popup_active:
			_show_notes_backup_popup()
		else:
			get_tree().quit()
```

- [ ] **Step 2: Add the popup builder**

Add this method that builds the entire popup dynamically. It creates a full-screen overlay with a centered panel containing the message, file path input with browse button, and confirm/cancel buttons:

```gdscript
func _show_notes_backup_popup() -> void:
	_notes_popup_active = true

	# Full-screen semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.name = "NotesBackupOverlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100

	# Centered panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 250)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.15, 1.0)
	sb.border_color = Color(0.4, 0.4, 0.5, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)

	# Header label
	var header = Label.new()
	header.text = "Have you remembered to save the notes file?"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)

	# File path row
	var hbox_path = HBoxContainer.new()
	hbox_path.add_theme_constant_override("separation", 8)

	var path_edit = LineEdit.new()
	path_edit.name = "NotesPathEdit"
	path_edit.placeholder_text = "Select your notes file..."
	path_edit.editable = false
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_path.add_child(path_edit)

	var browse_btn = Button.new()
	browse_btn.text = "Browse"
	hbox_path.add_child(browse_btn)
	vbox.add_child(hbox_path)

	# Status label (for sending/error feedback)
	var status_label = Label.new()
	status_label.name = "NotesStatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_label.text = ""
	vbox.add_child(status_label)

	# Button row
	var hbox_btns = HBoxContainer.new()
	hbox_btns.alignment = BoxContainer.ALIGNMENT_END
	hbox_btns.add_theme_constant_override("separation", 12)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	hbox_btns.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.name = "NotesConfirmBtn"
	confirm_btn.text = "Confirm and exit"
	confirm_btn.disabled = true
	hbox_btns.add_child(confirm_btn)

	vbox.add_child(hbox_btns)
	panel.add_child(vbox)
	overlay.add_child(panel)

	# FileDialog for browsing
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.doc, *.docx ; Word Documents"])
	file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	file_dialog.size = Vector2(800, 500)
	file_dialog.title = "Select Notes File"
	overlay.add_child(file_dialog)

	# Load persisted path
	var config = ConfigFile.new()
	if config.load("user://brian_notes_path.cfg") == OK:
		var saved_path = config.get_value("notes", "path", "")
		if saved_path != "":
			path_edit.text = saved_path
			if FileAccess.file_exists(saved_path):
				confirm_btn.disabled = false

	# Wire up signals
	browse_btn.pressed.connect(func(): file_dialog.popup_centered())
	file_dialog.file_selected.connect(func(path: String):
		path_edit.text = path
		confirm_btn.disabled = not FileAccess.file_exists(path)
		status_label.text = ""
	)
	cancel_btn.pressed.connect(func():
		overlay.queue_free()
		_notes_popup_active = false
	)
	confirm_btn.pressed.connect(_on_notes_confirm.bind(path_edit, confirm_btn, cancel_btn, browse_btn, status_label, overlay))

	# Add to the scene tree root so it works from any scene
	get_tree().root.add_child(overlay)
```

- [ ] **Step 3: Add the confirm handler**

Add this method that reads the file, sends it via RPC, waits for acknowledgment, persists the path, then quits:

```gdscript
func _on_notes_confirm(path_edit: LineEdit, confirm_btn: Button, cancel_btn: Button, browse_btn: Button, status_label: Label, overlay: ColorRect) -> void:
	var file_path = path_edit.text
	if not FileAccess.file_exists(file_path):
		status_label.text = "File not found. Please browse again."
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		confirm_btn.disabled = true
		return

	# Disable UI while sending
	confirm_btn.disabled = true
	cancel_btn.disabled = true
	browse_btn.disabled = true
	status_label.text = "Sending file to host..."
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Read the file
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		status_label.text = "Failed to read file: %s" % error_string(FileAccess.get_open_error())
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		confirm_btn.disabled = false
		cancel_btn.disabled = false
		browse_btn.disabled = false
		return

	var file_bytes = file.get_buffer(file.get_length())
	file.close()
	var filename = file_path.get_file()

	# Send to host (peer 1)
	NetworkManager.send_notes_file.rpc_id(1, filename, file_bytes)

	# Wait for ack with timeout
	var result = await _wait_for_notes_ack(10.0)
	if result:
		# Save the path for next time
		var config = ConfigFile.new()
		config.set_value("notes", "path", file_path)
		config.save("user://brian_notes_path.cfg")
		get_tree().quit()
	else:
		status_label.text = "Failed to send file. Try again or cancel."
		status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		confirm_btn.disabled = false
		cancel_btn.disabled = false
		browse_btn.disabled = false

func _wait_for_notes_ack(timeout: float) -> bool:
	var timer = get_tree().create_timer(timeout)
	var result = await _race_signals(
		NetworkManager.notes_file_ack_received,
		timer.timeout
	)
	return result

func _race_signals(success_signal: Signal, timeout_signal: Signal) -> bool:
	var resolved = false
	var success = false

	success_signal.connect(func(ok: bool):
		if not resolved:
			resolved = true
			success = ok
	, CONNECT_ONE_SHOT)

	timeout_signal.connect(func():
		if not resolved:
			resolved = true
			success = false
	, CONNECT_ONE_SHOT)

	while not resolved:
		await get_tree().process_frame
	return success
```

- [ ] **Step 4: Commit**

```bash
git add Singletons/Global.gd
git commit -m "feat: add Brian's notes backup popup and close intercept"
```

---

### Task 4: Update player_hub.gd exit button to delegate for Brian

**Files:**
- Modify: `Scenes/player_hub.gd:555-563`

- [ ] **Step 1: Modify the exit button handler**

Replace the existing `_on_exit_button_pressed` and `_on_quit_confirmed` functions to delegate to the notes backup popup for Brian F., and keep the normal confirmation dialog for everyone else:

```gdscript
func _on_exit_button_pressed() -> void:
	if Global.ACTIVE_USER_NAME == "Brian F.":
		Global._show_notes_backup_popup()
		return
	var confirmation = ConfirmationDialog.new()
	confirmation.dialog_text = "Are you sure you want to quit?"
	confirmation.connect("confirmed", Callable(self, "_on_quit_confirmed"))
	add_child(confirmation)
	confirmation.popup_centered()
	
func _on_quit_confirmed():
	get_tree().quit()
```

- [ ] **Step 2: Commit**

```bash
git add Scenes/player_hub.gd
git commit -m "feat: delegate exit button to notes backup for Brian F."
```

---

### Task 5: Manual testing checklist

- [ ] **Step 1: Test as non-Brian player**

Launch the client as any player other than Brian F. Verify:
- Clicking the exit button shows the normal "Are you sure you want to quit?" dialog
- Clicking the window X button closes immediately
- No notes backup popup appears

- [ ] **Step 2: Test as Brian F. — exit button**

Launch the client as Brian F. Click the exit button. Verify:
- The notes backup popup appears with "Have you remembered to save the notes file?"
- The "Confirm and exit" button is disabled
- Clicking "Browse" opens a file dialog filtered to `.doc`/`.docx` starting at the Desktop
- Selecting a file populates the path and enables "Confirm and exit"
- Clicking "Cancel" closes the popup and returns to the game

- [ ] **Step 3: Test as Brian F. — window X button**

Launch the client as Brian F. Click the window X button. Verify:
- The notes backup popup appears (same as exit button)
- The game does NOT close

- [ ] **Step 4: Test file transfer end-to-end**

With both host and Brian F. connected:
- Brian selects a `.docx` file and clicks "Confirm and exit"
- Status shows "Sending file to host..."
- Host receives the file at `user://notes_backups/<filename>`
- Brian's client quits after acknowledgment
- On next launch, Brian's path is pre-populated in the LineEdit

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: Brian's notes backup on exit — complete"
```
