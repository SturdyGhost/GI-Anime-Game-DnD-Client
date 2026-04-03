extends Control
## RulesScene — Full game rules & reference guide.
## Dark-themed, chapter-based layout with search and TOC navigation.
## All UI built programmatically.

# ═══════════════════════════════════════════════════════════════════════
#  COLORS
# ═══════════════════════════════════════════════════════════════════════
const BG      = Color(0.102, 0.122, 0.169)
const PANEL   = Color(0.133, 0.157, 0.220)
const CARD    = Color(0.165, 0.192, 0.270)
const INSET   = Color(0.086, 0.106, 0.149)
const HOVER   = Color(0.188, 0.227, 0.322)
const BORDER  = Color(0.227, 0.259, 0.376)
const TEXT    = Color(0.941, 0.949, 0.973)
const SEC     = Color(0.690, 0.722, 0.800)
const MUTED   = Color(0.471, 0.510, 0.627)
const ACCENT  = Color(0.788, 0.659, 0.298)
const GREEN   = Color(0.292, 0.855, 0.498)
const RED     = Color(0.937, 0.267, 0.267)
const BLUE    = Color(0.376, 0.647, 0.980)
const ORANGE  = Color(0.961, 0.620, 0.043)

const ELEM_COLORS = {
	"Fire": Color(0.937, 0.420, 0.227),
	"Water": Color(0.298, 0.624, 0.941),
	"Electric": Color(0.706, 0.478, 0.875),
	"Ice": Color(0.604, 0.894, 0.941),
	"Wind": Color(0.455, 0.784, 0.643),
	"Earth": Color(0.941, 0.698, 0.196),
	"Nature": Color(0.627, 0.816, 0.251),
}
const ELEM_ICONS = {
	"Fire": "Pyro",  "Water": "Hydro",  "Electric": "Electro",
	"Ice": "Cryo",   "Wind": "Anemo",   "Earth": "Geo",
	"Nature": "Dendro",
}
const ELEMENTS = ["Fire", "Water", "Electric", "Ice", "Wind", "Earth", "Nature"]

# ═══════════════════════════════════════════════════════════════════════
#  CONTENT DATA
# ═══════════════════════════════════════════════════════════════════════
const STATUS_DATA = {
	"Control": [
		["Stun", "Turn is skipped entirely. Cannot act, move, or use any abilities — including \"at any time\" abilities."],
		["Root", "Cannot move. Abilities with built-in movement (blinks, dashes) cannot be used. You can still attack."],
		["Blind", "Your target is randomized by dice roll. AoE abilities center on the random target. Friendly fire is enabled."],
		["Disarm", "Weapon is knocked away. Cannot attack until recovered. May swap to a same-type weapon from inventory (counts as action). Weapon lost if not picked up by battle end."],
		["Taunt", "Forces enemies to target the taunting unit."],
		["Fear", "Forces enemies to move away from and target the ally furthest from the fearing unit."],
	],
	"Movement": [
		["Slow", "Each tile of movement counts as 2. (Move half as far.)"],
		["Quick", "Each tile of movement counts as 0.5. (Move twice as far.)"],
		["Hot Feet", "Must use full movement before attacking. Cannot end on your starting tile."],
		["Slippery", "Next movement slides your full distance in the chosen direction. Cannot stop early."],
		["Pinned", "Cannot rotate or change facing direction."],
		["Loner", "If any entity is on surrounding tiles at end of turn, your next attack deals no damage."],
	],
	"Combat": [
		["Advantage", "Roll twice, take the better result."],
		["Disadvantage", "Roll twice, take the worse result."],
		["Camouflage", "Cannot be seen or targeted by enemies. Ends when you attack or use an ability on an ally."],
		["Dazed", "Must act, but can only use Basic Attacks. Skills and Bursts are locked."],
		["Collateral Damage", "When you deal damage, 25% of the final damage is also dealt to the ally closest to you."],
		["Reflect", "The next attack against this unit is reflected back at the attacker."],
	],
	"Debuffs": [
		["Burst Bust", "Cannot generate burst charges while active."],
		["Skill Suck", "Skill cooldowns do not decrease while active."],
		["Unlucky", "Overrides your daily luck. Bad things happen."],
		["Overheated", "Using an ability with a cooldown increases its cooldown by 1 additional turn."],
		["Locked In", "Must repeat the same actions from last turn in the same order, if possible."],
		["Shield-Break", "Incoming damage is doubled. Cannot gain a new shield or eat food items. Lasts 2 turns."],
	],
	"Buffs": [
		["Lucky", "Overrides your daily luck. Good things happen."],
		["En Garde", "The next attack against this unit deals no damage and the attacker is stunned for 1 turn."],
	],
}

const STATUS_CATEGORY_COLORS = {
	"Control": ORANGE, "Movement": BLUE, "Combat": SEC,
	"Debuffs": RED, "Buffs": GREEN,
}

const ENEMY_CLASSES = [
	["Common", "10–60", "Single weak attack (e.g., slimes)"],
	["Uncommon", "35–125", "Single heavy attack, potentially one weak attack"],
	["Rare", "75–175", "Multiple attack types, often multi-tile enemies"],
	["Epic", "150–350", "Multiple strong attacks, usually has at least one immunity"],
	["Legendary", "250–600", "Essentially single-phase bosses. Very painful."],
]

const WEAPON_RARITIES = [
	["Common", "3–4", "None"],
	["Uncommon", "4–5", "Basic effect"],
	["Rare", "5–6", "Decent effect"],
	["Epic", "6–8", "Good effect"],
	["Legendary", "8–10", "Great effect"],
]

const DICE_BREAKPOINTS = [
	["0 – 3", "D4", "Minimum die"],
	["4 – 5", "D4", ""],
	["6 – 7", "D6", ""],
	["8 – 9", "D8", ""],
	["10 – 11", "D10", ""],
	["12 – 19", "D12", "Must reach 20 to upgrade"],
	["20 – 23", "D20", "Full threshold required"],
	["24 – 25", "D20 + D4", "Overflow adds bonus die"],
	["26 – 27", "D20 + D6", ""],
	["28+", "D20 + ...", "Remainder rounded down to bonus die"],
]

const STAT_ALLOC = [
	["Health", "1 point", "+2 HP"],
	["Attack", "1 point", "+1 ATK"],
	["Defense", "1 point", "+1 DEF"],
	["Elemental Mastery", "1 point", "+1 EM"],
	["Energy Recharge", "1 point", "+0.1 ER"],
	["Critical Damage", "1 point", "+0.1 CD"],
]

const MOVEMENT_TABLE = [
	["No combat action (move only)", "7 tiles"],
	["Basic Attack", "Varies by ability"],
	["Charged Attack", "1 tile"],
	["Skill", "1 tile"],
	["Burst", "Varies by ability"],
]

const MULTIHIT_TABLE = [
	["1st Hit", "100%", "Full damage"],
	["2nd Hit", "33%", "1/3 damage"],
	["3rd Hit", "11%", "1/9 damage"],
	["4th Hit", "3.6%", "1/27 damage"],
	["5th+ Hit", "<2%", "Continues at 1/3 per hit"],
]

const ABILITY_TYPES = [
	["Basic Attack", "None", "Standard attack. Usually allows the most movement."],
	["Charged Attack", "None (or burst)", "Stronger than basic but limits movement to 1 tile. Some consume burst charges."],
	["Skill", "Cooldown", "Powerful ability with a turn cooldown. Often generates burst charges."],
	["Burst", "Burst Charges", "Ultimate ability consuming burst charges. Most powerful attacks."],
	["Passive", "None", "Always-active effect. No action required."],
]

