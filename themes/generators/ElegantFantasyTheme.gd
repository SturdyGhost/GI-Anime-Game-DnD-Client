# ElegantFantasyTheme.gd — ThemeGen generator (Godot 4.4.1)
# Output: res://themes/generated/ElegantFantasy.tres

@tool
extends ProgrammaticTheme

# ===== Palette =====
const COL_BG            = Color("#1E2235")
const COL_PANEL         = Color("#242a41d2")
const COL_TEXT          = Color("#FFFFFF")   # default white text
const COL_TEXT_DIM      = Color("#C9CFDE")
const COL_TEXT_DISABLED = Color("#8A90A7")

const COL_GOLD          = Color("#E2C290")  # interactive + borders
const COL_BLUE          = Color("#3C445C")  # inputs / tracks
const COL_BLUE_PRESS    = Color("#2E3950")  # darker blue

const COL_ACCENT_CYAN   = Color("#8BD3DD")  # focus ring
const COL_ERROR         = Color("#D97E7E")

# ===== Metrics =====
const RADIUS_LG  = 14
const RADIUS_SM  = 10
const BORDER_W   = 1
const PAD        = 10
const PAD_SM     = 8

# ===== Typography (doubled) =====
const FONT_PATH          = "res://UI/zh-cn.ttf"
const FONT_SIZE_BASE     = 32
const FONT_SIZE_TITLE    = 40
const FONT_SIZE_SMALL    = 28
const FONT_OUTLINE_SIZE  = 8               # thick outline
const FONT_OUTLINE_COLOR = Color(0, 0, 0)  # black

func setup() -> void:
	var out_dir := "res://themes/generated"
	DirAccess.make_dir_recursive_absolute(out_dir)
	set_save_path(out_dir + "/ElegantFantasy.tres")

