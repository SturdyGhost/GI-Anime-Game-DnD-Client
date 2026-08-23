extends Control
## Quest log + DM authoring. Opened from the DM Hub and Player Hub. The DM can
## create quests, toggle objectives, and complete/fail them (which grants Mora +
## reputation); players see the log read-only.

signal panel_closed

const BG_DEEP   = Color(0.102, 0.122, 0.169)
const BG_PANEL  = Color(0.133, 0.157, 0.22)
const BG_INSET  = Color(0.09, 0.11, 0.155)
const BORDER    = Color(0.22, 0.25, 0.33)
const TEXT      = Color(0.96, 0.96, 0.98)
const TEXT_SEC  = Color(0.78, 0.80, 0.87)
const TEXT_MUT  = Color(0.58, 0.62, 0.71)
const ACCENT    = Color(0.788, 0.659, 0.298)
const GREEN     = Color(0.292, 0.855, 0.498)
const ORANGE    = Color(0.90, 0.55, 0.20)
const RED       = Color(0.937, 0.267, 0.267)

const FONT_BODY  = 28
const FONT_HDR   = 34
const FONT_TITLE = 46
const MARGIN     = 60

var _list: VBoxContainer

func _ready() -> void:
	custom_minimum_size = Vector2(2560, 1440)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	if not QuestManager.is_connected("quests_changed", Callable(self, "_refresh")):
		QuestManager.connect("quests_changed", Callable(self, "_refresh"))
	if not Global.is_connected("data_load_complete", Callable(self, "_refresh")):
		Global.connect("data_load_complete", Callable(self, "_refresh"))
	_refresh()

func _build_ui() -> void:
	var bg = Panel.new(); bg.set_anchors_preset(PRESET_FULL_RECT); bg.add_theme_stylebox_override("panel", _flat(BG_DEEP)); add_child(bg)
	var outer = MarginContainer.new(); outer.set_anchors_preset(PRESET_FULL_RECT)
	for m in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + m, MARGIN)
	add_child(outer)
	var main = VBoxContainer.new(); main.add_theme_constant_override("separation", 12); outer.add_child(main)

	var top = HBoxContainer.new(); top.add_theme_constant_override("separation", 16); main.add_child(top)
	var title = Label.new(); title.text = "QUESTS"
	title.add_theme_font_size_override("font_size", FONT_TITLE); title.add_theme_color_override("font_color", ACCENT)
	top.add_child(title)
	var spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer)
	if NetworkManager.is_host:
		var new_btn = Button.new(); new_btn.text = "+ New Quest"; _style_btn(new_btn, true)
		new_btn.pressed.connect(_open_new_quest); top.add_child(new_btn)
	var close_btn = Button.new(); close_btn.text = "X"; close_btn.custom_minimum_size = Vector2(40, 40)
	_style_btn(close_btn); close_btn.pressed.connect(_close); top.add_child(close_btn)

	var scroll = ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; main.add_child(scroll)
	_list = VBoxContainer.new(); _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8); scroll.add_child(_list)

func _refresh(_a = null) -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var by_status := {"active": [], "offered": [], "completed": [], "failed": []}
	for q in QuestManager.all_quests():
		var st := str(q.get("Status", "active"))
		if st == "deleted":
			continue
		if not by_status.has(st):
			by_status[st] = []
		by_status[st].append(q)
	var any := false
	for st in ["active", "offered", "completed", "failed"]:
		if by_status.get(st, []).is_empty():
			continue
		any = true
		var hdr = Label.new(); hdr.text = st.to_upper()
		hdr.add_theme_font_size_override("font_size", FONT_BODY); hdr.add_theme_color_override("font_color", TEXT_SEC)
		_list.add_child(hdr)
		for q in by_status[st]:
			_list.add_child(_quest_card(q))
	if not any:
		var none = Label.new(); none.text = "No quests yet." + ("  Use + New Quest to add one." if NetworkManager.is_host else "")
		none.add_theme_font_size_override("font_size", FONT_BODY); none.add_theme_color_override("font_color", TEXT_MUT)
		_list.add_child(none)