# ═══════════════════════════════════════════════════════════════════════
#  TOC STRUCTURE
# ═══════════════════════════════════════════════════════════════════════
const TOC = [
	{"ch": "1", "title": "Combat", "sections": [
		{"title": "Overview", "id": "combat_overview"},
		{"title": "Turn Order", "id": "combat_turn_order"},
		{"title": "Movement", "id": "combat_movement"},
		{"title": "Attacking & Defending", "id": "combat_attacking", "subs": [
			{"title": "Roll Resolution", "id": "combat_roll_resolution"},
			{"title": "Critical Hits", "id": "combat_crits"},
			{"title": "Multi-Hit Diminishing", "id": "combat_multihit"},
		]},
		{"title": "Items in Combat", "id": "combat_items"},
		{"title": "Shields", "id": "combat_shields"},
		{"title": "Burst Charges", "id": "combat_burst"},
	]},
	{"ch": "2", "title": "Stats & Dice", "sections": [
		{"title": "Base Stats", "id": "stats_overview"},
		{"title": "Stat Allocation", "id": "stats_allocation"},
		{"title": "Dice Scaling", "id": "stats_dice_scaling"},
		{"title": "Stat Descriptions", "id": "stats_details", "subs": [
			{"title": "Health", "id": "stats_health"},
			{"title": "Attack", "id": "stats_attack"},
			{"title": "Defense", "id": "stats_defense"},
			{"title": "Elemental Mastery", "id": "stats_em"},
			{"title": "Energy Recharge", "id": "stats_er"},
			{"title": "Critical Damage", "id": "stats_cd"},
		]},
	]},
	{"ch": "3", "title": "Elements & Reactions", "sections": [
		{"title": "The Seven Elements", "id": "elements_overview"},
		{"title": "How Reactions Work", "id": "reactions_overview"},
		{"title": "Fire Reactions", "id": "reactions_fire"},
		{"title": "Water Reactions", "id": "reactions_water"},
		{"title": "Electric Reactions", "id": "reactions_electric"},
		{"title": "Ice Reactions", "id": "reactions_ice"},
		{"title": "Wind Reactions", "id": "reactions_wind"},
		{"title": "Earth Reactions", "id": "reactions_earth"},
		{"title": "Nature Reactions", "id": "reactions_nature"},
	]},
	{"ch": "4", "title": "Status Effects", "sections": [
		{"title": "Control Effects", "id": "status_control"},
		{"title": "Movement Effects", "id": "status_movement"},
		{"title": "Combat Effects", "id": "status_combat"},
		{"title": "Debuffs", "id": "status_debuffs"},
		{"title": "Buffs", "id": "status_buffs"},
	]},
	{"ch": "5", "title": "Abilities & Kits", "sections": [
		{"title": "Ability Types", "id": "abilities_types"},
		{"title": "Cooldowns", "id": "abilities_cooldowns"},
		{"title": "Passives", "id": "abilities_passives"},
		{"title": "Targeting & AoE", "id": "abilities_targeting"},
	]},
	{"ch": "6", "title": "Equipment", "sections": [
		{"title": "Weapons", "id": "equip_weapons"},
		{"title": "Artifacts", "id": "equip_artifacts"},
		{"title": "Artifact Set Bonuses", "id": "equip_artifact_sets"},
		{"title": "Artifact Forge", "id": "equip_artifact_forge"},
	]},
	{"ch": "7", "title": "Enemies", "sections": [
		{"title": "Classifications", "id": "enemies_classifications"},
		{"title": "World Bosses", "id": "enemies_world_bosses"},
		{"title": "Quest Bosses", "id": "enemies_quest_bosses"},
		{"title": "Fog of War", "id": "enemies_fog"},
	]},
	{"ch": "8", "title": "Companions", "sections": [
		{"title": "Overview", "id": "companions_overview"},
		{"title": "Companion Stats", "id": "companions_stats"},
		{"title": "Companion Death", "id": "companions_death"},
		{"title": "Active Limits", "id": "companions_limits"},
	]},
	{"ch": "9", "title": "Economy & Crafting", "sections": [
		{"title": "Market", "id": "economy_market"},
		{"title": "Crafting", "id": "economy_crafting"},
		{"title": "Gathering", "id": "economy_gathering"},
		{"title": "Elemental Gems", "id": "economy_gems"},
	]},
	{"ch": "10", "title": "Progression", "sections": [
		{"title": "Ascension", "id": "prog_ascension"},
		{"title": "Respec", "id": "prog_respec"},
		{"title": "Character Gambles", "id": "prog_gambles"},
	]},
]

# ═══════════════════════════════════════════════════════════════════════
#  MEMBER VARIABLES
# ═══════════════════════════════════════════════════════════════════════
var _content_scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _toc_scroll: ScrollContainer
var _search_input: LineEdit
var _search_results_panel: VBoxContainer
var _search_results_container: VBoxContainer
var _section_nodes: Dictionary = {}     # id -> Control
var _toc_buttons: Dictionary = {}       # id -> Button
var _search_index: Array = []           # [{title, chapter, snippet, id}]
var _chapter_section_containers: Array = []  # [{btn, sections_vbox}]


func _ready():
	_build_ui()


# ═══════════════════════════════════════════════════════════════════════
#  MAIN UI STRUCTURE
# ═══════════════════════════════════════════════════════════════════════
func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Root split: sidebar | content
	var root_hbox = HBoxContainer.new()
	root_hbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 0)
	add_child(root_hbox)

	# ── Sidebar ──
	var sidebar = PanelContainer.new()
	sidebar.custom_minimum_size.x = 290
	sidebar.size_flags_horizontal = Control.SIZE_FILL
	var sb_style = StyleBoxFlat.new()
	sb_style.bg_color = PANEL
	sb_style.border_color = BORDER
	sb_style.border_width_right = 1
	sidebar.add_theme_stylebox_override("panel", sb_style)
	root_hbox.add_child(sidebar)

	var sidebar_vbox = VBoxContainer.new()
	sidebar_vbox.add_theme_constant_override("separation", 0)
	sidebar.add_child(sidebar_vbox)

	_build_sidebar_header(sidebar_vbox)
	_build_toc(sidebar_vbox)

	# ── Content area ──
	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_hbox.add_child(_content_scroll)

	var content_margin = MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 36)
	content_margin.add_theme_constant_override("margin_right", 36)
	content_margin.add_theme_constant_override("margin_top", 24)
	content_margin.add_theme_constant_override("margin_bottom", 60)
	_content_scroll.add_child(content_margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 6)
	content_margin.add_child(_content_vbox)

	# ── Build all content ──
	_ch1_combat()
	_ch2_stats()
	_ch3_elements()
	_ch4_status()
	_ch5_abilities()
	_ch6_equipment()
	_ch7_enemies()
	_ch8_companions()
	_ch9_economy()
	_ch10_progression()

	# Wire scroll tracking
	_content_scroll.get_v_scroll_bar().value_changed.connect(_on_content_scrolled)

	# Close button — anchored top-right, always on top
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 18)
	var csb = StyleBoxFlat.new()
	csb.bg_color = PANEL
	csb.border_color = BORDER
	csb.set_border_width_all(1)
	csb.set_corner_radius_all(4)
	csb.content_margin_left = 10
	csb.content_margin_right = 10
	csb.content_margin_top = 6
	csb.content_margin_bottom = 6
	close_btn.add_theme_stylebox_override("normal", csb)
	var csb_h = csb.duplicate()
	csb_h.bg_color = Color(RED.r, RED.g, RED.b, 0.2)
	csb_h.border_color = RED
	close_btn.add_theme_stylebox_override("hover", csb_h)
	close_btn.add_theme_color_override("font_color", MUTED)
	close_btn.add_theme_color_override("font_hover_color", RED)
	close_btn.pressed.connect(func():
		var win = get_parent()
		if win is Window:
			win.queue_free()
		else:
			queue_free()
	)
	close_btn.z_index = 100
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.anchor_left = 1.0
	close_btn.anchor_top = 0.0
	close_btn.anchor_right = 1.0
	close_btn.anchor_bottom = 0.0
	close_btn.offset_left = -50
	close_btn.offset_top = 8
	close_btn.offset_right = -8
	close_btn.offset_bottom = 42
	add_child(close_btn)


# ═══════════════════════════════════════════════════════════════════════
#  SIDEBAR HEADER (title + search)
# ═══════════════════════════════════════════════════════════════════════
func _build_sidebar_header(parent: VBoxContainer):
	var header = VBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var hm = MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 16)
	hm.add_theme_constant_override("margin_right", 16)
	hm.add_theme_constant_override("margin_top", 14)
	hm.add_theme_constant_override("margin_bottom", 10)
	hm.add_child(header)
	parent.add_child(hm)

	var title = Label.new()
	title.text = "Rules & Reference"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT)
	header.add_child(title)

	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search rules, terms, mechanics..."
	_search_input.add_theme_font_size_override("font_size", 13)
	var si_sb = StyleBoxFlat.new()
	si_sb.bg_color = INSET
	si_sb.border_color = BORDER
	si_sb.set_border_width_all(1)
	si_sb.set_corner_radius_all(6)
	si_sb.content_margin_left = 10
	si_sb.content_margin_right = 10
	si_sb.content_margin_top = 7
	si_sb.content_margin_bottom = 7
	_search_input.add_theme_stylebox_override("normal", si_sb)
	var si_focus = si_sb.duplicate()
	si_focus.border_color = ACCENT
	_search_input.add_theme_stylebox_override("focus", si_focus)
	_search_input.add_theme_color_override("font_color", TEXT)
	_search_input.add_theme_color_override("font_placeholder_color", MUTED)
	_search_input.text_changed.connect(_on_search_changed)
	header.add_child(_search_input)

	# Search results container (hidden by default)
	_search_results_panel = VBoxContainer.new()
	_search_results_panel.visible = false
	header.add_child(_search_results_panel)

	var sr_scroll = ScrollContainer.new()
	sr_scroll.custom_minimum_size.y = 40
	sr_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	sr_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_search_results_panel.add_child(sr_scroll)

	_search_results_container = VBoxContainer.new()
	_search_results_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_results_container.add_theme_constant_override("separation", 0)
	sr_scroll.add_child(_search_results_container)

	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	parent.add_child(sep)


