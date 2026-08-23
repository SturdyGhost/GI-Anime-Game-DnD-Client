extends Control

# Minigame registry — add entries here for new games
const GAMES: Array = [
	{
		"key": "Klee Fish Blast",
		"title": "Klee's Fish Blasting",
		"description": "Blast fish for points! 30 seconds on the clock.",
		"scene": "res://Scenes/KleeFishBlast.tscn",
	},
	{
		"key": "Ninguang Slots",
		"title": "Ninguang's Golden Parlor",
		"description": "Try your luck at the slot machine. Bet Mora, win big.",
		"scene": "res://Scenes/NinguangSlots.tscn",
	},
	{
		"key": "Yelan Blackjack",
		"title": "Yelan's Table — 21",
		"description": "Real casino blackjack vs Yelan. 6-deck shoe, 3:2 payouts, double, split & insurance. Wager your Mora.",
		"scene": "res://Scenes/YelanBlackjack.tscn",
	},
	{
		"key": "Exterminator Hunt",
		"title": "The Exterminator",
		"description": "A theatrical Fontainian exterminator hunts you through the aqueducts. Break his line of sight, stay quiet, and survive as long as you can.",
		"scene": "res://Scenes/ExterminatorHunt.tscn",
	},
	{
		"key": "Genshin Hold'em",
		"title": "Genshin Hold'em",
		"description": "No-limit Texas Hold'em against companions you've met. Blinds, side pots, bluffs and trash talk. Cash out with more chips than you sat down with.",
		"scene": "res://Scenes/GenshinHoldem.tscn",
	},
	{
		"key": "Ningguang Roulette",
		"title": "Ningguang's Wheel of Fortune",
		"description": "American roulette in the Golden Parlor. Spread your Mora across numbers, dozens, columns and red/black, then spin. Straight-up pays 35:1.",
		"scene": "res://Scenes/NingguangRoulette.tscn",
	},
]

var _cards_container: GridContainer

func _ready() -> void:
	# Full-screen dark overlay background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 60)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	margin.add_child(vbox)

	# Header row
	var header_row = HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title = Label.new()
	title.text = "Minigames"
	title.add_theme_font_size_override("font_size", 65)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close)
	header_row.add_child(close_btn)
	vbox.add_child(header_row)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Cards grid — wrapped in a scroll container so rows past the first stay
	# reachable (the Play buttons were getting clipped off the bottom).
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_cards_container = GridContainer.new()
	_cards_container.columns = 3
	_cards_container.add_theme_constant_override("h_separation", 24)
	_cards_container.add_theme_constant_override("v_separation", 24)
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards_container)

	_build_cards()

func _build_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()

	for game in GAMES:
		var card = _create_card(game)
		_cards_container.add_child(card)

func _create_card(game: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 220)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.16, 1.0)
	sb.border_color = Color(0.35, 0.35, 0.45, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", sb)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var title_label = Label.new()
	title_label.text = game["title"]
	title_label.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = game["description"]
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Scores
	var scores = _get_scores(game["key"])
	var score_hbox = HBoxContainer.new()
	score_hbox.add_theme_constant_override("separation", 20)

	var best_label = Label.new()
	best_label.text = "Best: %d" % scores["overall"]
	best_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	best_label.add_theme_font_size_override("font_size", 29)
	score_hbox.add_child(best_label)

	var my_label = Label.new()
	my_label.text = "Your Best: %d" % scores["personal"]
	my_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	my_label.add_theme_font_size_override("font_size", 29)
	score_hbox.add_child(my_label)

	vbox.add_child(score_hbox)

	# Play button
	var play_btn = Button.new()
	play_btn.text = "Play"
	play_btn.pressed.connect(_launch_game.bind(game["scene"]))
	vbox.add_child(play_btn)

	card.add_child(vbox)
	return card

func _get_scores(game_key: String) -> Dictionary:
	var overall_best = 0
	var personal_best = 0
	var results = Global.MINIGAMES_RESULTS
	for rid in results:
		var r = results[rid]
		if str(r.get("Minigame", r.get("minigame_id", ""))) != game_key:
			continue
		var s = int(r.get("Score", r.get("score", 0)))
		if s > overall_best:
			overall_best = s
		if str(r.get("Player", r.get("player_name", ""))) == Global.ACTIVE_USER_NAME:
			if s > personal_best:
				personal_best = s
	return {"overall": overall_best, "personal": personal_best}

func _launch_game(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		push_warning("[MINIGAMES] Scene not found: %s" % scene_path)
		return
	var s: PackedScene = load(scene_path)
	var dlg = s.instantiate()

	var win := Window.new()
	win.exclusive = true
	win.transparent = true
	win.unresizable = true
	win.size = get_viewport_rect().size
	win.position = Vector2.ZERO

	win.add_child(dlg)
	# Add to scene tree above the menu window
	var menu_win = get_parent()
	while menu_win and not (menu_win is Window):
		menu_win = menu_win.get_parent()
	if menu_win:
		menu_win.get_parent().add_child(win)
	else:
		get_tree().root.add_child(win)

	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Refresh scores when game window closes
	if dlg.has_signal("game_finished"):
		dlg.game_finished.connect(func(_score): _build_cards())

func _on_close() -> void:
	var win = get_parent()
	while win and not (win is Window):
		win = win.get_parent()
	if win and win is Window:
		win.queue_free()
