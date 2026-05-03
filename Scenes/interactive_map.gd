extends Control
## Interactive Teyvat map — pan/zoom, official POI markers, player markers with notes.
## Fetches map from the Genshin Wiki and POI data from HoYoLAB API.

const PLAYER_COLORS: Array[Color] = [
	Color("#e84545"),  # red
	Color("#4589e8"),  # blue
	Color("#45e87a"),  # green
	Color("#e8c845"),  # gold
	Color("#c845e8"),  # purple
	Color("#45c8e8"),  # cyan
]

const SHAPES: Array[String] = ["circle", "diamond", "star", "triangle", "square", "cross"]

const WIKI_IMAGE_API := "https://genshin-impact.fandom.com/api.php?action=query&titles=File:Teyvat_Map.png&prop=imageinfo&iiprop=url&format=json"
const POI_API_URLS: Array[String] = [
	"https://sg-public-api-static.hoyoverse.com/common/map_user/ys_obc/v1/map/point/list?map_id=2&app_sn=ys_obc&lang=en-us",
	"https://api-os-takumi-static.hoyoverse.com/common/map_user/ys_obc/v1/map/point/list?map_id=2&app_sn=ys_obc&lang=en-us",
]

# HoYoLAB map uses this origin offset for point coordinates
const MAP_ORIGIN := Vector2(12524, 7406)
const HOYOLAB_MAP_SIZE := Vector2(22528, 20480)

# Calibration: the wiki map crops differently than HoYoLAB.
# These map the fractional extent of the land content in each image.
# HoYoLAB land spans roughly x=[0.02..0.90], y=[0.08..0.85]
# Wiki land spans roughly x=[0.05..0.87], y=[0.03..0.95]
# Transform: wiki_frac = (hoyolab_frac - SRC_MIN) * (DST_RANGE / SRC_RANGE) + DST_MIN
const CALIB_SRC_X_MIN := 0.02   # leftmost land in HoYoLAB frac
const CALIB_SRC_X_MAX := 0.90   # rightmost land in HoYoLAB frac
const CALIB_DST_X_MIN := 0.05   # leftmost land in wiki frac
const CALIB_DST_X_MAX := 0.87   # rightmost land in wiki frac
const CALIB_SRC_Y_MIN := 0.08   # topmost land in HoYoLAB frac
const CALIB_SRC_Y_MAX := 0.85   # bottommost land in HoYoLAB frac
const CALIB_DST_Y_MIN := 0.03   # topmost land in wiki frac
const CALIB_DST_Y_MAX := 0.95   # bottommost land in wiki frac

const CACHE_DIR := "user://map_cache/"
const CACHE_MAP_FILE := "user://map_cache/teyvat_map.webp"
const CACHE_POI_FILE := "user://map_cache/poi.json"
const CACHE_ICONS_DIR := "user://map_cache/icons/"
const CACHE_MAX_AGE_DAYS := 7

# Domain → artifact set names mapping (official Genshin domain drops).
# Names must match the artifact_set field in ArtifactSetData .tres files exactly.
# Sets not yet defined in the game data will show "Set effects not yet defined".
# Domain → artifact set mapping. Keys identified by manual labeling on the map.
# Names must match artifact_set field in ArtifactSetData .tres files exactly.
# Undefined sets show "Set effects not yet defined" in the panel.
const DOMAIN_ARTIFACT_SETS: Dictionary = {
	# Mondstadt
	"poi_12443_8026": ["Viridescent Venerer", "Maiden Beloved"],           # Valley of Remembrance
	"poi_13338_7232": ["Thundering Fury", "Thundersoother"],               # Midsummer Courtyard
	"poi_10350_8438": ["Bloodstained Chivalry", "Noblesse Oblige"],        # Clear Pool and Mountain Cavern
	# Liyue
	"poi_11381_8038": ["Crimson Witch of Flames", "Lavawalker"],           # Hidden Palace of Zhou Formula
	"poi_12093_8265": ["Pale Flame", "Tenacity of the Millelith"],         # Ridge Watch
	"poi_12598_8692": ["Heart of Depth", "Blizzard Strayer"],              # Peak of Vindagnyr
	"poi_12743_10015": ["Archaic Petra", "Retracing Bolide"],              # Domain of Guyun
	# Inazuma
	"poi_14152_13499": ["Shimenawas Reminiscence", "Emblem of Severed Fate"], # Momiji-Dyed Court
	"poi_15990_14023": ["Husk of Opulent Dreams", "Ocean-Hued Clam"],      # Slumbering Court
	"poi_9877_10204": ["Vermillion Hereafter", "Echoes of an Offering"],   # The Lost Valley
	# Sumeru
	"poi_9568_10293": ["Deepwood Memories", "Gilded Dreams"],              # Spire of Solitary Enlightenment
	"poi_7481_11137": ["Desert Pavilion Chronicle", "Flower of Paradise Lost"], # City of Gold
	"poi_5725_9801": ["Nymphs Dream", "Vourukashas Glow"],                # Molten Iron Fortress
	# Fontaine
	"poi_7046_7882": ["Marechaussee Hunter", "Golden Troupe"],             # Denouement of Sin
	"poi_7823_7262": ["Song of Days Past", "Nighttime Whispers in the Echoing Woods"], # Faded Theater
	"poi_1229_13119": ["Golden Troupe", "Marechaussee Hunter"],            # Finale of the Deep
	# Natlan
	"poi_2736_12150": ["Scroll of the Hero of Cinder City", "Obsidian Codex"], # Sanctum of Rainbow Spirits
	# Nod Krai
	"poi_1734_3786": ["Aubade of Morningstar and Moon", "A Day Carved from Rising Winds"], # Moonchild's Treasures
	"poi_2398_6577": ["Silken Moon's Serenade", "Night of the Sky's Unveiling"],           # Frostladen Machinery
}

# Set to true to allow dragging POIs/labels to new positions (for calibration)
const ALLOW_POI_DRAGGING := false

const ZOOM_MIN := 0.15
const ZOOM_MAX := 3.0
const ZOOM_STEP := 0.1
const PING_DURATION := 4.0  # seconds before a ping fades

# Label IDs for POI categories
const LABEL_DOMAIN := 154
const LABEL_STATUE := 2
const BOSS_LABEL_IDS: Array[int] = [
	132,133,134,135,136,137,138,157,181,183,203,204,262,263,318,333,352,
	390,391,432,433,452,457,455,497,498,539,540,553,564,586,609,610,608,
	629,660,670,687,690,743,744,762,764,769,788,810
	# 809 (Domain Keeper) excluded
]

# City labels in wiki pixel coordinates (manually positioned)
const CITY_LABELS: Array[Dictionary] = [
	{"name": "Mondstadt", "mx": 8588.93, "my": 2962.96},
	{"name": "Liyue Harbor", "mx": 8047.32, "my": 4442.9},
	{"name": "Inazuma City", "mx": 10423.25, "my": 5658.33},
	{"name": "Sumeru City", "mx": 6743.75, "my": 4327.0},
	{"name": "Court of Fontaine", "mx": 5990.92, "my": 2426.09},
	{"name": "Natlan", "mx": 4000.17, "my": 4782.57},
	{"name": "Nod Krai", "mx": 3201.83, "my": 2906.09},
]

