extends AcceptDialog

@onready var server_field: LineEdit = $VBoxContainer/ServerField
@onready var volume_slider: HSlider = $VBoxContainer/VolumeRow/VolumeSlider
@onready var volume_label: Label = $VBoxContainer/VolumeRow/VolumeValue
@onready var sfx_slider: HSlider = $VBoxContainer/SFXRow/SFXSlider
@onready var sfx_label: Label = $VBoxContainer/SFXRow/SFXValue
@onready var font_slider: HSlider = $VBoxContainer/FontRow/FontSlider
@onready var font_label: Label = $VBoxContainer/FontRow/FontValue
@onready var font_title: Label = $VBoxContainer/FontLabel
@onready var dylan_slider: HSlider = $VBoxContainer/DylanRow/DylanSlider
@onready var dylan_label: Label = $VBoxContainer/DylanRow/DylanValue

const SETTINGS_PATH = "user://ui_settings.cfg"

# Sizes Dylan's Slider multiplies from. The font base is read off the theme the
# first time it's needed rather than hardcoded — hardcoding it made the row
# render SMALLER than its neighbours at 100%.
const DYLAN_BASE_SLIDER_H := 16.0
const DYLAN_BASE_VALUE_W := 60.0
var _row_base_font: int = 0

## The unscaled grabber texture, cached the first time we enlarge it so we can
## keep scaling from the original instead of compounding a resized copy.
var _grabber_base: Texture2D = null

func _ready() -> void:
	title = "Settings"
	if NetworkManager.is_host:
		server_field.text = "Hosting on port %d" % NetworkManager.DEFAULT_PORT
		if NetworkManager.public_ip != "":
			server_field.text += " (Public IP: %s)" % NetworkManager.public_ip
	elif NetworkManager.is_connected_to_host:
		server_field.text = "Connected to host"
	else:
		server_field.text = "Not connected"

	server_field.editable = false
	confirmed.connect(_on_confirmed)

	# Volume slider
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = _load_setting("audio", "music_volume", 0.0)
	_apply_volume(volume_slider.value)
	_update_volume_label(volume_slider.value)
	volume_slider.value_changed.connect(_on_volume_changed)

	# SFX slider
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.step = 1.0
	sfx_slider.value = _load_setting("audio", "sfx_volume", 50.0)
	_apply_sfx_volume(sfx_slider.value)
	_update_sfx_label(sfx_slider.value)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	# Font scale slider (50% to 150%, default 100%)
	font_slider.min_value = 50.0
	font_slider.max_value = 150.0
	font_slider.step = 5.0
	font_slider.value = _load_setting("ui", "font_scale", 100.0)
	_update_font_label(font_slider.value)
	font_slider.value_changed.connect(_on_font_scale_changed)

	# Dylan's Slider (100% to 400%, default 100%)
	dylan_slider.min_value = 100.0
	dylan_slider.max_value = 400.0
	dylan_slider.step = 10.0
	dylan_slider.value = _load_setting("ui", "dylan_scale", 100.0)
	_update_dylan_label(dylan_slider.value)
	_apply_dylan_scale(dylan_slider.value)
	dylan_slider.value_changed.connect(_on_dylan_scale_changed)


# ── Volume ──

func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_update_volume_label(value)
	_save_setting("audio", "music_volume", value)


func _apply_volume(value: float) -> void:
	# Ensure Music bus exists
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	var bus_idx = AudioServer.get_bus_index("Music")
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))


func _update_volume_label(value: float) -> void:
	volume_label.text = "Muted" if value <= 0.0 else "%d%%" % int(value)


# ── SFX Volume ──

func _on_sfx_changed(value: float) -> void:
	_apply_sfx_volume(value)
	_update_sfx_label(value)
	_save_setting("audio", "sfx_volume", value)


func _apply_sfx_volume(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx == -1:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))


func _update_sfx_label(value: float) -> void:
	sfx_label.text = "Muted" if value <= 0.0 else "%d%%" % int(value)


static func load_and_apply_sfx_volume() -> void:
	var cfg = ConfigFile.new()
	var vol = 50.0
	if cfg.load(SETTINGS_PATH) == OK:
		vol = cfg.get_value("audio", "sfx_volume", 50.0)
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx == -1:
		return
	if vol <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(vol / 100.0))


# ── Font Scale ──

func _on_font_scale_changed(value: float) -> void:
	_update_font_label(value)
	_save_setting("ui", "font_scale", value)
	apply_font_scale(value)


