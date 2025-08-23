# res://Singletons/ResearchAPI.gd (Godot 4.4.1)
extends Node

var base_url: String = Global.API_BASE  # set this once on startup, e.g. from Global.API_BASE_URL

func start(session_id: String, duration_sec: int) -> void:
	var url = "%s/dm/research/start" % base_url
	var body = {"session_id": session_id, "duration_sec": duration_sec}
	_post(url, body)

func push_text(session_id: String, text: String) -> void:
	var url = "%s/dm/research/push" % base_url
	var body = {"session_id": session_id, "kind": "text", "text": text}
	_post(url, body)

func push_image(session_id: String, url_str: String, caption: String) -> void:
	var url = "%s/dm/research/push" % base_url
	var body = {"session_id": session_id, "kind": "image", "url": url_str, "caption": caption}
	_post(url, body)

func create_session(on_done: Callable) -> void:
	var url = "%s/dm/research/create" % base_url
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, b):
		var data := {}
		if code == 200:
			data = JSON.parse_string(b.get_string_from_utf8())
		on_done.call(data)
		http.queue_free()
	, CONNECT_ONE_SHOT)
	var headers := PackedStringArray(["Content-Type: application/json"])
	http.request(url, headers, HTTPClient.METHOD_POST, "{}")

func fetch_current(on_done: Callable) -> void:
	var url = "%s/research/current" % base_url
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, b):
		var data := {}
		if code == 200:
			data = JSON.parse_string(b.get_string_from_utf8())
		on_done.call(code, data)
		http.queue_free()
	, CONNECT_ONE_SHOT)
	http.request(url)

func end(session_id: String) -> void:
	var url = "%s/dm/research/end" % base_url
	var body = {"session_id": session_id}
	_post(url, body)

func fetch_state(session_id: String, on_done: Callable) -> void:
	var url = "%s/research/session?session_id=%s" % [base_url, session_id]
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, b):
		var data: Dictionary = {}
		if code == 200:
			data = JSON.parse_string(b.get_string_from_utf8())
		_safe_callv(on_done, [data])  # ← guard against freed targets
		http.queue_free()
	, CONNECT_ONE_SHOT)
	http.request(url)

func _safe_callv(cb: Callable, args: Array) -> void:
	if cb.is_valid():
		cb.callv(args)

func _post(url: String, body: Dictionary) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var json := JSON.stringify(body)
	req.request(url, headers, HTTPClient.METHOD_POST, json)
	req.request_completed.connect(func(_r, _c, _h, _b): req.queue_free(), CONNECT_ONE_SHOT)