# Default POI positions in wiki pixel coords (manually calibrated).
# These override the HoYoLAB→wiki coordinate transform for all known POIs.
# New POIs from future API updates fall back to the calibration transform.
const DEFAULT_POI_POSITIONS: Dictionary = {
	"poi_10013_9107": Vector2(7350.67, 3783.93),
	"poi_10291_9528": Vector2(7480.2, 3972.78),
	"poi_10296_8978": Vector2(7482.53, 3726.36),
	"poi_10312_7746": Vector2(7490.21, 3174.47),
	"poi_1031_7401": Vector2(2838.12, 2950.35),
	"poi_10350_8438": Vector2(7507.68, 3484.18),
	"poi_10605_9072": Vector2(7626.72, 3768.47),
	"poi_10791_10086": Vector2(7713.38, 4222.58),
	"poi_10823_9577": Vector2(7725.8, 4001.08),
	"poi_10887_10302": Vector2(7758.11, 4319.58),
	"poi_11249_9625": Vector2(7926.53, 4016.02),
	"poi_11381_8038": Vector2(7997.0, 3185.26),
	"poi_11500_7944": Vector2(8012.31, 3268.37),
	"poi_11519_10633": Vector2(8064.81, 4545.69),
	"poi_11520_8462": Vector2(8052.79, 3494.94),
	"poi_11525_9753": Vector2(8055.35, 4073.38),
	"poi_11596_9342": Vector2(8088.43, 3889.45),
	"poi_11599_7100": Vector2(8093.24, 2798.13),
	"poi_11650_7074": Vector2(8128.23, 2767.51),
	"poi_11852_6428": Vector2(8259.46, 2478.8),
	"poi_12015_7471": Vector2(8314.14, 2935.92),
	"poi_12031_5536": Vector2(8311.96, 1993.24),
	"poi_12034_9112": Vector2(8325.08, 3749.56),
	"poi_12041_7739": Vector2(8331.64, 3091.21),
	"poi_12093_8265": Vector2(8331.64, 3325.24),
	"poi_12189_9006": Vector2(8395.07, 3699.25),
	"poi_1229_13119": Vector2(2925.05, 5746.12),
	"poi_12325_8555": Vector2(8427.85, 3536.61),
	"poi_12350_7881": Vector2(8480.37, 3128.39),
	"poi_12355_13566": Vector2(8475.33, 5980.55),
	"poi_12443_8026": Vector2(8526.3, 3222.44),
	"poi_12598_8692": Vector2(8591.92, 3570.21),
	"poi_12630_9681": Vector2(8570.18, 4041.34),
	"poi_12667_8064": Vector2(8626.91, 3233.38),
	"poi_12740_13285": Vector2(8689.22, 5828.91),
	"poi_12743_10015": Vector2(8622.6, 4190.77),
	"poi_12800_8552": Vector2(8712.21, 3476.16),
	"poi_12904_13341": Vector2(8765.63, 5853.77),
	"poi_12949_7589": Vector2(8795.33, 2990.6),
	"poi_13040_7810": Vector2(8834.7, 3110.9),
	"poi_13077_6820": Vector2(8828.14, 2642.84),
	"poi_13101_7173": Vector2(8847.82, 2787.19),
	"poi_13214_8061": Vector2(8882.81, 3235.57),
	"poi_13338_7232": Vector2(8963.74, 2817.81),
	"poi_13385_8005": Vector2(8989.99, 3194.01),
	"poi_13414_7562": Vector2(9005.3, 2970.92),
	"poi_13451_7632": Vector2(8941.87, 2942.48),
	"poi_13651_8399": Vector2(9090.6, 3384.3),
	"poi_1369_8087": Vector2(2995.83, 3257.49),
	"poi_13718_8419": Vector2(9169.34, 3447.72),
	"poi_13995_13434": Vector2(9299.9, 5925.87),
	"poi_14006_13726": Vector2(9288.96, 6065.85),
	"poi_14113_13676": Vector2(9358.96, 6081.16),
	"poi_14152_13499": Vector2(9372.08, 5941.18),
	"poi_1416_3325": Vector2(3034.13, 923.31),
	"poi_14320_14700": Vector2(9466.13, 6579.84),
	"poi_14439_16384": Vector2(9520.81, 7415.35),
	"poi_14954_12769": Vector2(9774.52, 5608.73),
	"poi_15001_13608": Vector2(9802.96, 6013.36),
	"poi_15015_13266": Vector2(9798.58, 5814.32),
	"poi_15049_15861": Vector2(9818.27, 7155.07),
	"poi_15684_12162": Vector2(10135.41, 5289.4),
	"poi_15709_12937": Vector2(10159.88, 5661.82),
	"poi_15812_14167": Vector2(10198.84, 6282.38),
	"poi_15990_14023": Vector2(10308.2, 6210.21),
	"poi_16034_14436": Vector2(10323.51, 6422.36),
	"poi_16177_12209": Vector2(10389.12, 5289.4),
	"poi_16180_12132": Vector2(10384.75, 5252.22),
	"poi_16245_11852": Vector2(10409.72, 5175.69),
	"poi_16245_11918": Vector2(10409.49, 5205.26),
	"poi_16339_13083": Vector2(10470.05, 5761.83),
	"poi_1732_8262": Vector2(3164.73, 3335.9),
	"poi_1734_3786": Vector2(3182.35, 1129.92),
	"poi_1750_12350": Vector2(3168.08, 5401.51),
	"poi_1806_7903": Vector2(3199.2, 3175.05),
	"poi_1858_11983": Vector2(3218.38, 5237.14),
	"poi_1905_3661": Vector2(3262.07, 1073.97),
	"poi_1923_11016": Vector2(3269.05, 4713.67),
	"poi_2020_10344": Vector2(3314.18, 4412.93),
	"poi_2089_3935": Vector2(3347.69, 1196.62),
	"poi_2113_4175": Vector2(3358.58, 1304.1),
	"poi_2145_4766": Vector2(3373.49, 1568.79),
	"poi_2243_11634": Vector2(3397.83, 5080.65),
	"poi_2251_3339": Vector2(3423.04, 929.58),
	"poi_2255_11508": Vector2(3393.46, 5001.66),
	"poi_2269_6308": Vector2(3427.59, 2416.05),
	"poi_2277_8001": Vector2(3418.88, 3218.96),
	"poi_2297_11672": Vector2(3448.14, 5119.77),
	"poi_2354_6692": Vector2(3454.75, 2632.46),
	"poi_2398_6577": Vector2(3475.02, 2580.93),
	"poi_2450_11004": Vector2(3514.31, 4708.32),
	"poi_2481_7231": Vector2(3513.93, 2874.07),
	"poi_2736_12150": Vector2(3662.48, 5294.74),
	"poi_2829_11167": Vector2(3691.04, 4781.62),
	"poi_3106_11961": Vector2(3889.95, 5196.32),
	"poi_3177_11670": Vector2(3903.07, 5084.77),
	"poi_3197_12398": Vector2(3887.76, 5436.91),
	"poi_3249_11586": Vector2(3953.38, 4995.1),
	"poi_3440_12477": Vector2(2214.56, 5946.53),
	"poi_3599_11603": Vector2(4117.03, 5005.63),
	"poi_3980_11593": Vector2(4294.37, 5001.37),
	"poi_4030_11135": Vector2(4310.38, 4765.97),
	"poi_4928_9184": Vector2(4809.24, 3795.23),
	"poi_5591_9245": Vector2(5117.91, 3822.78),
	"poi_5630_8802": Vector2(5136.19, 3623.96),
	"poi_5725_9801": Vector2(5141.32, 4106.46),
	"poi_5831_9111": Vector2(5229.73, 3762.74),
	"poi_6025_9933": Vector2(5281.21, 4165.82),
	"poi_6113_11558": Vector2(5388.65, 5024.95),
	"poi_6243_9338": Vector2(7094.4, 3825.49),
	"poi_6495_11983": Vector2(5566.86, 5215.37),
	"poi_6499_12516": Vector2(5568.73, 5454.18),
	"poi_6533_6332": Vector2(5573.31, 2345.89),
	"poi_6705_11325": Vector2(5542.89, 4890.26),
	"poi_6773_8076": Vector2(5692.23, 3233.65),
	"poi_6782_10125": Vector2(5609.26, 4273.53),
	"poi_6784_11887": Vector2(5701.28, 5172.25),
	"poi_6832_5543": Vector2(5714.36, 1966.99),
	"poi_7015_4945": Vector2(5813.92, 1660.01),
	"poi_7027_7110": Vector2(5830.51, 2760.73),
	"poi_7046_7882": Vector2(5851.35, 3142.83),
	"poi_7075_5779": Vector2(5827.75, 2088.68),
	"poi_7144_6144": Vector2(5888.59, 2293.34),
	"poi_7212_10751": Vector2(5825.83, 4590.41),
	"poi_7238_5503": Vector2(5907.95, 1989.12),
	"poi_7292_12652": Vector2(5938.31, 5514.89),
	"poi_7328_8473": Vector2(5982.74, 3407.69),
	"poi_7356_10471": Vector2(5893.27, 4464.62),
	"poi_7357_11765": Vector2(5968.36, 5117.47),
	"poi_7383_7560": Vector2(6008.13, 2998.56),
	"poi_7481_11137": Vector2(6144.88, 4755.03),
	"poi_7570_8443": Vector2(6095.25, 3394.19),
	"poi_7585_6753": Vector2(6068.36, 2569.9),
	"poi_7656_5388": Vector2(6120.9, 1911.68),
	"poi_7734_10452": Vector2(6069.5, 4456.44),
	"poi_7742_6678": Vector2(6173.45, 2517.35),
	"poi_7788_11728": Vector2(6169.17, 5101.12),
	"poi_7823_7262": Vector2(6209.4, 2799.45),
	"poi_7877_12165": Vector2(6210.63, 5296.91),
	"poi_7896_9840": Vector2(6259.19, 4110.35),
	"poi_7908_5241": Vector2(6336.62, 1812.12),
	"poi_7964_6131": Vector2(6286.84, 2199.31),
	"poi_7991_8590": Vector2(6291.52, 3460.05),
	"poi_8138_5926": Vector2(6372.58, 2110.81),
	"poi_8219_6713": Vector2(6408.53, 2561.6),
	"poi_8304_11477": Vector2(6409.46, 4988.54),
	"poi_8338_9830": Vector2(6472.14, 4129.71),
	"poi_8373_10899": Vector2(6472.31, 4628.73),
	"poi_8429_10551": Vector2(6498.29, 4472.92),
	"poi_8523_10330": Vector2(6541.96, 4374.12),
	"poi_8544_11567": Vector2(6521.28, 5028.98),
	"poi_8765_9825": Vector2(6665.73, 4124.18),
	"poi_8807_11183": Vector2(6762.9, 4775.67),
	"poi_9211_11150": Vector2(6950.97, 4760.57),
	"poi_9231_10249": Vector2(6925.29, 4335.72),
	"poi_9430_9737": Vector2(7025.9, 4038.27),
	"poi_9451_8132": Vector2(7019.73, 3269.6),
	"poi_9482_10553": Vector2(7077.15, 4493.4),
	"poi_9555_8314": Vector2(7086.11, 3396.82),
	"poi_955_7787": Vector2(2802.95, 3123.41),
	"poi_9568_10293": Vector2(7117.46, 4376.57),
	"poi_9587_9250": Vector2(7491.44, 3999.14),
	"poi_9648_9680": Vector2(7133.07, 4033.89),
	"poi_9673_11072": Vector2(7166.03, 4725.6),
	"poi_9774_10410": Vector2(7213.29, 4429.08),
	"poi_9877_10204": Vector2(7255.55, 4298.54),
}

