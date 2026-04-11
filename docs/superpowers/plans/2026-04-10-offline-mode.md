# Offline Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit offline mode so players and DM can continue playing locally when the network is unavailable, with automatic merge on reconnect.

**Architecture:** A `Global.is_offline` flag gates all mutation paths (`Update_Records`, `Insert`, `Remove_Record`) to apply locally and log changes instead of sending RPCs. Local save snapshots (`user://last_sync.json`) are auto-saved on every successful sync, with a bundled default (`res://data/default_sync.json`) for first-time use. On reconnect, clients submit their offline changes log to the host before receiving the full sync.

**Tech Stack:** GDScript (Godot 4.4.1), JSON for persistence, ENet multiplayer RPCs for merge protocol.

**Spec:** `docs/superpowers/specs/2026-04-10-offline-mode-design.md`

---

### Task 1: Auto-Snapshot on Successful Sync

Save `_synced` to disk every time a client finishes initial sync from the host. This creates the local save that offline mode will use.

**Files:**
- Modify: `Singletons/Global.gd:29-31` (add snapshot functions)
- Modify: `Singletons/NetworkManager.gd:370-375` (trigger snapshot after `all_data_received`)

- [ ] **Step 1: Add `save_synced_snapshot()` to Global.gd**

Add this function near the data loading section (after line 525):

```gdscript
func save_synced_snapshot() -> void:
	var snapshot: Dictionary = {}
	for table_name in _synced.keys():
		var records: Array = []
		for rid in _synced[table_name].keys():
			records.append(_synced[table_name][rid].duplicate(true))
		snapshot[table_name] = records
	var json_str = JSON.stringify(snapshot, "\t")
	var file = FileAccess.open("user://last_sync.json", FileAccess.WRITE)
	if file == null:
		push_error("Global: Failed to save sync snapshot")
		return
	file.store_string(json_str)
	file.close()
	print("Global: Saved sync snapshot to user://last_sync.json")
```

- [ ] **Step 2: Add `load_synced_snapshot()` to Global.gd**

Add this function right after `save_synced_snapshot()`:

```gdscript
func load_synced_snapshot() -> bool:
	var path := "user://last_sync.json"
	if not FileAccess.file_exists(path):
		path = "res://data/default_sync.json"
		if not FileAccess.file_exists(path):
			push_error("Global: No sync snapshot or default found")
			return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Global: Failed to open snapshot at %s" % path)
		return false
	var text = file.get_as_text()
	file.close()

	var snapshot = JSON.parse_string(text)
	if snapshot == null or typeof(snapshot) != TYPE_DICTIONARY:
		push_error("Global: Invalid snapshot JSON")
		return false

	for table_name in snapshot.keys():
		_process_table(table_name, snapshot[table_name])

	print("Global: Loaded sync snapshot from %s" % path)
	return true
```

- [ ] **Step 3: Trigger snapshot after successful sync in NetworkManager.gd**

In `_receive_table_sync()`, after the `emit_signal("all_data_received")` call at line 375, add:

```gdscript
		Global.save_synced_snapshot()
```

- [ ] **Step 4: Verify manually**

Run the game, host on one instance, join from another. After the client finishes syncing, check that `user://last_sync.json` exists in the client's user data directory. On Windows this is typically `%APPDATA%/Godot/app_userdata/<project_name>/`.

- [ ] **Step 5: Commit**

```bash
git add Singletons/Global.gd Singletons/NetworkManager.gd
git commit -m "feat(offline): auto-snapshot _synced to disk after successful sync"
```

---

### Task 2: Offline Changes Logger

Create a module that logs all offline mutations to `user://offline_changes.json` so they can be submitted to the host on reconnect.

**Files:**
- Create: `Singletons/OfflineChanges.gd`

- [ ] **Step 1: Create OfflineChanges.gd**

Create a new autoload singleton at `Singletons/OfflineChanges.gd`:

```gdscript
extends Node
## Logs mutations made during offline mode to user://offline_changes.json.
## On reconnect, the log is submitted to the host and cleared.

const CHANGES_PATH := "user://offline_changes.json"

var _changes: Array = []

func _ready() -> void:
	_load_from_disk()

func _load_from_disk() -> void:
	if not FileAccess.file_exists(CHANGES_PATH):
		_changes = []
		return
	var file = FileAccess.open(CHANGES_PATH, FileAccess.READ)
	if file == null:
		_changes = []
		return
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	_changes = parsed if parsed is Array else []

func _save_to_disk() -> void:
	var file = FileAccess.open(CHANGES_PATH, FileAccess.WRITE)
	if file == null:
		push_error("OfflineChanges: Failed to save changes log")
		return
	file.store_string(JSON.stringify(_changes, "\t"))
	file.close()

func log_update(table: String, record_id: int, field: String, value) -> void:
	_changes.append({
		"action": "update",
		"table": table,
		"record_id": record_id,
		"field": field,
		"value": value,
		"timestamp": Time.get_datetime_string_from_system()
	})
	_save_to_disk()

func log_insert(table: String, record_id: int, record: Dictionary) -> void:
	_changes.append({
		"action": "insert",
		"table": table,
		"record_id": record_id,
		"data": record.duplicate(true),
		"timestamp": Time.get_datetime_string_from_system()
	})
	_save_to_disk()

func log_delete(table: String, record_id: int) -> void:
	_changes.append({
		"action": "delete",
		"table": table,
		"record_id": record_id,
		"timestamp": Time.get_datetime_string_from_system()
	})
	_save_to_disk()

func has_changes() -> bool:
	return _changes.size() > 0

func get_changes_json() -> String:
	return JSON.stringify(_changes)

func clear() -> void:
	_changes = []
	if FileAccess.file_exists(CHANGES_PATH):
		DirAccess.remove_absolute(CHANGES_PATH)
```

