extends Control

# ============================================================
# CraftingMenu — full-screen crafting popup (all UI built in code)
# Godot 4.4 — uses `=` not `:=`
# ============================================================

# --- COLORS (exact) ---
const BG = Color(0.102, 0.122, 0.169)
const PANEL = Color(0.133, 0.157, 0.22)
const CARD = Color(0.165, 0.192, 0.27)
const INSET = Color(0.086, 0.106, 0.149)
const HOVER = Color(0.188, 0.227, 0.322)
const BORDER = Color(0.227, 0.259, 0.376)
const TEXT = Color(0.941, 0.949, 0.973)
const SEC = Color(0.69, 0.722, 0.8)
const MUTED = Color(0.471, 0.51, 0.627)
const ACCENT = Color(0.788, 0.659, 0.298)
const GREEN = Color(0.292, 0.855, 0.498)
const RED = Color(0.937, 0.267, 0.267)

# --- STATE ---
var _grouped_recipes = {}        # product_name -> { meta:{}, requirements:[] }
var _visible_products = []       # Array[String]
var _selected_product = ""
var _slot_to_item_id = {}        # slot_idx -> inventory item Id
var _slot_requirements = []      # current product requirements array
var _inventory_snapshot_before = {}

# --- UI REFS (set in _ready) ---
var search_input: LineEdit
var _craft_filter: String = "all"
var _filter_chips: Array = []
var _body_split: HSplitContainer
var _right_split: VSplitContainer
var _tab_recipes: Button
var _tab_artifact: Button
var _artifact_forge_panel: VBoxContainer

# Artifact forge state
var _af_mode: String = "random"  # "random" or "selected"
var _af_selected_artifacts: Array = []  # IDs of artifacts chosen for sacrifice
var _af_artifact_list: VBoxContainer
var _af_set_dropdown: OptionButton
var _af_rolls: Array = []  # SpinBoxes for dice rolls
var _af_sub2_row: VBoxContainer
var _af_sub2_label: Label
var _af_target_dropdown: OptionButton
var _af_forge_btn: Button
var _af_body_split: HSplitContainer  # sacrifice picker | rolls+target
var _af_rolls_split: VSplitContainer  # rolls panel | target+forge
var recipe_list_container: VBoxContainer
var product_icon: TextureRect
var product_name_label: Label
var product_meta_label: Label
var product_desc_label: RichTextLabel
var ingredients_container: VBoxContainer
var ingredients_title_label: Label
var qty_spin: SpinBox
var target_select: OptionButton
var craft_button: Button
var _recipe_cards = []   # Array of PanelContainer refs in left list


# ============================================================
# READY — build everything
# ============================================================
func _ready() -> void:
	# Full screen background
	var bg_panel = PanelContainer.new()
	bg_panel.name = "BgPanel"
	var bg_sb = StyleBoxFlat.new()
	bg_sb.bg_color = BG
	bg_panel.add_theme_stylebox_override("panel", bg_sb)
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg_panel)

	# Root margin
	var root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 32)
	root_margin.add_theme_constant_override("margin_right", 32)
	root_margin.add_theme_constant_override("margin_top", 24)
	root_margin.add_theme_constant_override("margin_bottom", 24)
	bg_panel.add_child(root_margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 16)
	root_margin.add_child(root_vbox)

	# ---- HEADER ----
	var header = _build_header()
	root_vbox.add_child(header)

	# ---- TAB BAR (Recipes / Artifact Forge) ----
	var tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	root_vbox.add_child(tab_row)

	_tab_recipes = Button.new()
	_tab_recipes.text = "RECIPES"
	_tab_recipes.toggle_mode = true
	_tab_recipes.button_pressed = true
	_tab_recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_recipes.add_theme_font_size_override("font_size", 40)
	_style_tab_btn(_tab_recipes, true)
	_tab_recipes.pressed.connect(func(): _switch_crafting_tab("recipes"))
	tab_row.add_child(_tab_recipes)

	_tab_artifact = Button.new()
	_tab_artifact.text = "ARTIFACT FORGE"
	_tab_artifact.toggle_mode = true
	_tab_artifact.button_pressed = false
	_tab_artifact.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_artifact.add_theme_font_size_override("font_size", 40)
	_style_tab_btn(_tab_artifact, false)
	_tab_artifact.pressed.connect(func(): _switch_crafting_tab("artifact"))
	tab_row.add_child(_tab_artifact)

	# ---- RECIPE BODY (2 columns, resizable) ----
	_body_split = HSplitContainer.new()
	var body_split = _body_split
	body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	root_vbox.add_child(body_split)

	# LEFT COLUMN (280px fixed)
	var left_panel = _build_left_panel()
	body_split.add_child(left_panel)

	# RIGHT COLUMN (expand)
	var right_panel = _build_right_panel()
	body_split.add_child(right_panel)

	# ---- ARTIFACT FORGE PANEL (hidden by default, Artisan only) ----
	_artifact_forge_panel = _build_artifact_forge()
	_artifact_forge_panel.visible = false
	root_vbox.add_child(_artifact_forge_panel)
	# Only Artisans see the forge tab
	if _get_active_role() != "Artisan":
		_tab_artifact.visible = false

	# ---- WIRE SIGNALS ----
	search_input.text_changed.connect(_on_search_changed)
	qty_spin.value_changed.connect(_on_qty_changed)
	craft_button.pressed.connect(_on_confirm_pressed)

	# ---- POPULATE ----
	_build_product_groups()
	_populate_party_targets()
	_build_recipe_cards()
	_refresh_confirm_enabled()
	_body_split.dragged.connect(func(_ofs): _save_layout())
	_right_split.dragged.connect(func(_ofs): _save_layout())
	_load_layout.call_deferred()
	_log("_ready complete: %d products" % _grouped_recipes.size())


# ============================================================
# HEADER
# ============================================================
func _build_header() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# Title
	var title = Label.new()
	title.text = "CRAFTING"
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", TEXT)
	hbox.add_child(title)

	# Role badge
	var badge = Label.new()
	var role = _get_active_role()
	badge.text = role if role != "" else "No Role"
	badge.add_theme_font_size_override("font_size", 40)
	badge.add_theme_color_override("font_color", ACCENT)
	var badge_sb = StyleBoxFlat.new()
	badge_sb.bg_color = CARD
	badge_sb.border_color = ACCENT
	badge_sb.border_width_left = 1
	badge_sb.border_width_right = 1
	badge_sb.border_width_top = 1
	badge_sb.border_width_bottom = 1
	badge_sb.corner_radius_top_left = 4
	badge_sb.corner_radius_top_right = 4
	badge_sb.corner_radius_bottom_left = 4
	badge_sb.corner_radius_bottom_right = 4
	badge_sb.content_margin_left = 10
	badge_sb.content_margin_right = 10
	badge_sb.content_margin_top = 4
	badge_sb.content_margin_bottom = 4
	var badge_panel = PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", badge_sb)
	badge_panel.add_child(badge)
	hbox.add_child(badge_panel)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Exit button
	var exit_btn = Button.new()
	exit_btn.text = "X"
	exit_btn.add_theme_font_size_override("font_size", 50)
	exit_btn.custom_minimum_size = Vector2(40, 40)
	var exit_sb = StyleBoxFlat.new()
	exit_sb.bg_color = CARD
	exit_sb.border_color = BORDER
	exit_sb.border_width_left = 1
	exit_sb.border_width_right = 1
	exit_sb.border_width_top = 1
	exit_sb.border_width_bottom = 1
	exit_sb.corner_radius_top_left = 6
	exit_sb.corner_radius_top_right = 6
	exit_sb.corner_radius_bottom_left = 6
	exit_sb.corner_radius_bottom_right = 6
	exit_btn.add_theme_stylebox_override("normal", exit_sb)
	var exit_hover_sb = exit_sb.duplicate()
	exit_hover_sb.bg_color = RED
	exit_btn.add_theme_stylebox_override("hover", exit_hover_sb)
	exit_btn.add_theme_color_override("font_color", TEXT)
	exit_btn.add_theme_color_override("font_hover_color", TEXT)
	exit_btn.pressed.connect(_on_exit_pressed)
	hbox.add_child(exit_btn)

	return hbox


# ============================================================
# LEFT PANEL — search + scrollable recipe list
# ============================================================
func _build_left_panel() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 280
	panel.size_flags_horizontal = 0  # no expand
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb = _make_card_stylebox(PANEL)
	panel.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	var margin = _wrap_margin(vbox, 12, 12, 12, 12)
	panel.add_child(margin)

	# Search
	search_input = LineEdit.new()
	search_input.placeholder_text = "Search recipes..."
	search_input.add_theme_font_size_override("font_size", 40)
	search_input.add_theme_color_override("font_color", TEXT)
	search_input.add_theme_color_override("font_placeholder_color", MUTED)
	var search_sb = StyleBoxFlat.new()
	search_sb.bg_color = INSET
	search_sb.border_color = BORDER
	search_sb.border_width_left = 1
	search_sb.border_width_right = 1
	search_sb.border_width_top = 1
	search_sb.border_width_bottom = 1
	search_sb.corner_radius_top_left = 6
	search_sb.corner_radius_top_right = 6
	search_sb.corner_radius_bottom_left = 6
	search_sb.corner_radius_bottom_right = 6
	search_sb.content_margin_left = 10
	search_sb.content_margin_right = 10
	search_sb.content_margin_top = 8
	search_sb.content_margin_bottom = 8
	search_input.add_theme_stylebox_override("normal", search_sb)
	search_input.add_theme_stylebox_override("focus", search_sb)
	search_input.clear_button_enabled = true
	vbox.add_child(search_input)

	# Filter chips: All / Craftable / Missing
	var filter_row = HFlowContainer.new()
	filter_row.add_theme_constant_override("h_separation", 4)
	vbox.add_child(filter_row)

	var chip_all = _make_chip("All", true)
	chip_all.pressed.connect(_on_filter_pressed.bind("all"))
	filter_row.add_child(chip_all)

	var chip_craftable = _make_chip("Craftable", false)
	chip_craftable.pressed.connect(_on_filter_pressed.bind("craftable"))
	filter_row.add_child(chip_craftable)

	var chip_missing = _make_chip("Missing", false)
	chip_missing.pressed.connect(_on_filter_pressed.bind("missing"))
	filter_row.add_child(chip_missing)

	_filter_chips = [chip_all, chip_craftable, chip_missing]

	# Scroll container for recipe list
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	vbox.add_child(scroll)

	recipe_list_container = VBoxContainer.new()
	recipe_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list_container.add_theme_constant_override("separation", 6)
	scroll.add_child(recipe_list_container)

	return panel