# ═══════════════════════════════════════════════════════════════════════
#  TABLE OF CONTENTS
# ═══════════════════════════════════════════════════════════════════════
func _build_toc(parent: VBoxContainer):
	_toc_scroll = ScrollContainer.new()
	_toc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_toc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(_toc_scroll)

	var toc_vbox = VBoxContainer.new()
	toc_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toc_vbox.add_theme_constant_override("separation", 0)
	_toc_scroll.add_child(toc_vbox)

	for ch_data in TOC:
		var ch_container = VBoxContainer.new()
		ch_container.add_theme_constant_override("separation", 0)
		toc_vbox.add_child(ch_container)

		# Chapter button
		var ch_btn = Button.new()
		ch_btn.text = "  %s.  %s" % [ch_data["ch"], ch_data["title"]]
		ch_btn.add_theme_font_size_override("font_size", 14)
		ch_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var btn_sb = StyleBoxFlat.new()
		btn_sb.bg_color = Color(0, 0, 0, 0)
		btn_sb.content_margin_left = 14
		btn_sb.content_margin_top = 7
		btn_sb.content_margin_bottom = 7
		ch_btn.add_theme_stylebox_override("normal", btn_sb)
		var btn_hov = btn_sb.duplicate()
		btn_hov.bg_color = CARD
		ch_btn.add_theme_stylebox_override("hover", btn_hov)
		ch_btn.add_theme_color_override("font_color", TEXT)
		ch_container.add_child(ch_btn)

		# Sections container (initially hidden except first chapter)
		var sections_vbox = VBoxContainer.new()
		sections_vbox.add_theme_constant_override("separation", 0)
		sections_vbox.visible = (ch_data["ch"] == "1")
		ch_container.add_child(sections_vbox)

		_chapter_section_containers.append({"btn": ch_btn, "sections": sections_vbox})

		# Wire chapter toggle
		var idx = _chapter_section_containers.size() - 1
		ch_btn.pressed.connect(_toggle_chapter.bind(idx))

		# Build section buttons
		for sec in ch_data["sections"]:
			_add_toc_section_btn(sections_vbox, sec["title"], sec["id"], 0)
			if sec.has("subs"):
				for sub in sec["subs"]:
					_add_toc_section_btn(sections_vbox, sub["title"], sub["id"], 1)


func _add_toc_section_btn(parent: VBoxContainer, title: String, id: String, depth: int):
	var btn = Button.new()
	btn.text = title
	btn.add_theme_font_size_override("font_size", 13 if depth == 0 else 12)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.content_margin_left = 30 + depth * 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.border_color = BORDER
	sb.border_width_left = 2
	btn.add_theme_stylebox_override("normal", sb)
	var hov = sb.duplicate()
	hov.bg_color = Color(1, 1, 1, 0.02)
	hov.border_color = MUTED
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_color_override("font_color", MUTED if depth == 1 else SEC)
	btn.pressed.connect(_scroll_to.bind(id))
	parent.add_child(btn)
	_toc_buttons[id] = btn


func _toggle_chapter(idx: int):
	var entry = _chapter_section_containers[idx]
	var was_visible = entry["sections"].visible

	# Collapse all
	for e in _chapter_section_containers:
		e["sections"].visible = false
		e["btn"].add_theme_color_override("font_color", TEXT)

	# Toggle this one
	if not was_visible:
		entry["sections"].visible = true
		entry["btn"].add_theme_color_override("font_color", ACCENT)

	# Scroll to first section of this chapter
	if not was_visible:
		var ch_data = TOC[idx]
		if ch_data["sections"].size() > 0:
			var first_id = ch_data["sections"][0]["id"]
			_scroll_to.call_deferred(first_id)


# ═══════════════════════════════════════════════════════════════════════
#  SEARCH
# ═══════════════════════════════════════════════════════════════════════
func _on_search_changed(query: String):
	if query.length() < 2:
		_search_results_panel.visible = false
		return

	_search_results_panel.visible = true
	for c in _search_results_container.get_children():
		c.queue_free()

	var q = query.to_lower()
	var matches = []
	for entry in _search_index:
		var title_lower = entry["title"].to_lower()
		var snippet_lower = entry["snippet"].to_lower()
		var kw_lower = entry.get("keywords", "").to_lower()
		if title_lower.find(q) >= 0 or snippet_lower.find(q) >= 0 or kw_lower.find(q) >= 0:
			matches.append(entry)
		if matches.size() >= 12:
			break

	if matches.is_empty():
		var no_lbl = Label.new()
		no_lbl.text = "  No results"
		no_lbl.add_theme_font_size_override("font_size", 13)
		no_lbl.add_theme_color_override("font_color", MUTED)
		_search_results_container.add_child(no_lbl)
		return

	# Set max height based on number of results
	var sr_scroll = _search_results_panel.get_child(0) as ScrollContainer
	sr_scroll.custom_minimum_size.y = mini(matches.size() * 54, 280)

	for m in matches:
		var btn = Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		var bsb = StyleBoxFlat.new()
		bsb.bg_color = CARD
		bsb.border_color = BORDER
		bsb.border_width_bottom = 1
		bsb.content_margin_left = 10
		bsb.content_margin_right = 10
		bsb.content_margin_top = 6
		bsb.content_margin_bottom = 6
		btn.add_theme_stylebox_override("normal", bsb)
		var bsb_h = bsb.duplicate()
		bsb_h.bg_color = INSET
		btn.add_theme_stylebox_override("hover", bsb_h)
		btn.add_theme_color_override("font_color", ACCENT)
		btn.text = "%s  —  %s" % [m["title"], m["chapter"]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_scroll_to.bind(m["id"]))
		_search_results_container.add_child(btn)


func _index(title: String, chapter: String, snippet: String, id: String, keywords: String = ""):
	_search_index.append({"title": title, "chapter": chapter, "snippet": snippet, "id": id, "keywords": keywords})


# ═══════════════════════════════════════════════════════════════════════
#  NAVIGATION
# ═══════════════════════════════════════════════════════════════════════
func _scroll_to(id: String):
	if not _section_nodes.has(id):
		return
	var node = _section_nodes[id] as Control
	# Calculate position relative to content vbox
	var pos = 0.0
	var n = node
	while n != null and n != _content_scroll:
		pos += n.position.y
		n = n.get_parent()
	_content_scroll.scroll_vertical = int(pos) - 16
	_highlight_toc(id)


func _highlight_toc(id: String):
	for tid in _toc_buttons:
		var btn = _toc_buttons[tid] as Button
		var sb = btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if tid == id:
			sb.border_color = ACCENT
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_color_override("font_color", ACCENT)
		else:
			sb.border_color = BORDER
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_color_override("font_color", SEC if sb.content_margin_left < 44 else MUTED)


func _on_content_scrolled(_val: float):
	# Find topmost visible section
	var scroll_y = _content_scroll.scroll_vertical + 60
	var best_id = ""
	var best_y = -999999.0
	for id in _section_nodes:
		var node = _section_nodes[id] as Control
		var pos = 0.0
		var n = node
		while n != null and n != _content_scroll:
			pos += n.position.y
			n = n.get_parent()
		if pos <= scroll_y and pos > best_y:
			best_y = pos
			best_id = id
	if best_id != "":
		_highlight_toc(best_id)


# ═══════════════════════════════════════════════════════════════════════
#  UI HELPERS
# ═══════════════════════════════════════════════════════════════════════
func _sec(id: String) -> MarginContainer:
	# Returns a margin container that registers as a scrollable section
	var mc = MarginContainer.new()
	mc.add_theme_constant_override("margin_top", 16)
	mc.add_theme_constant_override("margin_bottom", 8)
	mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_nodes[id] = mc
	return mc

func _h2(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", ACCENT)
	return l

func _h3(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", TEXT)
	return l

func _h4(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", SEC)
	return l

func _hr() -> HSeparator:
	return HSeparator.new()

func _p(bbcode: String, size: int = 14) -> RichTextLabel:
	var r = RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 1)
	r.add_theme_font_size_override("bold_italics_font_size", size + 1)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", SEC)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size.x = 200
	r.text = bbcode
	return r

func _info_card(title: String, body_bb: String, type: String = "default") -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	match type:
		"highlight": sb.border_width_left = 3; sb.border_color = ACCENT
		"warning":   sb.border_width_left = 3; sb.border_color = ORANGE; sb.bg_color = Color(ORANGE.r, ORANGE.g, ORANGE.b, 0.06)
		"danger":    sb.border_width_left = 3; sb.border_color = RED; sb.bg_color = Color(RED.r, RED.g, RED.b, 0.06)
	pc.add_theme_stylebox_override("panel", sb)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)
	var t = Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 14)
	t.add_theme_color_override("font_color", TEXT)
	vb.add_child(t)
	var b = _p(body_bb, 13)
	vb.add_child(b)
	return pc

