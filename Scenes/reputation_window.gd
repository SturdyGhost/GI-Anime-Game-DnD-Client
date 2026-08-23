extends Control
## Reputation window — opened from the DM Hub and Player Hub. Four tabs:
## Regions, Factions, People, Recent. Shows how the world regards the party,
## with the cascade region -> faction -> NPC. A region-context selector drives
## how cross-nation (Global) factions/NPCs are judged. The People tab is a
## master-detail NPC screen (portrait, bio, greeting, dealings, quests + the
## reputation analytics) driven by the same "Viewing as" / region selectors.

signal panel_closed

# ---- palette (matches the gear/detail scenes) ----
const BG_DEEP   = Color(0.102, 0.122, 0.169)
const BG_PANEL  = Color(0.133, 0.157, 0.22)
const BG_CARD   = Color(0.165, 0.192, 0.27)
const BG_INSET  = Color(0.09, 0.11, 0.155)
const BORDER    = Color(0.22, 0.25, 0.33)
const TEXT      = Color(0.96, 0.96, 0.98)
const TEXT_SEC  = Color(0.78, 0.80, 0.87)
const TEXT_MUT  = Color(0.58, 0.62, 0.71)
const ACCENT    = Color(0.788, 0.659, 0.298)
const GREEN     = Color(0.292, 0.855, 0.498)
const YELLOW    = Color(0.918, 0.702, 0.031)
const ORANGE    = Color(0.90, 0.55, 0.20)
const RED       = Color(0.937, 0.267, 0.267)

const FONT_BODY  = 28
const FONT_HDR   = 34
const FONT_TITLE = 46
const MARGIN     = 60

var _ctx_region: String = ""
var _actor: String = ""   # "" = whole party; else a specific member's view
var _region_select: OptionButton
var _actor_select: OptionButton
var _tabs: TabContainer
var _lists: Dictionary = {}   # tab name -> VBoxContainer
# People tab (master-detail)
var _people_list: VBoxContainer
var _people_detail: VBoxContainer
var _selected_npc: String = ""

func _ready() -> void:
	# Bare Control.new() roots start at 0x0 — fill the parent ourselves (the .tscn
	# panels bake this in). Without it the whole window collapses to nothing.
	custom_minimum_size = Vector2(2560, 1440)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ctx_region = str(Global.Current_Region) if str(Global.Current_Region) != "" else "Mondstadt"
	# Default to the viewer's OWN perspective if they're a party member, so each
	# player auto-sees their personal reputation. DM (not in party) sees the party.
	if str(Global.ACTIVE_USER_NAME) in Global.PartyCharacters:
		_actor = str(Global.ACTIVE_USER_NAME)
	_build_ui()
	if not ReputationManager.is_connected("reputation_changed", Callable(self, "_refresh")):
		ReputationManager.connect("reputation_changed", Callable(self, "_refresh"))
	if not Global.is_connected("data_load_complete", Callable(self, "_refresh")):
		Global.connect("data_load_complete", Callable(self, "_refresh"))
	if not QuestManager.is_connected("quests_changed", Callable(self, "_refresh")):
		QuestManager.connect("quests_changed", Callable(self, "_refresh"))
	_refresh()

