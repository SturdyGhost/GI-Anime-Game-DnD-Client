@tool
extends EditorPlugin

const CONTENT = "Control/PanelContainer/Contents/"

const popup_scene: PackedScene = preload("res://addons/Iconify/Iconify.tscn")
var canvas: CanvasLayer
var popup: Control
var overlay: ColorRect

var icons: Array

var icon_rect: TextureRect
var node_input: LineEdit
var property_input: OptionButton

var apply_button: Button
var cancel_button: Button

var selected: TextureRect
var icon_grid: GridContainer
var new_icon_rect: TextureRect
var new_icon_name: LineEdit

func _enter_tree() -> void:
	# Tool menu
	add_tool_menu_item("Iconify", Callable(self, "iconify"))
	add_tool_menu_item("Icon Browser", Callable(self, "iconify_view_only"))

	# Custom CanvasLayer / popup
	canvas = popup_scene.instantiate()
	overlay = canvas.get_node("ColorRect")
	popup = canvas.get_node("Control")
	popup.theme = get_editor_interface().get_base_control().theme

	icon_rect = canvas.get_node(CONTENT + "TargetNodeInput/InputDivider/TextureRect")
	node_input = canvas.get_node(CONTENT + "TargetNodeInput/InputDivider/LineEdit")
	property_input = canvas.get_node(CONTENT + "TargetPropertyInput/OptionButton")
	icon_grid = canvas.get_node(CONTENT + "IconInput/ScrollContainer/IconGrid")
	new_icon_rect = canvas.get_node(CONTENT + "IconInput/InputDivider/TextureRect")
	new_icon_name = canvas.get_node(CONTENT + "IconInput/InputDivider/LineEdit")
	cancel_button = canvas.get_node(CONTENT + "HBoxContainer/Cancel")
	apply_button = canvas.get_node(CONTENT + "HBoxContainer/Apply")

	icons = Array(get_editor_interface().get_base_control().theme.get_icon_list("EditorIcons"))
	icons.sort()

	for ic in icons:
		var icr := TextureRect.new()
		var ici: Texture2D = get_icon(ic)
		if ici.get_size() != Vector2(16, 16):
			var im := ImageTexture.new()
			var dat := ici.get_image()
			dat.resize(16, 16, Image.INTERPOLATE_LANCZOS)
			im.create_from_image(dat)
			icr.texture = im
		else:
			icr.texture = ici

		icr.hint_tooltip = ic
		icr.gui_input.connect(Callable(self, "icon_input").bind(icr))
		icon_grid.add_child(icr)

	node_input.text_changed.connect(Callable(self, "iconify_update"))
	property_input.item_selected.connect(Callable(self, "iconify_update"))
	new_icon_name.text_changed.connect(Callable(self, "iconify_search_update"))
	apply_button.pressed.connect(Callable(self, "apply"))
	cancel_button.pressed.connect(Callable(popup, "hide"))
	cancel_button.pressed.connect(Callable(overlay, "hide"))

	iconify_update()
	get_editor_interface().get_editor_viewport().add_child(canvas)

	# Panel style override (Godot 4 theme API)
	var panel := popup.get_node("PanelContainer") as PanelContainer
	panel.add_theme_stylebox_override(
		"panel",
		panel.get_theme_stylebox("panel", "Window")
	)

	hide_popup()


func icon_input(event: InputEvent, icon: TextureRect) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected = icon
			iconify_update()


func iconify(_d = null) -> void:
	var sel := get_editor_interface().get_selection()
	var selected_nodes: Array = sel.get_selected_nodes()
	if selected_nodes.size() > 0:
		var selected_node: Node = selected_nodes[0]
		var selected_node_path: NodePath = selected_node.get_path()
		var properties: Array = selected_node.get_property_list()

		icon_rect.texture = get_icon(selected_node.get_class())
		node_input.text = String(selected_node_path)

		property_input.clear()
		for p in properties:
			# Godot 4 uses "Texture2D"
			if "class_name" in p and p["class_name"] == "Texture2D":
				property_input.add_item(p.name)

		if property_input.get_item_count() == 0:
			show_error(
				"Error",
				"No texture properties found on selected node. If you just want to search for icons use Ctrl+I."
			)
		else:
			show_input(true)
			show_popup()
			iconify_update()
	else:
		show_error(
			"Error",
			"Please select a node before using Iconify. If you just want to search for icons use Ctrl+I."
		)


func iconify_view_only(_d = null) -> void:
	show_input(false)
	show_popup()


func iconify_search_update(new_text: String) -> void:
	if new_text.is_empty():
		for ic in icon_grid.get_children():
			ic.visible = true
	else:
		for ic in icon_grid.get_children():
			ic.visible = new_text.is_subsequence_ofn(ic.hint_tooltip)


# Null args to fit signal signatures
func iconify_update(_d = null, _d2 = null, _d3 = null) -> void:
	apply_button.disabled = \
		(property_input.get_item_count() == 0) or \
		(node_input.text.length() == 0) or \
		(selected == null)

	if selected == null:
		new_icon_rect.visible = false
	else:
		new_icon_rect.visible = true
		new_icon_rect.texture = selected.texture
		new_icon_name.text = selected.hint_tooltip


func apply() -> void:
	var target_path := NodePath(node_input.text)
	var target := get_node_or_null(target_path)
	if target:
		target.set(
			property_input.get_item_text(property_input.selected),
			get_icon(new_icon_name.text)
		)
	hide_popup()


func show_error(error_title: String, error_content: String) -> void:
	var p := AcceptDialog.new()
	p.title = error_title
	p.dialog_text = error_content
	p.exclusive = true
	p.canceled.connect(Callable(p, "queue_free"))
	p.confirmed.connect(Callable(p, "queue_free"))
	popup.add_child(p)
	p.popup_centered()


func get_icon(icon_name: String) -> Texture2D:
	return get_editor_interface().get_base_control().theme.get_icon(icon_name, "EditorIcons")


func show_input(target: bool) -> void:
	canvas.get_node(CONTENT + "TargetNodeInput").visible = target
	canvas.get_node(CONTENT + "TargetPropertyInput").visible = target
	if target:
		cancel_button.size_flags_horizontal = Control.SIZE_FILL
	else:
		cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_button.visible = target
	apply_button.disabled = not target


func show_popup() -> void:
	new_icon_name.grab_focus()
	popup.show()
	overlay.show()


func hide_popup() -> void:
	popup.hide()
	overlay.hide()


func _exit_tree() -> void:
	if canvas:
		canvas.queue_free()
	remove_tool_menu_item("Iconify")
	remove_tool_menu_item("Icon Browser")


# Shortcuts
func _unhandled_input(event: InputEvent) -> void:
	if not canvas:
		return

	if event is InputEventKey:
		if event.ctrl_pressed and event.pressed and not event.echo and event.keycode == KEY_I:
			if event.shift_pressed:
				iconify(null)
			else:
				iconify_view_only()

		if popup.visible:
			if event.pressed and event.keycode == KEY_ESCAPE:
				hide_popup()
			if event.pressed and event.keycode == KEY_ENTER and not apply_button.disabled and apply_button.visible:
				apply()