func _table(headers: Array, rows: Array) -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	pc.add_theme_stylebox_override("panel", sb)
	var grid = GridContainer.new()
	grid.columns = headers.size()
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	pc.add_child(grid)

	# Headers
	for h in headers:
		var cell = PanelContainer.new()
		var csb = StyleBoxFlat.new()
		csb.bg_color = CARD
		csb.border_color = BORDER
		csb.border_width_bottom = 2
		csb.content_margin_left = 12
		csb.content_margin_right = 12
		csb.content_margin_top = 7
		csb.content_margin_bottom = 7
		cell.add_theme_stylebox_override("panel", csb)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l = Label.new()
		l.text = h
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", ACCENT)
		cell.add_child(l)
		grid.add_child(cell)

	# Rows
	for row in rows:
		for i in range(row.size()):
			var cell = PanelContainer.new()
			var csb = StyleBoxFlat.new()
			csb.bg_color = Color(0, 0, 0, 0)
			csb.border_color = BORDER
			csb.border_width_bottom = 1
			csb.content_margin_left = 12
			csb.content_margin_right = 12
			csb.content_margin_top = 6
			csb.content_margin_bottom = 6
			cell.add_theme_stylebox_override("panel", csb)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var l = Label.new()
			l.text = str(row[i])
			l.add_theme_font_size_override("font_size", 13)
			l.add_theme_color_override("font_color", TEXT if i == 0 else SEC)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			cell.add_child(l)
			grid.add_child(cell)
	return pc

func _bullet_list(items: Array) -> VBoxContainer:
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	for item in items:
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		vb.add_child(hb)
		var arrow = Label.new()
		arrow.text = ">"
		arrow.add_theme_font_size_override("font_size", 13)
		arrow.add_theme_color_override("font_color", ACCENT)
		arrow.custom_minimum_size.x = 14
		hb.add_child(arrow)
		var r = _p(item, 13)
		hb.add_child(r)
	return vb

func _status_item(sname: String, desc: String, color: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	pc.add_child(hb)
	var nl = Label.new()
	nl.text = sname
	nl.add_theme_font_size_override("font_size", 14)
	nl.add_theme_color_override("font_color", color)
	nl.custom_minimum_size.x = 140
	hb.add_child(nl)
	var dl = _p(desc, 13)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(dl)
	return pc

func _reaction_card(elem1: String, elem2: String, outcome: String, desc: String) -> PanelContainer:
	var pc = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var ocolor = GREEN
	match outcome.to_upper():
		"UNFAVORABLE": ocolor = RED; sb.border_color = Color(RED.r, RED.g, RED.b, 0.4)
		"NEUTRAL": ocolor = BLUE; sb.border_color = Color(BLUE.r, BLUE.g, BLUE.b, 0.4)
		_: ocolor = GREEN; sb.border_color = Color(GREEN.r, GREEN.g, GREEN.b, 0.4)
	sb.border_width_left = 3
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	pc.add_child(vb)

	# Element labels
	var el_hb = HBoxContainer.new()
	el_hb.add_theme_constant_override("separation", 6)
	vb.add_child(el_hb)
	el_hb.add_child(_elem_badge(elem1))
	var plus = Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 14)
	plus.add_theme_color_override("font_color", MUTED)
	el_hb.add_child(plus)
	el_hb.add_child(_elem_badge(elem2))

	# Outcome
	var ol = Label.new()
	ol.text = outcome.to_upper()
	ol.add_theme_font_size_override("font_size", 11)
	ol.add_theme_color_override("font_color", ocolor)
	vb.add_child(ol)

	# Description
	var dl = _p(desc, 13)
	vb.add_child(dl)
	return pc