func define_theme() -> void:
	# Derived colors (runtime)
	var col_gold_hover = COL_GOLD.lightened(0.08)
	var col_gold_press = COL_GOLD.darkened(0.10)
	var col_blue_press = COL_BLUE_PRESS

	# 1) Default font + size
	var font_res := ResourceLoader.load(FONT_PATH)
	if font_res:
		define_default_font(font_res)
	define_default_font_size(FONT_SIZE_BASE)

	# 2) Panels / Containers (blue panel)
	var panel_style = stylebox_flat({
		bg_color = COL_PANEL,
		border_color = col_blue_press.darkened(0.10),
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_LG),
		content_margins_ = content_margins(PAD)
	})
	define_style("Panel", { panel = panel_style })
	define_style("PanelContainer", { panel = panel_style })

	# NEW: Panel hover variant with thick gold outline
	var panel_hover = stylebox_flat({
		bg_color = COL_PANEL,
		border_color = COL_GOLD,
		border_ = border_width(6),                       # thick outline on hover
		corner_radius_ = corner_radius(RADIUS_LG),
		content_margins_ = content_margins(PAD)
	})
	define_variant_style("HoverPanel", "Panel", { panel = panel_hover })
	# Usage in code:
	#   panel.theme_type_variation = "HoverPanel" on mouse enter, "" on exit.

	# --- Apply white text + black outline to classes that support these theme keys ---
	# (Avoid SpinBox and TabContainer: they don't own font_* theme items.)
	var TEXT_CLASSES := [
		"Label","Button","OptionButton","CheckBox","CheckButton",
		"LineEdit","ProgressBar","TooltipLabel","Tree","ItemList",
		"TabBar","RichTextLabel"  # RichTextLabel uses default_color (set below)
	]
	for cls in TEXT_CLASSES:
		define_style(cls, {
			font_color = COL_TEXT,
			font_outline_color = FONT_OUTLINE_COLOR,
			outline_size = FONT_OUTLINE_SIZE
		})

	# 3) Labels / Tooltips (explicit)
	define_style("Label", {
		font_color = COL_TEXT,
		font_outline_color = FONT_OUTLINE_COLOR,
		outline_size = FONT_OUTLINE_SIZE
	})
	define_variant_style("Title", "Label", { font_size = FONT_SIZE_TITLE })

	define_style("RichTextLabel", {
		default_color = COL_TEXT  # outline not themed on RTL; content dictates it
	})
	define_style("TooltipLabel", {
		font_color = COL_TEXT,
		font_size = FONT_SIZE_SMALL,
		font_outline_color = FONT_OUTLINE_COLOR,
		outline_size = FONT_OUTLINE_SIZE
	})
	define_style("TooltipPanel", {
		panel = stylebox_flat({
			bg_color = COL_PANEL.darkened(0.10),
			border_color = COL_GOLD,
			border_ = border_width(1),
			corner_radius_ = corner_radius(RADIUS_SM),
			content_margins_ = content_margins(PAD_SM)
		})
	})

	# 4) Buttons (gold) + cyan focus
	var btn_base = stylebox_flat({
		bg_color = COL_GOLD,
		border_color = COL_GOLD.darkened(0.35),
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_LG),
		content_margins_ = content_margins(PAD)
	})
	var btn_hover   = inherit(btn_base, {
		bg_color = col_gold_hover,
		border_ = border_width(6)   # NEW: thicker border on hover for outline pop
	})
	var btn_pressed = inherit(btn_base, { bg_color = col_gold_press })
	var btn_disabled= inherit(btn_base, { bg_color = COL_GOLD.darkened(0.25) })

	define_style("Button", {
		normal = btn_base,
		hover = btn_hover,
		pressed = btn_pressed,
		disabled = btn_disabled,
		font_color = COL_TEXT,
		font_hover_color = COL_TEXT,
		font_pressed_color = COL_TEXT,
		font_disabled_color = COL_TEXT_DISABLED,
		font_outline_color = FONT_OUTLINE_COLOR,
		outline_size = FONT_OUTLINE_SIZE
	})
	# Variants

	# 5) LineEdit (blue with pale-gold border)
	var le_normal = stylebox_flat({
		bg_color = COL_BLUE,
		border_color = COL_GOLD,            # pale-gold border
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_SM),
		content_margins_ = content_margins(PAD, PAD_SM, PAD, PAD_SM)
	})
	var le_focus  = inherit(le_normal, { border_color = COL_GOLD })
	define_style("LineEdit", {
		normal = le_normal,
		focus = le_focus,
		read_only = le_normal,
		font_color = COL_TEXT,
		font_uneditable_color = COL_TEXT_DIM,
		clear_button_color = COL_TEXT_DIM,
		font_outline_color = FONT_OUTLINE_COLOR,
		outline_size = FONT_OUTLINE_SIZE
	})

	# 6) OptionButton (gold like Button)
	define_style("OptionButton", {
		normal = btn_base,
		hover = btn_hover,
		pressed = btn_pressed,
		disabled = btn_disabled,
		font_color = COL_TEXT,
		font_outline_color = FONT_OUTLINE_COLOR,
		outline_size = FONT_OUTLINE_SIZE
	})

	# 7) ProgressBar (blue bg with pale-gold border, gold fill, white text+outline)
	var pb_bg   = stylebox_flat({
		bg_color = COL_BLUE_PRESS,
		border_color = COL_GOLD,            # pale-gold border
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_SM)
	})
	var pb_fill = stylebox_flat({ bg_color = COL_GOLD, corner_radius_ = corner_radius(RADIUS_SM) })
	define_style("ProgressBar", {
		background = pb_bg,
		fill = pb_fill,
		font_color = COL_TEXT,
		font_outline_color = FONT_OUTLINE_COLOR,
		outline_size = FONT_OUTLINE_SIZE
	})

	# 8) Sliders (blue track with pale-gold border; gold filled area)
	var slider_track = stylebox_flat({
		bg_color = COL_BLUE,
		border_color = COL_GOLD,            # pale-gold border
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_SM),
		content_margins_ = content_margins(4)
	})
	var grab_area    = stylebox_flat({ bg_color = COL_GOLD, corner_radius_ = corner_radius(RADIUS_SM), content_margins_ = content_margins(6) })
	var grab_area_h  = inherit(grab_area, { bg_color = col_gold_hover })
	define_style("HSlider", { slider = slider_track, grabber_area = grab_area, grabber_area_highlight = grab_area_h })
	define_style("VSlider", { slider = slider_track, grabber_area = grab_area, grabber_area_highlight = grab_area_h })

	# 9) ScrollBars (blue track with pale-gold border; gold grabber)
	var sb_track = stylebox_flat({
		bg_color = COL_BLUE.darkened(0.20),
		border_color = COL_GOLD,            # pale-gold border
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_SM),
		content_margins_ = content_margins(4)
	})
	var sb_grab  = stylebox_flat({
		bg_color = COL_GOLD,
		border_color = COL_GOLD.darkened(0.35),
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_SM),
		content_margins_ = content_margins(6)
	})
	var sb_grab_h= inherit(sb_grab, { bg_color = col_gold_hover })
	var sb_grab_p= inherit(sb_grab, { bg_color = col_gold_press })
	define_style("HScrollBar", { scroll = sb_track, grabber = sb_grab, grabber_highlight = sb_grab_h, grabber_pressed = sb_grab_p })
	define_style("VScrollBar", { scroll = sb_track, grabber = sb_grab, grabber_highlight = sb_grab_h, grabber_pressed = sb_grab_p })

	# 10) Tabs (blue tabs with pale-gold border)
	var tab_unsel = stylebox_flat({
		bg_color = COL_BLUE,
		border_color = COL_GOLD,            # pale-gold border
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_SM),
		content_margins_ = content_margins(PAD_SM)
	})
	var tab_sel   = stylebox_flat({
		bg_color = col_blue_press,
		border_color = COL_GOLD,            # pale-gold border
		border_ = border_width(BORDER_W),
		corner_radius_ = corner_radius(RADIUS_SM),
		content_margins_ = content_margins(PAD_SM)
	})
	define_style("TabBar", { tab_unselected = tab_unsel, tab_selected = tab_sel })