# =============================================================================
func _build_ui() -> void:
	var bg = Panel.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _flat(BG_DEEP))
	add_child(bg)

	var outer = MarginContainer.new()
	outer.set_anchors_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", MARGIN)
	outer.add_theme_constant_override("margin_right", MARGIN)
	outer.add_theme_constant_override("margin_top", MARGIN)
	outer.add_theme_constant_override("margin_bottom", MARGIN)
	add_child(outer)

	var main = VBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	outer.add_child(main)

	# Title row + region context selector + close
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	main.add_child(top)

	var title = Label.new()
	title.text = "REPUTATION"
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", ACCENT)
	top.add_child(title)

	var ctx_lbl = Label.new()
	ctx_lbl.text = "Region context:"
	ctx_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	ctx_lbl.add_theme_color_override("font_color", TEXT_SEC)
	ctx_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ctx_lbl)

	_region_select = OptionButton.new()
	_region_select.add_theme_font_size_override("font_size", FONT_BODY)
	for rn in ReputationManager.region_names():
		_region_select.add_item(str(rn))
	# select current context
	for i in range(_region_select.item_count):
		if _region_select.get_item_text(i) == _ctx_region:
			_region_select.select(i)
			break
	_region_select.item_selected.connect(func(idx):
		_ctx_region = _region_select.get_item_text(idx)
		_refresh())
	top.add_child(_region_select)

	# "Viewing as" — whole party (baseline) or a specific member's perspective
	var actor_lbl = Label.new()
	actor_lbl.text = "Viewing as:"
	actor_lbl.add_theme_font_size_override("font_size", FONT_BODY)
	actor_lbl.add_theme_color_override("font_color", TEXT_SEC)
	actor_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(actor_lbl)

	_actor_select = OptionButton.new()
	_actor_select.add_theme_font_size_override("font_size", FONT_BODY)
	_actor_select.add_item("Whole Party")
	for pn in Global.PartyCharacters:
		_actor_select.add_item(str(pn))
	# Default-select the viewer themselves.
	for i in range(_actor_select.item_count):
		if _actor_select.get_item_text(i) == _actor:
			_actor_select.select(i)
			break
	_actor_select.item_selected.connect(func(idx):
		_actor = "" if idx == 0 else _actor_select.get_item_text(idx)
		_refresh())
	top.add_child(_actor_select)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	# DM-only controls
	if NetworkManager.is_host:
		var log_btn = Button.new()
		log_btn.text = "Log Deed (DM)"
		log_btn.tooltip_text = "Record a reputation deed: fire an action or adjust standing for a member or the party."
		_style_btn(log_btn)
		log_btn.pressed.connect(_open_log_deed)
		top.add_child(log_btn)

		var reseed_btn = Button.new()
		reseed_btn.text = "Re-seed (DM)"
		reseed_btn.tooltip_text = "Clear all reputation events and reload the bundled default campaign seed."
		_style_btn(reseed_btn)
		reseed_btn.pressed.connect(_on_reseed_pressed)
		top.add_child(reseed_btn)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(40, 40)
	_style_btn(close_btn)
	close_btn.pressed.connect(_close)
	top.add_child(close_btn)

	# Legend / key — what the numbers and labels mean
	_build_legend(main)

	# Tabs
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", FONT_HDR)
	main.add_child(_tabs)

	for tab_name in ["Regions", "Factions", "People", "Recent"]:
		if tab_name == "People":
			_build_people_tab()
			continue
		var scroll = ScrollContainer.new()
		scroll.name = tab_name
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 6)
		scroll.add_child(vbox)
		_tabs.add_child(scroll)
		_lists[tab_name] = vbox

## The People tab is a master-detail view: NPC list on the left, rich detail on
## the right. It folds in the old standalone "People" screen (portrait, bio,
## greeting, dealings, quests-given) plus the reputation analytics.
func _build_people_tab() -> void:
	var split = HBoxContainer.new()
	split.name = "People"
	split.add_theme_constant_override("separation", 16)

	var lscroll = ScrollContainer.new()
	lscroll.custom_minimum_size.x = 560
	lscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_people_list = VBoxContainer.new()
	_people_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_people_list.add_theme_constant_override("separation", 4)
	lscroll.add_child(_people_list)
	split.add_child(lscroll)

	var dscroll = ScrollContainer.new()
	dscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_people_detail = VBoxContainer.new()
	_people_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_people_detail.add_theme_constant_override("separation", 8)
	dscroll.add_child(_people_detail)
	split.add_child(dscroll)

	_tabs.add_child(split)

# =============================================================================
## A key explaining the standing scale and what each label/number means.
func _build_legend(parent: VBoxContainer) -> void:
	var legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 8)
	parent.add_child(legend)

	var lead = Label.new()
	lead.text = "Standing scale  −1.5 … +1.5  →"
	lead.add_theme_font_size_override("font_size", FONT_BODY - 4)
	lead.add_theme_color_override("font_color", TEXT_MUT)
	lead.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	legend.add_child(lead)

	var tiers = [
		["Hostile", "≤ −0.6", RED],
		["Wary", "−0.6…−0.2", ORANGE],
		["Neutral", "−0.2…+0.2", TEXT_MUT],
		["Friendly", "+0.2…+0.6", GREEN.darkened(0.15)],
		["Honored", "≥ +0.6", GREEN],
	]
	for t in tiers:
		legend.add_child(_make_badge("%s  %s" % [t[0], t[1]], (t[2] as Color).darkened(0.3)))