# ── State ────────────────────────────────────────────────────────────────────
var _map_texture: ImageTexture
var _map_size := Vector2(11264, 7680)  # wiki image size

# Camera
var _cam_offset := Vector2.ZERO
var _zoom := 0.3
var _dragging := false  # middle mouse pan
var _right_dragging := false  # right mouse pan

# Marker placement
var _selected_shape: String = "circle"
var _placement_mode := false

# Markers runtime
var _markers: Dictionary = {}

# POI data
var _poi_list: Array = []  # [{name, x, y, label_id, icon_url}, ...]
var _poi_icons: Dictionary = {}  # label_id -> ImageTexture
var _poi_notes: Dictionary = {}  # "poi_x_y" -> note string (persisted)
var _poi_overrides: Dictionary = {}  # "poi_x_y" -> {"mx": wiki_x, "my": wiki_y} (persisted)
var _label_overrides: Dictionary = {}  # "label_Name" -> {"mx": wiki_x, "my": wiki_y} (persisted)
var _label_names: Dictionary = {}  # label_id -> name

# POI/label dragging
var _dragging_poi: Dictionary = {}
var _dragging_label: Dictionary = {}
var _dragging_poi_started := false

# Multi-select
var _selection_box_start := Vector2.ZERO  # screen coords where box drag began
var _selection_box_end := Vector2.ZERO
var _selection_box_active := false  # currently drawing a selection box
var _selected_pois: Array = []  # Array of POI dicts currently selected
var _selected_labels: Array = []  # Array of city label dicts currently selected
var _bulk_dragging := false  # dragging the selected group
var _bulk_drag_last := Vector2.ZERO  # last mouse pos during bulk drag

# Pings — [{map_pos: Vector2, color: Color, player: String, time: float}, ...]
var _active_pings: Array = []

# Player info
var _ascension_rank: int = 0
var _player_name: String = ""
var _player_names: Array = []

# UI references
var _sidebar: PanelContainer
var _marker_panel: PanelContainer
var _tooltip: PanelContainer
var _placement_banner: Label
var _note_edit: TextEdit
var _loading_label: Label
var _shape_buttons: Dictionary = {}
var _editing_marker: Dictionary = {}
var _editing_poi: Dictionary = {}

# Panel dragging
var _panel_dragging := false
var _panel_drag_offset := Vector2.ZERO

# Download state
var _downloading := false
var _close_btn: Button
var _progress_bar: ProgressBar
var _download_http: HTTPRequest

var _initialized := false

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	_player_name = Global.ACTIVE_USER_NAME
	_ascension_rank = _get_ascension_rank()
	_player_names = _get_all_player_names()

	_load_markers()
	_load_poi_notes()
	_build_ui()

	if not NetworkManager.map_markers_updated.is_connected(_on_markers_updated):
		NetworkManager.map_markers_updated.connect(_on_markers_updated)
	if not NetworkManager.map_ping_received.is_connected(_receive_ping):
		NetworkManager.map_ping_received.connect(_receive_ping)

	set_process_input(true)
	set_process(false)
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	if _initialized:
		return
	_initialized = true
	await get_tree().process_frame
	_init_camera()
	_ensure_cache_dir()
	_fetch_map_image()
	_fetch_poi_data()
	queue_redraw()

func _process(_delta: float) -> void:
	if _download_http and _downloading:
		var body_size = _download_http.get_body_size()
		var downloaded = _download_http.get_downloaded_bytes()
		if body_size > 0:
			_progress_bar.value = (float(downloaded) / float(body_size)) * 100.0
		else:
			# Unknown size — show indeterminate-style (estimate ~25MB)
			_progress_bar.value = (float(downloaded) / 25_000_000.0) * 100.0

func _init_camera() -> void:
	var view_size = _get_map_panel_rect().size
	_zoom = min(view_size.x / _map_size.x, view_size.y / _map_size.y) * 0.95
	_zoom = clamp(_zoom, ZOOM_MIN, ZOOM_MAX)
	_cam_offset = _map_size * 0.5 - (view_size * 0.5 / _zoom)
	_clamp_camera()

func _ensure_cache_dir() -> void:
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(CACHE_ICONS_DIR)

# ── MAP IMAGE FETCHING (wiki source) ────────────────────────────────────────

func _fetch_map_image() -> void:
	# Check cache
	if FileAccess.file_exists(CACHE_MAP_FILE):
		var mod_time = FileAccess.get_modified_time(CACHE_MAP_FILE)
		var age_days = (Time.get_unix_time_from_system() - mod_time) / 86400.0
		if age_days < CACHE_MAX_AGE_DAYS:
			_load_map_from_cache()
			return

	_set_downloading(true)
	_update_loading_label("Fetching map URL...")
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_wiki_api_response.bind(http))
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"]
	http.request(WIKI_IMAGE_API, headers)

func _on_wiki_api_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_update_loading_label("Failed to get map URL")
		_load_map_from_cache()  # try stale cache
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		_load_map_from_cache()
		return

	var pages = json.get("query", {}).get("pages", {})
	var url := ""
	for page in pages.values():
		var ii = page.get("imageinfo", [])
		if ii.size() > 0:
			url = str(ii[0].get("url", ""))
			break

	if url == "":
		_load_map_from_cache()
		return

	_update_loading_label("Downloading map (~25MB) — please don't close this window...")
	_progress_bar.visible = true
	_progress_bar.value = 0
	set_process(true)
	_download_http = HTTPRequest.new()
	_download_http.download_file = CACHE_MAP_FILE
	_download_http.timeout = 120  # 2 minute timeout
	add_child(_download_http)
	_download_http.request_completed.connect(_on_map_downloaded.bind(_download_http))
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"]
	_download_http.request(url, headers)

func _on_map_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	_download_http = null
	set_process(false)
	_progress_bar.visible = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_update_loading_label("Map download failed")
		_set_downloading(false)
		_load_map_from_cache()
		return
	_load_map_from_cache()

func _load_map_from_cache() -> void:
	if not FileAccess.file_exists(CACHE_MAP_FILE):
		_update_loading_label("No map available — check internet connection")
		_set_downloading(false)
		return

	_update_loading_label("Loading map into memory...")
	# Defer the heavy image load so the label renders first
	call_deferred("_do_load_image")

func _do_load_image() -> void:
	var img = Image.new()
	var err = img.load(CACHE_MAP_FILE)
	if err != OK:
		_update_loading_label("Failed to load map image (error %d)" % err)
		_set_downloading(false)
		return

	_map_size = Vector2(img.get_width(), img.get_height())
	_map_texture = ImageTexture.create_from_image(img)
	_init_camera()
	_set_downloading(false)
	_update_loading_label("")
	queue_redraw()

func _set_downloading(active: bool) -> void:
	_downloading = active
	if _close_btn:
		_close_btn.disabled = active
	if _sidebar:
		_sidebar.visible = not active

# ── POI FETCHING ─────────────────────────────────────────────────────────────

func _fetch_poi_data() -> void:
	if _load_cached_poi():
		_fetch_poi_icons()
		return
	_fetch_points(0)

func _fetch_points(url_idx: int) -> void:
	if url_idx >= POI_API_URLS.size():
		return
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_points_received.bind(http, url_idx))
	http.request(POI_API_URLS[url_idx])