- [ ] **Step 2: Register as autoload**

In the Godot project settings (`project.godot`), add the autoload. Find the `[autoload]` section and add:

```ini
OfflineChanges="*res://Singletons/OfflineChanges.gd"
```

Make sure it loads after Global and NetworkManager in the autoload order.

- [ ] **Step 3: Commit**

```bash
git add Singletons/OfflineChanges.gd project.godot
git commit -m "feat(offline): add OfflineChanges logger singleton"
```

---

### Task 3: Offline Flag and Mutation Routing

Add the `is_offline` flag to Global and route `Update_Records`, `Insert`, and `Remove_Record` through the offline path when active.

**Files:**
- Modify: `Singletons/Global.gd:29-31` (add `is_offline` flag)
- Modify: `Singletons/Global.gd:528-538` (`Update_Records`)
- Modify: `Singletons/Global.gd:540-558` (`Insert`)
- Modify: `Singletons/Global.gd:560-566` (`Remove_Record`)

- [ ] **Step 1: Add `is_offline` flag to Global.gd**

Add after the `_synced_name` declaration (around line 31):

```gdscript
var is_offline: bool = false
```

- [ ] **Step 2: Add offline path to `Update_Records()`**

Replace the function at lines 528-538 with:

```gdscript
func Update_Records(updates: Array) -> void:
	print("Global.Update_Records: %d updates, is_host=%s, is_offline=%s" % [updates.size(), str(NetworkManager.is_host), str(is_offline)])
	if is_offline:
		for u in updates:
			_apply_update_to_save(u)
			OfflineChanges.log_update(
				str(u.get("table", "")),
				int(u.get("record_id", 0)),
				str(u.get("field", "")),
				u.get("value")
			)
		CharacterManager.recalculate_all()
		emit_signal("data_load_complete")
		return
	if NetworkManager.is_host:
		NetworkManager.host_update_records(updates)
	else:
		var json_str = JSON.stringify(updates)
		NetworkManager.request_update.rpc_id(1, json_str)
	# Apply to save data
	for u in updates:
		_apply_update_to_save(u)
	SaveManager.mark_dirty()
```

- [ ] **Step 3: Add offline path to `Insert()`**

Replace the function at lines 540-558 with:

```gdscript
func Insert(table: String, columns: Array, values: Array) -> void:
	if table.strip_edges() == "" or columns.is_empty():
		return
	if columns.size() != values.size():
		return

	if is_offline:
		var new_id = _next_offline_id(table)
		var record = {"id": new_id}
		for i in columns.size():
			record[columns[i]] = values[i]
		_insert_record(table, str(new_id), record)
		OfflineChanges.log_insert(table, new_id, record)
		var corr_id = _next_insert_corr_id
		_next_insert_corr_id = ""
		emit_signal("insert_finished", corr_id, table, new_id, record, true)
		CharacterManager.recalculate_all()
		emit_signal("data_load_complete")
		return

	var corr_id = _next_insert_corr_id
	_next_insert_corr_id = ""
	if NetworkManager.is_host:
		var new_id = NetworkManager.host_insert(table, columns, values)
		var record = {"id": new_id}
		for i in columns.size():
			record[columns[i]] = values[i]
		emit_signal("insert_finished", corr_id, table, new_id, record, true)
	else:
		var record = {}
		for i in columns.size():
			record[columns[i]] = values[i]
		var json_str = JSON.stringify(record)
		NetworkManager.request_insert.rpc_id(1, table, json_str, corr_id)
```

- [ ] **Step 4: Add `_next_offline_id()` helper to Global.gd**

Add near the `_insert_record` function (around line 742):

```gdscript
func _next_offline_id(table_name: String) -> int:
	var dict: Dictionary = _synced.get(table_name, {})
	var max_id = 0
	for key in dict.keys():
		var id_val = int(key)
		if id_val > max_id:
			max_id = id_val
	return max_id + 1
```

- [ ] **Step 5: Add offline path to `Remove_Record()`**

Replace the function at lines 560-566 with:

```gdscript
func Remove_Record(table: String, record_id: int) -> void:
	if table.strip_edges() == "":
		return
	if is_offline:
		_remove_record(table, str(record_id))
		OfflineChanges.log_delete(table, record_id)
		CharacterManager.recalculate_all()
		emit_signal("data_load_complete")
		return
	if NetworkManager.is_host:
		NetworkManager.host_remove(table, record_id)
	else:
		NetworkManager.request_remove.rpc_id(1, table, record_id)
```

- [ ] **Step 6: Commit**

```bash
git add Singletons/Global.gd
git commit -m "feat(offline): route Update_Records/Insert/Remove through offline path when is_offline"
```

---

### Task 4: Lobby "Play Offline" Button

Add the offline entry point to the lobby scene.

**Files:**
- Modify: `Scenes/lobby.gd`
- Modify: `Scenes/Lobby.tscn`

- [ ] **Step 1: Add the button to lobby.gd**

Add an `@onready` reference after line 14 (`start_button`):

```gdscript
@onready var offline_button: Button = $VBoxContainer/OfflineButton
```

- [ ] **Step 2: Add the OfflineButton node to Lobby.tscn**

Open `Scenes/Lobby.tscn` in the editor and add a new Button node named `OfflineButton` as a child of `VBoxContainer`, positioned after `JoinButton`. Set its text to `"Play Offline"`. Alternatively, add it programmatically — but the scene file approach matches the existing pattern.

If editing the `.tscn` file directly, add after the JoinButton node definition:

```
[node name="OfflineButton" type="Button" parent="VBoxContainer"]
text = "Play Offline"
```

- [ ] **Step 3: Wire the button and add handler in lobby.gd**

In `_ready()`, after line 24 (`join_button.pressed.connect...`), add:

```gdscript
	offline_button.pressed.connect(_on_offline_pressed)
```

In `_hide_all()`, add:

```gdscript
	offline_button.visible = false
```

In `_show_main_menu()`, after `join_button.visible = true`, add:

```gdscript
	offline_button.visible = true
```

- [ ] **Step 4: Add the offline button handler and offline select flow**

Add new state and handler functions. First, add `OFFLINE_SELECT` to the State enum at line 16:

```gdscript
enum State { MAIN_MENU, JOIN_SELECT, WAITING_ROOM, OFFLINE_SELECT }
```

Then add these functions:

```gdscript
func _on_offline_pressed() -> void:
	_show_offline_select()

func _show_offline_select() -> void:
	current_state = State.OFFLINE_SELECT
	_hide_all()
	back_button.visible = true
	character_list.visible = true
	status_label.text = "Select your character for offline play (or DM to manage battles)"

	character_list.clear()
	# Add DM option first
	if _dm_character != null:
		character_list.add_item("[DM] %s (Dungeon Master)" % _dm_character.get("Name", "DM"))
	for ch in _available_characters:
		character_list.add_item("%s (Lv%s %s)" % [ch.get("Name", "???"), str(ch.get("Level", "?")), str(ch.get("Element", ""))])

func _on_offline_character_selected(index: int) -> void:
	# Account for DM being at index 0 if present
	if _dm_character != null:
		if index == 0:
			Global.ACTIVE_USER_NAME = _dm_character.get("Name", "Chase")
			Global.ACTIVE_USER_RECORD_ID = _dm_character.get("id", 0)
			Global.ACTIVE_USER_TYPE = "Dungeon Master"
			Global.ACTIVE_USER_EMAIL = ""
			_enter_offline_mode()
			return
		index -= 1  # Shift for player characters

	if index < 0 or index >= _available_characters.size():
		return
	var ch = _available_characters[index]
	Global.ACTIVE_USER_NAME = ch.get("Name", "")
	Global.ACTIVE_USER_RECORD_ID = ch.get("id", 0)
	Global.ACTIVE_USER_TYPE = "Player"
	Global.ACTIVE_USER_EMAIL = ""
	_enter_offline_mode()

func _enter_offline_mode() -> void:
	Global.is_offline = true
	status_label.text = "Loading offline data..."

	if not Global.load_synced_snapshot():
		status_label.text = "No offline data available! Connect to host at least once."
		Global.is_offline = false
		return

	Global.calculate_all_stats()
	_go_to_game()
```

- [ ] **Step 5: Update `_on_character_selected` to handle offline select state**

Modify the existing `_on_character_selected` function (line 168) to delegate to the offline handler when in `OFFLINE_SELECT` state:

```gdscript
func _on_character_selected(index: int) -> void:
	if current_state == State.OFFLINE_SELECT:
		_on_offline_character_selected(index)
		return
	if index < 0 or index >= _available_characters.size():
		return
	var ch = _available_characters[index]
	Global.ACTIVE_USER_NAME = ch.get("Name", "")
	Global.ACTIVE_USER_RECORD_ID = ch.get("id", 0)
	Global.ACTIVE_USER_TYPE = "Player"
	Global.ACTIVE_USER_EMAIL = ""
	status_label.text = "Selected: %s — now pick a host or enter IP" % Global.ACTIVE_USER_NAME
```