func _refresh(_a = null) -> void:
	if _lists.is_empty():
		return
	_fill_regions(_lists["Regions"])
	_fill_factions(_lists["Factions"])
	_fill_people()
	_fill_recent(_lists["Recent"])

func _fill_regions(box: VBoxContainer) -> void:
	_clear(box)
	for r in ReputationManager.all_regions():
		var name_str := str(r.get("Name", ""))
		var weights: Dictionary = r.get("Profile", {})
		var n := ReputationManager.region_standing(name_str, _actor)
		var pills := ReputationManager.viewer_pills(weights, name_str, 8, _actor)
		var contribs := ReputationManager.deed_contributions(weights, name_str, _actor)
		contribs.append_array(ReputationManager.standing_contributions("Region", name_str))
		contribs.sort_custom(func(a, b): return absf(a.value) > absf(b.value))
		_add_entry(box, name_str, "", n, pills, contribs)

func _fill_factions(box: VBoxContainer) -> void:
	_clear(box)
	# parents first, then their children indented
	var parents := []
	var children := {}   # parent -> [factions]
	for f in ReputationManager.all_factions():
		var p := str(f.get("Parent", ""))
		if p == "":
			parents.append(f)
		else:
			if not children.has(p):
				children[p] = []
			children[p].append(f)
	for f in parents:
		_add_faction_entry(box, f, false)
		var fname := str(f.get("Name", ""))
		if children.has(fname):
			for c in children[fname]:
				_add_faction_entry(box, c, true)

func _add_faction_entry(box: VBoxContainer, f: Dictionary, is_child: bool) -> void:
	var fname := str(f.get("Name", ""))
	var region := ReputationManager.ctx_region_for(fname, _ctx_region)
	var weights := ReputationManager.faction_lens(fname)
	var n := ReputationManager.faction_standing(fname, _ctx_region, _actor)
	var pills := ReputationManager.viewer_pills(weights, region, 8, _actor)
	var contribs := ReputationManager.deed_contributions(weights, region, _actor)
	contribs.append_array(ReputationManager.standing_contributions("Faction", fname))
	contribs.sort_custom(func(a, b): return absf(a.value) > absf(b.value))
	var sub := ("sub-faction · " if is_child else "") + ("region: %s" % str(f.get("Region", "")))
	if str(f.get("Status", "active")) != "active":
		sub += "  ·  [%s]" % str(f.get("Status"))
	_add_entry(box, ("    " if is_child else "") + fname, sub, n, pills, contribs)

func _fill_recent(box: VBoxContainer) -> void:
	_clear(box)
	var hdr = Label.new()
	hdr.text = "Most recent reputation shifts (newest first)"
	hdr.add_theme_font_size_override("font_size", FONT_BODY - 2)
	hdr.add_theme_color_override("font_color", TEXT_MUT)
	box.add_child(hdr)
	for rec in ReputationManager.recent_events(50):
		var day := int(rec.get("Campaign_Day", 0))
		var who := str(rec.get("Actor", "Party"))
		var line := ""
		var val := 0.0
		if str(rec.get("Trait", "")) != "":
			val = float(rec.get("Points", 0))
			line = "%s · %s · %s %+d (%s)" % [ReputationManager.fmt_day(day), who, str(rec.get("Trait")), int(val), str(rec.get("Region", ""))]
		else:
			val = float(rec.get("Standing", 0))
			var what := str(rec.get("Note", "%s standing" % str(rec.get("Scope_Type", ""))))
			line = "%s · %s · %s [%s %s %+d]" % [ReputationManager.fmt_day(day), who, what, str(rec.get("Scope_Type", "")), str(rec.get("Scope", "")), int(val)]
		var l = Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", FONT_BODY - 4)
		l.add_theme_color_override("font_color", GREEN if val >= 0 else RED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)