func _quest_card(q: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var sb = _flat(BG_PANEL); sb.border_color = BORDER; sb.set_border_width_all(1); sb.set_corner_radius_all(6); sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 4); card.add_child(v)

	var head = HBoxContainer.new(); head.add_theme_constant_override("separation", 10); v.add_child(head)
	var name_lbl = Label.new(); name_lbl.text = str(q.get("Title", "Untitled"))
	name_lbl.add_theme_font_size_override("font_size", FONT_HDR); name_lbl.add_theme_color_override("font_color", TEXT)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(name_lbl)
	var st := str(q.get("Status", "active"))
	head.add_child(_badge(st.to_upper(), _status_color(st)))

	var meta := []
	if str(q.get("Giver", "")) not in ["", "None"]:
		meta.append("Giver: " + str(q.get("Giver")))
	if str(q.get("Region", "")) != "":
		meta.append("Region: " + str(q.get("Region")))
	if str(q.get("Owner", "Party")) not in ["", "Party"]:
		meta.append("For: " + str(q.get("Owner")))
	if not meta.is_empty():
		var ml = Label.new(); ml.text = "  ·  ".join(meta)
		ml.add_theme_font_size_override("font_size", FONT_BODY - 4); ml.add_theme_color_override("font_color", TEXT_MUT); v.add_child(ml)

	var desc := str(q.get("Description", ""))
	if desc != "":
		var dl = Label.new(); dl.text = desc; dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.add_theme_font_size_override("font_size", FONT_BODY - 2); dl.add_theme_color_override("font_color", TEXT_SEC); v.add_child(dl)

	var objs := QuestManager.objectives_of(q)
	for i in range(objs.size()):
		var done: bool = bool(objs[i].get("done", false))
		var orow = HBoxContainer.new(); orow.add_theme_constant_override("separation", 6); v.add_child(orow)
		if NetworkManager.is_host:
			var cb = CheckBox.new(); cb.button_pressed = done
			cb.add_theme_font_size_override("font_size", FONT_BODY - 2)
			cb.toggled.connect(func(_p): QuestManager.toggle_objective(q.get("id"), i))
			orow.add_child(cb)
		var ol = Label.new(); ol.text = ("✓ " if done else "○ ") + str(objs[i].get("text", ""))
		ol.add_theme_font_size_override("font_size", FONT_BODY - 2)
		ol.add_theme_color_override("font_color", GREEN if done else TEXT_SEC)
		orow.add_child(ol)

	var rewards := []
	if int(q.get("Reward_Mora", 0)) > 0:
		rewards.append("%d Mora" % int(q.get("Reward_Mora")))
	if str(q.get("Rep_Action", "")) not in ["", "None"]:
		rewards.append("Reputation: " + ReputationManager.action_label(str(q.get("Rep_Action"))))
	if not rewards.is_empty():
		var rl = Label.new(); rl.text = "Reward — " + ", ".join(rewards)
		rl.add_theme_font_size_override("font_size", FONT_BODY - 4); rl.add_theme_color_override("font_color", ACCENT); v.add_child(rl)

	if NetworkManager.is_host:
		var btns = HBoxContainer.new(); btns.add_theme_constant_override("separation", 6); v.add_child(btns)
		var qid = q.get("id")
		if st != "completed":
			var done_btn = Button.new(); done_btn.text = "Complete"; _style_btn(done_btn, true)
			done_btn.pressed.connect(func(): QuestManager.set_status(qid, "completed"); Toast.notify("Quest completed — rewards granted.", Toast.SUCCESS))
			btns.add_child(done_btn)
		if st != "failed":
			var fail_btn = Button.new(); fail_btn.text = "Fail"; _style_btn(fail_btn)
			fail_btn.pressed.connect(func(): QuestManager.set_status(qid, "failed"))
			btns.add_child(fail_btn)
		if st == "active":
			var off_btn = Button.new(); off_btn.text = "Mark Offered"; _style_btn(off_btn)
			off_btn.pressed.connect(func(): QuestManager.set_status(qid, "offered"))
			btns.add_child(off_btn)
		elif st == "offered":
			var act_btn = Button.new(); act_btn.text = "Activate"; _style_btn(act_btn)
			act_btn.pressed.connect(func(): QuestManager.set_status(qid, "active"))
			btns.add_child(act_btn)
		var del_btn = Button.new(); del_btn.text = "Delete"; _style_btn(del_btn)
		del_btn.pressed.connect(func(): QuestManager.delete_quest(qid))
		btns.add_child(del_btn)
	return card