func _on_points_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, url_idx: int) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		if url_idx + 1 < POI_API_URLS.size():
			_fetch_points(url_idx + 1)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		return

	var point_list = json.get("data", {}).get("point_list", [])
	var label_list = json.get("data", {}).get("label_list", [])

	# Build label name + icon map
	_label_names.clear()
	var icon_urls: Dictionary = {}
	for l in label_list:
		var lid = int(l.get("id", 0))
		_label_names[lid] = str(l.get("name", ""))
		var icon = str(l.get("icon", ""))
		if icon != "":
			icon_urls[lid] = icon

	_poi_list.clear()
	for p in point_list:
		var lid: int = int(p.get("label_id", 0))
		if lid != LABEL_DOMAIN and lid != LABEL_STATUE and lid not in BOSS_LABEL_IDS:
			continue
		var px: float = float(p.get("x_pos", 0)) + MAP_ORIGIN.x
		var py: float = float(p.get("y_pos", 0)) + MAP_ORIGIN.y
		_poi_list.append({
			"name": _label_names.get(lid, ""),
			"x": px, "y": py,
			"label_id": lid,
			"icon_url": icon_urls.get(lid, ""),
		})

	_save_poi_cache()
	_fetch_poi_icons()
	queue_redraw()

func _save_poi_cache() -> void:
	var file = FileAccess.open(CACHE_POI_FILE, FileAccess.WRITE)
	if file:
		# version 2: Domain Keeper excluded
		file.store_string(JSON.stringify({"version": 2, "timestamp": Time.get_unix_time_from_system(), "pois": _poi_list}))
		file.close()

func _load_cached_poi() -> bool:
	if not FileAccess.file_exists(CACHE_POI_FILE):
		return false
	var file = FileAccess.open(CACHE_POI_FILE, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null or not data is Dictionary:
		return false
	if (Time.get_unix_time_from_system() - float(data.get("timestamp", 0))) / 86400.0 > CACHE_MAX_AGE_DAYS:
		return false
	# Invalidate cache if POI version changed (e.g. removed Domain Keeper)
	if int(data.get("version", 0)) != 2:
		return false
	_poi_list = data.get("pois", [])
	return true

func _fetch_poi_icons() -> void:
	# Collect unique icon URLs needed
	var needed: Dictionary = {}  # label_id -> url
	for poi in _poi_list:
		var lid = int(poi.get("label_id", 0))
		if _poi_icons.has(lid):
			continue
		var url = str(poi.get("icon_url", ""))
		if url == "":
			continue
		# Check disk cache
		var cache_path = CACHE_ICONS_DIR + "icon_%d.png" % lid
		if FileAccess.file_exists(cache_path):
			var img = Image.new()
			if img.load(cache_path) == OK:
				_poi_icons[lid] = ImageTexture.create_from_image(img)
				continue
		needed[lid] = url

	# Download missing icons
	for lid in needed:
		var cache_path = CACHE_ICONS_DIR + "icon_%d.png" % lid
		var http = HTTPRequest.new()
		http.download_file = cache_path
		add_child(http)
		http.request_completed.connect(_on_icon_downloaded.bind(lid, cache_path, http))
		http.request(needed[lid])

func _on_icon_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, lid: int, cache_path: String, http: HTTPRequest) -> void:
	http.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var img = Image.new()
	if img.load(cache_path) == OK:
		_poi_icons[lid] = ImageTexture.create_from_image(img)
		queue_redraw()

# ── POI NOTES PERSISTENCE ────────────────────────────────────────────────────

func _poi_key(poi: Dictionary) -> String:
	return "poi_%d_%d" % [int(poi.get("x", 0)), int(poi.get("y", 0))]

func _label_key(city: Dictionary) -> String:
	return "label_%s" % str(city.get("name", ""))

func _get_label_map_pos(city: Dictionary) -> Vector2:
	var key = _label_key(city)
	if _label_overrides.has(key):
		var ov = _label_overrides[key]
		return Vector2(float(ov.get("mx", 0)), float(ov.get("my", 0)))
	# Labels use wiki pixel coords directly (already calibrated)
	return Vector2(float(city.get("mx", 0)), float(city.get("my", 0)))

func _find_label_at(screen_pos: Vector2, view_rect: Rect2) -> Dictionary:
	var font = ThemeDB.fallback_font
	if font == null:
		return {}
	for city in CITY_LABELS:
		var pos = _map_to_screen(_get_label_map_pos(city), view_rect)
		var name_str = str(city.get("name", ""))
		var fs = clampi(int(16 * _zoom * 4), 10, 22)
		var ts = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		var hit_rect = Rect2(pos - ts * 0.5 - Vector2(4, fs * 0.5), ts + Vector2(8, fs))
		if hit_rect.has_point(screen_pos):
			return city
	return {}

## Get the wiki-image-space position of a POI.
## Priority: local override > hardcoded default > calibration transform
func _get_poi_map_pos(poi: Dictionary) -> Vector2:
	var key = _poi_key(poi)
	if _poi_overrides.has(key):
		var ov = _poi_overrides[key]
		return Vector2(float(ov.get("mx", 0)), float(ov.get("my", 0)))
	if DEFAULT_POI_POSITIONS.has(key):
		return DEFAULT_POI_POSITIONS[key]
	# Fallback for new POIs not yet calibrated
	var hoyolab_pos = Vector2(float(poi.get("x", 0)), float(poi.get("y", 0)))
	return _hoyolab_to_map(hoyolab_pos)

const LOCAL_POI_DATA_FILE := "user://map_cache/local_poi_data.json"

func _load_poi_notes() -> void:
	_poi_notes = {}
	_poi_overrides = {}
	_label_overrides = {}

	if not FileAccess.file_exists(LOCAL_POI_DATA_FILE):
		# Migrate from old SaveManager storage if present
		var all_markers = SaveManager.get_map_markers()
		if all_markers.has("__poi_notes__") and all_markers["__poi_notes__"] is Dictionary:
			_poi_notes = all_markers["__poi_notes__"]
		if all_markers.has("__poi_overrides__") and all_markers["__poi_overrides__"] is Dictionary:
			_poi_overrides = all_markers["__poi_overrides__"]
		if all_markers.has("__label_overrides__") and all_markers["__label_overrides__"] is Dictionary:
			_label_overrides = all_markers["__label_overrides__"]
		if not _poi_notes.is_empty() or not _poi_overrides.is_empty() or not _label_overrides.is_empty():
			_save_poi_data()  # migrate to local file
		return

	var file = FileAccess.open(LOCAL_POI_DATA_FILE, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null or not data is Dictionary:
		return
	if data.has("notes") and data["notes"] is Dictionary:
		_poi_notes = data["notes"]
	if data.has("poi_overrides") and data["poi_overrides"] is Dictionary:
		_poi_overrides = data["poi_overrides"]
	if data.has("label_overrides") and data["label_overrides"] is Dictionary:
		_label_overrides = data["label_overrides"]

func _save_poi_data() -> void:
	_ensure_cache_dir()
	var file = FileAccess.open(LOCAL_POI_DATA_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"notes": _poi_notes,
		"poi_overrides": _poi_overrides,
		"label_overrides": _label_overrides,
	}))
	file.close()

# ── DATA HELPERS ─────────────────────────────────────────────────────────────

func _load_markers() -> void:
	_markers = SaveManager.get_map_markers().duplicate(true)

func _get_ascension_rank() -> int:
	var max_asc = 0
	for char in Global.CHARACTERS.values():
		max_asc = maxi(max_asc, int(char.get("Ascension_Rank", 0)))
	return max_asc

func _get_all_player_names() -> Array:
	var names: Array = []
	for char in Global.CHARACTERS.values():
		var n = str(char.get("Name", ""))
		if n != "" and n not in names:
			names.append(n)
	return names

func _get_player_color(player_name: String) -> Color:
	var idx = _player_names.find(player_name)
	if idx < 0:
		idx = 0
	return PLAYER_COLORS[idx % PLAYER_COLORS.size()]

# Convert HoYoLAB absolute coords to wiki image pixel coords.
# Uses calibrated edge mapping since the two maps have different aspect ratios and cropping.
func _hoyolab_to_map(hoyolab_pos: Vector2) -> Vector2:
	var frac = hoyolab_pos / HOYOLAB_MAP_SIZE
	var wiki_frac_x = (frac.x - CALIB_SRC_X_MIN) / (CALIB_SRC_X_MAX - CALIB_SRC_X_MIN) * (CALIB_DST_X_MAX - CALIB_DST_X_MIN) + CALIB_DST_X_MIN
	var wiki_frac_y = (frac.y - CALIB_SRC_Y_MIN) / (CALIB_SRC_Y_MAX - CALIB_SRC_Y_MIN) * (CALIB_DST_Y_MAX - CALIB_DST_Y_MIN) + CALIB_DST_Y_MIN
	return Vector2(wiki_frac_x, wiki_frac_y) * _map_size