- [ ] **Step 6: Commit**

```bash
git add Scenes/lobby.gd Scenes/Lobby.tscn
git commit -m "feat(offline): add Play Offline button and character selection flow in lobby"
```

---

### Task 5: Create Bundled Default Sync File

Export the current save state as `res://data/default_sync.json` so first-time users have data for offline mode.

**Files:**
- Create: `data/default_sync.json`
- Modify: `Singletons/Global.gd` (add export helper)

- [ ] **Step 1: Add a `_export_synced_to_file()` debug helper to Global.gd**

Add this temporary helper function (can be removed later or kept for DM use):

```gdscript
func export_synced_to_file(path: String) -> void:
	var snapshot: Dictionary = {}
	for table_name in _synced.keys():
		var records: Array = []
		for rid in _synced[table_name].keys():
			records.append(_synced[table_name][rid].duplicate(true))
		snapshot[table_name] = records
	var json_str = JSON.stringify(snapshot, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Global: Failed to export synced data to %s" % path)
		return
	file.store_string(json_str)
	file.close()
	print("Global: Exported synced data to %s" % path)
```

- [ ] **Step 2: Generate the default sync file**

After tonight's session data is loaded, run the game as host and call from the Godot debugger or a temporary button:

```gdscript
Global.export_synced_to_file("res://data/default_sync.json")
```

This writes the bundled default. The file gets committed to the repo.

- [ ] **Step 3: Verify the file loads correctly**

Test by temporarily deleting `user://last_sync.json` (if it exists) and entering offline mode from the lobby. The client should load from `res://data/default_sync.json` and display all character data.

- [ ] **Step 4: Commit**

```bash
git add data/default_sync.json Singletons/Global.gd
git commit -m "feat(offline): add bundled default sync file and export helper"
```

---

### Task 6: Offline Status Indicator in Hubs

Add a visible "Offline" label to both the player hub and DM hub when in offline mode.

**Files:**
- Modify: `Scenes/player_hub.gd:145-166` (add offline indicator and skip connection check)
- Modify: `Scenes/DMHub.gd:58+` (add offline indicator)

- [ ] **Step 1: Add offline indicator to player_hub.gd**

In `_try_initial_setup()` (line 145), replace the connection check block (lines 152-154):

```gdscript
	# Wait for connection if we're a client (skip in offline mode)
	if not Global.is_offline and not NetworkManager.is_host and not NetworkManager.is_connected_to_host:
		_show_reconnect_popup()
		return
```

Then at the end of `_try_initial_setup()`, after `_initial_setup_done = true` and `set_ui()`, add:

```gdscript
	if Global.is_offline:
		_show_offline_indicator()
```

Add the indicator function:

```gdscript
func _show_offline_indicator() -> void:
	var indicator = Label.new()
	indicator.name = "OfflineIndicator"
	indicator.text = "OFFLINE"
	indicator.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	indicator.add_theme_font_size_override("font_size", 18)
	indicator.position = Vector2(20, 20)
	add_child(indicator)
```

- [ ] **Step 2: Add offline indicator to DMHub.gd**

In `_ready()` of DMHub.gd (line 58), add at the end of the function:

```gdscript
	if Global.is_offline:
		_show_offline_indicator()
```

Add the indicator function:

```gdscript
func _show_offline_indicator() -> void:
	var indicator = Label.new()
	indicator.name = "OfflineIndicator"
	indicator.text = "OFFLINE"
	indicator.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	indicator.add_theme_font_size_override("font_size", 18)
	indicator.position = Vector2(20, 20)
	add_child(indicator)
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/player_hub.gd Scenes/DMHub.gd
git commit -m "feat(offline): add OFFLINE status indicator to player and DM hubs"
```

---

### Task 7: Disable Combat Button for Players in Offline Mode

Hide/disable the combat and turn order button in the player hub when offline.

**Files:**
- Modify: `Scenes/player_hub.gd`

- [ ] **Step 1: Find the combat/turn order button reference**

Search `player_hub.gd` for the combat or turn order button reference. It will be an `@onready var` referencing a Button node. This button needs to be disabled when `Global.is_offline` is true.

- [ ] **Step 2: Disable the button in `_try_initial_setup()` or `set_ui()`**

After the offline indicator is shown, add:

```gdscript
	if Global.is_offline:
		# Disable combat/turn order — DM manages all combat
		if <combat_button_reference> != null:
			<combat_button_reference>.visible = false
```

Replace `<combat_button_reference>` with the actual variable name found in Step 1.

- [ ] **Step 3: Verify the button is hidden in offline mode**

Run the game, enter offline mode as a player, confirm the combat/turn order button is not visible.

- [ ] **Step 4: Commit**