# =============================================================================
# New-quest form (DM)
# =============================================================================
func _open_new_quest() -> void:
	var overlay = ColorRect.new(); overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.z_index = 60; add_child(overlay)
	var center = CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(center)
	var panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(760, 0)
	var sb = _flat(BG_PANEL); sb.border_color = ACCENT; sb.set_border_width_all(1); sb.set_corner_radius_all(8); sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb); center.add_child(panel)
	var v = VBoxContainer.new(); v.add_theme_constant_override("separation", 8); panel.add_child(v)
	var title = Label.new(); title.text = "New Quest"
	title.add_theme_font_size_override("font_size", FONT_HDR); title.add_theme_color_override("font_color", ACCENT); v.add_child(title)

	var title_edit = _line(v, "Title")
	var desc_edit = TextEdit.new(); desc_edit.placeholder_text = "Description"; desc_edit.custom_minimum_size = Vector2(0, 80)
	v.add_child(_wrap("Description:", desc_edit))
	var region_opt = _opt(v, "Region:", Array(ReputationManager.region_names()))
	var giver_opt = _opt(v, "Giver:", ["None"] + Array(ReputationManager.npc_names()))
	var owner_opt = _opt(v, "For:", ["Party"] + Array(Global.PartyCharacters))
	var obj_edit = TextEdit.new(); obj_edit.placeholder_text = "One objective per line"; obj_edit.custom_minimum_size = Vector2(0, 90)
	v.add_child(_wrap("Objectives:", obj_edit))
	var mora_row = HBoxContainer.new(); mora_row.add_theme_constant_override("separation", 8); v.add_child(mora_row)
	mora_row.add_child(_mini("Reward Mora:"))
	var mora_spin = SpinBox.new(); mora_spin.min_value = 0; mora_spin.max_value = 100000; mora_spin.step = 50; mora_spin.value = 0; mora_row.add_child(mora_spin)
	var rep_ids: Array = ["None"]
	var rep_labels: Array = ["None"]
	for a in ReputationManager.all_actions():
		rep_ids.append(str(a.get("Id", "")))
		rep_labels.append(str(a.get("Label", a.get("Id", ""))))
	var rep_opt = _opt(v, "Reputation reward:", rep_labels)

	var brow = HBoxContainer.new(); brow.add_theme_constant_override("separation", 8); brow.alignment = BoxContainer.ALIGNMENT_END; v.add_child(brow)
	var cancel = Button.new(); cancel.text = "Cancel"; _style_btn(cancel); cancel.pressed.connect(func(): overlay.queue_free()); brow.add_child(cancel)
	var create = Button.new(); create.text = "Create"; _style_btn(create, true)
	create.pressed.connect(func():
		var objs := []
		for line in desc_objectives(obj_edit.text):
			objs.append({"text": line, "done": false})
		var data := {
			"Title": title_edit.text.strip_edges() if title_edit.text.strip_edges() != "" else "Untitled",
			"Description": desc_edit.text.strip_edges(),
			"Region": region_opt.get_item_text(region_opt.selected),
			"Giver": giver_opt.get_item_text(giver_opt.selected),
			"Owner": owner_opt.get_item_text(owner_opt.selected),
			"Objectives": JSON.stringify(objs),
			"Reward_Mora": int(mora_spin.value),
			"Rep_Action": rep_ids[rep_opt.selected] if rep_opt.selected >= 0 else "None",
			"Status": "active",
		}
		QuestManager.create_quest(data)
		overlay.queue_free())
	brow.add_child(create)

func desc_objectives(text: String) -> Array:
	var out := []
	for line in text.split("\n", false):
		var t := str(line).strip_edges()
		if t != "":
			out.append(t)
	return out

# =============================================================================
# Helpers
# =============================================================================
func _status_color(st: String) -> Color:
	match st:
		"completed": return GREEN
		"failed": return RED
		"offered": return ORANGE
		_: return ACCENT

func _badge(text: String, bg: Color) -> PanelContainer:
	var p = PanelContainer.new(); var sb = _flat(bg.darkened(0.25)); sb.set_corner_radius_all(4)
	sb.content_margin_left = 8; sb.content_margin_right = 8; sb.content_margin_top = 2; sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l = Label.new(); l.text = text; l.add_theme_font_size_override("font_size", FONT_BODY - 4); l.add_theme_color_override("font_color", TEXT); p.add_child(l)
	return p

func _line(parent: VBoxContainer, ph: String) -> LineEdit:
	var le = LineEdit.new(); le.placeholder_text = ph; le.add_theme_font_size_override("font_size", FONT_BODY - 2); parent.add_child(le); return le

func _wrap(label_text: String, ctrl: Control) -> VBoxContainer:
	var box = VBoxContainer.new(); box.add_child(_mini(label_text)); box.add_child(ctrl); return box

func _opt(parent: VBoxContainer, label_text: String, items: Array) -> OptionButton:
	var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 8); parent.add_child(row)
	row.add_child(_mini(label_text))
	var opt = OptionButton.new(); opt.add_theme_font_size_override("font_size", FONT_BODY - 2); opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for it in items: opt.add_item(str(it))
	row.add_child(opt); return opt

func _mini(t: String) -> Label:
	var l = Label.new(); l.text = t; l.add_theme_font_size_override("font_size", FONT_BODY - 4); l.add_theme_color_override("font_color", TEXT_SEC)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER; return l

func _close() -> void:
	emit_signal("panel_closed")
	var p = get_parent()
	if p is Window: p.queue_free()
	else: queue_free()

func _flat(c: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new(); sb.bg_color = c; return sb

func _style_btn(btn: Button, primary: bool = false) -> void:
	var sb = _flat(ACCENT if primary else BG_INSET); sb.border_color = BORDER; sb.set_border_width_all(1); sb.set_corner_radius_all(4)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	var h = sb.duplicate(); h.bg_color = sb.bg_color.lightened(0.15); btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_color_override("font_color", BG_DEEP if primary else ACCENT)
	btn.add_theme_color_override("font_hover_color", BG_DEEP if primary else ACCENT)
	btn.add_theme_font_size_override("font_size", FONT_BODY - 2)
