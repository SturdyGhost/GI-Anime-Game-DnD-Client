# res://ui/research/ResearchDMPanel.gd
extends Control
class_name ResearchDMPanel

var session_id: String = ""

@onready var session_label: Label = $Margin/VBox/Row1/SessionLabel
@onready var duration: SpinBox = $Margin/VBox/Row1/Duration
@onready var start_btn: Button = $Margin/VBox/Row1/StartBtn
@onready var push_text_edit: TextEdit = $Margin/VBox/Row2/PushTextEdit
@onready var push_text_btn: Button = $Margin/VBox/Row2/PushTextBtn
@onready var image_url: LineEdit = $Margin/VBox/Row3/ImageUrl
@onready var image_caption: LineEdit = $Margin/VBox/Row3/ImageCaption
@onready var push_image_btn: Button = $Margin/VBox/Row3/PushImageBtn
@onready var end_btn: Button = $Margin/VBox/EndBtn

func _ready() -> void:
	session_label.text = "Session: (creating…)"
	start_btn.disabled = true
	push_text_btn.disabled = true
	push_image_btn.disabled = true
	end_btn.disabled = true

	duration.min_value = 10
	duration.max_value = 3600
	duration.step = 5
	duration.value = 30

	start_btn.pressed.connect(_on_start)
	push_text_btn.pressed.connect(_on_push_text)
	push_image_btn.pressed.connect(_on_push_image)
	end_btn.pressed.connect(_on_end)

	# Auto-create a fresh session on open
	ResearchAPI.create_session(func(data):
		if data.get("ok", false):
			session_id = str(data.get("session_id", ""))
			session_label.text = "Session: %s" % session_id
			start_btn.disabled = false
			push_text_btn.disabled = false
			push_image_btn.disabled = false
			end_btn.disabled = false
		else:
			session_label.text = "Session: (failed to create)"
	)

func _on_start() -> void:
	if session_id == "":
		return
	ResearchAPI.start(session_id, int(duration.value))

func _on_push_text() -> void:
	if session_id == "":
		return
	var txt = push_text_edit.text.strip_edges()
	if txt == "":
		return
	ResearchAPI.push_text(session_id, txt)
	push_text_edit.text = ""

func _on_push_image() -> void:
	if session_id == "":
		return
	var url = image_url.text.strip_edges()
	if url == "":
		return
	var cap = image_caption.text.strip_edges()
	ResearchAPI.push_image(session_id, url, cap)
	image_url.text = ""
	image_caption.text = ""

func _on_end() -> void:
	if session_id == "":
		return
	ResearchAPI.end(session_id)
