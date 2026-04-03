extends AcceptDialog

@onready var server_field: LineEdit = $VBoxContainer/ServerField
@onready var volume_slider: HSlider = $VBoxContainer/VolumeRow/VolumeSlider
@onready var volume_label: Label = $VBoxContainer/VolumeRow/VolumeValue
@onready var font_slider: HSlider = $VBoxContainer/FontRow/FontSlider
@onready var font_label: Label = $VBoxContainer/FontRow/FontValue

const SETTINGS_PATH = "user://ui_settings.cfg"

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

	# Font scale slider (50% to 150%, default 100%)
	font_slider.min_value = 50.0
	font_slider.max_value = 150.0
	font_slider.step = 5.0
	font_slider.value = _load_setting("ui", "font_scale", 100.0)
	_update_font_label(font_slider.value)
	font_slider.value_changed.connect(_on_font_scale_changed)


# ── Volume ──

func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_update_volume_label(value)
	_save_setting("audio", "music_volume", value)


func _apply_volume(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))


func _update_volume_label(value: float) -> void:
	volume_label.text = "Muted" if value <= 0.0 else "%d%%" % int(value)


# ── Font Scale ──

func _on_font_scale_changed(value: float) -> void:
	_update_font_label(value)
	_save_setting("ui", "font_scale", value)
	apply_font_scale(value)


func _update_font_label(value: float) -> void:
	font_label.text = "%d%%" % int(value)


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