# ============================================================
# RIGHT PANEL — preview + ingredients + craft controls
# ============================================================
func _build_right_panel() -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)

	# --- Resizable split: preview vs ingredients ---
	_right_split = VSplitContainer.new()
	var right_split = _right_split
	right_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	vbox.add_child(right_split)

	# --- Product Preview Card ---
	var preview_card = _build_preview_card()
	right_split.add_child(preview_card)

	# --- Ingredients + Controls in bottom split ---
	var bottom_section = VBoxContainer.new()
	bottom_section.add_theme_constant_override("separation", 10)
	bottom_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_split.add_child(bottom_section)

	var ingredients_card = _build_ingredients_card()
	ingredients_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_section.add_child(ingredients_card)

	var controls_card = _build_controls_card()
	bottom_section.add_child(controls_card)

	return vbox


func _build_preview_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_stylebox(CARD))

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# Icon
	product_icon = TextureRect.new()
	product_icon.custom_minimum_size = Vector2(64, 64)
	product_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	product_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	product_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(product_icon)

	# Meta VBox
	var meta_vbox = VBoxContainer.new()
	meta_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(meta_vbox)

	product_name_label = Label.new()
	product_name_label.text = "Select a recipe"
	product_name_label.add_theme_font_size_override("font_size", 40)
	product_name_label.add_theme_color_override("font_color", TEXT)
	meta_vbox.add_child(product_name_label)

	product_meta_label = Label.new()
	product_meta_label.text = ""
	product_meta_label.add_theme_font_size_override("font_size", 40)
	product_meta_label.add_theme_color_override("font_color", SEC)
	meta_vbox.add_child(product_meta_label)

	product_desc_label = RichTextLabel.new()
	product_desc_label.text = ""
	product_desc_label.bbcode_enabled = true
	product_desc_label.fit_content = true
	product_desc_label.scroll_active = false
	product_desc_label.custom_minimum_size = Vector2(0, 40)
	product_desc_label.add_theme_font_size_override("normal_font_size", 14)
	product_desc_label.add_theme_color_override("default_color", MUTED)
	meta_vbox.add_child(product_desc_label)

	return card


func _build_ingredients_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_stylebox(CARD))

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	ingredients_title_label = Label.new()
	ingredients_title_label.text = "INGREDIENTS"
	ingredients_title_label.add_theme_font_size_override("font_size", 29)
	ingredients_title_label.add_theme_color_override("font_color", SEC)
	vbox.add_child(ingredients_title_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	ingredients_container = VBoxContainer.new()
	ingredients_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ingredients_container.add_theme_constant_override("separation", 6)
	scroll.add_child(ingredients_container)

	return card


func _build_controls_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _make_card_stylebox(CARD))

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	# Quantity
	var qty_label = Label.new()
	qty_label.text = "Qty:"
	qty_label.add_theme_font_size_override("font_size", 27)
	qty_label.add_theme_color_override("font_color", SEC)
	hbox.add_child(qty_label)

	qty_spin = SpinBox.new()
	qty_spin.min_value = 1
	qty_spin.max_value = 999
	qty_spin.value = 1
	qty_spin.custom_minimum_size.x = 80
	qty_spin.add_theme_font_size_override("font_size", 40)
	hbox.add_child(qty_spin)

	# Target player
	var target_label = Label.new()
	target_label.text = "Craft for:"
	target_label.add_theme_font_size_override("font_size", 27)
	target_label.add_theme_color_override("font_color", SEC)
	hbox.add_child(target_label)

	target_select = OptionButton.new()
	target_select.custom_minimum_size.x = 160
	target_select.add_theme_font_size_override("font_size", 40)
	hbox.add_child(target_select)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Craft button
	craft_button = Button.new()
	craft_button.text = "Craft"
	craft_button.disabled = true
	craft_button.custom_minimum_size = Vector2(140, 44)
	craft_button.add_theme_font_size_override("font_size", 50)
	# Outline style matching weapon scene buttons
	var craft_sb = StyleBoxFlat.new()
	craft_sb.bg_color = Color(GREEN.r, GREEN.g, GREEN.b, 0.1)
	craft_sb.border_color = GREEN
	craft_sb.set_border_width_all(2)
	craft_sb.set_corner_radius_all(6)
	craft_sb.content_margin_left = 20
	craft_sb.content_margin_right = 20
	craft_sb.content_margin_top = 8
	craft_sb.content_margin_bottom = 8
	craft_button.add_theme_stylebox_override("normal", craft_sb)
	var craft_hover_sb = craft_sb.duplicate()
	craft_hover_sb.bg_color = Color(GREEN.r, GREEN.g, GREEN.b, 0.2)
	craft_button.add_theme_stylebox_override("hover", craft_hover_sb)
	var craft_disabled_sb = craft_sb.duplicate()
	craft_disabled_sb.bg_color = INSET
	craft_disabled_sb.border_color = BORDER
	craft_button.add_theme_stylebox_override("disabled", craft_disabled_sb)
	craft_button.add_theme_color_override("font_color", GREEN)
	craft_button.add_theme_color_override("font_hover_color", GREEN)
	craft_button.add_theme_color_override("font_disabled_color", MUTED)
	hbox.add_child(craft_button)

	return card


# ============================================================
# STYLE HELPERS
# ============================================================
func _make_card_stylebox(color: Color, border_clr: Color = BORDER, radius: int = 8) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border_clr
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb


func _wrap_margin(child: Control, l: int, r: int, t: int, b: int) -> MarginContainer:
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_bottom", b)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(child)
	return m


func _make_chip(text: String, active: bool) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 23)
	_style_chip(btn, active)
	return btn


func _style_chip(btn: Button, active: bool) -> void:
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	if active:
		sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.08)
		sb.border_color = ACCENT
	else:
		sb.bg_color = CARD
		sb.border_color = BORDER
	sb.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", sb)
	var hover = sb.duplicate()
	hover.bg_color = HOVER
	btn.add_theme_stylebox_override("hover", hover)
	var pressed = sb.duplicate()
	pressed.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.15) if active else HOVER
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_color_override("font_color", ACCENT if active else MUTED)
	btn.add_theme_color_override("font_hover_color", ACCENT if active else TEXT)
	btn.add_theme_color_override("font_pressed_color", ACCENT)


# ============================================================
# ROLE / RECIPES
# ============================================================
func _get_active_role() -> String:
	var role = ""
	if "ACTIVE_USER_NAME" in Global and "CHARACTERS_NAME" in Global and "CHARACTERS" in Global:
		var readable = Global.ACTIVE_USER_NAME
		var rec_id = Global.CHARACTERS_NAME.get(readable, null)
		if rec_id != null and rec_id in Global.CHARACTERS:
			role = str(Global.CHARACTERS[rec_id].get("Role", ""))
	return role


func _build_product_groups() -> void:
	_grouped_recipes.clear()
	var active_role = _get_active_role()

	# Read directly from GameDB for accurate typed resource access.
	# IMPORTANT: legacy data stores each ingredient as its own JSON row sharing
	# the same Product (e.g., Bamboo Shoot Soup -> 6 rows, one per ingredient).
	# When GameDB falls back to JSON (e.g., on a build without baked .tres
	# files), iterating values() yields multiple CraftingRecipeData entries for
	# the same product, each with one slot. Don't blindly overwrite — when a
	# product's first row was a single-slot legacy entry, treat subsequent
	# single-slot rows for the same product as additional ingredients of the
	# same recipe, not as alternative variants.
	var single_slot_legacy_products: Dictionary = {}
	for recipe_res in GameDB.crafting_recipes.values():
		if recipe_res.role != active_role:
			continue
		if recipe_res.product == "":
			continue

		var recipes: Array = recipe_res.get_recipes()
		if recipes.is_empty():
			continue

		var incoming_is_single_slot: bool = (
			recipes.size() == 1
			and recipes[0].get("slots", []).size() == 1
		)

		if not _grouped_recipes.has(recipe_res.product):
			_grouped_recipes[recipe_res.product] = {
				"meta": {
					"Product": recipe_res.product,
					"Region": recipe_res.region,
					"Description": recipe_res.description,
					"Icon": null,
					"output_quantity": recipe_res.output_quantity,
				},
				"recipes": recipes,
				"_resource": recipe_res,
			}
			single_slot_legacy_products[recipe_res.product] = incoming_is_single_slot
			continue

		var existing = _grouped_recipes[recipe_res.product]
		var existing_recipes: Array = existing["recipes"]
		var first_row_was_legacy: bool = single_slot_legacy_products.get(recipe_res.product, false)

		if first_row_was_legacy and incoming_is_single_slot:
			# Accumulating legacy single-ingredient rows — fold this slot into
			# the first recipe so all ingredients render together.
			existing_recipes[0]["slots"].append_array(recipes[0]["slots"])
		else:
			# Real alternative recipe (or first row wasn't legacy) — append.
			existing_recipes.append_array(recipes)
			# Mark as no-longer-pure-legacy so further rows don't merge into it.
			single_slot_legacy_products[recipe_res.product] = false


# ============================================================
# PARTY TARGETS
# ============================================================
func _populate_party_targets() -> void:
	target_select.clear()
	# Add self first
	var active_name = Global.ACTIVE_USER_NAME
	target_select.add_item(active_name + " (me)")
	target_select.set_item_metadata(0, active_name)
	# Add all other party members
	var idx = 0
	for player_name in Global.PartyCharacters:
		if player_name == active_name:
			continue
		idx += 1
		target_select.add_item(player_name)
		target_select.set_item_metadata(idx, player_name)
	if target_select.item_count > 0:
		target_select.select(0)


# ============================================================
# LEFT LIST — recipe cards
# ============================================================
func _build_recipe_cards() -> void:
	for c in recipe_list_container.get_children():
		if c != null:
			c.queue_free()
	_recipe_cards.clear()

	_visible_products = _filter_products(search_input.text if search_input != null else "")
	_visible_products.sort()

	for product in _visible_products:
		var card = _create_recipe_card(product)
		recipe_list_container.add_child(card)
		_recipe_cards.append(card)