func _elem_badge(elem: String) -> PanelContainer:
	var pc = PanelContainer.new()
	var color = ELEM_COLORS.get(elem, TEXT)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.12)
	sb.border_color = Color(color.r, color.g, color.b, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	var l = Label.new()
	l.text = elem
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	pc.add_child(l)
	return pc

func _spacer(h: int = 12) -> Control:
	var c = Control.new()
	c.custom_minimum_size.y = h
	return c


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 1: COMBAT
# ═══════════════════════════════════════════════════════════════════════
func _ch1_combat():
	var ch = "Ch. 1 — Combat"

	# Overview
	var s1 = _sec("combat_overview")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_h2("1. Combat"))
	v1.add_child(_p("Combat is turn-based. Each player takes their turn in a set order, performing movement, attacks, and item usage. Enemies act between player turns depending on their type."))
	_content_vbox.add_child(s1)
	_index("Combat Overview", ch, "Turn-based combat with dice rolls", "combat_overview", "battle fight turn")

	# Turn Order
	var s2 = _sec("combat_turn_order")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("Turn Order"))
	v2.add_child(_hr())
	v2.add_child(_p("Turn order is set during [b]Battle Prep[/b] before combat begins. Players decide the order they will act in. This order stays fixed for the entire combat encounter but can be rearranged between encounters."))
	v2.add_child(_info_card("Boss Turn Timing", "[b]World Bosses[/b] act after every [i]other[/i] player action.\n[b]Quest Bosses[/b] act after [i]every[/i] player action.", "highlight"))
	_content_vbox.add_child(s2)
	_index("Turn Order", ch, "Set during battle prep, fixed for encounter", "combat_turn_order", "order initiative sequence")

	# Movement
	var s3 = _sec("combat_movement")
	var v3 = VBoxContainer.new()
	v3.add_theme_constant_override("separation", 8)
	s3.add_child(v3)
	v3.add_child(_h3("Movement"))
	v3.add_child(_hr())
	v3.add_child(_p("Each player can move a number of tiles per turn. Movement generally happens [b]before[/b] attacking unless the ability specifies otherwise."))
	v3.add_child(_table(["Action", "Movement Tiles"], MOVEMENT_TABLE))
	v3.add_child(_info_card("Distance Calculation", "Tile distance is calculated using [b]4 cardinal directions only[/b] (up/down/left/right), not diagonals. This applies to movement, ability range, and all distance checks.", "default"))
	_content_vbox.add_child(s3)
	_index("Movement", ch, "7 tiles no action, 1 tile for skill/charged", "combat_movement", "move tiles walk run")

	# Attacking & Defending
	var s4 = _sec("combat_attacking")
	var v4 = VBoxContainer.new()
	v4.add_theme_constant_override("separation", 8)
	s4.add_child(v4)
	v4.add_child(_h3("Attacking & Defending"))
	v4.add_child(_hr())
	_content_vbox.add_child(s4)
	_index("Attacking & Defending", ch, "Attack and defense dice rolls", "combat_attacking", "attack defend damage hit miss roll")

	# Roll Resolution
	var s4a = _sec("combat_roll_resolution")
	var v4a = VBoxContainer.new()
	v4a.add_theme_constant_override("separation", 8)
	s4a.add_child(v4a)
	v4a.add_child(_h4("Roll Resolution"))
	v4a.add_child(_p("When a player attacks, both sides roll dice:"))
	v4a.add_child(_bullet_list([
		"[b]Attacker[/b] rolls their attack die — determined by [b]Attack stat[/b] for physical attacks, or [b]Elemental Mastery stat[/b] for elemental attacks",
		"[b]Defender[/b] rolls their defense die (determined by their Defense stat)",
		"If the attacker's roll is [b]higher[/b], the attack hits",
		"The [b]difference[/b] between the rolls determines the damage die: round down to the nearest standard die size",
		"The attacker then rolls that damage die to determine [b]base damage[/b] before any multipliers or bonuses",
	]))
	v4a.add_child(_info_card("Example", "Attacker rolls [b]15[/b], Defender rolls [b]8[/b]. Difference = 7.\nRounded down to nearest die: [b]D6[/b]. Attacker rolls a D6 for base damage.", "highlight"))
	v4a.add_child(_info_card("Which Stat Determines Your Dice?", "[b]Physical attacks[/b] (generally basic and charged attacks): uses your [b]Attack[/b] stat.\n[b]Elemental attacks[/b] (skills, bursts, anything dealing elemental damage): uses your [b]Elemental Mastery[/b] stat.\nSome abilities specify exceptions to this rule.", "warning"))
	_content_vbox.add_child(s4a)
	_index("Roll Resolution", ch, "Attacker vs defender dice, difference = damage die", "combat_roll_resolution", "dice roll damage difference resolution")

	# Crits
	var s4b = _sec("combat_crits")
	var v4b = VBoxContainer.new()
	v4b.add_theme_constant_override("separation", 8)
	s4b.add_child(v4b)
	v4b.add_child(_h4("Critical Hits"))
	v4b.add_child(_p("A critical hit occurs when the attacker's roll exceeds [b]20[/b] (by default). Weapons and effects can raise or lower this threshold. Critical hits apply bonus damage from your Critical Damage stat and trigger any ON_CRIT effects from weapons, artifacts, or abilities."))
	_content_vbox.add_child(s4b)
	_index("Critical Hits", ch, "Roll above 20 to crit, threshold can change", "combat_crits", "crit critical hit threshold")

	# Multi-hit
	var s4c = _sec("combat_multihit")
	var v4c = VBoxContainer.new()
	v4c.add_theme_constant_override("separation", 8)
	s4c.add_child(v4c)
	v4c.add_child(_h4("Multi-Hit Diminishing Returns"))
	v4c.add_child(_p("Successive hits on the [b]same target[/b] from a single attack deal diminishing damage unless the ability specifies otherwise:"))
	v4c.add_child(_table(["Hit #", "Damage", "Fraction"], MULTIHIT_TABLE))
	v4c.add_child(_info_card("Exceptions", "Some abilities explicitly bypass diminishing returns. The more situational or difficult an ability's AoE is to land, the less likely this rule applies. Abilities will state if they are an exception.", "warning"))
	_content_vbox.add_child(s4c)
	_index("Multi-Hit Diminishing", ch, "Successive hits on same target reduced by 1/3 each", "combat_multihit", "multi hit aoe diminishing returns successive")

	# Items
	var s5 = _sec("combat_items")
	var v5 = VBoxContainer.new()
	v5.add_theme_constant_override("separation", 8)
	s5.add_child(v5)
	v5.add_child(_h3("Items in Combat"))
	v5.add_child(_hr())
	v5.add_child(_p("Using an item does [b]not[/b] consume your action for the turn. You may attack and use an item in the same turn. However, you may only use [b]one item per turn[/b]."))
	v5.add_child(_bullet_list([
		"Multiple heal-over-time foods do [b]not[/b] stack. Using a new one replaces the active one.",
		"You can use an instant heal food while keeping an active heal-over-time effect.",
		"Soups are used to revive downed players/companions.",
	]))
	_content_vbox.add_child(s5)
	_index("Items in Combat", ch, "Free action, one per turn, food stacking rules", "combat_items", "items food heal potion soup revive")

	# Shields
	var s6 = _sec("combat_shields")
	var v6 = VBoxContainer.new()
	v6.add_theme_constant_override("separation", 8)
	s6.add_child(v6)
	v6.add_child(_h3("Shields"))
	v6.add_child(_hr())
	v6.add_child(_p("Shields are [b]directional[/b] and rotate with your character. By default a shield covers one of 4 cardinal directions unless the ability specifies multiple or all directions."))
	v6.add_child(_bullet_list([
		"Shields absorb damage before HP when hit from the shielded direction",
		"Default shield duration is [b]4 turns[/b] unless specified otherwise",
		"When a shield's [b]health reaches 0[/b] (broken by damage), the unit receives [b]Shield-Break[/b] status for 2 turns",
		"When a shield [b]expires naturally[/b] (turns run out), no penalty is applied",
		"You control when your shield blocks — you can choose to save it for a specific attack",
		"All elements create the same shield. They will last for a set number of turns or until health runs out",
	]))
	v6.add_child(_info_card("Shield-Break", "Incoming damage is [b]doubled[/b]. Cannot gain a new shield or eat food items while active. Lasts 2 turns.", "danger"))
	_content_vbox.add_child(s6)
	_index("Shields", ch, "Directional, absorb before HP, shield-break debuff", "combat_shields", "shield block direction guard protect crystallize")

	# Burst Charges
	var s7 = _sec("combat_burst")
	var v7 = VBoxContainer.new()
	v7.add_theme_constant_override("separation", 8)
	s7.add_child(v7)
	v7.add_child(_h3("Burst Charges"))
	v7.add_child(_hr())
	v7.add_child(_p("Burst charges are the resource used to activate your Burst ability. They are generated primarily through Skills and Charged Attacks."))
	v7.add_child(_bullet_list([
		"After using a Skill or Charged Attack, the ability typically has you roll a [b]D4[/b] for burst charges gained",
		"The roll result is then [b]multiplied by your Energy Recharge[/b] stat (rounded down, minimum 1)",
		"Once you reach your Burst's charge cost, you can use it — charges are consumed on use",
	]))
	_content_vbox.add_child(s7)
	_index("Burst Charges", ch, "Generated by skills, multiplied by ER, spent on bursts", "combat_burst", "burst charge energy ultimate")


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 2: STATS & DICE
# ═══════════════════════════════════════════════════════════════════════
func _ch2_stats():
	var ch = "Ch. 2 — Stats & Dice"

	var s1 = _sec("stats_overview")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_spacer(20))
	v1.add_child(_h2("2. Stats & Dice"))
	v1.add_child(_p("Your stats determine the dice you roll in combat. Higher stats mean bigger dice, and bigger dice mean better outcomes."))
	_content_vbox.add_child(s1)
	_index("Stats Overview", ch, "Stats determine dice size", "stats_overview", "stats dice")

	# Allocation
	var s2 = _sec("stats_allocation")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("Stat Allocation"))
	v2.add_child(_hr())
	v2.add_child(_p("Each player starts with [b]45 base stat points[/b] they can allocate freely:"))
	v2.add_child(_table(["Stat", "Cost per Point", "Gain per Point"], STAT_ALLOC))
	v2.add_child(_p("Upon ascending, stats reset to base values. Each ascension level grants [b]that level's worth of bonus points[/b] (e.g., ascending to rank 3 gives 3 additional points)."))
	_content_vbox.add_child(s2)
	_index("Stat Allocation", ch, "45 base points, HP costs 2 per point", "stats_allocation", "allocate points distribute base")

	# Dice Scaling
	var s3 = _sec("stats_dice_scaling")
	var v3 = VBoxContainer.new()
	v3.add_theme_constant_override("separation", 8)
	s3.add_child(v3)
	v3.add_child(_h3("Dice Scaling"))
	v3.add_child(_hr())
	v3.add_child(_p("Your stat value determines what die you roll. Values round [b]down[/b] to the nearest valid die size:"))
	v3.add_child(_table(["Stat Value", "Die", "Notes"], DICE_BREAKPOINTS))
	v3.add_child(_info_card("The D20 Threshold", "You must reach [b]exactly 20[/b] to qualify for a D20. A stat of 19 still rounds down to D12. This encourages balanced stat distribution rather than maxing a single stat.", "warning"))
	_content_vbox.add_child(s3)
	_index("Dice Scaling", ch, "Stat to die conversion, D4 through D20+bonus", "stats_dice_scaling", "dice scaling D4 D6 D8 D10 D12 D20 breakpoint threshold")

	# Stat Details
	var s4 = _sec("stats_details")
	var v4 = VBoxContainer.new()
	v4.add_theme_constant_override("separation", 8)
	s4.add_child(v4)
	v4.add_child(_h3("Stat Descriptions"))
	v4.add_child(_hr())
	_content_vbox.add_child(s4)
	_index("Stat Descriptions", ch, "What each stat does", "stats_details")

	var stat_info = [
		["stats_health", "Health (HP)", "Your hit points. When HP reaches 0, you are [b]downed[/b] and must be revived with a soup item. Cost: 2 HP per stat point. Also boosted by weapon effects, artifact stats, and food buffs."],
		["stats_attack", "Attack (ATK)", "Determines your attack die for [b]physical attacks[/b] (generally basic and charged attacks). Higher attack means bigger dice when attacking physically."],
		["stats_defense", "Defense (DEF)", "Determines your defense die. When attacked, you roll your defense die — the higher you roll, the less damage you take or block the attack entirely."],
		["stats_em", "Elemental Mastery (EM)", "Determines your attack die for [b]elemental attacks[/b] (skills, bursts, anything dealing elemental damage). Does [b]not[/b] influence reaction damage — reactions have their own preset dice."],
		["stats_er", "Energy Recharge (ER)", "Multiplies burst charge gain. When you gain burst charges (e.g., rolling a D4 after a skill), the result is multiplied by your ER value, rounded down (minimum 1)."],
		["stats_cd", "Critical Damage (CD)", "Bonus damage multiplier applied on critical hits. Added on top of base damage when your attack roll exceeds the crit threshold."],
	]
	for si in stat_info:
		var ss = _sec(si[0])
		var vv = VBoxContainer.new()
		vv.add_theme_constant_override("separation", 6)
		ss.add_child(vv)
		vv.add_child(_h4(si[1]))
		vv.add_child(_p(si[2]))
		_content_vbox.add_child(ss)
		_index(si[1], ch, si[2].substr(0, 60), si[0], si[1].to_lower())


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 3: ELEMENTS & REACTIONS
# ═══════════════════════════════════════════════════════════════════════
func _ch3_elements():
	var ch = "Ch. 3 — Elements & Reactions"

	# Overview
	var s1 = _sec("elements_overview")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_spacer(20))
	v1.add_child(_h2("3. Elements & Reactions"))
	v1.add_child(_p("Seven elements govern combat. Applying one element to a target that already has a different element triggers a reaction — some helpful, some disastrous."))
	# Element badges
	var badge_flow = HFlowContainer.new()
	badge_flow.add_theme_constant_override("h_separation", 8)
	badge_flow.add_theme_constant_override("v_separation", 6)
	for elem in ELEMENTS:
		var badge_pc = _elem_badge(elem)
		# Make it bigger
		var bl = badge_pc.get_child(0) as Label
		bl.text = "%s (%s)" % [elem, ELEM_ICONS[elem]]
		bl.add_theme_font_size_override("font_size", 14)
		badge_flow.add_child(badge_pc)
	v1.add_child(badge_flow)
	_content_vbox.add_child(s1)
	_index("The Seven Elements", ch, "Fire Water Electric Ice Wind Earth Nature", "elements_overview", "element pyro hydro electro cryo anemo geo dendro")

	# How reactions work
	var s2 = _sec("reactions_overview")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("How Reactions Work"))
	v2.add_child(_hr())
	v2.add_child(_p("When an attack applies an element to a target that already has a [b]different[/b] element applied, a reaction triggers. The reaction depends on [b]which element was already on the target[/b] (first) and [b]which element is being applied[/b] (second). [b]Order matters[/b] for almost every reaction — the same two elements can produce very different outcomes depending on which was applied first."))
	v2.add_child(_info_card("Favorable vs Unfavorable",
		"[color=#4ada7f][b]FAVORABLE[/b][/color] — Benefits the attacker\n[color=#ef4444][b]UNFAVORABLE[/b][/color] — Hurts the attacker or helps the defender\n[color=#60a5fa][b]NEUTRAL[/b][/color] — Affects both sides equally", "highlight"))
	v2.add_child(_p("[i]Reaction damage is separate from the attack's own damage and is not affected by multipliers (like crits) unless specified otherwise.[/i]"))
	_content_vbox.add_child(s2)
	_index("How Reactions Work", ch, "Order matters, favorable vs unfavorable", "reactions_overview", "reaction element order favorable unfavorable")

	# Load reactions from .tres files
	var reactions = _load_reactions()

	# Per-element reaction sections
	for elem in ELEMENTS:
		var sec_id = "reactions_" + elem.to_lower()
		var s = _sec(sec_id)
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		s.add_child(v)
		var hb_title = HBoxContainer.new()
		hb_title.add_theme_constant_override("separation", 10)
		v.add_child(hb_title)
		hb_title.add_child(_elem_badge(elem))
		hb_title.add_child(_h3("Reactions"))
		v.add_child(_hr())

		# Reactions where this element is being applied (second)
		v.add_child(_p("[b]When %s is applied[/b] to a target that already has another element:" % elem))
		var grid1 = GridContainer.new()
		grid1.columns = 2
		grid1.add_theme_constant_override("h_separation", 10)
		grid1.add_theme_constant_override("v_separation", 10)
		grid1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(grid1)
		for other in ELEMENTS:
			if other == elem:
				continue
			var key = other.to_lower() + "_" + elem.to_lower()
			if reactions.has(key):
				var r = reactions[key]
				grid1.add_child(_reaction_card(r.first_element, r.second_element, r.outcome, r.effect))
				_index("%s + %s Reaction" % [r.first_element, r.second_element], ch, r.effect.substr(0, 50), sec_id, "%s %s reaction %s" % [r.first_element.to_lower(), r.second_element.to_lower(), r.outcome.to_lower()])

		v.add_child(_spacer(8))

		# Reactions where this element is already on target (first)
		v.add_child(_p("[b]When %s is already on the target[/b] and another element is applied:" % elem))
		var grid2 = GridContainer.new()
		grid2.columns = 2
		grid2.add_theme_constant_override("h_separation", 10)
		grid2.add_theme_constant_override("v_separation", 10)
		grid2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(grid2)
		for other in ELEMENTS:
			if other == elem:
				continue
			var key = elem.to_lower() + "_" + other.to_lower()
			if reactions.has(key):
				var r = reactions[key]
				grid2.add_child(_reaction_card(r.first_element, r.second_element, r.outcome, r.effect))

		_content_vbox.add_child(s)
		_index("%s Reactions" % elem, ch, "All reactions involving %s" % elem, sec_id, "%s %s element reaction" % [elem.to_lower(), ELEM_ICONS[elem].to_lower()])