func _update_font_label(value: float) -> void:
	font_label.text = "%d%%" % int(value)


# ── Dylan's Slider ──
# The Text Size slider above only takes effect on UI built after it changes, so
# from where Dylan sits it does nothing at all. This slider does something very
# visible: it makes THAT slider bigger. That is its entire purpose.

func _on_dylan_scale_changed(value: float) -> void:
	_update_dylan_label(value)
	_save_setting("ui", "dylan_scale", value)
	_apply_dylan_scale(value)


func _update_dylan_label(value: float) -> void:
	dylan_label.text = "%d%%" % int(value)


## Grow the Text Size row — its heading, its readout and the slider itself.
func _apply_dylan_scale(value: float) -> void:
	var s: float = clampf(value / 100.0, 1.0, 4.0)

	if _row_base_font <= 0:
		_row_base_font = font_title.get_theme_font_size("font_size")
		if _row_base_font <= 0:
			_row_base_font = ThemeDB.fallback_font_size

	if is_equal_approx(s, 1.0):
		# Back to untouched: let the row inherit the theme like every other row.
		font_title.remove_theme_font_size_override("font_size")
		font_label.remove_theme_font_size_override("font_size")
	else:
		var fs: int = maxi(int(_row_base_font * s), 8)
		font_title.add_theme_font_size_override("font_size", fs)
		font_label.add_theme_font_size_override("font_size", fs)

	font_label.custom_minimum_size.x = DYLAN_BASE_VALUE_W * s
	font_slider.custom_minimum_size.y = DYLAN_BASE_SLIDER_H * s
	_scale_grabber(font_slider, s)


## The default theme draws a slider's grabber from a texture, so the only way to
## make it physically bigger is to hand it a bigger texture.
func _scale_grabber(slider: HSlider, s: float) -> void:
	if _grabber_base == null:
		_grabber_base = slider.get_theme_icon("grabber", "HSlider")
	if _grabber_base == null:
		return

	if is_equal_approx(s, 1.0):
		slider.remove_theme_icon_override("grabber")
		slider.remove_theme_icon_override("grabber_highlight")
		return

	var img: Image = _grabber_base.get_image()
	if img == null:
		return
	img = img.duplicate()
	img.resize(
		maxi(int(img.get_width() * s), 1),
		maxi(int(img.get_height() * s), 1),
		Image.INTERPOLATE_LANCZOS
	)
	var tex := ImageTexture.create_from_image(img)
	slider.add_theme_icon_override("grabber", tex)
	slider.add_theme_icon_override("grabber_highlight", tex)


static func apply_font_scale(scale_percent: float) -> void:
	var scale = scale_percent / 100.0
	scale = clampf(scale, 0.5, 1.5)
	ThemeDB.fallback_font_size = int(16 * scale)
	# Store on Global so scenes can read it when building UI
	if Engine.get_main_loop() and Engine.get_main_loop() is SceneTree:
		var root = Engine.get_main_loop().root
		root.set_meta("font_scale", scale)


static func load_and_apply_font_scale() -> void:
	var cfg = ConfigFile.new()
	var scale = 100.0
	if cfg.load(SETTINGS_PATH) == OK:
		scale = cfg.get_value("ui", "font_scale", 100.0)
	apply_font_scale(scale)


## Call this from any scene to get the scaled font size.
## Usage: var size = SettingsPopup.scaled_font(15) → returns 15 at 100%, 22 at 150%, 8 at 50%
static func scaled_font(base_size: int) -> int:
	var scale = 1.0
	if Engine.get_main_loop() and Engine.get_main_loop() is SceneTree:
		var root = Engine.get_main_loop().root
		if root.has_meta("font_scale"):
			scale = root.get_meta("font_scale")
	return maxi(int(base_size * scale), 8)


static func get_font_scale() -> float:
	var cfg = ConfigFile.new()
	if cfg.load("user://ui_settings.cfg") == OK:
		return cfg.get_value("ui", "font_scale", 100.0) / 100.0
	return 1.0


# ── Persistence ──

func _save_setting(section: String, key: String, value) -> void:
	var cfg = ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # load existing to preserve other settings
	cfg.set_value(section, key, value)
	cfg.save(SETTINGS_PATH)


func _load_setting(section: String, key: String, default_val) -> float:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return cfg.get_value(section, key, default_val)
	return default_val


func _on_confirmed() -> void:
	pass
