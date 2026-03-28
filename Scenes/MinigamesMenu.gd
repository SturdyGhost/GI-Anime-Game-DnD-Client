extends Control

func _ready() -> void:
	$Panel/VBoxContainer/KleeFishBlastButton.pressed.connect(_on_klee_fish_blast)
	$Panel/VBoxContainer/CloseButton.pressed.connect(_on_close)

func _on_klee_fish_blast() -> void:
	if not ResourceLoader.exists("res://Scenes/KleeFishBlast.tscn"):
		push_warning("[MINIGAMES] KleeFishBlast.tscn not found")
		return
	var s: PackedScene = load("res://Scenes/KleeFishBlast.tscn")
	var dlg = s.instantiate()

	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO

	win.add_child(dlg)
	get_parent().get_parent().add_child(win)  # add to scene tree above the menu

	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)

func _on_close() -> void:
	# Close the window containing this menu
	var win = get_parent()
	while win and not (win is Window):
		win = win.get_parent()
	if win and win is Window:
		win.queue_free()