# =============================================================================
# People tab (master-detail NPC screen)
# =============================================================================
func _fill_people() -> void:
	if _people_list == null:
		return
	_clear(_people_list)
	var entries := []
	for npc in ReputationManager.all_npcs():
		var nm := str(npc.get("Name", ""))
		entries.append({"name": nm, "standing": ReputationManager.npc_standing(nm, _ctx_region, _actor)})
	entries.sort_custom(func(a, b): return a.standing > b.standing)
	# Keep selection valid; default to the most-favourable NPC.
	var names := []
	for e in entries:
		names.append(e.name)
	if (_selected_npc == "" or not names.has(_selected_npc)) and not entries.is_empty():
		_selected_npc = entries[0].name
	for e in entries:
		var lbl := ReputationManager.disposition_label(e.standing)
		var btn = Button.new()
		btn.text = "%s   (%s)" % [e.name, lbl]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", FONT_BODY - 2)
		var sb = _flat(BG_CARD if e.name == _selected_npc else BG_PANEL)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(8)
		sb.border_color = ACCENT if e.name == _selected_npc else BORDER
		sb.set_border_width_all(1)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_color_override("font_color", _dispo_color(lbl))
		var nm: String = e.name
		btn.pressed.connect(func():
			_selected_npc = nm
			_fill_people())
		_people_list.add_child(btn)
	_build_person_detail()

func _build_person_detail() -> void:
	if _people_detail == null:
		return
	_clear(_people_detail)
	if _selected_npc == "":
		return
	var npc := ReputationManager.npc_def(_selected_npc)
	if npc.is_empty():
		return
	var fac := str(npc.get("Faction", ""))
	var region := ReputationManager.ctx_region_for(fac, _ctx_region)
	var standing := ReputationManager.npc_standing(_selected_npc, _ctx_region, _actor)
	var label := ReputationManager.disposition_label(standing)

	# Header: portrait + name / faction / disposition
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	_people_detail.add_child(hbox)
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(220, 220)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_load_portrait(portrait, _selected_npc)
	hbox.add_child(portrait)
	var hv = VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 4)
	hbox.add_child(hv)
	var nlbl = Label.new()
	nlbl.text = _selected_npc
	nlbl.add_theme_font_size_override("font_size", FONT_TITLE)
	nlbl.add_theme_color_override("font_color", TEXT)
	hv.add_child(nlbl)
	var flbl = Label.new()
	flbl.text = "%s · %s" % [fac, region]
	flbl.add_theme_font_size_override("font_size", FONT_BODY - 2)
	flbl.add_theme_color_override("font_color", TEXT_MUT)
	hv.add_child(flbl)
	var drow = HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	hv.add_child(drow)
	drow.add_child(_make_badge("%s  (%+.2f)" % [label, standing], _dispo_color(label)))
	if _actor != "":
		var av = Label.new()
		av.text = "toward " + _actor
		av.add_theme_font_size_override("font_size", FONT_BODY - 6)
		av.add_theme_color_override("font_color", TEXT_MUT)
		av.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		drow.add_child(av)

	# Bio
	var notes := str(npc.get("Notes", ""))
	if notes != "":
		_people_detail.add_child(_para(notes, TEXT_SEC))

	# Greeting (disposition-flavoured)
	_people_detail.add_child(_section("On meeting you"))
	_people_detail.add_child(_para(_greeting(_selected_npc, label), _dispo_color(label)))

	# Dealings gate by standing tier
	_people_detail.add_child(_section("Dealings"))
	if standing <= -0.6:
		_people_detail.add_child(_para("%s wants nothing to do with you — no trade, no favours." % _selected_npc, RED))
	elif standing < -0.2:
		_people_detail.add_child(_para("%s is guarded; they'll trade, grudgingly and at a poor rate." % _selected_npc, ORANGE))
	elif standing < 0.6:
		_people_detail.add_child(_para("%s is willing to trade and hear you out." % _selected_npc, TEXT_SEC))
	else:
		_people_detail.add_child(_para("%s is glad to help you — favourable prices and an open ear." % _selected_npc, GREEN))

	# Reputation analytics: trait pills + the deeds driving them
	var weights := ReputationManager.npc_lens(_selected_npc)
	var pills := ReputationManager.viewer_pills(weights, region, 8, _actor)
	_people_detail.add_child(_section("What shapes their view"))
	if pills.is_empty():
		_people_detail.add_child(_para("No reputation with them yet.", TEXT_MUT))
	else:
		_add_chips(_people_detail, pills)
	var contribs := ReputationManager.deed_contributions(weights, region, _actor)
	contribs.append_array(ReputationManager.standing_contributions("Faction", fac))
	contribs.append_array(ReputationManager.standing_contributions("Individual", _selected_npc))
	contribs.sort_custom(func(a, b): return absf(a.value) > absf(b.value))
	if not contribs.is_empty():
		_build_detail(_people_detail, contribs)

	# Quests this NPC has given
	var their_quests := []
	for q in QuestManager.all_quests():
		if str(q.get("Status", "")) == "deleted":
			continue
		if str(q.get("Giver", "")) == _selected_npc:
			their_quests.append(q)
	_people_detail.add_child(_section("Quests from %s" % _selected_npc))
	if their_quests.is_empty():
		var hint := "None right now."
		if NetworkManager.is_host:
			hint += "  (Author one in the Quests window, set this NPC as Giver.)"
		_people_detail.add_child(_para(hint, TEXT_MUT))
	else:
		for q in their_quests:
			_people_detail.add_child(_para("• %s  [%s]" % [str(q.get("Title", "")), str(q.get("Status", ""))], TEXT))