# ── UI BUILDING ──────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_loading_label = Label.new()
	_loading_label.text = "Loading map..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_preset(PRESET_CENTER)
	_loading_label.offset_top = -30
	_loading_label.add_theme_color_override("font_color", Color("#d4a74a"))
	_loading_label.add_theme_font_size_override("font_size", 18)
	add_child(_loading_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.set_anchors_preset(PRESET_CENTER)
	_progress_bar.offset_left = -150
	_progress_bar.offset_right = 150
	_progress_bar.offset_top = 10
	_progress_bar.offset_bottom = 35
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.visible = false
	add_child(_progress_bar)

	_build_sidebar()

	_placement_banner = Label.new()
	_placement_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placement_banner.set_anchors_preset(PRESET_CENTER_TOP)
	_placement_banner.offset_top = 12
	_placement_banner.offset_left = -200
	_placement_banner.offset_right = 200
	_placement_banner.add_theme_color_override("font_color", Color("#d4a74a"))
	_placement_banner.add_theme_font_size_override("font_size", 14)
	_placement_banner.visible = false
	add_child(_placement_banner)

	_build_tooltip()
	_build_marker_panel()
	_build_zoom_controls()
	_build_close_button()

func _build_sidebar() -> void:
	_sidebar = PanelContainer.new()
	_sidebar.custom_minimum_size.x = 260
	_sidebar.set_anchors_preset(PRESET_LEFT_WIDE)
	_sidebar.offset_right = 260
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = Color(0.086, 0.129, 0.243, 1.0)
	sb_style.border_color = Color("#d4a74a")
	sb_style.border_width_right = 2
	_sidebar.add_theme_stylebox_override("panel", sb_style)
	add_child(_sidebar)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_sidebar.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = Label.new()
	title.text = "TEYVAT MAP"
	title.add_theme_color_override("font_color", Color("#d4a74a"))
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(_make_separator())

	# Shape picker
	var shape_label = Label.new()
	shape_label.text = "PLACE MARKER"
	shape_label.add_theme_color_override("font_color", Color("#888"))
	shape_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(shape_label)

	var shape_row = HBoxContainer.new()
	shape_row.add_theme_constant_override("separation", 6)
	vbox.add_child(shape_row)

	for shape_name in SHAPES:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		btn.tooltip_text = shape_name.capitalize()
		btn.text = _shape_icon(shape_name)
		btn.pressed.connect(_on_shape_selected.bind(shape_name))
		shape_row.add_child(btn)
		_shape_buttons[shape_name] = btn
	_update_shape_buttons()

	vbox.add_child(_make_separator())

	# Player legend
	var legend_label = Label.new()
	legend_label.text = "PLAYER MARKERS"
	legend_label.add_theme_color_override("font_color", Color("#888"))
	legend_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(legend_label)

	for pname in _player_names:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = _get_player_color(pname)
		row.add_child(dot)
		var lbl = Label.new()
		lbl.text = pname + ("  (You)" if pname == _player_name else "")
		lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)
		vbox.add_child(row)

func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 200
	var tt_style = StyleBoxFlat.new()
	tt_style.bg_color = Color(0.086, 0.129, 0.243, 0.95)
	tt_style.border_color = Color("#d4a74a88")
	tt_style.set_border_width_all(1)
	tt_style.set_corner_radius_all(6)
	tt_style.set_content_margin_all(8)
	_tooltip.add_theme_stylebox_override("panel", tt_style)
	add_child(_tooltip)

	var tt_vbox = VBoxContainer.new()
	tt_vbox.add_theme_constant_override("separation", 4)
	_tooltip.add_child(tt_vbox)

	var tt_name = Label.new()
	tt_name.name = "PlayerName"
	tt_name.add_theme_font_size_override("font_size", 12)
	tt_vbox.add_child(tt_name)

	var tt_note = Label.new()
	tt_note.name = "NotePreview"
	tt_note.add_theme_font_size_override("font_size", 11)
	tt_note.add_theme_color_override("font_color", Color("#ccc"))
	tt_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	tt_note.custom_minimum_size.x = 180
	tt_vbox.add_child(tt_note)

func _build_marker_panel() -> void:
	_marker_panel = PanelContainer.new()
	_marker_panel.visible = false
	_marker_panel.z_index = 300
	_marker_panel.custom_minimum_size = Vector2(300, 0)
	# Start in a sensible position (will be draggable)
	_marker_panel.position = Vector2(400, 200)
	_marker_panel.size = Vector2(300, 240)
	var mp_style = StyleBoxFlat.new()
	mp_style.bg_color = Color(0.086, 0.129, 0.243, 0.95)
	mp_style.border_color = Color("#d4a74a88")
	mp_style.set_border_width_all(2)
	mp_style.set_corner_radius_all(10)
	mp_style.set_content_margin_all(16)
	_marker_panel.add_theme_stylebox_override("panel", mp_style)
	add_child(_marker_panel)

	var mp_vbox = VBoxContainer.new()
	mp_vbox.add_theme_constant_override("separation", 8)
	_marker_panel.add_child(mp_vbox)

	# Drag handle label (title doubles as drag area)
	var mp_title = Label.new()
	mp_title.name = "Title"
	mp_title.text = "Marker Details  (drag to move)"
	mp_title.add_theme_color_override("font_color", Color("#d4a74a"))
	mp_title.add_theme_font_size_override("font_size", 14)
	mp_vbox.add_child(mp_title)

	var mp_owner = Label.new()
	mp_owner.name = "Owner"
	mp_owner.add_theme_font_size_override("font_size", 12)
	mp_vbox.add_child(mp_owner)

	var mp_info = Label.new()
	mp_info.name = "Info"
	mp_info.add_theme_font_size_override("font_size", 11)
	mp_info.add_theme_color_override("font_color", Color("#ccc"))
	mp_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	mp_info.visible = false
	mp_vbox.add_child(mp_info)

	_note_edit = TextEdit.new()
	_note_edit.custom_minimum_size = Vector2(0, 80)
	_note_edit.placeholder_text = "Add a note..."
	_note_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	mp_vbox.add_child(_note_edit)

	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	mp_vbox.add_child(btn_row)

	var save_btn = Button.new()
	save_btn.name = "SaveBtn"
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_marker_save)
	btn_row.add_child(save_btn)

	var delete_btn = Button.new()
	delete_btn.name = "DeleteBtn"
	delete_btn.text = "Delete"
	delete_btn.add_theme_color_override("font_color", Color("#cc4444"))
	delete_btn.pressed.connect(_on_marker_delete)
	btn_row.add_child(delete_btn)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_marker_panel_close)
	btn_row.add_child(close_btn)

func _build_zoom_controls() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	vbox.offset_left = -56
	vbox.offset_top = -140
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	for item in [["+" , "_on_zoom_in"], ["-", "_on_zoom_out"], ["R", "_on_zoom_reset"]]:
		var btn = Button.new()
		btn.text = item[0]
		btn.custom_minimum_size = Vector2(36, 36)
		btn.pressed.connect(Callable(self, item[1]))
		vbox.add_child(btn)

func _build_close_button() -> void:
	_close_btn = Button.new()
	_close_btn.text = "X"
	_close_btn.tooltip_text = "Close Map"
	_close_btn.custom_minimum_size = Vector2(32, 32)
	_close_btn.set_anchors_preset(PRESET_TOP_RIGHT)
	_close_btn.offset_left = -44
	_close_btn.offset_right = -12
	_close_btn.offset_top = 12
	_close_btn.offset_bottom = 44
	_close_btn.add_theme_color_override("font_color", Color("#cc4444"))
	_close_btn.pressed.connect(_close_map)
	add_child(_close_btn)

func _make_separator() -> HSeparator:
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color("#d4a74a44"))
	return sep

func _update_loading_label(text: String) -> void:
	if _loading_label:
		_loading_label.text = text
		_loading_label.visible = text != ""

# ── DRAWING ──────────────────────────────────────────────────────────────────

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.12, 1.0))
	var view_rect = _get_map_panel_rect()
	draw_rect(view_rect, Color(0.067, 0.094, 0.153, 1.0))

	# Map image
	if _map_texture:
		var src_rect = Rect2(_cam_offset, view_rect.size / _zoom)
		src_rect.position.x = clamp(src_rect.position.x, 0, max(0, _map_size.x - src_rect.size.x))
		src_rect.position.y = clamp(src_rect.position.y, 0, max(0, _map_size.y - src_rect.size.y))
		draw_texture_rect_region(_map_texture, view_rect, src_rect)

	# POIs
	_draw_pois(view_rect)

	# City labels
	_draw_city_labels(view_rect)

	# Player markers
	_draw_markers(view_rect)

	# Selection highlights
	_draw_selection_highlights(view_rect)

	# Selection box
	if _selection_box_active and _dragging_poi_started:
		var box = _get_selection_rect()
		draw_rect(box, Color(0.83, 0.65, 0.29, 0.15))
		draw_rect(box, Color(0.83, 0.65, 0.29, 0.6), false, 2.0)

	# Pings
	_draw_pings(view_rect)