func _load_reactions() -> Dictionary:
	var result = {}
	for e1 in ELEMENTS:
		for e2 in ELEMENTS:
			if e1 == e2:
				continue
			var path = "res://data/resources/reactions/%s_%s.tres" % [e1.to_lower(), e2.to_lower()]
			if ResourceLoader.exists(path):
				var r = load(path)
				if r:
					result[e1.to_lower() + "_" + e2.to_lower()] = r
	return result


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 4: STATUS EFFECTS
# ═══════════════════════════════════════════════════════════════════════
func _ch4_status():
	var ch = "Ch. 4 — Status Effects"

	var s0 = _sec("status_control")
	var v0 = VBoxContainer.new()
	v0.add_theme_constant_override("separation", 8)
	s0.add_child(v0)
	v0.add_child(_spacer(20))
	v0.add_child(_h2("4. Status Effects"))
	v0.add_child(_p("Status effects alter a unit's capabilities for a set duration. Multiple statuses can be active simultaneously. Some cancel out (e.g., Slow + Quick = normal speed)."))
	_content_vbox.add_child(s0)
	_index("Status Effects", ch, "Alter capabilities, can stack or cancel", "status_control", "status effect buff debuff condition")

	var category_ids = {"Control": "status_control", "Movement": "status_movement",
		"Combat": "status_combat", "Debuffs": "status_debuffs", "Buffs": "status_buffs"}

	for cat_name in STATUS_DATA:
		var sid = category_ids[cat_name]
		var is_first = (cat_name == "Control")
		var container = v0 if is_first else null

		if not is_first:
			var ss = _sec(sid)
			container = VBoxContainer.new()
			container.add_theme_constant_override("separation", 8)
			ss.add_child(container)
			_content_vbox.add_child(ss)

		container.add_child(_h3(cat_name + " Effects" if cat_name in ["Control", "Movement", "Combat"] else cat_name))
		container.add_child(_hr())

		var cat_color = STATUS_CATEGORY_COLORS[cat_name]
		for entry in STATUS_DATA[cat_name]:
			var si = _status_item(entry[0], entry[1], cat_color)
			container.add_child(si)
			_index(entry[0], ch, entry[1].substr(0, 50), sid, "%s status effect %s" % [entry[0].to_lower(), cat_name.to_lower()])

		_index(cat_name, ch, "%d effects" % STATUS_DATA[cat_name].size(), sid)


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 5: ABILITIES & KITS
# ═══════════════════════════════════════════════════════════════════════
func _ch5_abilities():
	var ch = "Ch. 5 — Abilities & Kits"

	var s1 = _sec("abilities_types")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_spacer(20))
	v1.add_child(_h2("5. Abilities & Kits"))
	v1.add_child(_p("Every character has a set of abilities (their \"kit\") tied to their element and weapon type. Abilities are modular — there is no fixed template for what a kit must look like."))
	v1.add_child(_h3("Ability Types"))
	v1.add_child(_hr())
	v1.add_child(_table(["Type", "Cost", "Description"], ABILITY_TYPES))
	_content_vbox.add_child(s1)
	_index("Ability Types", ch, "Basic, Charged, Skill, Burst, Passive", "abilities_types", "ability type basic charged skill burst passive")

	# Cooldowns
	var s2 = _sec("abilities_cooldowns")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("Cooldowns"))
	v2.add_child(_hr())
	v2.add_child(_p("Skills (and some charged attacks) have a [b]turn cooldown[/b] after use. The cooldown decreases by 1 at the start of each of your turns. You cannot use the ability again until the cooldown reaches 0."))
	v2.add_child(_bullet_list([
		"Cooldowns reset between combat encounters",
		"Some abilities have [b]charges[/b] — you can use them multiple times before the cooldown starts",
		"The [b]Skill Suck[/b] status prevents cooldowns from decreasing",
		"The [b]Overheated[/b] status adds +1 to cooldowns on use",
	]))
	_content_vbox.add_child(s2)
	_index("Cooldowns", ch, "Turn-based cooldown on skills, resets between fights", "abilities_cooldowns", "cooldown charge turns reset")

	# Passives
	var s3 = _sec("abilities_passives")
	var v3 = VBoxContainer.new()
	v3.add_theme_constant_override("separation", 8)
	s3.add_child(v3)
	v3.add_child(_h3("Passives"))
	v3.add_child(_hr())
	v3.add_child(_p("Passive abilities are always active and require no action. They can provide stat bonuses, conditional triggers, stacking mechanics, or other persistent effects. Some passives have stacking systems that are tracked automatically."))
	_content_vbox.add_child(s3)
	_index("Passives", ch, "Always-active abilities, stacking mechanics", "abilities_passives", "passive always active stack")

	# Targeting
	var s4 = _sec("abilities_targeting")
	var v4 = VBoxContainer.new()
	v4.add_theme_constant_override("separation", 8)
	s4.add_child(v4)
	v4.add_child(_h3("Targeting & AoE"))
	v4.add_child(_hr())
	v4.add_child(_p("Abilities specify their targeting rules:"))
	v4.add_child(_bullet_list([
		"[b]Single target[/b] — One enemy or ally",
		"[b]AoE (Area of Effect)[/b] — Hits all units within a radius, line, or cone",
		"[b]Self[/b] — Affects only the caster",
		"Distances use [b]cardinal directions[/b] (not diagonal)",
		"AoE abilities subject to [b]multi-hit diminishing[/b] on same targets unless stated otherwise",
	]))
	_content_vbox.add_child(s4)
	_index("Targeting & AoE", ch, "Single target, AoE, self-targeting rules", "abilities_targeting", "target area effect aoe range radius")


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 6: EQUIPMENT
# ═══════════════════════════════════════════════════════════════════════
func _ch6_equipment():
	var ch = "Ch. 6 — Equipment"

	# Weapons
	var s1 = _sec("equip_weapons")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_spacer(20))
	v1.add_child(_h2("6. Equipment"))
	v1.add_child(_p("Weapons and artifacts provide stat bonuses and powerful effects that define your build."))
	v1.add_child(_h3("Weapons"))
	v1.add_child(_hr())
	v1.add_child(_p("Weapons come in 5 types: [b]Sword, Claymore, Polearm, Bow, Catalyst[/b]. Your equipped weapon type determines which abilities you can use."))
	v1.add_child(_table(["Rarity", "Stat Attributes", "Effect"], WEAPON_RARITIES))
	v1.add_child(_info_card("Stat Conversion on Weapons",
		"HP, ATK, DEF, EM: [b]1 attribute point = 1 stat[/b]\nCrit Damage, Energy Recharge: [b]1 attribute point = 0.25 stat[/b]", "default"))
	v1.add_child(_p("A refined weapon of a lower tier can match or exceed a base weapon of a higher tier. A max-refined Rare weapon is comparable to a Legendary weapon in stats, with a slightly weaker effect."))
	_content_vbox.add_child(s1)
	_index("Weapons", ch, "5 types, rarity determines stats and effects", "equip_weapons", "weapon sword claymore polearm bow catalyst rarity")

	# Artifacts
	var s2 = _sec("equip_artifacts")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("Artifacts"))
	v2.add_child(_hr())
	v2.add_child(_p("Artifacts are equippable gear pieces that provide stat bonuses. There are 5 artifact slots:"))
	v2.add_child(_table(["Piece", "Can Have"], [
		["Flower of Life", "HP, ATK, DEF, EM"],
		["Feather of Death", "HP, ATK, DEF, EM"],
		["Sands of Time", "HP, ATK, DEF, EM, Energy Recharge"],
		["Goblet of Space", "HP, ATK, DEF, EM, Universal Damage Bonus"],
		["Circlet of Principles", "HP, ATK, DEF, EM, Critical Damage"],
	]))
	v2.add_child(_p("Artifacts can have 1 or 2 substats. Each substat has a value that can be positive or negative."))
	_content_vbox.add_child(s2)
	_index("Artifacts", ch, "5 slots, substats with positive/negative values", "equip_artifacts", "artifact flower feather sands goblet circlet substat")

	# Set bonuses
	var s3 = _sec("equip_artifact_sets")
	var v3 = VBoxContainer.new()
	v3.add_theme_constant_override("separation", 8)
	s3.add_child(v3)
	v3.add_child(_h3("Artifact Set Bonuses"))
	v3.add_child(_hr())
	v3.add_child(_p("Equipping multiple artifacts from the same set activates set bonuses:"))
	v3.add_child(_bullet_list([
		"[b]2-piece bonus[/b] — Activated when 2 or more pieces from the same set are equipped",
		"[b]4-piece bonus[/b] — Activated when 4 or more pieces from the same set are equipped (includes the 2-piece bonus as well)",
		"Some set bonuses have [b]element conditions[/b] — they only activate when your character's current element matches",
	]))
	_content_vbox.add_child(s3)
	_index("Artifact Set Bonuses", ch, "2-piece and 4-piece bonuses from matching sets", "equip_artifact_sets", "set bonus 2pc 4pc artifact equip")

	# Forge
	var s4 = _sec("equip_artifact_forge")
	var v4 = VBoxContainer.new()
	v4.add_theme_constant_override("separation", 8)
	s4.add_child(v4)
	v4.add_child(_h3("Artifact Forge"))
	v4.add_child(_hr())
	v4.add_child(_p("Artisans can sacrifice artifacts to forge new ones using dice rolls:"))
	v4.add_child(_bullet_list([
		"[b]Random Set[/b] — Sacrifice 2 artifacts, get a random set piece",
		"[b]Choose Set[/b] — Sacrifice 3 artifacts, choose which set the result belongs to",
	]))
	v4.add_child(_p("[b]Forge Dice Rolls:[/b]"))
	v4.add_child(_table(["Step", "Dice", "Determines"], [
		["1. Piece Type", "D12", "1-3 Flower, 4-6 Feather, 7-8 Sands, 9-10 Goblet, 11-12 Circlet"],
		["1. Substat Count", "D20", "1-12 = one substat, 13+ = two substats"],
		["2. Stat Type", "D8 or D10", "D8 for Flower/Feather, D10 for Sands/Goblet/Circlet"],
		["2. Sign", "D12", "1-6 = negative stat, 7+ = positive stat"],
		["2. Value", "D20", "Multiplied by 0.1 for final stat value"],
		["3. Substat 2", "Same as Step 2", "Only if D20 from Step 1 was 13+"],
	]))
	v4.add_child(_info_card("D10 Stat Mapping (Sands/Goblet/Circlet)",
		"1-2 HP, 3-4 ATK, 5-7 DEF, 8-9 EM\n[b]10:[/b] Sands = Energy Recharge, Goblet = Damage Bonus, Circlet = Crit Damage", "highlight"))
	_content_vbox.add_child(s4)
	_index("Artifact Forge", ch, "Sacrifice artifacts to forge new ones with dice", "equip_artifact_forge", "forge craft sacrifice artifact artisan dice")


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 7: ENEMIES
# ═══════════════════════════════════════════════════════════════════════
func _ch7_enemies():
	var ch = "Ch. 7 — Enemies"

	var s1 = _sec("enemies_classifications")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_spacer(20))
	v1.add_child(_h2("7. Enemies"))
	v1.add_child(_p("Enemies are classified by rarity which determines their health range, attack variety, and overall threat."))
	v1.add_child(_h3("Classifications"))
	v1.add_child(_hr())
	v1.add_child(_table(["Classification", "Health", "Description"], ENEMY_CLASSES))
	v1.add_child(_p("Health values scale with game progression — earlier encounters use lower values, later ones use higher values within each tier."))
	_content_vbox.add_child(s1)
	_index("Enemy Classifications", ch, "Common through Legendary, health ranges", "enemies_classifications", "enemy classification common uncommon rare epic legendary tier")

	# World bosses
	var s2 = _sec("enemies_world_bosses")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("World Bosses"))
	v2.add_child(_hr())
	v2.add_child(_p("World bosses have clear attack patterns with indicators. They act after every [b]other[/b] player action."))
	v2.add_child(_table(["Property", "Value"], [
		["Phases", "1–3"],
		["Unique Attacks", "6–12"],
		["HP per Phase", "50–400"],
		["Defense to Block", "6–16 (avg ~10)"],
		["Attacks that Penetrate Defense", "1 or fewer"],
		["Damage per Hit", "D4–D12 (avg ~1D8)"],
	]))
	_content_vbox.add_child(s2)
	_index("World Bosses", ch, "Multi-phase, act every other player turn", "enemies_world_bosses", "world boss phase pattern")

	# Quest bosses
	var s3 = _sec("enemies_quest_bosses")
	var v3 = VBoxContainer.new()
	v3.add_theme_constant_override("separation", 8)
	s3.add_child(v3)
	v3.add_child(_h3("Quest Bosses"))
	v3.add_child(_hr())
	v3.add_child(_p("Quest bosses are tougher than world bosses. They act after [b]every[/b] player action. Player death is not uncommon."))
	v3.add_child(_table(["Property", "Value"], [
		["Phases", "1–4"],
		["Unique Attacks", "6–16"],
		["HP per Phase", "100–500"],
		["Defense to Block", "10–20 (avg ~10)"],
		["Attacks that Penetrate Defense", "2+"],
		["Damage per Hit", "D8+ (avg ~10)"],
	]))
	v3.add_child(_p("Average damage and defense requirements scale up by [b]half the ascension level[/b] (e.g., at rank 4, avg defense to block becomes 12 instead of 10)."))
	_content_vbox.add_child(s3)
	_index("Quest Bosses", ch, "Tougher than world bosses, act every turn", "enemies_quest_bosses", "quest boss hard difficult")

	# Fog of War
	var s4 = _sec("enemies_fog")
	var v4 = VBoxContainer.new()
	v4.add_theme_constant_override("separation", 8)
	s4.add_child(v4)
	v4.add_child(_h3("Fog of War"))
	v4.add_child(_hr())
	v4.add_child(_p("Some enemies are hidden at the start of battle. They are not visible on the physical board or in the battle UI until you trigger discovering them (e.g., entering a room). Once discovered, the battle UI automatically updates to show them."))
	_content_vbox.add_child(s4)
	_index("Fog of War", ch, "Hidden enemies until discovered on the board", "enemies_fog", "fog war hidden discover surprise")


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 8: COMPANIONS
# ═══════════════════════════════════════════════════════════════════════
func _ch8_companions():
	var ch = "Ch. 8 — Companions"

	var s1 = _sec("companions_overview")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_spacer(20))
	v1.add_child(_h2("8. Companions"))
	v1.add_child(_p("Companions are NPCs that fight alongside your party. They have their own abilities and can hold/use items in battle."))
	_content_vbox.add_child(s1)
	_index("Companions Overview", ch, "NPCs that fight alongside your party", "companions_overview", "companion npc ally friend")

	var s2 = _sec("companions_stats")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("Companion Stats"))
	v2.add_child(_hr())
	v2.add_child(_p("Companion stats are equal to the [b]average of the entire party[/b] in every stat. They cannot equip artifacts but will be able to equip weapons."))
	_content_vbox.add_child(s2)
	_index("Companion Stats", ch, "Equal to party average in every stat", "companions_stats", "companion stats average")

	var s3 = _sec("companions_death")
	var v3 = VBoxContainer.new()
	v3.add_theme_constant_override("separation", 8)
	s3.add_child(v3)
	v3.add_child(_h3("Companion Death"))
	v3.add_child(_hr())
	v3.add_child(_p("Companions can be [b]downed[/b] (reach 0 HP) during battle and revived with soups, just like players. However:"))
	v3.add_child(_info_card("Permanent Death", "If a companion is still [b]downed (0 HP)[/b] when the battle ends, they are [b]permanently dead[/b] and cannot be used anymore. Revive them before the battle ends!", "danger"))
	_content_vbox.add_child(s3)
	_index("Companion Death", ch, "Permanent if still downed when battle ends", "companions_death", "companion death die permanent down revive")

	var s4 = _sec("companions_limits")
	var v4 = VBoxContainer.new()
	v4.add_theme_constant_override("separation", 8)
	s4.add_child(v4)
	v4.add_child(_h3("Active Limits"))
	v4.add_child(_hr())
	v4.add_child(_bullet_list([
		"[b]Free companions[/b] (gained at the start of a region) can only be used within that region",
		"[b]Permanently unlocked[/b] companions can be used anywhere, including other regions' story missions",
		"Unlockable companions start at the ascension level of their region (e.g., Liyue companion starts at rank 2)",
		"There are two types of active companions: [b]Player Chosen[/b] (you select them) and [b]DM Set[/b] (always active, set by the DM)",
	]))
	_content_vbox.add_child(s4)
	_index("Companion Limits", ch, "Free vs permanent, region restrictions", "companions_limits", "companion limit region free permanent unlock")


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 9: ECONOMY & CRAFTING
# ═══════════════════════════════════════════════════════════════════════
func _ch9_economy():
	var ch = "Ch. 9 — Economy & Crafting"

	var s1 = _sec("economy_market")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_spacer(20))
	v1.add_child(_h2("9. Economy & Crafting"))
	v1.add_child(_h3("Market"))
	v1.add_child(_hr())
	v1.add_child(_p("The market lets you buy and sell items, weapons, and artifacts. Gold (Mora) is a [b]party-wide[/b] resource."))
	v1.add_child(_bullet_list([
		"[b]Buy prices[/b] vary by item rarity, region stock, and luck",
		"[b]Sell prices[/b] are intentionally low (10-30% of value) — like a pawn shop",
		"Market stock [b]refreshes when you return from a battle[/b], not on every visit",
		"Artifacts and weapons have their own market sections separate from items",
	]))
	_content_vbox.add_child(s1)
	_index("Market", ch, "Buy/sell items, party-wide gold, pawn shop prices", "economy_market", "market buy sell gold mora shop price")

	var s2 = _sec("economy_crafting")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("Crafting"))
	v2.add_child(_hr())
	v2.add_child(_p("Crafting recipes use materials from your inventory to create items, food, and other materials. Some recipes accept [b]any material of a type[/b] rather than a specific material (e.g., \"any type of sugar\")."))
	v2.add_child(_p("Recipes are role-gated. The [b]Artisan[/b] role has access to the Artifact Forge for creating new artifacts from sacrificed ones."))
	_content_vbox.add_child(s2)
	_index("Crafting", ch, "Use materials to craft items, role-gated", "economy_crafting", "craft recipe material cook food")

	var s3 = _sec("economy_gathering")
	var v3 = VBoxContainer.new()
	v3.add_theme_constant_override("separation", 8)
	s3.add_child(v3)
	v3.add_child(_h3("Gathering"))
	v3.add_child(_hr())
	v3.add_child(_p("Gathering lets you collect regional materials by rolling dice. Available materials depend on your current region. Gathering is a frequent activity done between combat encounters."))
	_content_vbox.add_child(s3)
	_index("Gathering", ch, "Roll dice to collect regional materials", "economy_gathering", "gather collect material resource")

	var s4 = _sec("economy_gems")
	var v4 = VBoxContainer.new()
	v4.add_theme_constant_override("separation", 8)
	s4.add_child(v4)
	v4.add_child(_h3("Elemental Gems"))
	v4.add_child(_hr())
	v4.add_child(_p("Elemental gems come in 4 star tiers (1-star through 4-star) for each of the 7 elements. They are used for ascension and can be crafted:"))
	v4.add_child(_bullet_list([
		"[b]Upgrade[/b] — Combine lower-tier gems of the same element into a higher-tier gem",
		"[b]Downgrade[/b] — Break a higher-tier gem into multiple lower-tier gems of any element (3 gems per downgrade)",
		"Gem crafting recipes use generic material types (e.g., \"2-Star Gem\" matches any element)",
	]))
	_content_vbox.add_child(s4)
	_index("Elemental Gems", ch, "Upgrade/downgrade between tiers, used for ascension", "economy_gems", "gem element star tier upgrade downgrade ascension")