func _create_recipe_card(product: String) -> PanelContainer:
	var can_craft = _can_craft_product(product)

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Style with left accent border
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = BORDER
	sb.border_width_left = 3
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	# Left border color = green if craftable, red if not
	sb.border_color = BORDER
	if can_craft:
		sb.border_width_left = 3
		sb.set_border_width(SIDE_LEFT, 3)
		# We use a separate approach: draw the left border with the accent color
		var left_color = GREEN
		sb.border_color = BORDER
		# StyleBoxFlat only supports one border color, so we handle it differently
		# We'll just tint the whole border based on status
		sb.border_color = GREEN if can_craft else RED
	else:
		sb.border_color = RED

	card.add_theme_stylebox_override("panel", sb)

	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	top_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(top_hbox)

	# Product icon
	var product_icon = TextureRect.new()
	product_icon.custom_minimum_size = Vector2(40, 40)
	product_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	product_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	product_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_name = product.to_lower().replace(" ", "-")
	var icon_tex = _load_icon(icon_name)
	if icon_tex != null:
		product_icon.texture = icon_tex
	else:
		product_icon.visible = false
	top_hbox.add_child(product_icon)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(vbox)

	# Product name
	var name_label = Label.new()
	name_label.text = product
	name_label.add_theme_font_size_override("font_size", 29)
	name_label.add_theme_color_override("font_color", TEXT if can_craft else MUTED)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Region + availability
	var meta = _grouped_recipes[product]["meta"]
	var region_text = str(meta.get("Region", ""))
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 8)
	bottom_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_hbox)

	if region_text != "":
		var region_lbl = Label.new()
		region_lbl.text = region_text
		region_lbl.add_theme_font_size_override("font_size", 40)
		region_lbl.add_theme_color_override("font_color", MUTED)
		region_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bottom_hbox.add_child(region_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hbox.add_child(spacer)

	var status_lbl = Label.new()
	if can_craft:
		status_lbl.text = "Can craft"
		status_lbl.add_theme_color_override("font_color", GREEN)
	else:
		status_lbl.text = "Missing materials"
		status_lbl.add_theme_color_override("font_color", RED)
	status_lbl.add_theme_font_size_override("font_size", 40)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hbox.add_child(status_lbl)

	# Click handler
	card.gui_input.connect(_on_recipe_card_input.bind(product, card))

	return card


static func _load_icon(hyphen_name: String) -> Texture2D:
	for folder in ["res://UI/Food Icons/", "res://UI/Weapon Icons/", "res://UI/Item Icons/"]:
		var path = folder + hyphen_name + ".png"
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _on_recipe_card_input(event: InputEvent, product: String, card: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_product(product)


func _select_product(product: String) -> void:
	_selected_product = product

	# Update card selection visuals
	var idx = 0
	for p in _visible_products:
		if idx < _recipe_cards.size():
			var card = _recipe_cards[idx]
			var is_selected = (p == product)
			var can_craft = _can_craft_product(p)
			var sb = StyleBoxFlat.new()
			sb.bg_color = HOVER if is_selected else CARD
			sb.border_color = ACCENT if is_selected else (GREEN if can_craft else RED)
			sb.border_width_left = 3
			sb.border_width_right = 1 if not is_selected else 2
			sb.border_width_top = 1 if not is_selected else 2
			sb.border_width_bottom = 1 if not is_selected else 2
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			sb.content_margin_left = 12
			sb.content_margin_right = 10
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			card.add_theme_stylebox_override("panel", sb)
		idx += 1

	_assign_icon(product)
	_update_preview(product)
	_build_ingredient_rows(product)
	_refresh_confirm_enabled()
	_log("Selected: %s" % product)


func _can_craft_product(product: String) -> bool:
	if not _grouped_recipes.has(product):
		return false
	var entry = _grouped_recipes[product]
	var recipes: Array = entry.get("recipes", [])
	# Craftable if ANY recipe can be fully satisfied
	for recipe in recipes:
		if _check_recipe(recipe):
			return true
	return false


func _check_recipe(recipe: Dictionary) -> bool:
	var slots = recipe.get("slots", [])
	for slot in slots:
		var options = slot.get("options", [])
		var any_option_ok = false
		for opt in options:
			var mat = str(opt.get("material", ""))
			var needed = int(opt.get("quantity", 1))
			var is_type = bool(opt.get("match_type", false))
			var matches = _find_inventory_matches(mat, is_type)
			var total_have = 0
			for m in matches:
				total_have += _to_int(m.get("Quantity", 0))
			if total_have >= needed:
				any_option_ok = true
				break
		if not any_option_ok:
			return false
	return true


func _filter_products(query: String) -> Array[String]:
	var out: Array[String] = []
	var seen = {}
	var q = query.strip_edges()

	if q == "":
		# No search — include all products
		for k in _grouped_recipes.keys():
			var s = str(k)
			if not seen.has(s):
				seen[s] = true
				out.append(s)
	else:
		# Search filter — match by name, region, description
		var ql = q.to_lower()
		for p in _grouped_recipes.keys():
			var product_str = str(p)
			var entry = _grouped_recipes[p]
			var meta = entry.get("meta", {})
			var meta_product = str(meta.get("Product", ""))
			var meta_region = str(meta.get("Region", ""))
			var meta_desc = str(meta.get("Description", ""))

			var matched = false
			if meta_product.to_lower().find(ql) != -1:
				matched = true
			elif meta_region.to_lower().find(ql) != -1:
				matched = true
			elif meta_desc.to_lower().find(ql) != -1:
				matched = true

			if matched and not seen.has(product_str):
				seen[product_str] = true
				out.append(product_str)

	out.sort()

	# Apply craftable/missing filter (runs for both search and no-search)
	if _craft_filter == "craftable":
		var filtered: Array[String] = []
		for p in out:
			if _can_craft_product(p):
				filtered.append(p)
		return filtered
	elif _craft_filter == "missing":
		var filtered: Array[String] = []
		for p in out:
			if not _can_craft_product(p):
				filtered.append(p)
		return filtered

	return out


func _on_filter_pressed(filter_name: String) -> void:
	print("[CraftingMenu] Filter changed to: %s" % filter_name)
	_craft_filter = filter_name
	_refresh_recipe_list()


func _refresh_recipe_list() -> void:
	# Update chip styles
	var chip_labels = ["all", "craftable", "missing"]
	for i in _filter_chips.size():
		var active = chip_labels[i] == _craft_filter
		_style_chip(_filter_chips[i], active)
	_build_recipe_cards()


func _on_search_changed(_t: String) -> void:
	_build_recipe_cards()


# ============================================================
# PRODUCT PREVIEW (top right)
# ============================================================
func _update_preview(product: String) -> void:
	var role = _get_active_role()
	if role == "Blacksmith":
		_populate_blacksmith_preview(product)
	else:
		_populate_artisan_preview(product)


func _populate_artisan_preview(selected_item) -> void:
	var name_str = str(selected_item)
	var row = _lookup_items_by_item_field(name_str)
	if row.is_empty():
		product_name_label.text = name_str
		product_meta_label.text = ""
		product_desc_label.text = ""
		return
	product_name_label.text = str(row.get("Item", name_str))
	var type_str = str(row.get("Type", ""))
	var rarity = str(row.get("Rarity", ""))
	var region = str(row.get("Region", ""))
	var parts = []
	if type_str != "":
		parts.append(type_str)
	if rarity != "":
		parts.append(rarity)
	if region != "":
		parts.append(region)
	product_meta_label.text = " · ".join(parts)
	product_desc_label.text = str(row.get("Description", row.get("Notes", "")))


func _lookup_items_by_item_field(item_name: String) -> Dictionary:
	var items = Global.ITEMS
	if typeof(items) != TYPE_DICTIONARY or items.is_empty():
		return {}
	var key = item_name.strip_edges()
	var key_lc = key.to_lower()
	if items.has(key):
		var direct = items[key]
		if typeof(direct) == TYPE_DICTIONARY:
			return direct
	for rid in items.keys():
		var row = items[rid]
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var item_field = str(row.get("Item", "")).strip_edges().to_lower()
		if item_field != "" and item_field == key_lc:
			return row
	return {}


func _populate_blacksmith_preview(selected_item) -> void:
	var weapon = _lookup_weapon(selected_item)
	if weapon.is_empty():
		product_name_label.text = str(selected_item)
		product_meta_label.text = ""
		product_desc_label.text = "Weapon not found"
		return
	product_name_label.text = str(weapon.get("Name", ""))
	var w_type = str(weapon.get("WeaponType", weapon.get("Type", "")))
	var rarity = str(weapon.get("Rarity", weapon.get("Stars", "")))
	var region = str(weapon.get("Region", ""))
	var parts = []
	if w_type != "":
		parts.append(w_type)
	if rarity != "":
		parts.append(rarity)
	if region != "":
		parts.append(region)
	product_meta_label.text = " · ".join(parts)
	product_desc_label.text = _format_weapon_desc(weapon)


func _lookup_weapon(selection) -> Dictionary:
	if typeof(selection) == TYPE_STRING:
		var key = selection.strip_edges()
		if Global.WEAPONS.has(key):
			return Global.WEAPONS[key]
		var key_lc = key.to_lower()
		for id in Global.WEAPONS.keys():
			var w = Global.WEAPONS[id]
			var nm = str(w.get("Name", "")).to_lower()
			if nm == key_lc:
				return w
		for id in Global.WEAPONS.keys():
			var w2 = Global.WEAPONS[id]
			var alt = str(w2.get("WeaponName", w2.get("Product", ""))).to_lower()
			if alt != "" and alt == key_lc:
				return w2
		return {}
	if typeof(selection) == TYPE_DICTIONARY:
		if selection.has("WeaponId"):
			var wid = selection["WeaponId"]
			if Global.WEAPONS.has(wid):
				return Global.WEAPONS[wid]
		if selection.has("Name"):
			return _lookup_weapon(selection["Name"])
	var id_str = str(selection)
	if Global.WEAPONS.has(id_str):
		return Global.WEAPONS[id_str]
	return {}


func _format_weapon_desc(w: Dictionary) -> String:
	var lines = []
	if w.has("Stat_3_Type") and w.get("Stat_3_Type") != null:
		lines.append(str(w.get("Stat_1_Type", "")) + ": " + str(w.get("Stat_1_Value", "")))
		lines.append(str(w.get("Stat_2_Type", "")) + ": " + str(w.get("Stat_2_Value", "")))
		lines.append(str(w.get("Stat_3_Type", "")) + ": " + str(w.get("Stat_3_Value", "")))
	elif w.has("Stat_2_Type") and w.get("Stat_2_Type") != null:
		lines.append(str(w.get("Stat_1_Type", "")) + ": " + str(w.get("Stat_1_Value", "")))
		lines.append(str(w.get("Stat_2_Type", "")) + ": " + str(w.get("Stat_2_Value", "")))
	else:
		lines.append(str(w.get("Stat_1_Type", "")) + ": " + str(w.get("Stat_1_Value", "")))
	var effect_text = str(w.get("Effect", w.get("Passive", "")))
	if effect_text != "" and effect_text != "<null>":
		lines.append("")
		lines.append(effect_text)
	return "\n".join(lines)


# ============================================================
# ICON
# ============================================================
func _assign_icon(item) -> void:
	var hyphen_name = str(item).to_lower().replace(" ", "-")
	if _get_active_role() == "Artisan":
		product_icon.texture = load("res://UI/Food Icons/" + hyphen_name + ".png")
	else:
		product_icon.texture = load("res://UI/Weapon Icons/" + hyphen_name + ".png")


# ============================================================
# INGREDIENTS (right side, middle card)
# ============================================================
var _active_variant_idx = 0

func _build_ingredient_rows(product: String) -> void:
	_slot_to_item_id.clear()
	_inventory_snapshot_before = _snapshot_inventory()
	_active_variant_idx = 0

	# Clear old rows
	for c in ingredients_container.get_children():
		if c != null:
			c.queue_free()

	var entry = _grouped_recipes.get(product, {})
	var recipes: Array = entry.get("recipes", [])

	# If multiple recipes, show a selector dropdown
	if recipes.size() > 1:
		var variant_row = HBoxContainer.new()
		variant_row.add_theme_constant_override("separation", 8)
		ingredients_container.add_child(variant_row)

		var variant_label = Label.new()
		variant_label.text = "Recipe:"
		variant_label.add_theme_font_size_override("font_size", 40)
		variant_label.add_theme_color_override("font_color", ACCENT)
		variant_row.add_child(variant_label)

		var variant_dropdown = OptionButton.new()
		variant_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		variant_dropdown.add_theme_font_size_override("font_size", 40)
		for vi in recipes.size():
			var recipe = recipes[vi]
			var slots = recipe.get("slots", [])
			var parts: Array = []
			for slot in slots:
				var opts = slot.get("options", [])
				if opts.size() == 1:
					parts.append("%dx %s" % [int(opts[0].get("quantity", 1)), str(opts[0].get("material", "?"))])
				elif opts.size() > 1:
					var opt_strs: Array = []
					for o in opts:
						opt_strs.append("%dx %s" % [int(o.get("quantity", 1)), str(o.get("material", "?"))])
					parts.append("(%s)" % " or ".join(opt_strs))
			variant_dropdown.add_item("Recipe %d: %s" % [vi + 1, " + ".join(parts)], vi)
		variant_dropdown.selected = 0
		variant_dropdown.item_selected.connect(func(idx):
			_active_variant_idx = idx
			_switch_variant(product, idx)
		)

		var sb = StyleBoxFlat.new()
		sb.bg_color = INSET
		sb.border_color = BORDER
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		variant_dropdown.add_theme_stylebox_override("normal", sb)
		variant_dropdown.add_theme_color_override("font_color", TEXT)
		variant_row.add_child(variant_dropdown)

	# Use the active recipe
	_apply_variant(product, _active_variant_idx)


func _switch_variant(product: String, variant_idx: int) -> void:
	_active_variant_idx = variant_idx
	# Remove all children except the variant selector (first child)
	var children = ingredients_container.get_children()
	for i in range(children.size() - 1, 0, -1):
		children[i].queue_free()
	_apply_variant(product, variant_idx)


func _apply_variant(product: String, variant_idx: int) -> void:
	var entry = _grouped_recipes.get(product, {})
	var recipes: Array = entry.get("recipes", [])
	if variant_idx >= recipes.size():
		return

	var recipe = recipes[variant_idx]
	var slots = recipe.get("slots", [])

	_slot_requirements = []
	for i in range(slots.size()):
		var slot = slots[i]
		var options = slot.get("options", [])
		# Build a requirement dict with the first option as default
		var req = {}
		if options.size() == 1:
			req = {"material": str(options[0].get("material", "")), "quantity": int(options[0].get("quantity", 1))}
		elif options.size() > 1:
			req = {"material": str(options[0].get("material", "")), "quantity": int(options[0].get("quantity", 1)), "options": options}
		else:
			continue
		_slot_requirements.append(req)
		var slot_panel = _create_ingredient_slot(i, req)
		ingredients_container.add_child(slot_panel)

	_validate_all_slots()
	_refresh_confirm_enabled()


func _create_ingredient_slot(slot_idx: int, req: Dictionary) -> PanelContainer:
	var material = str(req.get("material", "Material"))
	var need_per = int(req.get("quantity", 1))
	var need_total = need_per * int(qty_spin.value)
	var options = req.get("options", [])
	var is_type = bool(req.get("match_type", false))

	var matches = _find_inventory_matches(material, is_type)
	var best_have = 0
	for m in matches:
		var h = _to_int(m.get("Quantity", 0))
		if h > best_have:
			best_have = h
	var satisfied = (best_have >= need_total)

	# Check if any alternative option is satisfied
	if not satisfied and options.size() > 1:
		for opt in options:
			var opt_mat = str(opt.get("material", ""))
			var opt_is_type = bool(opt.get("match_type", false))
			var opt_need = int(opt.get("quantity", 1)) * int(qty_spin.value)
			var opt_matches = _find_inventory_matches(opt_mat, opt_is_type)
			for m in opt_matches:
				if _to_int(m.get("Quantity", 0)) >= opt_need:
					satisfied = true
					break
			if satisfied:
				break

	# Slot panel
	var slot = PanelContainer.new()
	slot.name = "Slot_%d" % slot_idx
	var sb = StyleBoxFlat.new()
	sb.bg_color = INSET
	sb.border_color = GREEN if satisfied else RED
	sb.border_width_left = 2
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	slot.add_theme_stylebox_override("panel", sb)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	slot.add_child(hbox)

	# 32x32 icon placeholder
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Try to load a material icon from all icon folders
	var mat_hyphen = material.to_lower().replace(" ", "-")
	var mat_tex = _load_icon(mat_hyphen)
	if mat_tex != null:
		icon_rect.texture = mat_tex
	hbox.add_child(icon_rect)

	# Material name / option selector
	if options.size() > 1:
		# Multi-option slot: show dropdown to pick which material
		var opt_select = OptionButton.new()
		opt_select.name = "OptSelect_%d" % slot_idx
		opt_select.custom_minimum_size.x = 200
		opt_select.add_theme_font_size_override("font_size", 40)
		for oi in options.size():
			var o = options[oi]
			opt_select.add_item("%dx %s" % [int(o.get("quantity", 1)), str(o.get("material", "?"))], oi)
		opt_select.selected = 0
		var sidx = slot_idx
		opt_select.item_selected.connect(func(idx):
			# Update the requirement for this slot to the selected option
			var selected_opt = options[idx]
			_slot_requirements[sidx] = {"material": str(selected_opt.get("material", "")), "quantity": int(selected_opt.get("quantity", 1)), "options": options}
			# Rebuild this slot
			_rebuild_single_slot(sidx)
		)
		hbox.add_child(opt_select)
	else:
		var name_label = Label.new()
		name_label.text = ("Any %s" % material) if is_type else material
		name_label.add_theme_font_size_override("font_size", 27)
		name_label.add_theme_color_override("font_color", TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		hbox.add_child(name_label)

	# Inventory item dropdown (find matching items in inventory)
	var opt = OptionButton.new()
	opt.name = "Opt_%d" % slot_idx
	opt.custom_minimum_size.x = 220
	opt.add_theme_font_size_override("font_size", 40)
	opt.clip_text = true
	hbox.add_child(opt)

	_populate_option_for_requirement(opt, slot_idx, req)
	opt.item_selected.connect(_on_option_selected.bind(slot_idx))

	# Have/Need label
	var hn_label = Label.new()
	hn_label.name = "HaveNeed_%d" % slot_idx
	hn_label.add_theme_font_size_override("font_size", 40)
	hn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hn_label.custom_minimum_size.x = 70

	# Calculate have based on current selection
	var have = 0
	if opt.selected > 0:
		var sel_meta = opt.get_selected_metadata()
		var sel_item = _get_inventory_item_by_id(sel_meta)
		if sel_item.size() > 0:
			have = _to_int(sel_item.get("Quantity", 0))

	hn_label.text = "%d / %d" % [have, need_total]
	hn_label.add_theme_color_override("font_color", GREEN if have >= need_total else RED)
	hbox.add_child(hn_label)

	return slot


func _populate_option_for_requirement(opt: OptionButton, slot_idx: int, req: Dictionary) -> void:
	opt.clear()
	var material = str(req.get("material", ""))
	var is_type = bool(req.get("match_type", false))
	var matches = _find_inventory_matches(material, is_type)
	var need_per = int(req.get("quantity", 1))
	var need_total = need_per * int(qty_spin.value)

	opt.add_item("-- Select --")
	opt.set_item_metadata(0, null)

	var exact_idx = -1
	for item in matches:
		var label = _format_option_label(item, need_total)
		var idx = opt.item_count
		opt.add_item(label)
		opt.set_item_metadata(idx, item.get("Id", null))

		var tip = "Name: %s\nType: %s\nHave: %d\nNeed: %d" % [
			str(item.get("Name", "")),
			str(item.get("Type", "")),
			_to_int(item.get("Quantity", 0)),
			need_total
		]
		opt.set_item_tooltip(idx, tip)

		if str(item.get("Name", "")).to_lower() == material.to_lower():
			exact_idx = idx

	if exact_idx != -1:
		opt.select(exact_idx)
		_slot_to_item_id[slot_idx] = opt.get_item_metadata(exact_idx)
	elif matches.size() == 1:
		opt.select(1)
		_slot_to_item_id[slot_idx] = matches[0].get("Id", null)
	else:
		opt.select(0)


func _format_option_label(item: Dictionary, need_total: int) -> String:
	var name_str = str(item.get("Name", "Unknown"))
	var type_str = str(item.get("Type", "")).strip_edges()
	var have = _to_int(item.get("Quantity", 0))
	var head = name_str if type_str == "" else "%s [%s]" % [name_str, type_str]
	return "%s — (x%d have; need %d)" % [head, have, need_total]


func _on_option_selected(_index: int, slot_idx: int) -> void:
	var opt = _get_slot_option(slot_idx)
	if opt == null:
		return
	var meta = opt.get_selected_metadata()
	if meta == null:
		_slot_to_item_id.erase(slot_idx)
	else:
		_slot_to_item_id[slot_idx] = meta

	# Update have/need label
	var have = 0
	if opt.selected > 0:
		var item = _get_inventory_item_by_id(meta)
		if item.size() > 0:
			have = _to_int(item.get("Quantity", 0))

	var need_per = int(_slot_requirements[slot_idx].get("quantity", 1))
	var need_total = need_per * int(qty_spin.value)
	var hn = _get_slot_have_need(slot_idx)
	if hn != null:
		hn.text = "%d / %d" % [have, need_total]
		hn.add_theme_color_override("font_color", GREEN if have >= need_total else RED)

	_update_slot_border(slot_idx)
	_refresh_confirm_enabled()


func _on_qty_changed(_v: float) -> void:
	if _selected_product == "":
		return
	# Rebuild ingredient rows to reflect new quantities
	_build_ingredient_rows(_selected_product)


func _rebuild_single_slot(slot_idx: int) -> void:
	# Find and replace the slot panel in ingredients_container
	var slot_node = ingredients_container.get_node_or_null("Slot_%d" % slot_idx)
	if slot_node == null:
		return
	var idx = slot_node.get_index()
	slot_node.queue_free()
	var new_slot = _create_ingredient_slot(slot_idx, _slot_requirements[slot_idx])
	ingredients_container.add_child(new_slot)
	ingredients_container.move_child(new_slot, idx)
	_validate_all_slots()
	_refresh_confirm_enabled()

func _validate_all_slots() -> void:
	for i in range(_slot_requirements.size()):
		_update_slot_border(i)


func _update_slot_border(slot_idx: int) -> void:
	if slot_idx >= ingredients_container.get_child_count():
		return
	var slot_panel = ingredients_container.get_child(slot_idx)
	if slot_panel == null or not (slot_panel is PanelContainer):
		return
	var enough = _has_enough_for_slot(slot_idx)
	var sb = StyleBoxFlat.new()
	sb.bg_color = INSET
	sb.border_color = GREEN if enough else RED
	sb.border_width_left = 2
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	slot_panel.add_theme_stylebox_override("panel", sb)


func _get_slot_option(slot_idx: int) -> OptionButton:
	if slot_idx >= ingredients_container.get_child_count():
		return null
	var slot_panel = ingredients_container.get_child(slot_idx)
	return slot_panel.find_child("Opt_%d" % slot_idx, true, false) as OptionButton


func _get_slot_have_need(slot_idx: int) -> Label:
	if slot_idx >= ingredients_container.get_child_count():
		return null
	var slot_panel = ingredients_container.get_child(slot_idx)
	return slot_panel.find_child("HaveNeed_%d" % slot_idx, true, false) as Label


func _refresh_confirm_enabled() -> void:
	var ok = true
	if _selected_product == "":
		ok = false
	if target_select == null or target_select.selected < 0:
		ok = false
	for i in range(_slot_requirements.size()):
		if not _slot_to_item_id.has(i) or not _has_enough_for_slot(i):
			ok = false
			break
	craft_button.disabled = not ok


# ============================================================
# INVENTORY / MATCHING
# ============================================================
func _has_enough_for_slot(slot_idx: int) -> bool:
	var need_per = int(_slot_requirements[slot_idx].get("quantity", 1))
	var qty_total = need_per * int(qty_spin.value)
	var have = _get_selected_item_quantity(slot_idx)
	return have >= qty_total


func _get_selected_item_quantity(slot_idx: int) -> int:
	if not _slot_to_item_id.has(slot_idx):
		return 0
	var item = _get_inventory_item_by_id(_slot_to_item_id[slot_idx])
	if item.size() == 0:
		return 0
	return int(item.get("Quantity", 0))


func _get_inventory_item_by_id(item_id) -> Dictionary:
	var inv_arr = _get_inventory_array()
	for it in inv_arr:
		if it.get("Id", null) == item_id:
			return it
	return {}


func _find_inventory_matches(material_or_type: String, type_match: bool = false) -> Array:
	var inv_arr = _get_inventory_array()
	var out = []
	var needle = material_or_type.strip_edges().to_lower()
	for it in inv_arr:
		var nm = str(it.get("Name", "")).to_lower()
		var tp = str(it.get("Type", "")).to_lower()
		var have = int(it.get("Quantity", 0))
		if have <= 0:
			continue
		if type_match:
			# Match by item type only
			if tp == needle:
				out.append(it)
		else:
			# Match by specific item name, or fall back to type
			if nm == needle or tp == needle or (needle != "" and tp.find(needle) != -1):
				out.append(it)
	return out


func _normalize_inventory_item(raw: Dictionary, key = null) -> Dictionary:
	var id = raw.get("Id", key)
	var item_name = str(
		raw.get("Name",
		raw.get("ItemName",
		raw.get("Material",
		raw.get("Product",
		raw.get("DisplayName", ""))))))
	var typ = str(
		raw.get("Type",
		raw.get("Material_Type",
		raw.get("Category",
		raw.get("Kind",
		raw.get("Subtype", ""))))))
	var qty = _to_int(
		raw.get("Quantity",
		raw.get("Qty",
		raw.get("Count",
		raw.get("Owned",
		raw.get("Amount", 0))))))
	var icon = raw.get("Icon", raw.get("Image", raw.get("IconTexture", null)))
	return {"Id": id, "Name": item_name, "Type": typ, "Quantity": qty, "Icon": icon}


func _get_inventory_array() -> Array:
	if "CHARACTER_ITEMS" in Global:
		var inv = Global.CHARACTER_ITEMS
		if inv is Array:
			var arr = []
			for it in inv:
				if it is Dictionary:
					arr.append(_normalize_inventory_item(it, it.get("Id", null)))
			return arr
		if inv is Dictionary:
			var arr2 = []
			for k in inv.keys():
				var it = inv[k]
				if it is Dictionary and it.get("Owner") == Global.ACTIVE_USER_NAME:
					arr2.append(_normalize_inventory_item(it, k))
			return arr2
	return []


func _snapshot_inventory() -> Dictionary:
	var snap = {}
	var arr = _get_inventory_array()
	for it in arr:
		var iid = it.get("Id", null)
		if iid != null:
			snap[iid] = int(it.get("Quantity", 0))
	return snap


func _to_int(v) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_STRING:
		return String(v).to_int()
	return 0


func _as_int_id(v) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_STRING:
		return String(v).to_int()
	return 0


func _as_int(v) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT:
		return int(v)
	if typeof(v) == TYPE_STRING:
		return String(v).to_int()
	return 0


# ============================================================
# CONFIRM CRAFT
# ============================================================
func _on_confirm_pressed() -> void:
	if craft_button.disabled:
		return
	if _selected_product == "":
		return

	var craft_count = _as_int(qty_spin.value)
	# output_quantity: how many items produced per craft (e.g., downgrade 1 gem → 3 gems)
	var output_qty = int(_grouped_recipes.get(_selected_product, {}).get("meta", {}).get("output_quantity", 1))
	var qty_to_make = craft_count * maxi(output_qty, 1)
	var target = target_select.get_item_text(target_select.selected) \
		if target_select != null and target_select.selected >= 0 else "Unknown"

	# Build consumption plan
	var consumption = []
	for i in range(_slot_requirements.size()):
		var need_per = _as_int(_slot_requirements[i].get("quantity", 1))
		var total_need = need_per * qty_to_make
		var raw_id = _slot_to_item_id.get(i, null)
		var rid = _as_int_id(raw_id)
		consumption.append({"id": rid, "take": total_need})

	# Decrement inventory
	var updates = []
	for c in consumption:
		var rid = c["id"]
		var current_amount = _as_int(Global.CHARACTER_ITEMS[str(int(rid))].get("Quantity", 0))
		var new_qty = current_amount - _as_int(c["take"])
		updates.append({
			"table": "Character_Items",
			"record_id": rid,
			"field": "Quantity",
			"value": _as_int(new_qty)
		})

	# Grant product
	var has_item = false
	var product_amount = 0
	var product_record = 0
	if _get_active_role() == "Artisan":
		for item_key in Global.CHARACTER_ITEMS:
			var it = Global.CHARACTER_ITEMS[item_key]
			if it.get("Name") == _selected_product and it.get("Owner") == target:
				has_item = true
				product_amount = _as_int(it.get("Quantity", 0))
				product_record = _as_int_id(item_key)
				break

		if has_item:
			updates.append({
				"table": "Character_Items",
				"record_id": product_record,
				"field": "Quantity",
				"value": _as_int(qty_to_make + product_amount)
			})
		else:
			var Type = ""
			var Rarity = ""
			var Description = ""
			for item in Global.ITEMS.values():
				if item.get("Item") == _selected_product:
					Type = str(item.get("Type", ""))
					Rarity = str(item.get("Rarity", ""))
					Description = str(item.get("Description", ""))
			Global.Insert(
				"Character_Items",
				["Owner", "Name", "Type", "Rarity", "Quantity", "Description"],
				[target, _selected_product, Type, Rarity, _as_int(qty_to_make), Description]
			)
	else:
		for item_key in Global.CHARACTER_WEAPONS:
			var it = Global.CHARACTER_WEAPONS[item_key]
			if it.get("Weapon") == _selected_product and it.get("Owner") == target:
				has_item = true
				product_amount = _as_int(it.get("Quantity", 0))
				product_record = _as_int_id(item_key)
				break

		if has_item:
			updates.append({
				"table": "Character_Weapons",
				"record_id": product_record,
				"field": "Quantity",
				"value": _as_int(qty_to_make + product_amount)
			})
		else:
			var Type = ""
			var Rarity = ""
			var Effect = ""
			var Region = ""
			var Stat1Type = ""
			var Stat2Type = ""
			var Stat3Type = ""
			var Stat1Value = ""
			var Stat2Value = ""
			var Stat3Value = ""
			for item in Global.WEAPONS.values():
				if item.get("Name") == _selected_product:
					Type = str(item.get("Weapon_Type", ""))
					Rarity = str(item.get("Rarity", ""))
					if item.get("Effect", "") != null:
						Effect = str(item.get("Effect", ""))
					else:
						Effect = ""
					Region = str(item.get("Region", ""))
					Stat1Type = str(item.get("Stat_1_Type", ""))
					Stat1Value = item.get("Stat_1_Value", "")
					if item.get("Stat_2_Type") != null:
						Stat2Type = str(item.get("Stat_2_Type", ""))
						Stat2Value = item.get("Stat_2_Value", "")
					else:
						Stat2Type = null
						Stat2Value = null
					if item.get("Stat_3_Type") != null:
						Stat3Type = str(item.get("Stat_3_Type", ""))
						Stat3Value = item.get("Stat_3_Value", "")
					else:
						Stat3Type = null
						Stat3Value = null
			Global.Insert(
				"Character_Weapons",
				["Owner", "Weapon", "Type", "Rarity", "Region", "Quantity", "Effect", "Stat_1_Type", "Stat_2_Type", "Stat_3_Type", "Stat_1_Value", "Stat_2_Value", "Stat_3_Value", "Refinement", "Equipped"],
				[target, _selected_product, Type, Rarity, Region, _as_int(qty_to_make), Effect, Stat1Type, Stat2Type, Stat3Type, Stat1Value, Stat2Value, Stat3Value, 0, false]
			)

	# Ship updates
	if updates.size() > 0:
		Global.Update_Records(updates)

	# Log
	if "Log" in Global:
		var old_values = {"inventory_before": _inventory_snapshot_before.duplicate()}
		var new_values = {
			"crafted_product": _selected_product,
			"quantity": qty_to_make,
			"target": target,
			"consumed": consumption
		}
		var metadata = {"screen": "CraftingMenu"}
		Global.Log("crafting", "Craft %s" % _selected_product, "Recipe", _selected_product, old_values, new_values, metadata, "success", "audit")

	_show_toast("Crafted %d x %s for %s" % [qty_to_make, _selected_product, target])

	# Close
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()


# ============================================================
# FEEDBACK
# ============================================================
func _show_toast(msg: String) -> void:
	var l = Label.new()
	l.text = msg
	l.add_theme_color_override("font_color", GREEN)
	l.add_theme_font_size_override("font_size", 50)
	l.modulate = Color(1, 1, 1, 0)
	add_child(l)
	l.global_position = Vector2(40, 40)
	var tw = create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.3)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.finished.connect(l.queue_free)


# ============================================================
# EXIT
# ============================================================
func _on_exit_pressed() -> void:
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()


# ============================================================
# LOGGING
# ============================================================
func _log(msg: String) -> void:
	print("[CraftingMenu] %s" % msg)



func _save_layout() -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://ui_settings.cfg")
	cfg.set_value("crafting_layout", "body_split", _body_split.split_offset)
	cfg.set_value("crafting_layout", "right_split", _right_split.split_offset)
	if _af_body_split:
		cfg.set_value("crafting_layout", "af_body_split", _af_body_split.split_offset)
	if _af_rolls_split:
		cfg.set_value("crafting_layout", "af_rolls_split", _af_rolls_split.split_offset)
	cfg.save("user://ui_settings.cfg")

func _load_layout() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		if cfg.has_section_key("crafting_layout", "body_split"):
			_body_split.split_offset = cfg.get_value("crafting_layout", "body_split", 0)
		if cfg.has_section_key("crafting_layout", "right_split"):
			_right_split.split_offset = cfg.get_value("crafting_layout", "right_split", 0)
		if _af_body_split and cfg.has_section_key("crafting_layout", "af_body_split"):
			_af_body_split.split_offset = cfg.get_value("crafting_layout", "af_body_split", 0)
		if _af_rolls_split and cfg.has_section_key("crafting_layout", "af_rolls_split"):
			_af_rolls_split.split_offset = cfg.get_value("crafting_layout", "af_rolls_split", 0)


# ═══════════════════════════════════════════════════════════════════════
#  TAB SWITCHING
# ═══════════════════════════════════════════════════════════════════════

func _style_tab_btn(btn: Button, active: bool) -> void:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = ACCENT if active else Color.TRANSPARENT
	sb.border_width_bottom = 2 if active else 0
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", ACCENT if active else MUTED)

func _switch_crafting_tab(tab: String) -> void:
	var is_recipes = (tab == "recipes")
	_body_split.visible = is_recipes
	_artifact_forge_panel.visible = not is_recipes
	_tab_recipes.button_pressed = is_recipes
	_tab_artifact.button_pressed = not is_recipes
	_style_tab_btn(_tab_recipes, is_recipes)
	_style_tab_btn(_tab_artifact, not is_recipes)
	if not is_recipes:
		_af_refresh_artifact_list()

	# Only Artisans can see the artifact tab
	if _tab_artifact:
		_tab_artifact.visible = (_get_active_role() == "Artisan")


# ═══════════════════════════════════════════════════════════════════════
#  ARTIFACT FORGE
# ═══════════════════════════════════════════════════════════════════════


func _build_artifact_forge() -> VBoxContainer:
	var FS = 50  # base font size for this panel (larger than normal)
	var FS_SM = 40
	var FS_LBL = 45
	var root = VBoxContainer.new()
	_artifact_forge_panel = root  # assign early so helpers can access metas
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)

	# ── Mode selection ──
	var mode_row = HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	root.add_child(mode_row)

	var mode_label = Label.new()
	mode_label.text = "Forge Mode:"
	mode_label.add_theme_font_size_override("font_size", FS)
	mode_label.add_theme_color_override("font_color", ACCENT)
	mode_row.add_child(mode_label)

	var mode_random = Button.new()
	mode_random.text = "Random Set (sacrifice 2)"
	mode_random.toggle_mode = true
	mode_random.button_pressed = true
	mode_random.add_theme_font_size_override("font_size", FS_SM)
	_style_chip(mode_random, true)
	mode_random.pressed.connect(func(): _af_set_mode("random"))
	mode_row.add_child(mode_random)

	var mode_selected = Button.new()
	mode_selected.text = "Choose Set (sacrifice 3)"
	mode_selected.toggle_mode = true
	mode_selected.button_pressed = false
	mode_selected.add_theme_font_size_override("font_size", FS_SM)
	_style_chip(mode_selected, false)
	mode_selected.pressed.connect(func(): _af_set_mode("selected"))
	mode_row.add_child(mode_selected)

	root.set_meta("mode_btns", [mode_random, mode_selected])

	# ── Set selection + bonus preview (only visible in "selected" mode) ──
	var set_section = VBoxContainer.new()
	set_section.name = "SetRow"
	set_section.visible = false
	set_section.add_theme_constant_override("separation", 6)
	root.add_child(set_section)

	var set_hbox = HBoxContainer.new()
	set_hbox.add_theme_constant_override("separation", 10)
	set_section.add_child(set_hbox)

	var set_label = Label.new()
	set_label.text = "Artifact Set:"
	set_label.add_theme_font_size_override("font_size", FS)
	set_label.add_theme_color_override("font_color", SEC)
	set_hbox.add_child(set_label)

	_af_set_dropdown = OptionButton.new()
	_af_set_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_af_set_dropdown.add_theme_font_size_override("font_size", FS_SM)
	var set_names = []
	for a in Global.ARTIFACTS.values():
		var sn = str(a.get("Artifact_Set", ""))
		if sn != "" and not set_names.has(sn):
			set_names.append(sn)
	set_names.sort()
	for sn in set_names:
		_af_set_dropdown.add_item(sn)
	_af_set_dropdown.item_selected.connect(func(_idx): _af_update_set_bonus_display())
	set_hbox.add_child(_af_set_dropdown)

	# Set bonus display
	var bonus_card = PanelContainer.new()
	bonus_card.name = "BonusCard"
	bonus_card.custom_minimum_size.y = 80
	var bsb = _make_card_stylebox(CARD)
	bsb.content_margin_top = 10
	bsb.content_margin_bottom = 10
	bsb.content_margin_left = 12
	bsb.content_margin_right = 12
	bonus_card.add_theme_stylebox_override("panel", bsb)
	bonus_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_section.add_child(bonus_card)

	var bonus_vbox = VBoxContainer.new()
	bonus_vbox.name = "BonusContent"
	bonus_vbox.add_theme_constant_override("separation", 6)
	bonus_card.add_child(bonus_vbox)

	# ── Main body: sacrifice picker (left) | rolls + target (right) ──
	_af_body_split = HSplitContainer.new()
	_af_body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_af_body_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_af_body_split.dragged.connect(func(_ofs): _save_layout())
	root.add_child(_af_body_split)

	# LEFT: Artifact sacrifice picker
	var picker_card = PanelContainer.new()
	picker_card.custom_minimum_size.x = 280
	picker_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_card.add_theme_stylebox_override("panel", _make_card_stylebox(PANEL))
	_af_body_split.add_child(picker_card)

	var picker_vbox = VBoxContainer.new()
	picker_vbox.add_theme_constant_override("separation", 8)
	picker_card.add_child(picker_vbox)

	var pick_title = Label.new()
	pick_title.text = "Artifacts to Sacrifice"
	pick_title.add_theme_font_size_override("font_size", FS)
	pick_title.add_theme_color_override("font_color", ACCENT)
	picker_vbox.add_child(pick_title)

	var cost_lbl = Label.new()
	cost_lbl.name = "CostLabel"
	cost_lbl.text = "Select 2 artifacts (Random mode)"
	cost_lbl.add_theme_font_size_override("font_size", FS_SM)
	cost_lbl.add_theme_color_override("font_color", MUTED)
	picker_vbox.add_child(cost_lbl)
	root.set_meta("cost_label", cost_lbl)

	var pick_scroll = ScrollContainer.new()
	pick_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	picker_vbox.add_child(pick_scroll)

	_af_artifact_list = VBoxContainer.new()
	_af_artifact_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_af_artifact_list.add_theme_constant_override("separation", 4)
	pick_scroll.add_child(_af_artifact_list)

	# RIGHT: rolls (top) | target+forge (bottom) via VSplitContainer
	_af_rolls_split = VSplitContainer.new()
	_af_rolls_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_af_rolls_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_af_rolls_split.dragger_visibility = SplitContainer.DRAGGER_VISIBLE
	_af_rolls_split.dragged.connect(func(_ofs): _save_layout())
	_af_body_split.add_child(_af_rolls_split)

	# TOP of right: Dice rolls panel
	var rolls_card = PanelContainer.new()
	rolls_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolls_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolls_card.add_theme_stylebox_override("panel", _make_card_stylebox(PANEL))
	_af_rolls_split.add_child(rolls_card)

	var rolls_scroll = ScrollContainer.new()
	rolls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolls_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolls_card.add_child(rolls_scroll)

	var rolls_vbox = VBoxContainer.new()
	rolls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolls_vbox.add_theme_constant_override("separation", 12)
	rolls_scroll.add_child(rolls_vbox)

	_af_rolls.clear()

	# Step 1: Piece Type
	var step1 = Label.new()
	step1.text = "Step 1: Roll Piece Type"
	step1.add_theme_font_size_override("font_size", FS)
	step1.add_theme_color_override("font_color", ACCENT)
	rolls_vbox.add_child(step1)

	var r1 = HBoxContainer.new()
	r1.add_theme_constant_override("separation", 20)
	rolls_vbox.add_child(r1)
	_af_rolls.append(_af_spin_field(r1, "D12", 1, 12, FS_SM))
	_af_rolls.append(_af_spin_field(r1, "D20", 1, 20, FS_SM))

	# Step 2: Substat 1
	var step2 = Label.new()
	step2.name = "Step2Label"
	step2.text = "Step 2: Roll Substat 1"
	step2.add_theme_font_size_override("font_size", FS)
	step2.add_theme_color_override("font_color", ACCENT)
	rolls_vbox.add_child(step2)
	root.set_meta("step2_label", step2)

	var r2 = HBoxContainer.new()
	r2.add_theme_constant_override("separation", 20)
	rolls_vbox.add_child(r2)
	var s1_stat = _af_spin_field(r2, "D8", 1, 8, FS_SM)
	_af_rolls.append(s1_stat)
	root.set_meta("s1_stat_label", s1_stat.get_parent().get_child(0))
	_af_rolls.append(_af_spin_field(r2, "D12", 1, 12, FS_SM))
	_af_rolls.append(_af_spin_field(r2, "D20", 1, 20, FS_SM))

	# Step 3: Substat 2 (always shown, disabled if D20 < 13)
	var step3 = Label.new()
	step3.text = "Step 3: Roll Substat 2 (if D20 >= 13)"
	step3.name = "Step3Label"
	step3.add_theme_font_size_override("font_size", FS)
	step3.add_theme_color_override("font_color", MUTED)
	rolls_vbox.add_child(step3)
	root.set_meta("step3_label", step3)

	var r3 = HBoxContainer.new()
	r3.add_theme_constant_override("separation", 20)
	r3.name = "Sub2Row"
	rolls_vbox.add_child(r3)
	root.set_meta("sub2_row", r3)

	var sub2_s1 = _af_spin_field(r3, "D8", 1, 8, FS_SM)
	sub2_s1.editable = false
	_af_rolls.append(sub2_s1)
	root.set_meta("s2_stat_label", sub2_s1.get_parent().get_child(0))
	var sub2_s2 = _af_spin_field(r3, "D12", 1, 12, FS_SM)
	sub2_s2.editable = false
	_af_rolls.append(sub2_s2)
	var sub2_s3 = _af_spin_field(r3, "D20", 1, 20, FS_SM)
	sub2_s3.editable = false
	_af_rolls.append(sub2_s3)

	# Wire D12 piece type to update stat dice labels (D8 vs D10)
	_af_rolls[0].value_changed.connect(func(_v): _af_update_stat_dice_labels())
	# Wire D20 substats to enable/disable step 3
	_af_rolls[1].value_changed.connect(func(_v): _af_update_sub2_vis())

	# BOTTOM of right: Target + Forge button
	var target_card = PanelContainer.new()
	target_card.custom_minimum_size.y = 110
	target_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_card.add_theme_stylebox_override("panel", _make_card_stylebox(PANEL))
	_af_rolls_split.add_child(target_card)

	var target_vbox = VBoxContainer.new()
	target_vbox.add_theme_constant_override("separation", 10)
	target_card.add_child(target_vbox)

	var target_row = HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 10)
	target_vbox.add_child(target_row)

	var target_lbl = Label.new()
	target_lbl.text = "Give to:"
	target_lbl.add_theme_font_size_override("font_size", FS)
	target_lbl.add_theme_color_override("font_color", SEC)
	target_row.add_child(target_lbl)

	_af_target_dropdown = OptionButton.new()
	_af_target_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_af_target_dropdown.add_theme_font_size_override("font_size", FS_SM)
	_af_target_dropdown.add_item(Global.ACTIVE_USER_NAME + " (me)")
	for pname in Global.PartyCharacters:
		if pname != Global.ACTIVE_USER_NAME:
			_af_target_dropdown.add_item(pname)
	target_row.add_child(_af_target_dropdown)

	_af_forge_btn = Button.new()
	_af_forge_btn.text = "FORGE ARTIFACT"
	_af_forge_btn.custom_minimum_size = Vector2(0, 48)
	_af_forge_btn.add_theme_font_size_override("font_size", FS)
	_af_forge_btn.disabled = true
	var forge_sb = StyleBoxFlat.new()
	forge_sb.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.1)
	forge_sb.border_color = ACCENT
	forge_sb.set_border_width_all(2)
	forge_sb.set_corner_radius_all(6)
	forge_sb.content_margin_left = 24
	forge_sb.content_margin_right = 24
	forge_sb.content_margin_top = 10
	forge_sb.content_margin_bottom = 10
	_af_forge_btn.add_theme_stylebox_override("normal", forge_sb)
	var forge_hover = forge_sb.duplicate()
	forge_hover.bg_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.2)
	_af_forge_btn.add_theme_stylebox_override("hover", forge_hover)
	var forge_dis = forge_sb.duplicate()
	forge_dis.bg_color = INSET
	forge_dis.border_color = BORDER
	_af_forge_btn.add_theme_stylebox_override("disabled", forge_dis)
	_af_forge_btn.add_theme_color_override("font_color", ACCENT)
	_af_forge_btn.add_theme_color_override("font_disabled_color", MUTED)
	_af_forge_btn.pressed.connect(_af_on_forge_pressed)
	target_vbox.add_child(_af_forge_btn)

	# Initialize stat dice labels based on default piece type
	_af_update_stat_dice_labels()

	return root