func _greeting(npc_name: String, label: String) -> String:
	match label:
		"Honored": return "\"%s! Well met — it's an honour. Whatever you need, you have it.\"" % npc_name
		"Friendly": return "%s greets you with a warm, easy nod. \"Good to see you.\"" % npc_name
		"Neutral": return "%s gives you a measured, noncommittal look. \"...Yes? What is it?\"" % npc_name
		"Wary": return "%s watches you warily, one hand never far from trouble. \"State your business.\"" % npc_name
		_: return "%s's face hardens with open contempt. \"You have some nerve showing your face here.\"" % npc_name

func _load_portrait(tex_rect: TextureRect, npc_name: String) -> void:
	var hyphen := npc_name.to_lower().replace(" ", "-")
	var candidates := [
		"res://UI/Splash Arts/" + hyphen + ".png",
		"res://UI/Splash Arts/" + hyphen + "-nobg.png",
		"res://UI/Character Portraits/" + npc_name + ".png",
		"res://UI/Character Portaits/ui-avataricon-" + hyphen + ".png",
		"res://UI/Character Portaits/" + npc_name + ".png",
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			var t = load(path)
			if t is Texture2D:
				tex_rect.texture = t
				return
	tex_rect.texture = null  # no art found — leave the slot empty

func _para(t: String, col: Color) -> Label:
	var l = Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", FONT_BODY - 2)
	l.add_theme_color_override("font_color", col)
	return l

# =============================================================================
# Entry (clickable / expandable row)
# =============================================================================
func _add_entry(box: VBoxContainer, title: String, subtitle: String, standing: float, pills: Array, contributions: Array) -> void:
	var card = PanelContainer.new()
	var sb = _flat(BG_PANEL)
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	# Header: ▸ + clickable title (toggles detail) + subtitle + standing badge
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)

	var arrow = Label.new()
	arrow.text = "▸"
	arrow.add_theme_font_size_override("font_size", FONT_HDR)
	arrow.add_theme_color_override("font_color", ACCENT)
	head.add_child(arrow)

	var toggle = Button.new()
	toggle.text = title
	toggle.flat = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.add_theme_font_size_override("font_size", FONT_HDR)
	toggle.add_theme_color_override("font_color", TEXT)
	toggle.add_theme_color_override("font_hover_color", ACCENT)
	head.add_child(toggle)

	if subtitle != "":
		var sub_lbl = Label.new()
		sub_lbl.text = subtitle
		sub_lbl.add_theme_font_size_override("font_size", FONT_BODY - 4)
		sub_lbl.add_theme_color_override("font_color", TEXT_MUT)
		sub_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(sub_lbl)

	var label_text := ReputationManager.disposition_label(standing)
	head.add_child(_make_badge("%s  (%+.2f)" % [label_text, standing], _dispo_color(label_text)))

	# Pills: the traits that actually drive this viewer's feeling, ordered by
	# impact and coloured green (they like) / red (they dislike).
	if pills.is_empty():
		var none = Label.new()
		none.text = "no reputation here yet"
		none.add_theme_font_size_override("font_size", FONT_BODY - 4)
		none.add_theme_color_override("font_color", TEXT_MUT)
		v.add_child(none)
	else:
		_add_chips(v, pills)

	# Detail (collapsed) — the actions driving this view, built on first expand.
	var detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 2)
	detail.visible = false
	v.add_child(detail)

	var built := [false]
	toggle.pressed.connect(func():
		if not built[0]:
			_build_detail(detail, contributions)
			built[0] = true
		detail.visible = not detail.visible
		arrow.text = "▾" if detail.visible else "▸")

	box.add_child(card)