```bash
git add Scenes/player_hub.gd
git commit -m "feat(offline): hide combat button for players in offline mode"
```

---

### Task 8: Disable DM Hub First Tab in Offline Mode

Disable the PartyManagement (item management) tab in the DM Hub when offline.

**Files:**
- Modify: `Scenes/DMHub.gd:58+`

- [ ] **Step 1: Disable the PartyManagement tab**

The DM Hub uses a TabContainer at path `$Layout/MainSplit/Tabs`. In `_ready()`, after the offline indicator setup, add:

```gdscript
	if Global.is_offline:
		# Disable item management tab — players self-manage in offline mode
		var tabs = $Layout/MainSplit/Tabs
		tabs.set_tab_disabled(0, true)
		tabs.set_tab_title(0, "Party Management (Disabled Offline)")
		# Default to BattlePrep tab
		tabs.current_tab = 1
```

- [ ] **Step 2: Verify**

Run the game, enter offline mode as DM, confirm the first tab is greyed out and the BattlePrep tab is selected by default.

- [ ] **Step 3: Commit**

```bash
git add Scenes/DMHub.gd
git commit -m "feat(offline): disable party management tab for DM in offline mode"
```

---

### Task 9: Player Offline Management Sub-Panel

Create a new panel that gives players self-service control over their character's inventory in offline mode (add/remove weapons, artifacts, items, edit mora).

**Files:**
- Create: `Scenes/UI/offline_management_panel.gd`
- Create: `Scenes/UI/offline_management_panel.tscn`
- Modify: `Scenes/player_hub.gd` (add panel when offline)

- [ ] **Step 1: Create the management panel script**

Create `Scenes/UI/offline_management_panel.gd`:

```gdscript
extends PanelContainer
## Offline-only panel for players to add/remove weapons, artifacts, items, and edit mora.
## Mirrors the DM Hub's first tab but scoped to the active player's character only.

signal panel_closed

var _category_btn: OptionButton
var _item_list: ItemList
var _search_field: LineEdit
var _add_btn: Button
var _remove_btn: Button
var _mora_spin: SpinBox
var _mora_btn: Button
var _close_btn: Button

var _current_category: String = "Weapons"
var _filtered_items: Array = []  # GameDB items matching current search
var _owned_items: Array = []     # Items owned by this player in _synced
var _player_rid: int = 0

func _ready() -> void:
	_player_rid = Global.ACTIVE_USER_RECORD_ID
	_build_ui()
	_refresh_owned_list()

func _build_ui() -> void:
	custom_minimum_size = Vector2(500, 600)

	var vbox = VBoxContainer.new()
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Offline Inventory Management"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Category selector
	var cat_hbox = HBoxContainer.new()
	vbox.add_child(cat_hbox)
	var cat_label = Label.new()
	cat_label.text = "Category:"
	cat_hbox.add_child(cat_label)
	_category_btn = OptionButton.new()
	_category_btn.add_item("Weapons")
	_category_btn.add_item("Artifacts")
	_category_btn.add_item("Items")
	_category_btn.item_selected.connect(_on_category_changed)
	cat_hbox.add_child(_category_btn)

	# Search field
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Search..."
	_search_field.text_changed.connect(_on_search_changed)
	vbox.add_child(_search_field)

	# Split: available (left) and owned (right)
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)

	# Available items from GameDB
	var avail_vbox = VBoxContainer.new()
	split.add_child(avail_vbox)
	var avail_label = Label.new()
	avail_label.text = "Available"
	avail_vbox.add_child(avail_label)
	var avail_list = ItemList.new()
	avail_list.name = "AvailableList"
	avail_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	avail_vbox.add_child(avail_list)

	# Owned items
	var own_vbox = VBoxContainer.new()
	split.add_child(own_vbox)
	var own_label = Label.new()
	own_label.text = "Owned"
	own_vbox.add_child(own_label)
	_item_list = ItemList.new()
	_item_list.name = "OwnedList"
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	own_vbox.add_child(_item_list)

	# Add/Remove buttons
	var btn_hbox = HBoxContainer.new()
	vbox.add_child(btn_hbox)
	_add_btn = Button.new()
	_add_btn.text = "Add Selected"
	_add_btn.pressed.connect(_on_add_pressed)
	btn_hbox.add_child(_add_btn)
	_remove_btn = Button.new()
	_remove_btn.text = "Remove Selected"
	_remove_btn.pressed.connect(_on_remove_pressed)
	btn_hbox.add_child(_remove_btn)

	# Mora editor
	var mora_hbox = HBoxContainer.new()
	vbox.add_child(mora_hbox)
	var mora_label = Label.new()
	mora_label.text = "Mora:"
	mora_hbox.add_child(mora_label)
	_mora_spin = SpinBox.new()
	_mora_spin.max_value = 999999
	_mora_spin.step = 100
	# Load current mora from Party record
	var party = Global.Current_Party
	_mora_spin.value = int(party.get("Mora", 0)) if party else 0
	mora_hbox.add_child(_mora_spin)
	_mora_btn = Button.new()
	_mora_btn.text = "Set Mora"
	_mora_btn.pressed.connect(_on_set_mora)
	mora_hbox.add_child(_mora_btn)

	# Close button
	_close_btn = Button.new()
	_close_btn.text = "Close"
	_close_btn.pressed.connect(func(): panel_closed.emit(); queue_free())
	vbox.add_child(_close_btn)

func _get_available_list() -> ItemList:
	return get_node("VBoxContainer/HSplitContainer/VBoxContainer/AvailableList") if has_node("VBoxContainer/HSplitContainer/VBoxContainer/AvailableList") else null

func _on_category_changed(index: int) -> void:
	_current_category = _category_btn.get_item_text(index)
	_search_field.text = ""
	_refresh_available_list("")
	_refresh_owned_list()

func _on_search_changed(text: String) -> void:
	_refresh_available_list(text)

func _refresh_available_list(search: String) -> void:
	_filtered_items.clear()
	# GameDB stores static data as Dictionary properties: GameDB.weapons, GameDB.items, GameDB.artifact_sets
	# Each is { int_id: TypedResource, ... }. Resources have a .name property.
	var source_dict: Dictionary = {}
	match _current_category:
		"Weapons":
			source_dict = GameDB.weapons
		"Artifacts":
			source_dict = GameDB.artifact_sets
		"Items":
			source_dict = GameDB.items

	for id in source_dict.keys():
		var res = source_dict[id]
		var item_name = str(res.name) if res.has_method("get") == false else str(res.get("Name", ""))
		# Try .name property (typed Resource) or dict key
		if "name" in res:
			item_name = str(res.name)
		elif res is Dictionary and res.has("Name"):
			item_name = str(res["Name"])
		if search == "" or search.to_lower() in item_name.to_lower():
			_filtered_items.append({"id": id, "Name": item_name, "_resource": res})

	# Update available list UI
	var avail_list = _find_available_list()
	if avail_list:
		avail_list.clear()
		for item in _filtered_items:
			avail_list.add_item(item["Name"])

func _find_available_list() -> ItemList:
	# Find the AvailableList node in the tree
	for child in get_children():
		if child is VBoxContainer:
			for subchild in child.get_children():
				if subchild is HSplitContainer:
					var first_vbox = subchild.get_child(0)
					if first_vbox is VBoxContainer:
						for node in first_vbox.get_children():
							if node is ItemList:
								return node
	return null

func _refresh_owned_list() -> void:
	_owned_items.clear()
	var table_name = _synced_table_for_category()
	var synced_table = Global._synced.get(table_name, {})
	for rid in synced_table.keys():
		var record = synced_table[rid]
		# Filter to only this player's items
		var owner_id = int(record.get("Owner", record.get("Character_Id", 0)))
		if owner_id == _player_rid:
			_owned_items.append(record)

	_item_list.clear()
	for item in _owned_items:
		var display = str(item.get("Name", "Item #%s" % str(item.get("id", "?"))))
		if item.has("Equipped") and item["Equipped"]:
			display += " [E]"
		_item_list.add_item(display)

func _synced_table_for_category() -> String:
	match _current_category:
		"Weapons": return "Character_Weapons"
		"Artifacts": return "Character_Artifacts"
		"Items": return "Character_Items"
	return ""

func _on_add_pressed() -> void:
	var avail_list = _find_available_list()
	if avail_list == null or not avail_list.is_anything_selected():
		return
	var selected_indices = avail_list.get_selected_items()
	if selected_indices.is_empty():
		return
	var idx = selected_indices[0]
	if idx >= _filtered_items.size():
		return

	var source_item = _filtered_items[idx]
	var table = _synced_table_for_category()
	var columns: Array = []
	var values: Array = []

	match _current_category:
		"Weapons":
			columns = ["Name", "Owner", "Equipped", "Refinement"]
			values = [source_item.get("Name", ""), _player_rid, false, 1]
		"Artifacts":
			columns = ["Name", "Owner", "Equipped", "Set_Name"]
			values = [source_item.get("Name", ""), _player_rid, false, source_item.get("Set_Name", "")]
		"Items":
			columns = ["Name", "Owner", "Quantity"]
			values = [source_item.get("Name", ""), _player_rid, 1]

	Global.Insert(table, columns, values)
	_refresh_owned_list()

func _on_remove_pressed() -> void:
	if not _item_list.is_anything_selected():
		return
	var selected_indices = _item_list.get_selected_items()
	if selected_indices.is_empty():
		return
	var idx = selected_indices[0]
	if idx >= _owned_items.size():
		return

	var record = _owned_items[idx]
	var table = _synced_table_for_category()
	Global.Remove_Record(table, int(record.get("id", 0)))
	_refresh_owned_list()

func _on_set_mora() -> void:
	var party = Global.Current_Party
	if party == null or not party.has("id"):
		return
	Global.Update_Records([{
		"table": "Party",
		"record_id": int(party["id"]),
		"field": "Mora",
		"value": int(_mora_spin.value)
	}])
```