func _af_spin_field(parent: Node, hint: String, min_val: int, max_val: int, fs: int = 15) -> SpinBox:
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	parent.add_child(vb)
	var l = Label.new()
	l.text = hint
	l.add_theme_font_size_override("font_size", 23)
	l.add_theme_color_override("font_color", MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 140
	vb.add_child(l)
	var sb = SpinBox.new()
	sb.min_value = min_val
	sb.max_value = max_val
	sb.value = min_val
	sb.custom_minimum_size.x = 90
	sb.add_theme_font_size_override("font_size", fs)
	vb.add_child(sb)
	return sb


func _af_set_mode(mode: String) -> void:
	_af_mode = mode
	_af_selected_artifacts.clear()
	var btns = _artifact_forge_panel.get_meta("mode_btns", [])
	if btns.size() == 2:
		_style_chip(btns[0], mode == "random")
		btns[0].button_pressed = (mode == "random")
		_style_chip(btns[1], mode == "selected")
		btns[1].button_pressed = (mode == "selected")
	var set_row = _artifact_forge_panel.get_node_or_null("SetRow")
	if set_row:
		set_row.visible = (mode == "selected")
		if mode == "selected":
			_af_update_set_bonus_display()
	var cost_lbl = _artifact_forge_panel.get_meta("cost_label", null)
	if cost_lbl:
		var needed = 2 if mode == "random" else 3
		cost_lbl.text = "Select %d artifacts (%s mode)" % [needed, "Random" if mode == "random" else "Selected Set"]
	_af_refresh_artifact_list()


func _af_update_stat_dice_labels() -> void:
	# Determine if the current D12 piece roll gives a special piece (D10) or basic (D8)
	var d12 = int(_af_rolls[0].value)
	var piece = _af_resolve_piece(d12)
	var is_special = piece in ["Sands of Time", "Goblet of Space", "Circlet of Principles"]
	var die_text = "D10" if is_special else "D8"
	var die_max = 10 if is_special else 8

	# Update step 2 label
	var step2_lbl = _artifact_forge_panel.get_meta("step2_label", null)
	if step2_lbl:
		step2_lbl.text = "Step 2: Roll Substat 1 (%s)" % die_text

	# Update substat 1 stat spin label + max
	var s1_lbl = _artifact_forge_panel.get_meta("s1_stat_label", null)
	if s1_lbl:
		s1_lbl.text = die_text
	_af_rolls[2].max_value = die_max
	if _af_rolls[2].value > die_max:
		_af_rolls[2].value = die_max

	# Update substat 2 stat spin label + max
	var s2_lbl = _artifact_forge_panel.get_meta("s2_stat_label", null)
	if s2_lbl:
		s2_lbl.text = die_text
	_af_rolls[5].max_value = die_max
	if _af_rolls[5].value > die_max:
		_af_rolls[5].value = die_max


func _af_update_sub2_vis() -> void:
	var has_two = int(_af_rolls[1].value) >= 13
	var step3_lbl = _artifact_forge_panel.get_meta("step3_label", null)
	if step3_lbl:
		step3_lbl.add_theme_color_override("font_color", ACCENT if has_two else MUTED)
	# Enable/disable the sub2 spinboxes (indices 5, 6, 7)
	for i in [5, 6, 7]:
		if i < _af_rolls.size():
			_af_rolls[i].editable = has_two


func _af_update_set_bonus_display() -> void:
	var set_row = _artifact_forge_panel.get_node_or_null("SetRow")
	if set_row == null:
		return
	var bonus_card = set_row.get_node_or_null("BonusCard")
	if bonus_card == null:
		return
	var bonus_content = bonus_card.get_node_or_null("BonusContent")
	if bonus_content == null:
		return
	for c in bonus_content.get_children():
		c.queue_free()

	var sel_set = _af_set_dropdown.get_item_text(_af_set_dropdown.selected)
	var two_pc = ""
	var four_pc = ""
	for a in Global.ARTIFACTS.values():
		if str(a.get("Artifact_Set", "")) == sel_set:
			if str(a.get("Bonus_Type", "")) == "2" or int(a.get("Bonus_Type", 0)) == 2:
				two_pc = str(a.get("Bonus_Effect", a.get("Effect", "")))
			elif str(a.get("Bonus_Type", "")) == "4" or int(a.get("Bonus_Type", 0)) == 4:
				four_pc = str(a.get("Bonus_Effect", a.get("Effect", "")))

	if two_pc != "":
		var l2 = Label.new()
		l2.text = "2pc: " + two_pc
		l2.add_theme_font_size_override("font_size", 27)
		l2.add_theme_color_override("font_color", GREEN)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD
		l2.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bonus_content.add_child(l2)
	if four_pc != "":
		var l4 = Label.new()
		l4.text = "4pc: " + four_pc
		l4.add_theme_font_size_override("font_size", 27)
		l4.add_theme_color_override("font_color", SEC)
		l4.autowrap_mode = TextServer.AUTOWRAP_WORD
		l4.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bonus_content.add_child(l4)


func _af_refresh_artifact_list() -> void:
	for c in _af_artifact_list.get_children():
		c.queue_free()
	_af_selected_artifacts.clear()

	for rid in Global.CHARACTER_ARTIFACTS.keys():
		var art = Global.CHARACTER_ARTIFACTS[rid]
		if str(art.get("Owner", "")) != Global.ACTIVE_USER_NAME:
			continue
		if art.get("Equipped", false) == true:
			continue

		var art_id = str(rid)
		var set_name = str(art.get("Artifact_Set", art.get("Set_Name", "")))
		var art_type = str(art.get("Type", ""))
		var s1t = str(art.get("Stat_1_Type", ""))
		var s1v = float(art.get("Stat_1_Value", 0) if art.get("Stat_1_Value") != null else 0)
		var s2t = str(art.get("Stat_2_Type", ""))
		var s2v = float(art.get("Stat_2_Value", 0) if art.get("Stat_2_Value") != null else 0)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_af_artifact_list.add_child(row)

		var check = CheckBox.new()
		check.add_theme_font_size_override("font_size", 29)
		check.toggled.connect(func(pressed):
			if pressed:
				_af_selected_artifacts.append(art_id)
			else:
				_af_selected_artifacts.erase(art_id)
			_af_update_forge_enabled()
		)
		row.add_child(check)

		# Primary display: stats (most important info)
		var stat_text = s1t.replace("_", " ") + ": " + ("+" if s1v >= 0 else "") + str(snapped(s1v, 0.01))
		if s2t != "":
			stat_text += "  |  " + s2t.replace("_", " ") + ": " + ("+" if s2v >= 0 else "") + str(snapped(s2v, 0.01))

		var stat_lbl = Label.new()
		stat_lbl.text = stat_text
		stat_lbl.add_theme_font_size_override("font_size", 29)
		# Color: green if both positive, red if both negative, default otherwise
		if s1v > 0 and (s2v > 0 or s2t == ""):
			stat_lbl.add_theme_color_override("font_color", GREEN)
		elif s1v < 0 and (s2v < 0 or s2t == ""):
			stat_lbl.add_theme_color_override("font_color", RED)
		else:
			stat_lbl.add_theme_color_override("font_color", TEXT)
		stat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_lbl.clip_text = true
		stat_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		# Tooltip: full artifact details
		stat_lbl.tooltip_text = "%s\n%s\n%s: %s\n%s" % [
			set_name, art_type,
			s1t.replace("_", " "), str(snapped(s1v, 0.01)),
			(s2t.replace("_", " ") + ": " + str(snapped(s2v, 0.01))) if s2t != "" else "No second stat"
		]
		row.add_child(stat_lbl)

	_af_update_forge_enabled()


func _af_update_forge_enabled() -> void:
	var needed = 2 if _af_mode == "random" else 3
	_af_forge_btn.disabled = _af_selected_artifacts.size() < needed


func _af_on_forge_pressed() -> void:
	var needed = 2 if _af_mode == "random" else 3
	if _af_selected_artifacts.size() < needed:
		return

	var has_good = false
	for art_id in _af_selected_artifacts:
		var art = Global.CHARACTER_ARTIFACTS.get(art_id, {})
		var s1v = float(art.get("Stat_1_Value", 0) if art.get("Stat_1_Value") != null else 0)
		var s2v = float(art.get("Stat_2_Value", 0) if art.get("Stat_2_Value") != null else 0)
		if s1v > 0.5 and s2v > 0.5:
			has_good = true
			break

	var warning = "This will PERMANENTLY DESTROY %d artifacts.\nThis cannot be undone." % needed
	if has_good:
		warning = "[b][color=#ef4444]WARNING: You selected a HIGH-VALUE artifact\nwith two strong positive stats![/color][/b]\n\n" + warning + "\n\n[b]Are you absolutely sure?[/b]"

	_af_show_confirm(warning, _af_execute_forge)


func _af_show_confirm(message: String, on_confirm: Callable) -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 50
	add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 240)
	var sb = _make_card_stylebox(PANEL)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Confirm Artifact Forge"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", RED)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg = RichTextLabel.new()
	msg.bbcode_enabled = true
	msg.fit_content = true
	msg.scroll_active = false
	msg.add_theme_font_size_override("normal_font_size", 16)
	msg.add_theme_color_override("default_color", TEXT)
	msg.text = message
	vbox.add_child(msg)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size.x = 130
	cancel.add_theme_font_size_override("font_size", 29)
	_style_chip(cancel, false)
	cancel.pressed.connect(func(): overlay.queue_free())
	btn_row.add_child(cancel)

	var confirm = Button.new()
	confirm.text = "FORGE"
	confirm.custom_minimum_size.x = 130
	confirm.add_theme_font_size_override("font_size", 29)
	var csb = StyleBoxFlat.new()
	csb.bg_color = Color(RED.r, RED.g, RED.b, 0.15)
	csb.border_color = RED
	csb.set_border_width_all(2)
	csb.set_corner_radius_all(6)
	csb.content_margin_left = 20
	csb.content_margin_right = 20
	csb.content_margin_top = 8
	csb.content_margin_bottom = 8
	confirm.add_theme_stylebox_override("normal", csb)
	confirm.add_theme_color_override("font_color", RED)
	confirm.pressed.connect(func():
		overlay.queue_free()
		on_confirm.call()
	)
	btn_row.add_child(confirm)