func _build_detail(detail: VBoxContainer, contributions: Array) -> void:
	var sep = HSeparator.new()
	detail.add_child(sep)
	var hdr = Label.new()
	hdr.text = "What they're reacting to:"
	hdr.add_theme_font_size_override("font_size", FONT_BODY - 4)
	hdr.add_theme_color_override("font_color", TEXT_MUT)
	detail.add_child(hdr)
	if contributions.is_empty():
		var l = Label.new()
		l.text = "nothing they care about yet"
		l.add_theme_font_size_override("font_size", FONT_BODY - 4)
		l.add_theme_color_override("font_color", TEXT_MUT)
		detail.add_child(l)
		return
	for c in contributions:
		var fav: bool = float(c.get("value", 0.0)) >= 0.0
		var traits_arr: Array = c.get("traits", [])
		var traits_str := ""
		if not traits_arr.is_empty():
			traits_str = "  —  " + ", ".join(traits_arr.slice(0, 5))
		var row = Label.new()
		row.text = ("▲ " if fav else "▼ ") + str(c.get("label", "")) + traits_str
		row.add_theme_font_size_override("font_size", FONT_BODY - 4)
		row.add_theme_color_override("font_color", GREEN if fav else RED)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(row)

func _add_chips(parent: Control, pills: Array) -> void:
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	parent.add_child(flow)
	for entry in pills:
		var v := float(entry.get("value", 0.0))
		var col := GREEN if v > 0.0 else RED
		flow.add_child(_make_badge(str(entry.get("trait", "")), col.darkened(0.35)))

func _make_badge(text: String, bg: Color) -> PanelContainer:
	var p = PanelContainer.new()
	var sb = _flat(bg)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT_BODY - 4)
	l.add_theme_color_override("font_color", TEXT)
	p.add_child(l)
	return p

func _dispo_color(label_text: String) -> Color:
	match label_text:
		"Honored": return GREEN
		"Friendly": return GREEN.darkened(0.15)
		"Neutral": return TEXT_MUT
		"Wary": return ORANGE
		_: return RED

# =============================================================================
func _clear(box: VBoxContainer) -> void:
	for c in box.get_children():
		c.queue_free()