# ═══════════════════════════════════════════════════════════════════════
#  CHAPTER 10: PROGRESSION
# ═══════════════════════════════════════════════════════════════════════
func _ch10_progression():
	var ch = "Ch. 10 — Progression"

	var s1 = _sec("prog_ascension")
	var v1 = VBoxContainer.new()
	v1.add_theme_constant_override("separation", 8)
	s1.add_child(v1)
	v1.add_child(_spacer(20))
	v1.add_child(_h2("10. Progression"))
	v1.add_child(_h3("Ascension"))
	v1.add_child(_hr())
	v1.add_child(_p("Ascension increases your level cap and grants bonus stat points. To ascend you must:"))
	v1.add_child(_bullet_list([
		"Be at the current [b]level cap[/b]",
		"Have [b]beaten the bosses[/b] of your current chapter/story section",
		"Have a certain number of [b]elemental gems[/b] for your base element",
	]))
	v1.add_child(_p("Each ascension grants [b]that rank's worth of bonus stat points[/b]. Ascending to rank 3 gives 3 extra points, rank 4 gives 4 extra points, etc."))
	_content_vbox.add_child(s1)
	_index("Ascension", ch, "Level cap increase, requires bosses and gems", "prog_ascension", "ascend level cap rank progression")

	var s2 = _sec("prog_respec")
	var v2 = VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	s2.add_child(v2)
	v2.add_child(_h3("Respec"))
	v2.add_child(_hr())
	v2.add_child(_p("At any point outside of battle, you can [b]redistribute your base stat points[/b] by making an offering to Paimon. If Paimon accepts, you can reallocate all your points according to the normal stat allocation rules."))
	_content_vbox.add_child(s2)
	_index("Respec", ch, "Redistribute stat points via Paimon offering", "prog_respec", "respec redistribute reallocate stats paimon")

	var s3 = _sec("prog_gambles")
	var v3 = VBoxContainer.new()
	v3.add_theme_constant_override("separation", 8)
	s3.add_child(v3)
	v3.add_child(_h3("Character Gambles"))
	v3.add_child(_hr())
	v3.add_child(_p("Character Gambles are a way to unlock companions without completing their quest:"))
	v3.add_child(_bullet_list([
		"Pay [b]500 Mora[/b] for a dice roll to earn a Character Gamble",
		"On success, you can choose to [b]double or nothing[/b] with a free follow-up roll",
		"Collect [b]10 Character Gambles[/b] to unlock a random locked character",
		"Gambles are [b]party-wide[/b] and NOT sellable",
		"Players must take [b]ordered turns[/b] — no one can do all gamble rolls in a row",
		"Daily luck [b]slightly[/b] impacts your dice roll chances",
		"Some characters require their quest and cannot be gambled (e.g., archons)",
	]))
	_content_vbox.add_child(s3)
	_index("Character Gambles", ch, "500 Mora dice roll, 10 gambles = random character", "prog_gambles", "gamble gacha character unlock roll dice mora")