func _af_execute_forge() -> void:
	var d12_type = int(_af_rolls[0].value)
	var d20_substats = int(_af_rolls[1].value)
	var s1_stat_die = int(_af_rolls[2].value)
	var s1_sign_die = int(_af_rolls[3].value)
	var s1_val_die = int(_af_rolls[4].value)
	var s2_stat_die = int(_af_rolls[5].value)
	var s2_sign_die = int(_af_rolls[6].value)
	var s2_val_die = int(_af_rolls[7].value)

	var target = _af_target_dropdown.get_item_text(_af_target_dropdown.selected)
	if target.ends_with(" (me)"):
		target = Global.ACTIVE_USER_NAME

	# Determine set
	var set_name = ""
	if _af_mode == "selected":
		set_name = _af_set_dropdown.get_item_text(_af_set_dropdown.selected)
	else:
		# Random: pick from all sets randomly
		var all_sets = []
		for a in Global.ARTIFACTS.values():
			var sn = str(a.get("Artifact_Set", ""))
			if sn != "" and not all_sets.has(sn):
				all_sets.append(sn)
		all_sets.sort()
		if all_sets.size() > 0:
			set_name = all_sets[randi() % all_sets.size()]

	var piece_type = _af_resolve_piece(d12_type)
	var has_two = d20_substats >= 13

	var stat_1_type = _af_resolve_stat(s1_stat_die, piece_type)
	var stat_1_sign = 1.0 if s1_sign_die >= 7 else -1.0
	var stat_1_value = stat_1_sign * s1_val_die * 0.1

	var stat_2_type = ""
	var stat_2_value = 0.0
	if has_two:
		stat_2_type = _af_resolve_stat(s2_stat_die, piece_type)
		var stat_2_sign = 1.0 if s2_sign_die >= 7 else -1.0
		stat_2_value = stat_2_sign * s2_val_die * 0.1

	# Delete sacrificed artifacts
	for art_id in _af_selected_artifacts:
		Global.Remove_Record("Character_Artifacts", int(art_id))

	# Insert new
	Global.Insert("Character_Artifacts",
		["Artifact_Set", "Owner", "Type", "Equipped", "Rarity", "Stat_1_Type", "Stat_1_Value", "Stat_2_Type", "Stat_2_Value"],
		[set_name, target, piece_type, false, 5, stat_1_type, snapped(stat_1_value, 0.01), stat_2_type, snapped(stat_2_value, 0.01)]
	)

	Global.Log("crafting", "artifact_forge", "Artifact", "",
		{"sacrificed": _af_selected_artifacts.duplicate(), "mode": _af_mode},
		{"set": set_name, "type": piece_type, "stat1": stat_1_type, "val1": stat_1_value, "stat2": stat_2_type, "val2": stat_2_value, "target": target},
		{"source": "CraftingMenu/ArtifactForge"}, "success", "audit"
	)

	var msg = "Forged %s %s for %s: %s %.2f" % [set_name, piece_type, target, stat_1_type, stat_1_value]
	if has_two:
		msg += ", %s %.2f" % [stat_2_type, stat_2_value]
	_show_toast(msg)

	_af_selected_artifacts.clear()
	_af_refresh_artifact_list()


func _af_resolve_piece(d12: int) -> String:
	if d12 <= 3: return "Flower of Life"
	if d12 <= 6: return "Feather of Death"
	if d12 <= 8: return "Sands of Time"
	if d12 <= 10: return "Goblet of Space"
	return "Circlet of Principles"


func _af_resolve_stat(die_roll: int, piece_type: String) -> String:
	var is_special = piece_type in ["Sands of Time", "Goblet of Space", "Circlet of Principles"]
	if is_special:
		# D10: 1-2 HP, 3-4 ATK, 5-7 DEF, 8-9 EM, 10 special
		match die_roll:
			1, 2: return "Health"
			3, 4: return "Attack"
			5, 6, 7: return "Defense"
			8, 9: return "Elemental_Mastery"
			10:
				match piece_type:
					"Sands of Time": return "Energy_Recharge"
					"Goblet of Space": return "Universal_Added_Damage_Bonus"
					"Circlet of Principles": return "Critical_Damage"
	else:
		# D8: 1-2 HP, 3-4 ATK, 5-6 DEF, 7-8 EM
		match die_roll:
			1, 2: return "Health"
			3, 4: return "Attack"
			5, 6: return "Defense"
			7, 8: return "Elemental_Mastery"
	return "Health"