func _draw_pings(view_rect: Rect2) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	for ping in _active_pings:
		var elapsed = now - float(ping.get("time", 0))
		if elapsed > PING_DURATION:
			continue
		var fade = 1.0 - (elapsed / PING_DURATION)
		var pulse = 1.0 + sin(elapsed * 6.0) * 0.3  # pulsing effect
		var screen_pos = _map_to_screen(ping.get("map_pos", Vector2.ZERO), view_rect)
		if not view_rect.has_point(screen_pos):
			continue
		var color: Color = ping.get("color", Color.WHITE)
		var r = 20.0 * pulse
		# Outer ring
		draw_arc(screen_pos, r, 0, TAU, 32, Color(color, fade * 0.8), 3.0)
		# Inner ring
		draw_arc(screen_pos, r * 0.5, 0, TAU, 24, Color(color, fade * 0.5), 2.0)
		# Center dot
		draw_circle(screen_pos, 4.0, Color(color, fade))
		# Player name
		var font = ThemeDB.fallback_font
		if font:
			var pname = str(ping.get("player", ""))
			var fs = 11
			draw_string(font, screen_pos + Vector2(r + 6, 4), pname, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, fade))

func _draw_pois(view_rect: Rect2) -> void:
	var icon_size = clamp(24.0 * _zoom * 3, 12.0, 36.0)
	for poi in _poi_list:
		var map_pos = _get_poi_map_pos(poi)
		var screen_pos = _map_to_screen(map_pos, view_rect)
		if not view_rect.has_point(screen_pos):
			continue

		var lid = int(poi.get("label_id", 0))
		if _poi_icons.has(lid):
			var tex: ImageTexture = _poi_icons[lid]
			var rect = Rect2(screen_pos - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
			draw_texture_rect(tex, rect, false)
		else:
			var color = Color("#4589e8") if lid == LABEL_DOMAIN else (Color("#45e87a") if lid == LABEL_STATUE else Color("#cc2222"))
			draw_circle(screen_pos, icon_size * 0.3, color)

func _draw_city_labels(view_rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	if font == null:
		return
	for city in CITY_LABELS:
		var pos = _map_to_screen(_get_label_map_pos(city), view_rect)
		if not view_rect.has_point(pos):
			continue
		var name_str: String = str(city.get("name", ""))
		var fs = clampi(int(16 * _zoom * 4), 10, 22)
		var ts = font.get_string_size(name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, pos - ts * 0.5 + Vector2(1, fs * 0.3 + 1), name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(0, 0, 0, 0.6))
		draw_string(font, pos - ts * 0.5 + Vector2(0, fs * 0.3), name_str, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color("#e0d5b8"))

func _draw_selection_highlights(view_rect: Rect2) -> void:
	if not _has_selection():
		return
	var highlight_color = Color(0.83, 0.65, 0.29, 0.4)
	var ring_color = Color(0.83, 0.65, 0.29, 0.8)
	for poi in _selected_pois:
		var sp = _map_to_screen(_get_poi_map_pos(poi), view_rect)
		if view_rect.has_point(sp):
			var r = clamp(14.0 * _zoom * 3, 8.0, 20.0)
			draw_circle(sp, r, highlight_color)
			draw_arc(sp, r, 0, TAU, 24, ring_color, 2.0)
	for lbl in _selected_labels:
		var sp = _map_to_screen(_get_label_map_pos(lbl), view_rect)
		if view_rect.has_point(sp):
			draw_circle(sp, 10, highlight_color)
			draw_arc(sp, 10, 0, TAU, 24, ring_color, 2.0)

func _draw_markers(view_rect: Rect2) -> void:
	for owner_name in _markers:
		var color = _get_player_color(owner_name)
		for m in _markers[owner_name]:
			var pos = Vector2(float(m.get("position_x", 0)), float(m.get("position_y", 0)))
			var screen_pos = _map_to_screen(pos, view_rect)
			if not view_rect.has_point(screen_pos):
				continue
			_draw_shape(screen_pos, str(m.get("shape", "circle")), color)

func _draw_shape(pos: Vector2, shape: String, color: Color) -> void:
	var s = clamp(10.0 * _zoom * 4, 8.0, 20.0)
	var outline = Color(1, 1, 1, 0.9)
	var ow = 2.0  # outline width
	# Drop shadow
	draw_circle(pos + Vector2(1, 2), s * 0.6, Color(0, 0, 0, 0.3))
	match shape:
		"circle":
			draw_circle(pos, s, color)
			draw_arc(pos, s, 0, TAU, 48, outline, ow, true)
		"diamond":
			var pts = PackedVector2Array([pos + Vector2(0,-s), pos + Vector2(s,0), pos + Vector2(0,s), pos + Vector2(-s,0), pos + Vector2(0,-s)])
			draw_colored_polygon(pts, color)
			draw_polyline(pts, outline, ow, true)
		"star":
			var pts = _star_points(pos, s, s * 0.4, 5)
			pts.append(pts[0])
			draw_colored_polygon(pts, color)
			draw_polyline(pts, outline, ow, true)
		"triangle":
			var pts = PackedVector2Array([pos + Vector2(0,-s), pos + Vector2(s, s*0.8), pos + Vector2(-s, s*0.8), pos + Vector2(0,-s)])
			draw_colored_polygon(pts, color)
			draw_polyline(pts, outline, ow, true)
		"square":
			var h = s * 0.8
			var pts = PackedVector2Array([pos + Vector2(-h,-h), pos + Vector2(h,-h), pos + Vector2(h,h), pos + Vector2(-h,h), pos + Vector2(-h,-h)])
			draw_colored_polygon(pts, color)
			draw_polyline(pts, outline, ow, true)
		"cross":
			# Draw as rounded cross with outline
			var t = s * 0.35
			draw_line(pos + Vector2(-s,-s)*0.7, pos + Vector2(s,s)*0.7, outline, t + ow, true)
			draw_line(pos + Vector2(s,-s)*0.7, pos + Vector2(-s,s)*0.7, outline, t + ow, true)
			draw_line(pos + Vector2(-s,-s)*0.7, pos + Vector2(s,s)*0.7, color, t, true)
			draw_line(pos + Vector2(s,-s)*0.7, pos + Vector2(-s,s)*0.7, color, t, true)

func _star_points(center: Vector2, outer_r: float, inner_r: float, points: int) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for i in points * 2:
		var angle = (PI * 2.0 * i / (points * 2)) - PI / 2.0
		var r = outer_r if i % 2 == 0 else inner_r
		result.append(center + Vector2(cos(angle), sin(angle)) * r)
	return result

# ── COORDINATE CONVERSION ────────────────────────────────────────────────────

func _get_map_panel_rect() -> Rect2:
	var vp_size = size
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		vp_size = Vector2(1920, 1080)
	return Rect2(Vector2(260, 0), vp_size - Vector2(260, 0))

func _map_to_screen(map_pos: Vector2, view_rect: Rect2) -> Vector2:
	return view_rect.position + (map_pos - _cam_offset) * _zoom

func _screen_to_map(screen_pos: Vector2, view_rect: Rect2) -> Vector2:
	return _cam_offset + (screen_pos - view_rect.position) / _zoom

func _clamp_camera() -> void:
	var view_rect = _get_map_panel_rect()
	var view_in_map = view_rect.size / _zoom
	_cam_offset.x = clamp(_cam_offset.x, 0, max(0, _map_size.x - view_in_map.x))
	_cam_offset.y = clamp(_cam_offset.y, 0, max(0, _map_size.y - view_in_map.y))

# ── INPUT ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	var view_rect = _get_map_panel_rect()

	# Panel dragging
	if _panel_dragging:
		if event is InputEventMouseMotion:
			_marker_panel.position += event.relative
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_panel_dragging = false
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if _downloading:
				get_viewport().set_input_as_handled()
				return
			if _has_selection():
				_clear_selection()
				queue_redraw()
			elif _marker_panel.visible:
				_on_marker_panel_close()
			elif _placement_mode:
				_placement_mode = false
				_placement_banner.visible = false
			else:
				_close_map()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		# Check if clicking on the marker panel title to drag
		if _marker_panel.visible and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var title_area = Rect2(_marker_panel.position, Vector2(_marker_panel.size.x, 40))
			if title_area.has_point(event.position) and not _note_edit.get_global_rect().has_point(event.position):
				_panel_dragging = true
				return

		if not view_rect.has_point(event.position):
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_cursor(ZOOM_STEP, event.position, view_rect)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_cursor(-ZOOM_STEP, event.position, view_rect)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Ctrl+click = ping
				if event.ctrl_pressed:
					_place_ping(event.position, view_rect)
					return
				if _placement_mode:
					_try_place_marker(event.position, view_rect)
				elif ALLOW_POI_DRAGGING and _has_selection():
					if _is_in_selection(event.position, view_rect):
						_bulk_dragging = true
						_bulk_drag_last = event.position
					else:
						_clear_selection()
						_selection_box_start = event.position
						_selection_box_end = event.position
						_selection_box_active = true
						_dragging_poi_started = false
				else:
					if _has_selection():
						_clear_selection()
						queue_redraw()
					# Check POI/label/marker hit
					var poi = _find_poi_at(event.position, view_rect)
					if not poi.is_empty():
						if ALLOW_POI_DRAGGING:
							_dragging_poi = poi
							_dragging_poi_started = false
						else:
							_open_poi_panel(poi)
					else:
						var label = _find_label_at(event.position, view_rect)
						if not label.is_empty() and ALLOW_POI_DRAGGING:
							_dragging_label = label
							_dragging_poi_started = false
						else:
							var marker = _find_marker_at(event.position, view_rect)
							if not marker.is_empty():
								_open_marker_panel(marker)
							elif ALLOW_POI_DRAGGING:
								_selection_box_start = event.position
								_selection_box_end = event.position
								_selection_box_active = true
								_dragging_poi_started = false
							else:
								_dragging = true
			else:
				# Mouse released
				if _bulk_dragging:
					_bulk_dragging = false
					_save_poi_data()
				elif _selection_box_active:
					_selection_box_active = false
					if _dragging_poi_started:
						_select_in_box(view_rect)
					_dragging_poi_started = false
					queue_redraw()
				elif not _dragging_label.is_empty():
					if _dragging_poi_started:
						var map_pos = _screen_to_map(event.position, view_rect)
						_label_overrides[_label_key(_dragging_label)] = {"mx": map_pos.x, "my": map_pos.y}
						_save_poi_data()
						queue_redraw()
					_dragging_label = {}
					_dragging_poi_started = false
				elif not _dragging_poi.is_empty():
					if _dragging_poi_started:
						var map_pos = _screen_to_map(event.position, view_rect)
						_poi_overrides[_poi_key(_dragging_poi)] = {"mx": map_pos.x, "my": map_pos.y}
						_save_poi_data()
						queue_redraw()
					else:
						_open_poi_panel(_dragging_poi)
					_dragging_poi = {}
					_dragging_poi_started = false
				_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if _placement_mode:
					_placement_mode = false
					_placement_banner.visible = false
				elif _has_selection():
					_clear_selection()
					queue_redraw()
				else:
					_right_dragging = true
			else:
				_right_dragging = false
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_dragging = true
			else:
				_dragging = false

	if event is InputEventMouseMotion:
		if _bulk_dragging:
			# Move all selected POIs and labels by the mouse delta
			var delta_map = event.relative / _zoom
			for poi in _selected_pois:
				var key = _poi_key(poi)
				var pos = _get_poi_map_pos(poi)
				_poi_overrides[key] = {"mx": pos.x + delta_map.x, "my": pos.y + delta_map.y}
			for lbl in _selected_labels:
				var key = _label_key(lbl)
				var pos = _get_label_map_pos(lbl)
				_label_overrides[key] = {"mx": pos.x + delta_map.x, "my": pos.y + delta_map.y}
			_bulk_drag_last = event.position
			queue_redraw()
		elif _selection_box_active:
			_dragging_poi_started = true
			_selection_box_end = event.position
			queue_redraw()
		elif not _dragging_label.is_empty():
			_dragging_poi_started = true
			var map_pos = _screen_to_map(event.position, view_rect)
			_label_overrides[_label_key(_dragging_label)] = {"mx": map_pos.x, "my": map_pos.y}
			_tooltip.visible = false
			queue_redraw()
		elif not _dragging_poi.is_empty():
			_dragging_poi_started = true
			var map_pos = _screen_to_map(event.position, view_rect)
			_poi_overrides[_poi_key(_dragging_poi)] = {"mx": map_pos.x, "my": map_pos.y}
			_tooltip.visible = false
			queue_redraw()
		elif _dragging or _right_dragging:
			_cam_offset -= event.relative / _zoom
			_clamp_camera()
			queue_redraw()
		elif view_rect.has_point(event.position):
			_update_tooltip(event.position, view_rect)

# ── POI INTERACTION ──────────────────────────────────────────────────────────

func _find_poi_at(screen_pos: Vector2, view_rect: Rect2) -> Dictionary:
	var hit_radius = clamp(16.0 * _zoom * 3, 10.0, 24.0)
	for poi in _poi_list:
		var map_pos = _get_poi_map_pos(poi)
		var sp = _map_to_screen(map_pos, view_rect)
		if sp.distance_to(screen_pos) <= hit_radius:
			return poi
	return {}

func _open_poi_panel(poi: Dictionary) -> void:
	_editing_poi = poi
	_editing_marker = {}
	_marker_panel.visible = true

	var mp_vbox = _marker_panel.get_child(0)
	var title_lbl: Label = mp_vbox.get_child(0)
	title_lbl.text = "%s  (drag to move)" % str(poi.get("name", "POI"))
	var owner_lbl: Label = mp_vbox.get_child(1)
	owner_lbl.text = "Official Marker"
	owner_lbl.add_theme_color_override("font_color", Color("#d4a74a"))

	# Show artifact set info for domains
	var info_lbl: Label = mp_vbox.get_child(2)
	var poi_key = _poi_key(poi)
	var lid = int(poi.get("label_id", 0))
	if lid == LABEL_DOMAIN and DOMAIN_ARTIFACT_SETS.has(poi_key):
		var artifact_text = _build_domain_artifact_text(DOMAIN_ARTIFACT_SETS[poi_key])
		info_lbl.text = artifact_text
		info_lbl.visible = true
	else:
		info_lbl.visible = false

	_note_edit.text = str(_poi_notes.get(poi_key, ""))
	_note_edit.editable = true

	# Hide delete button for official markers
	var btn_row = mp_vbox.get_child(4)
	for child in btn_row.get_children():
		if child.name == "DeleteBtn":
			child.visible = false
		elif child.name == "SaveBtn":
			child.visible = true

# ── PLAYER MARKER LOGIC ──────────────────────────────────────────────────────

func _find_marker_at(screen_pos: Vector2, view_rect: Rect2) -> Dictionary:
	var hit_radius = 14.0
	for owner_name in _markers:
		for m in _markers[owner_name]:
			var pos = Vector2(float(m.get("position_x", 0)), float(m.get("position_y", 0)))
			var sp = _map_to_screen(pos, view_rect)
			if sp.distance_to(screen_pos) <= hit_radius:
				var result = m.duplicate()
				result["_owner"] = owner_name
				return result
	return {}

func _try_place_marker(screen_pos: Vector2, view_rect: Rect2) -> void:
	var map_pos = _screen_to_map(screen_pos, view_rect)
	var marker = {
		"id": _generate_id(),
		"position_x": map_pos.x,
		"position_y": map_pos.y,
		"shape": _selected_shape,
		"note": "",
	}
	if not _markers.has(_player_name):
		_markers[_player_name] = []
	_markers[_player_name].append(marker)

	_placement_mode = false
	_placement_banner.visible = false
	_save_and_sync()
	queue_redraw()

	var m = marker.duplicate()
	m["_owner"] = _player_name
	_open_marker_panel(m)

func _open_marker_panel(marker: Dictionary) -> void:
	_editing_marker = marker
	_editing_poi = {}
	var owner_name: String = str(marker.get("_owner", ""))
	var is_mine = owner_name == _player_name

	_marker_panel.visible = true
	var mp_vbox = _marker_panel.get_child(0)
	var title_lbl: Label = mp_vbox.get_child(0)
	title_lbl.text = "Marker  (drag to move)"
	var owner_lbl: Label = mp_vbox.get_child(1)
	owner_lbl.text = "Placed by: %s" % owner_name
	owner_lbl.add_theme_color_override("font_color", _get_player_color(owner_name))

	# Hide artifact info for player markers
	var info_lbl: Label = mp_vbox.get_child(2)
	info_lbl.visible = false

	_note_edit.text = str(marker.get("note", ""))
	_note_edit.editable = is_mine

	var btn_row = mp_vbox.get_child(4)
	for child in btn_row.get_children():
		if child.name == "SaveBtn" or child.name == "DeleteBtn":
			child.visible = is_mine

func _on_marker_save() -> void:
	if not _editing_poi.is_empty():
		# Saving a POI note
		var key = _poi_key(_editing_poi)
		_poi_notes[key] = _note_edit.text
		_save_poi_data()
		_marker_panel.visible = false
		_editing_poi = {}
		return

	if _editing_marker.is_empty():
		return
	var marker_id = str(_editing_marker.get("id", ""))
	var owner_name = str(_editing_marker.get("_owner", _player_name))
	if owner_name != _player_name:
		return
	if not _markers.has(owner_name):
		return
	for i in _markers[owner_name].size():
		if str(_markers[owner_name][i].get("id", "")) == marker_id:
			_markers[owner_name][i]["note"] = _note_edit.text
			break
	_save_and_sync()
	_marker_panel.visible = false
	_editing_marker = {}

func _on_marker_delete() -> void:
	if _editing_marker.is_empty():
		return
	var marker_id = str(_editing_marker.get("id", ""))
	var owner_name = str(_editing_marker.get("_owner", _player_name))
	if owner_name != _player_name:
		return
	if not _markers.has(owner_name):
		return
	for i in range(_markers[owner_name].size() - 1, -1, -1):
		if str(_markers[owner_name][i].get("id", "")) == marker_id:
			_markers[owner_name].remove_at(i)
			break
	_save_and_sync()
	_marker_panel.visible = false
	_editing_marker = {}
	queue_redraw()

func _on_marker_panel_close() -> void:
	_marker_panel.visible = false
	_editing_marker = {}
	_editing_poi = {}

func _save_and_sync() -> void:
	SaveManager.set_player_markers(_player_name, _markers.get(_player_name, []))
	NetworkManager.send_markers_to_host(_player_name, _markers.get(_player_name, []))

func _on_markers_updated(all_markers: Dictionary) -> void:
	_markers = all_markers.duplicate(true)
	queue_redraw()

# ── TOOLTIP ──────────────────────────────────────────────────────────────────

func _update_tooltip(screen_pos: Vector2, view_rect: Rect2) -> void:
	# Check POIs first
	var poi = _find_poi_at(screen_pos, view_rect)
	if not poi.is_empty():
		var name_str = str(poi.get("name", ""))
		var key = _poi_key(poi)
		var lid = int(poi.get("label_id", 0))
		# Build tooltip: artifact info + user note
		var parts: Array = []
		if lid == LABEL_DOMAIN and DOMAIN_ARTIFACT_SETS.has(key):
			var sets = DOMAIN_ARTIFACT_SETS[key]
			parts.append(", ".join(sets))
		var user_note = str(_poi_notes.get(key, ""))
		if user_note != "":
			parts.append(user_note)
		var note = "\n".join(parts) if parts.size() > 0 else ""
		_show_tooltip(screen_pos, name_str, note, Color("#d4a74a"))
		return

	var marker = _find_marker_at(screen_pos, view_rect)
	if not marker.is_empty():
		var owner_name = str(marker.get("_owner", ""))
		var note = str(marker.get("note", ""))
		_show_tooltip(screen_pos, owner_name, note, _get_player_color(owner_name))
		return

	_tooltip.visible = false

func _show_tooltip(screen_pos: Vector2, title: String, note: String, color: Color) -> void:
	if note.length() > 50:
		note = note.substr(0, 50) + "..."
	var tt_vbox = _tooltip.get_child(0)
	var name_lbl: Label = tt_vbox.get_child(0)
	name_lbl.text = title
	name_lbl.add_theme_color_override("font_color", color)
	var note_lbl: Label = tt_vbox.get_child(1)
	note_lbl.text = note if note != "" else "(no note)"
	_tooltip.position = screen_pos + Vector2(15, -40)
	_tooltip.visible = true

# ── SHAPE SELECTION ──────────────────────────────────────────────────────────

func _on_shape_selected(shape_name: String) -> void:
	_selected_shape = shape_name
	_update_shape_buttons()
	_placement_mode = true
	_placement_banner.text = "Click on the map to place a %s marker  |  Right-click to cancel" % shape_name.capitalize()
	_placement_banner.visible = true

func _update_shape_buttons() -> void:
	for sname in _shape_buttons:
		_shape_buttons[sname].flat = sname != _selected_shape

func _shape_icon(shape_name: String) -> String:
	match shape_name:
		"circle": return "O"
		"diamond": return "<>"
		"star": return "*"
		"triangle": return "/\\"
		"square": return "[]"
		"cross": return "X"
	return "?"

# ── ZOOM ─────────────────────────────────────────────────────────────────────

func _zoom_at_cursor(delta: float, cursor_pos: Vector2, view_rect: Rect2) -> void:
	var map_under_cursor = _screen_to_map(cursor_pos, view_rect)
	_zoom = clamp(_zoom + delta, ZOOM_MIN, ZOOM_MAX)
	_cam_offset = map_under_cursor - (cursor_pos - view_rect.position) / _zoom
	_clamp_camera()
	queue_redraw()

func _on_zoom_in() -> void:
	var view_rect = _get_map_panel_rect()
	_zoom_at_cursor(ZOOM_STEP, view_rect.position + view_rect.size * 0.5, view_rect)

func _on_zoom_out() -> void:
	var view_rect = _get_map_panel_rect()
	_zoom_at_cursor(-ZOOM_STEP, view_rect.position + view_rect.size * 0.5, view_rect)

func _on_zoom_reset() -> void:
	_init_camera()
	queue_redraw()

# ── MULTI-SELECT ─────────────────────────────────────────────────────────────

func _has_selection() -> bool:
	return _selected_pois.size() > 0 or _selected_labels.size() > 0

func _clear_selection() -> void:
	_selected_pois.clear()
	_selected_labels.clear()

func _is_in_selection(screen_pos: Vector2, view_rect: Rect2) -> bool:
	var hit_radius = clamp(16.0 * _zoom * 3, 10.0, 24.0)
	for poi in _selected_pois:
		var sp = _map_to_screen(_get_poi_map_pos(poi), view_rect)
		if sp.distance_to(screen_pos) <= hit_radius:
			return true
	for lbl in _selected_labels:
		var sp = _map_to_screen(_get_label_map_pos(lbl), view_rect)
		if sp.distance_to(screen_pos) <= 30:
			return true
	return false

func _select_in_box(view_rect: Rect2) -> void:
	_selected_pois.clear()
	_selected_labels.clear()
	var box = _get_selection_rect()

	for poi in _poi_list:
		var sp = _map_to_screen(_get_poi_map_pos(poi), view_rect)
		if box.has_point(sp):
			_selected_pois.append(poi)

	for city in CITY_LABELS:
		var sp = _map_to_screen(_get_label_map_pos(city), view_rect)
		if box.has_point(sp):
			_selected_labels.append(city)

func _get_selection_rect() -> Rect2:
	var tl = Vector2(min(_selection_box_start.x, _selection_box_end.x), min(_selection_box_start.y, _selection_box_end.y))
	var br = Vector2(max(_selection_box_start.x, _selection_box_end.x), max(_selection_box_start.y, _selection_box_end.y))
	return Rect2(tl, br - tl)

# ── CLOSE ────────────────────────────────────────────────────────────────────

func _build_domain_artifact_text(set_names: Array) -> String:
	var text := ""
	for set_name in set_names:
		if text != "":
			text += "\n\n"
		text += "--- %s ---" % set_name
		var found_2pc := false
		var found_4pc := false
		for a in GameDB.artifact_sets.values():
			if a.artifact_set == set_name:
				if a.bonus_type == 2:
					text += "\n2pc: %s" % a.effect.strip_edges()
					found_2pc = true
				elif a.bonus_type == 4:
					text += "\n4pc: %s" % a.effect.strip_edges()
					found_4pc = true
		if not found_2pc and not found_4pc:
			text += "\nSet effects not yet defined"
		elif not found_2pc:
			text += "\n2pc: Not yet defined"
		elif not found_4pc:
			text += "\n4pc: Not yet defined"
	return text

# ── PINGS ────────────────────────────────────────────────────────────────────

func _place_ping(screen_pos: Vector2, view_rect: Rect2) -> void:
	var map_pos = _screen_to_map(screen_pos, view_rect)
	var color = _get_player_color(_player_name)
	var ping = {
		"map_pos": map_pos,
		"color": color,
		"player": _player_name,
		"time": Time.get_ticks_msec() / 1000.0,
	}
	_active_pings.append(ping)
	queue_redraw()
	# Broadcast to other players
	var json = JSON.stringify({"x": map_pos.x, "y": map_pos.y, "player": _player_name, "color": [color.r, color.g, color.b]})
	NetworkManager.broadcast_map_ping(json)
	# Schedule cleanup
	get_tree().create_timer(PING_DURATION + 0.5).timeout.connect(_cleanup_pings)

func _receive_ping(ping_json: String) -> void:
	var data = JSON.parse_string(ping_json)
	if data == null:
		return
	var c = data.get("color", [1, 1, 1])
	_active_pings.append({
		"map_pos": Vector2(float(data.get("x", 0)), float(data.get("y", 0))),
		"color": Color(float(c[0]), float(c[1]), float(c[2])),
		"player": str(data.get("player", "")),
		"time": Time.get_ticks_msec() / 1000.0,
	})
	queue_redraw()
	get_tree().create_timer(PING_DURATION + 0.5).timeout.connect(_cleanup_pings)

func _cleanup_pings() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	for i in range(_active_pings.size() - 1, -1, -1):
		if now - float(_active_pings[i].get("time", 0)) > PING_DURATION:
			_active_pings.remove_at(i)
	queue_redraw()

# ── CLOSE ────────────────────────────────────────────────────────────────────

func _close_map() -> void:
	if NetworkManager.map_markers_updated.is_connected(_on_markers_updated):
		NetworkManager.map_markers_updated.disconnect(_on_markers_updated)
	if NetworkManager.map_ping_received.is_connected(_receive_ping):
		NetworkManager.map_ping_received.disconnect(_receive_ping)
	var win = get_parent()
	if win is Window:
		win.queue_free()
	else:
		queue_free()

# ── HELPERS ──────────────────────────────────────────────────────────────────

func _generate_id() -> String:
	return "%d_%d" % [Time.get_ticks_msec(), randi() % 100000]