## DM tool: record a reputation deed live — fire an authored action, or nudge a
## region/faction/individual standing, for a chosen member or the whole party.
func _open_log_deed() -> void:
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 60
	add_child(overlay)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	var sb = _flat(BG_PANEL); sb.border_color = ACCENT; sb.set_border_width_all(1); sb.set_corner_radius_all(8); sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 10); panel.add_child(v)

	var title = Label.new(); title.text = "Log a Deed"
	title.add_theme_font_size_override("font_size", FONT_HDR); title.add_theme_color_override("font_color", ACCENT)
	v.add_child(title)

	# Who
	var who = _labeled_option(v, "Member:", ["Party"] + Array(Global.PartyCharacters))

	# --- Action path ---
	v.add_child(_section("Fire an action"))
	var action_ids: Array = []
	var action_opt = OptionButton.new(); action_opt.add_theme_font_size_override("font_size", FONT_BODY - 2)
	for a in ReputationManager.all_actions():
		action_opt.add_item(str(a.get("Label", a.get("Id", ""))))
		action_ids.append(str(a.get("Id", "")))
	v.add_child(action_opt)
	var act_region = _labeled_option(v, "Region:", Array(ReputationManager.region_names()))
	var fire_btn = Button.new(); fire_btn.text = "Apply Action"; _style_btn(fire_btn, true)
	fire_btn.pressed.connect(func():
		if action_opt.selected >= 0:
			ReputationManager.apply_action(action_ids[action_opt.selected], who.get_item_text(who.selected), act_region.get_item_text(act_region.selected))
			Toast.notify("Logged: %s" % action_opt.get_item_text(action_opt.selected), Toast.SUCCESS)
			_refresh(); overlay.queue_free())
	v.add_child(fire_btn)

	# --- Standing path ---
	v.add_child(_section("Or adjust standing directly"))
	var srow = HBoxContainer.new(); srow.add_theme_constant_override("separation", 8); v.add_child(srow)
	var scope_opt = OptionButton.new(); scope_opt.add_theme_font_size_override("font_size", FONT_BODY - 2)
	for s in ["Region", "Faction", "Individual"]:
		scope_opt.add_item(s)
	srow.add_child(scope_opt)
	var target_opt = OptionButton.new(); target_opt.add_theme_font_size_override("font_size", FONT_BODY - 2)
	target_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(target_opt)
	var repop = func():
		target_opt.clear()
		var names: Array = ReputationManager.region_names()
		if scope_opt.selected == 1: names = ReputationManager.faction_names()
		elif scope_opt.selected == 2: names = ReputationManager.npc_names()
		for n in names: target_opt.add_item(str(n))
	repop.call()
	scope_opt.item_selected.connect(func(_i): repop.call())
	var amt_row = HBoxContainer.new(); amt_row.add_theme_constant_override("separation", 8); v.add_child(amt_row)
	amt_row.add_child(_mini_label("Amount (-/+):"))
	var amt = SpinBox.new(); amt.min_value = -250; amt.max_value = 250; amt.value = 25; amt_row.add_child(amt)
	amt_row.add_child(_mini_label("Severity:"))
	var sev = SpinBox.new(); sev.min_value = 0.0; sev.max_value = 1.0; sev.step = 0.05; sev.value = 0.6; amt_row.add_child(sev)
	var stand_btn = Button.new(); stand_btn.text = "Apply Standing"; _style_btn(stand_btn, true)
	stand_btn.pressed.connect(func():
		if target_opt.selected >= 0:
			ReputationManager.record_standing(who.get_item_text(who.selected), scope_opt.get_item_text(scope_opt.selected), target_opt.get_item_text(target_opt.selected), amt.value, sev.value)
			Toast.notify("Standing logged: %s %+d" % [target_opt.get_item_text(target_opt.selected), int(amt.value)], Toast.SUCCESS)
			_refresh(); overlay.queue_free())
	v.add_child(stand_btn)

	var cancel = Button.new(); cancel.text = "Cancel"; _style_btn(cancel)
	cancel.pressed.connect(func(): overlay.queue_free())
	v.add_child(cancel)

func _labeled_option(parent: VBoxContainer, label_text: String, items: Array) -> OptionButton:
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); parent.add_child(row)
	row.add_child(_mini_label(label_text))
	var opt = OptionButton.new(); opt.add_theme_font_size_override("font_size", FONT_BODY - 2)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items: opt.add_item(str(it))
	row.add_child(opt)
	return opt

func _mini_label(t: String) -> Label:
	var l = Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", FONT_BODY - 4); l.add_theme_color_override("font_color", TEXT_SEC)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l

func _section(t: String) -> Label:
	var l = Label.new(); l.text = t
	l.add_theme_font_size_override("font_size", FONT_BODY - 2); l.add_theme_color_override("font_color", ACCENT)
	return l

func _on_reseed_pressed() -> void:
	var dlg = AcceptDialog.new()
	dlg.title = "Re-seed Reputation"
	dlg.dialog_text = "Clear ALL reputation events and reload the default campaign seed?\nThis discards reputation changes made since the last re-seed."
	dlg.ok_button_text = "Re-seed"
	dlg.add_cancel_button("Cancel")
	dlg.confirmed.connect(func():
		ReputationManager.reseed_from_defaults()
		_refresh()
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()

func _close() -> void:
	emit_signal("panel_closed")
	var p = get_parent()
	if p is Window:
		p.queue_free()
	else:
		queue_free()

func _flat(color: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = color
	return sb

func _style_btn(btn: Button, primary: bool = false) -> void:
	var base_color = ACCENT.darkened(0.45) if primary else BG_INSET
	var sb = _flat(base_color)
	sb.border_color = ACCENT if primary else BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate()
	h.bg_color = base_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)
	var fg = TEXT if primary else ACCENT
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_font_size_override("font_size", FONT_BODY)