- [ ] **Step 2: Create the scene file**

Create `Scenes/UI/offline_management_panel.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://Scenes/UI/offline_management_panel.gd" id="1"]

[node name="OfflineManagementPanel" type="PanelContainer"]
script = ExtResource("1")
```

- [ ] **Step 3: Add the panel to player_hub.gd in offline mode**

In `_try_initial_setup()`, after the offline indicator, add a button to open the management panel:

```gdscript
	if Global.is_offline:
		_add_offline_management_button()
```

Add the function:

```gdscript
func _add_offline_management_button() -> void:
	var btn = Button.new()
	btn.name = "OfflineManageBtn"
	btn.text = "Manage Inventory"
	btn.position = Vector2(20, 50)
	btn.pressed.connect(_open_offline_management)
	add_child(btn)

func _open_offline_management() -> void:
	if has_node("OfflineManagementPanel"):
		return  # Already open
	var panel = preload("res://Scenes/UI/offline_management_panel.tscn").instantiate()
	panel.position = Vector2(200, 100)
	panel.panel_closed.connect(func(): pass)  # Cleanup handled by queue_free in panel
	add_child(panel)
```

- [ ] **Step 4: Verify**

Run the game in offline mode as a player. Open the management panel. Add a weapon, remove an item, change mora. Confirm changes appear in `user://offline_changes.json`.

- [ ] **Step 5: Commit**

```bash
git add Scenes/UI/offline_management_panel.gd Scenes/UI/offline_management_panel.tscn Scenes/player_hub.gd
git commit -m "feat(offline): add player self-service inventory management panel"
```

---

### Task 10: Merge Protocol — Client Submits Offline Changes

Add RPCs so clients can submit their offline changes to the host on reconnect, and the host applies them before sending the full sync.

**Files:**
- Modify: `Singletons/NetworkManager.gd` (add submit/ack RPCs)
- Modify: `Singletons/NetworkManager.gd:306-332` (modify registration flow)

- [ ] **Step 1: Add the submit RPC (client → host)**

Add to NetworkManager.gd:

```gdscript
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

	for change in changes:
		var action = str(change.get("action", ""))
		var table = str(change.get("table", ""))
		match action:
			"update":
				var record_id = str(int(change.get("record_id", 0)))
				var field = str(change.get("field", ""))
				var value = change.get("value")
				Global._apply_local_update(table, record_id, field, value)
				DataStore.persist_table(table)
			"insert":
				var data = change.get("data", {})
				var new_id = _next_id_for_table(table)
				data["id"] = new_id
				Global._insert_record(table, str(new_id), data)
				DataStore.persist_table(table)
			"delete":
				var record_id = str(int(change.get("record_id", 0)))
				Global._remove_record(table, record_id)
				DataStore.persist_table(table)

	Toast.notify("Applied offline changes from %s" % player_name, Toast.SUCCESS)
	_ack_offline_changes.rpc_id(sender, true)
```

- [ ] **Step 2: Add the ack RPC (host → client)**

Add to NetworkManager.gd:

```gdscript
@rpc("authority", "reliable")
func _ack_offline_changes(success: bool) -> void:
	if success:
		print("NetworkManager: Host acknowledged offline changes — clearing local log")
		OfflineChanges.clear()
		Toast.notify("Offline changes merged successfully", Toast.SUCCESS)
	else:
		Toast.notify("Failed to merge offline changes", Toast.ERROR)
```

- [ ] **Step 3: Modify `_on_connection_succeeded` to submit changes before sync**

In `NetworkManager.gd`, find the `_on_connection_succeeded` signal handler. The client needs to submit offline changes right after connecting, before receiving the full sync. Modify the connection flow:

