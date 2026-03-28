# res://Singletons/ResearchAPI.gd (Godot 4.4.1)
# Research system — now uses local JSON via DataStore + NetworkManager instead of HTTP.
extends Node

var _sessions: Array = []
var _current_session_id: String = ""

func _load_sessions() -> Array:
	return DataStore.load_table("research_sessions")

func _save_sessions(sessions: Array) -> void:
	if NetworkManager.is_host:
		DataStore.save_table("research_sessions", sessions)

func create_session(on_done: Callable) -> void:
	var sessions := _load_sessions()
	var session_id := str(Time.get_unix_time_from_system())
	var session := {
		"session_id": session_id,
		"started_at": null,
		"duration_sec": null,
		"is_active": false,
		"version": 0,
		"state": {"items": []},
		"created_at": Time.get_datetime_string_from_system(),
		"closed_at": null
	}
	sessions.append(session)
	_save_sessions(sessions)
	on_done.call(session)

func start(session_id: String, duration_sec: int) -> void:
	var sessions := _load_sessions()
	for s in sessions:
		if str(s.get("session_id")) == session_id:
			s["started_at"] = Time.get_datetime_string_from_system()
			s["duration_sec"] = duration_sec
			s["is_active"] = true
			break
	_save_sessions(sessions)

func push_text(session_id: String, text: String) -> void:
	var sessions := _load_sessions()
	for s in sessions:
		if str(s.get("session_id")) == session_id:
			var state = s.get("state", {"items": []})
			if typeof(state) == TYPE_STRING:
				state = JSON.parse_string(state)
			if state == null:
				state = {"items": []}
			var items: Array = state.get("items", [])
			items.append({"kind": "text", "text": text})
			state["items"] = items
			s["state"] = state
			s["version"] = s.get("version", 0) + 1
			break
	_save_sessions(sessions)

func push_image(session_id: String, url_str: String, caption: String) -> void:
	var sessions := _load_sessions()
	for s in sessions:
		if str(s.get("session_id")) == session_id:
			var state = s.get("state", {"items": []})
			if typeof(state) == TYPE_STRING:
				state = JSON.parse_string(state)
			if state == null:
				state = {"items": []}
			var items: Array = state.get("items", [])
			items.append({"kind": "image", "url": url_str, "caption": caption})
			state["items"] = items
			s["state"] = state
			s["version"] = s.get("version", 0) + 1
			break
	_save_sessions(sessions)

func end(session_id: String) -> void:
	var sessions := _load_sessions()
	for s in sessions:
		if str(s.get("session_id")) == session_id:
			s["is_active"] = false
			s["closed_at"] = Time.get_datetime_string_from_system()
			break
	_save_sessions(sessions)

func fetch_current(on_done: Callable) -> void:
	var sessions := _load_sessions()
	var current := {}
	for s in sessions:
		if s.get("is_active") == true:
			current = s
			break
	on_done.call(200, current)

func fetch_state(session_id: String, on_done: Callable) -> void:
	var sessions := _load_sessions()
	for s in sessions:
		if str(s.get("session_id")) == session_id:
			_safe_callv(on_done, [s])
			return
	_safe_callv(on_done, [{}])

func _safe_callv(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)