Add to the connection succeeded handler (or create one if it's in lobby.gd):

```gdscript
func _on_peer_connected_as_client() -> void:
	is_connected_to_host = true
	# Submit offline changes before registration if they exist
	if OfflineChanges.has_changes():
		print("NetworkManager: Submitting offline changes to host")
		_submit_offline_changes.rpc_id(1, Global.ACTIVE_USER_NAME, OfflineChanges.get_changes_json())
```

- [ ] **Step 4: Clear offline mode flag on successful reconnect**

After the client receives the full sync (`all_data_received` signal), reset the offline flag:

In the `_receive_table_sync` function, after `emit_signal("all_data_received")` and the snapshot save, add:

```gdscript
		if Global.is_offline:
			Global.is_offline = false
			print("NetworkManager: Exited offline mode after successful sync")
```

- [ ] **Step 5: Commit**

```bash
git add Singletons/NetworkManager.gd
git commit -m "feat(offline): add merge protocol — client submits changes, host applies and acks"
```

---

### Task 11: Disconnect Returns to Lobby

When a client loses connection mid-session and reconnect fails, return to the lobby instead of showing a reconnect popup forever.

**Files:**
- Modify: `Singletons/NetworkManager.gd:279-302` (change disconnect behavior)
- Modify: `Scenes/player_hub.gd:177-199` (remove reconnect popup)

- [ ] **Step 1: Modify `_attempt_reconnect()` to return to lobby on failure**

Replace the end of `_attempt_reconnect()` (after the for loop) with:

```gdscript
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
```

- [ ] **Step 2: Remove reconnect popup from player_hub.gd**

In `_try_initial_setup()`, the reconnect popup block is no longer needed since disconnects return to the lobby. The `Global.is_offline` check added in Task 6 already handles the offline case. The existing connection check (modified in Task 6) handles the online-but-not-connected case by returning early — but now that should also return to lobby:

```gdscript
	if not Global.is_offline and not NetworkManager.is_host and not NetworkManager.is_connected_to_host:
		# Not connected — return to lobby to reconnect or go offline
		get_tree().change_scene_to_file("res://Scenes/Lobby.tscn")
		return
```

Remove the `_show_reconnect_popup()` and `_poll_reconnect()` functions since they're no longer used.

- [ ] **Step 3: Commit**

```bash
git add Singletons/NetworkManager.gd Scenes/player_hub.gd
git commit -m "feat(offline): return to lobby on disconnect instead of reconnect popup"
```

---

### Task 12: Region Editing in Offline Mode

Allow players to update their region locally in offline mode.

**Files:**
- Modify: `Scenes/player_hub.gd` (region is likely already editable via existing UI — verify and ensure it routes through `Update_Records`)

- [ ] **Step 1: Verify region editing flow**

Check how region is currently set in the player hub. Search for `Current_Region` or `Region` references. If region changes already go through `Global.Update_Records()`, they will automatically work offline via the Task 3 changes.

- [ ] **Step 2: If region editing doesn't exist in player hub, add it**

If there's no existing region selector, add one to the offline management panel or as a separate dropdown in the hub:

```gdscript
# In offline_management_panel.gd _build_ui(), add after mora section:
	var region_hbox = HBoxContainer.new()
	vbox.add_child(region_hbox)
	var region_label = Label.new()
	region_label.text = "Region:"
	region_hbox.add_child(region_label)
	var region_btn = OptionButton.new()
	for r in ["Mondstadt", "Liyue", "Inazuma", "Sumeru", "Fontaine", "Natlan", "Snezhnaya"]:
		region_btn.add_item(r)
	# Set current region
	var current = Global.Current_Region
	for i in region_btn.item_count:
		if region_btn.get_item_text(i) == current:
			region_btn.selected = i
			break
	region_btn.item_selected.connect(func(idx):
		var new_region = region_btn.get_item_text(idx)
		var char_rid = Global.ACTIVE_USER_RECORD_ID
		Global.Update_Records([{"table": "Characters", "record_id": char_rid, "field": "Region", "value": new_region}])
		Global.Current_Region = new_region
	)
	region_hbox.add_child(region_btn)
```

- [ ] **Step 3: Commit**

```bash
git add Scenes/player_hub.gd Scenes/UI/offline_management_panel.gd
git commit -m "feat(offline): add region editing for players in offline mode"
```

---

### Task 13: Integration Test — Full Offline Flow

End-to-end verification of the complete offline mode flow.

**Files:** None (manual testing)

- [ ] **Step 1: Test player offline flow**

1. Launch the game
2. Click "Play Offline" in lobby
3. Select a player character
4. Verify hub loads with character data and "OFFLINE" indicator
5. Verify combat button is hidden
6. Open management panel, add a weapon, remove an item, set mora
7. Change region
8. Close the game

- [ ] **Step 2: Verify offline changes persisted**

1. Relaunch the game
2. Enter offline mode again as the same character
3. Verify the weapon added in Step 1 is still there
4. Check `user://offline_changes.json` contains all mutations

- [ ] **Step 3: Test DM offline flow**

1. Launch the game
2. Click "Play Offline" in lobby
3. Select the DM character
4. Verify DM Hub loads with "OFFLINE" indicator
5. Verify first tab (Party Management) is disabled
6. Verify BattlePrep tab works — add an enemy
7. Verify Data Editor tab works

- [ ] **Step 4: Test merge on reconnect**

1. Launch host instance normally
2. Launch client that has offline changes
3. Client joins host — verify offline changes are submitted
4. Verify host applies changes (check toast notification)
5. Verify client receives full sync with merged data
6. Verify `user://offline_changes.json` is cleared on client

- [ ] **Step 5: Test disconnect → lobby flow**

1. Host and client connected
2. Kill the host process
3. Verify client attempts reconnect then returns to lobby
4. From lobby, client can choose "Play Offline" or try to reconnect

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "fix(offline): integration test fixes"
```
