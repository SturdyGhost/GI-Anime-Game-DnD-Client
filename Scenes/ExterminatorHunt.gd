extends Control
## "The Exterminator" — a suspenseful top-down stealth survival minigame set in
## the Fontaine aqueducts. A theatrical Fontainian exterminator hunts the player
## through claustrophobic sewer tunnels. Survive as long as possible.
##
## The hunter is a real FSM (Patrol → Search → Chase) driving A* pathfinding,
## a line-of-sight vision cone, and sound tracking. It is fair early and turns
## inexorable as the difficulty ramps, so survival time is a true skill score.
##
## >>> Set EXTERMINATOR_NAME / _TITLE below to your campaign NPC's real name. <<<

signal game_finished(score: int)

const EXTERMINATOR_NAME := "L'Exterminator"   # the Fontainian exterminator NPC

# ── Grid ──────────────────────────────────────────────────────────────────────
const COLS := 31
const ROWS := 19
const TILE := 46.0
const WALL := 0
const FLOOR := 1
const WATER := 2
const HIDE := 3

# ── Tuning ────────────────────────────────────────────────────────────────────
const PLAYER_WALK := 205.0
const PLAYER_SPRINT := 332.0
const RAMP_SECONDS := 60.0      # difficulty fully ramps over this long (fast rounds)
const PING_INTERVAL := 10.0     # every N seconds he gets a fresh ping of your location

# ── Prizes ────────────────────────────────────────────────────────────────────
const PRIZE_TIER_1_SECONDS := 50.0   # survive this long → 1 gem
const PRIZE_TIER_3_SECONDS := 90.0   # survive this long → 3 gems
const GEM_ITEMS: Array = [
	"1-Star Fire Gem", "1-Star Water Gem", "1-Star Ice Gem", "1-Star Electric Gem",
	"1-Star Wind Gem", "1-Star Earth Gem", "1-Star Nature Gem",
]

# colors
const C_BG     := Color(0.05, 0.07, 0.09)
const C_FLOOR  := Color(0.16, 0.19, 0.22)
const C_WALL   := Color(0.09, 0.11, 0.14)
const C_WATER  := Color(0.13, 0.22, 0.30)
const C_HIDE   := Color(0.20, 0.17, 0.10)
const C_PLAYER := Color(0.45, 0.85, 0.95)
const C_EXT    := Color(0.92, 0.28, 0.30)
const C_LIGHT  := Color(0.95, 0.78, 0.45)

# ── State ─────────────────────────────────────────────────────────────────────
enum { S_INTRO, S_COUNTDOWN, S_PLAYING, S_CAUGHT }
var _state := S_INTRO

var _grid: Array = []
var _origin := Vector2.ZERO

var _player_pos := Vector2.ZERO
var _player_vel := Vector2.ZERO
var _player_hidden := false
var _player_sprinting := false
var _hide_elapsed := 0.0                 # time spent crouched on the current spot
var _hide_tile := Vector2i(-1, -1)       # which alcove cell is being used
var _last_move_dir := Vector2.RIGHT

const HIDE_MAX := 4.0                     # an alcove only conceals you this long
const SPAWN_NO_HIDE_RADIUS := 5.0         # keep alcoves away from the spawn

# exterminator
var _ext_pos := Vector2.ZERO
var _ext_facing := 0.0
var _ext_state := 0   # 0 patrol, 1 search, 2 chase
var _ext_path: Array = []
var _ext_target := Vector2i.ZERO
var _last_known := Vector2i.ZERO
var _search_timer := 0.0
var _repath := 0.0
var _detection := 0.0
var _ping_timer := PING_INTERVAL
var _countdown := 3.0
var _elapsed := 0.0
var _best_time := 0.0

# difficulty-derived (recomputed each frame)
var _ext_speed := 235.0
var _vision_range := 6.5
var _cone_half := 0.73
var _hear_walk := 2.2
var _hear_sprint := 5.5
var _diff := 0.0   # 0..1 ramp, cached for the chase-speed bonus

# audio
var _heartbeat_timer := 0.0
var _taunt_timer := 0.0

# nodes
var _time_label: Label
var _taunt_label: Label
var _hint_label: Label
var _overlay: Control

func _ready() -> void:
	custom_minimum_size = Vector2(2560, 1440)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
		preload("res://Scenes/settings_popup.gd").load_and_apply_sfx_volume()

	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 44)
	_time_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_time_label.position = Vector2(60, 40)
	add_child(_time_label)

	_taunt_label = Label.new()
	_taunt_label.add_theme_font_size_override("font_size", 32)
	_taunt_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.55))
	_taunt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_taunt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_taunt_label.position = Vector2(640, 1300)
	_taunt_label.custom_minimum_size = Vector2(1280, 0)
	_taunt_label.size = Vector2(1280, 80)
	add_child(_taunt_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 30)
	_hint_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4))
	_hint_label.position = Vector2(60, 100)
	add_child(_hint_label)

	_generate_map()
	_place_actors()
	_show_intro()

func _process(delta: float) -> void:
	match _state:
		S_COUNTDOWN:
			_countdown -= delta
			_time_label.text = "The hunt begins in  %d" % int(ceil(_countdown))
			if _countdown <= 0.0:
				_state = S_PLAYING
				_say(_pick(["Bonsoir, little vermin. The stage is set... shall we begin our danse macabre?"]))
			queue_redraw()
		S_PLAYING:
			_elapsed += delta
			_update_difficulty()
			_update_player(delta)
			_update_exterminator(delta)
			_update_audio(delta)
			_check_caught()
			if _taunt_timer > 0.0:
				_taunt_timer -= delta
				if _taunt_timer <= 0.0:
					_taunt_label.text = ""
			_time_label.text = "Survived  %.1f s" % _elapsed
			if _player_hidden:
				_hint_label.text = "● HIDDEN — stay still"
				_hint_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
			elif _ext_state == 2:
				_hint_label.text = "⚠ SPOTTED — RUN"
				_hint_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
			else:
				_hint_label.text = ""
			queue_redraw()

# ── Map generation (braided maze) ─────────────────────────────────────────────
func _generate_map() -> void:
	_grid = []
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append(WALL)
		_grid.append(row)

	var cw := int((COLS - 1) / 2)
	var ch := int((ROWS - 1) / 2)
	var visited := {}
	var stack := [Vector2i(0, 0)]
	visited[Vector2i(0, 0)] = true
	_grid[1][1] = FLOOR
	while not stack.is_empty():
		var cur: Vector2i = stack[stack.size() - 1]
		var nbs := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = cur + d
			if nc.x >= 0 and nc.x < cw and nc.y >= 0 and nc.y < ch and not visited.has(nc):
				nbs.append(nc)
		if nbs.is_empty():
			stack.remove_at(stack.size() - 1)
			continue
		var nb: Vector2i = nbs[randi() % nbs.size()]
		# carve wall between cur and nb
		var gx := 1 + cur.x * 2
		var gy := 1 + cur.y * 2
		var ngx := 1 + nb.x * 2
		var ngy := 1 + nb.y * 2
		_grid[(gy + ngy) / 2][(gx + ngx) / 2] = FLOOR
		_grid[ngy][ngx] = FLOOR
		visited[nb] = true
		stack.append(nb)

	# Braid: open ~35% of dead ends to create loops (so you can break line-of-sight).
	for r in range(1, ROWS - 1):
		for c in range(1, COLS - 1):
			if _grid[r][c] != FLOOR:
				continue
			var open_n := 0
			var wall_dirs := []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _grid[r + d.y][c + d.x] == FLOOR:
					open_n += 1
				elif r + d.y > 0 and r + d.y < ROWS - 1 and c + d.x > 0 and c + d.x < COLS - 1:
					wall_dirs.append(d)
			if open_n <= 1 and not wall_dirs.is_empty() and randf() < 0.35:
				var d: Vector2i = wall_dirs[randi() % wall_dirs.size()]
				_grid[r + d.y][c + d.x] = FLOOR

	# Decorate floor with water patches (noisy) and hiding spots.
	var floors := []
	for r in range(1, ROWS - 1):
		for c in range(1, COLS - 1):
			if _grid[r][c] == FLOOR:
				floors.append(Vector2i(c, r))
	floors.shuffle()
	var n_water := int(floors.size() * 0.12)
	var n_hide := int(floors.size() * 0.10)
	for i in range(n_water):
		var p: Vector2i = floors[i]
		_grid[p.y][p.x] = WATER
	for i in range(n_water, min(n_water + n_hide, floors.size())):
		var p: Vector2i = floors[i]
		_grid[p.y][p.x] = HIDE

func _place_actors() -> void:
	# Player top-left region, exterminator bottom-right region — far apart.
	_player_pos = _cell_center(Vector2i(1, 1))
	if _is_wall_cell(Vector2i(1, 1)):
		_player_pos = _cell_center(_nearest_floor(Vector2i(1, 1)))
	var far := _nearest_floor(Vector2i(COLS - 2, ROWS - 2))
	_ext_pos = _cell_center(far)
	_last_known = _player_cell()
	_ext_state = 0
	_ext_target = far
	_detection = 0.0
	_ping_timer = PING_INTERVAL
	_hide_tile = Vector2i(-1, -1)
	_hide_elapsed = 0.0

	# Strip hiding alcoves around the spawn so the player is forced to move out
	# and find one rather than starting on top of safety.
	var spawn := _player_cell()
	for r in range(ROWS):
		for c in range(COLS):
			if _grid[r][c] == HIDE and Vector2(c - spawn.x, r - spawn.y).length() < SPAWN_NO_HIDE_RADIUS:
				_grid[r][c] = FLOOR

# ── Difficulty ────────────────────────────────────────────────────────────────
func _update_difficulty() -> void:
	var d: float = clamp(_elapsed / RAMP_SECONDS, 0.0, 1.0)
	_diff = d
	# Base patrol speed already beats the player's WALK (205); the chase bonus
	# (added below) pushes him to ~sprint speed early and past it late.
	_ext_speed = lerp(235.0, 300.0, d)
	_vision_range = lerp(6.5, 9.5, d)
	_cone_half = lerp(deg_to_rad(42.0), deg_to_rad(62.0), d)
	_hear_walk = lerp(2.2, 3.6, d)
	_hear_sprint = lerp(5.5, 8.5, d)

# ── Player ────────────────────────────────────────────────────────────────────
func _update_player(delta: float) -> void:
	var ix := (1.0 if _key(KEY_D) or _key(KEY_RIGHT) else 0.0) - (1.0 if _key(KEY_A) or _key(KEY_LEFT) else 0.0)
	var iy := (1.0 if _key(KEY_S) or _key(KEY_DOWN) else 0.0) - (1.0 if _key(KEY_W) or _key(KEY_UP) else 0.0)
	var dir := Vector2(ix, iy)
	var moving := dir.length() > 0.0
	var cur_cell := _player_cell()
	var on_hide := _cell_type(cur_cell) == HIDE
	var on_water := _cell_type(cur_cell) == WATER

	_player_sprinting = moving and Input.is_key_pressed(KEY_SHIFT)
	# An alcove conceals you for HIDE_MAX seconds, then it's "spent" — you stay
	# exposed until you LEAVE the tile and return, so you can't camp one corner.
	if on_hide and not moving:
		if cur_cell != _hide_tile:
			_hide_tile = cur_cell
			_hide_elapsed = 0.0
		_hide_elapsed += delta
		_player_hidden = _hide_elapsed > 0.25 and _hide_elapsed < HIDE_MAX
	else:
		_player_hidden = false
		# Stepping off the alcove entirely frees it to conceal you again later.
		if not on_hide:
			_hide_tile = Vector2i(-1, -1)
			_hide_elapsed = 0.0

	var speed := 0.0
	if moving:
		speed = PLAYER_SPRINT if _player_sprinting else PLAYER_WALK
		if on_water:
			speed *= 0.78
		_last_move_dir = dir.normalized()
	_player_vel = dir.normalized() * speed if moving else Vector2.ZERO

	var step := _player_vel * delta
	var nx := _player_pos + Vector2(step.x, 0)
	if not _blocked(nx):
		_player_pos.x = nx.x
	var ny := _player_pos + Vector2(0, step.y)
	if not _blocked(ny):
		_player_pos.y = ny.y

func _blocked(pos: Vector2) -> bool:
	var cell := _pos_to_cell(pos)
	return _is_wall_cell(cell)

# ── Exterminator AI ───────────────────────────────────────────────────────────
func _update_exterminator(delta: float) -> void:
	var seen := _player_visible()
	var pc := _player_cell()

	# Tracker ping: every PING_INTERVAL seconds he "senses" your exact location
	# and moves to hunt it — even with no line of sight. You're never fully lost.
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = PING_INTERVAL
		_last_known = pc
		if _ext_state == 2:
			_ext_target = pc
		else:
			_enter_search(pc)
		_sfx_ping()
		if randf() < 0.6:
			_say(_pick([
				"Ahh... I can smell you from here, little rat.",
				"There you are. The sewers whisper your every step.",
				"You cannot hide from me forever, mon cher.",
				"A scent on the draft... this way, then."]))

	# Vision → detection meter (locks fast, especially up close)
	if seen:
		var dist := _ext_pos.distance_to(_player_pos)
		var closeness: float = clamp(1.0 - dist / (_vision_range * TILE), 0.15, 1.0)
		_detection += (1.7 + 2.8 * closeness) * delta
		_last_known = pc
		if _detection >= 1.0:
			_enter_chase()
		elif _ext_state == 0:
			_enter_search(pc)
	else:
		# Stay committed — a brief break in sight shouldn't wipe the meter.
		_detection = max(0.0, _detection - 0.45 * delta)

	# Hearing
	var noise := _player_noise_radius()
	if noise > 0.0 and _ext_pos.distance_to(_player_pos) <= noise:
		_last_known = pc
		if _ext_state == 0:
			_enter_search(pc)
		elif _ext_state == 1:
			_search_timer = max(_search_timer, 4.0)
			_ext_target = pc

	# Behavior by state
	match _ext_state:
		2:  # CHASE
			if seen:
				_ext_target = pc
			else:
				# Cut toward where the player was HEADING, not just where last seen.
				var lead := _last_known + Vector2i((_last_move_dir * 3.0).round())
				_ext_target = lead if not _is_wall_cell(lead) else _last_known
				if _reached(_ext_target):
					_enter_search(_ext_target)
		1:  # SEARCH
			_search_timer -= delta
			if _reached(_ext_target):
				_ext_target = _random_floor_near(_last_known, 3)
			if _search_timer <= 0.0:
				_enter_patrol()
		0:  # PATROL
			if _reached(_ext_target):
				_ext_target = _patrol_target()

	# Pathfinding + movement (repath often so he tracks tightly)
	_repath -= delta
	if _repath <= 0.0 or _ext_path.is_empty():
		_ext_path = _astar(_ext_cell(), _ext_target)
		_repath = 0.12
	var speed := _ext_speed
	if _ext_state == 2:
		speed += lerp(90.0, 130.0, _diff)   # chase: ~sprint early, faster than sprint late
	elif _ext_state == 1:
		speed += 35.0                        # hustles while searching too
	# Final approach: when chasing with a clear line, beeline to the player's
	# ACTUAL position instead of cell centers, so he can pin you into a corner
	# and actually make contact (path nodes only ever reach tile centers). LoS
	# guarantees no wall lies on the straight segment, so this can't clip walls.
	if _ext_state == 2 and _ext_pos.distance_to(_player_pos) < TILE * 2.0 and _has_los(_ext_cell(), _player_cell()):
		var to := _player_pos - _ext_pos
		if to.length() > 1.0:
			_ext_pos += to.normalized() * speed * delta
		_ext_path.clear()
	else:
		_move_along_path(speed, delta)

	# Facing — snap quickly toward the player when chasing, the target otherwise,
	# so his vision cone actually sweeps where he's headed / heard something.
	var want_face := _ext_facing
	if _ext_state == 2 and seen:
		want_face = (_player_pos - _ext_pos).angle()
	elif _ext_path.size() > 0:
		want_face = (_cell_center(_ext_path[0]) - _ext_pos).angle()
	elif _ext_target != _ext_cell():
		want_face = (_cell_center(_ext_target) - _ext_pos).angle()
	_ext_facing = _rotate_toward(_ext_facing, want_face, 7.5 * delta)

func _move_along_path(speed: float, delta: float) -> void:
	if _ext_path.is_empty():
		return
	var target := _cell_center(_ext_path[0])
	var to := target - _ext_pos
	if to.length() < TILE * 0.30:
		_ext_path.remove_at(0)
		return
	_ext_pos += to.normalized() * speed * delta

func _enter_chase() -> void:
	if _ext_state != 2:
		_say(_pick([
			"There you are, mon trésor! BRAVO — it's so much better with movement!",
			"A protagonist at last! The spotlight is YOURS!",
			"Ahh, the chase! My favorite movement of the symphony!"]))
	_ext_state = 2
	_ext_path.clear()

func _enter_search(cell: Vector2i) -> void:
	if _ext_state == 2:
		_say(_pick([
			"Vanished? Oh, you tease. An intermission, then.",
			"Hiding in the dark? How wonderfully theatrical of you.",
			"Gone? No no no — the third act is always the best part."]))
	_ext_state = 1
	_last_known = cell
	_ext_target = cell
	_search_timer = 9.5
	_ext_path.clear()

func _enter_patrol() -> void:
	_ext_state = 0
	_ext_target = _patrol_target()
	_ext_path.clear()
	if randf() < 0.4:
		_say(_pick([
			"The sewers carry sound so beautifully, don't they?",
			"Come out, come out... the audience is waiting.",
			"I do so hate to lose my leading act."]))

# ── Sensing ───────────────────────────────────────────────────────────────────
func _player_visible() -> bool:
	if _player_hidden:
		return false
	var dist := _ext_pos.distance_to(_player_pos)
	if dist > _vision_range * TILE:
		return false
	if not _has_los(_ext_cell(), _player_cell()):
		return false
	# Point-blank sense: if you're right next to him in the open, he notices
	# regardless of which way he's facing (you can't tiptoe past his elbow).
	if dist <= TILE * 2.2:
		return true
	var ang := (_player_pos - _ext_pos).angle()
	return abs(_ang_diff(ang, _ext_facing)) <= _cone_half

func _player_noise_radius() -> float:
	if _player_hidden or _player_vel.length() < 5.0:
		return 0.0
	var tiles := _hear_sprint if _player_sprinting else _hear_walk
	if _cell_type(_player_cell()) == WATER:
		tiles += 1.6
	return tiles * TILE

func _check_caught() -> void:
	if _ext_pos.distance_to(_player_pos) <= TILE * 0.62:
		_on_caught()

# ── A* + line of sight ────────────────────────────────────────────────────────
func _astar(start: Vector2i, goal: Vector2i) -> Array:
	if _is_wall_cell(goal):
		goal = _nearest_floor(goal)
	if start == goal:
		return []
	var open := [start]
	var came := {}
	var g := {start: 0}
	var f := {start: _heur(start, goal)}
	while not open.is_empty():
		var cur: Vector2i = open[0]
		var ci := 0
		for i in range(1, open.size()):
			if float(f.get(open[i], INF)) < float(f.get(cur, INF)):
				cur = open[i]
				ci = i
		if cur == goal:
			return _reconstruct(came, cur)
		open.remove_at(ci)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if _is_wall_cell(nb):
				continue
			var tentative := int(g[cur]) + 1
			if tentative < int(g.get(nb, 1 << 30)):
				came[nb] = cur
				g[nb] = tentative
				f[nb] = tentative + _heur(nb, goal)
				if not open.has(nb):
					open.append(nb)
	return []

func _reconstruct(came: Dictionary, cur: Vector2i) -> Array:
	var path := [cur]
	while came.has(cur):
		cur = came[cur]
		path.append(cur)
	path.reverse()
	path.remove_at(0)
	return path

func _heur(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _has_los(a: Vector2i, b: Vector2i) -> bool:
	# Bresenham across cells; blocked if any intermediate cell is a wall.
	var x0: int = a.x
	var y0: int = a.y
	var dx: int = abs(b.x - x0)
	var dy: int = -abs(b.y - y0)
	var sx: int = 1 if x0 < b.x else -1
	var sy: int = 1 if y0 < b.y else -1
	var err: int = dx + dy
	while true:
		if not (x0 == a.x and y0 == a.y) and not (x0 == b.x and y0 == b.y):
			if _grid[y0][x0] == WALL:
				return false
		if x0 == b.x and y0 == b.y:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return true

# ── Grid helpers ──────────────────────────────────────────────────────────────
func _in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < COLS and c.y >= 0 and c.y < ROWS

func _is_wall_cell(c: Vector2i) -> bool:
	if not _in_bounds(c):
		return true
	return _grid[c.y][c.x] == WALL

func _cell_type(c: Vector2i) -> int:
	if not _in_bounds(c):
		return WALL
	return _grid[c.y][c.x]

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * TILE, (c.y + 0.5) * TILE)

func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE)), int(floor(pos.y / TILE)))

func _player_cell() -> Vector2i:
	return _pos_to_cell(_player_pos)

func _ext_cell() -> Vector2i:
	return _pos_to_cell(_ext_pos)

func _reached(cell: Vector2i) -> bool:
	return _ext_pos.distance_to(_cell_center(cell)) < TILE * 0.5

func _nearest_floor(c: Vector2i) -> Vector2i:
	if not _is_wall_cell(c):
		return c
	for radius in range(1, max(COLS, ROWS)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var n := Vector2i(c.x + dx, c.y + dy)
				if _in_bounds(n) and _grid[n.y][n.x] != WALL:
					return n
	return Vector2i(1, 1)

func _random_floor_near(center: Vector2i, radius: int) -> Vector2i:
	for _i in range(18):
		var n := Vector2i(center.x + randi_range(-radius, radius), center.y + randi_range(-radius, radius))
		if _in_bounds(n) and _grid[n.y][n.x] != WALL:
			return n
	return _nearest_floor(center)

func _patrol_target() -> Vector2i:
	# Bias toward where the player was last sensed (relentless), else roam wide.
	if randf() < 0.6:
		return _random_floor_near(_last_known, 5)
	for _i in range(20):
		var n := Vector2i(randi_range(1, COLS - 2), randi_range(1, ROWS - 2))
		if _grid[n.y][n.x] != WALL:
			return n
	return _nearest_floor(_last_known)

# ── Math helpers ──────────────────────────────────────────────────────────────
func _ang_diff(a: float, b: float) -> float:
	var d := fmod(a - b + PI, TAU)
	if d < 0.0:
		d += TAU
	return d - PI

func _rotate_toward(cur: float, target: float, max_step: float) -> float:
	var diff := _ang_diff(target, cur)
	if abs(diff) <= max_step:
		return target
	return cur + sign(diff) * max_step

func _key(code: int) -> bool:
	return Input.is_physical_key_pressed(code)

func _pick(arr: Array) -> String:
	return str(arr[randi() % arr.size()])

func _say(text: String) -> void:
	_taunt_label.text = "“%s”  — %s" % [text, EXTERMINATOR_NAME]
	_taunt_timer = 4.5

# ── Rendering ─────────────────────────────────────────────────────────────────
func _draw() -> void:
	_origin = (size - Vector2(COLS * TILE, ROWS * TILE)) * 0.5
	_origin.y += 30.0

	# board border
	draw_rect(Rect2(_origin - Vector2(6, 6), Vector2(COLS * TILE + 12, ROWS * TILE + 12)), Color(0.2, 0.6, 0.6, 0.5), false, 4.0)

	var pcell := _player_cell()
	var view := _vision_range  # player sees roughly as far as a tile radius for atmosphere
	for r in ROWS:
		for c in COLS:
			var t: int = _grid[r][c]
			var base := C_WALL
			match t:
				FLOOR: base = C_FLOOR
				WATER: base = C_WATER
				HIDE: base = C_HIDE
				_: base = C_WALL
			# fog: dim by distance from player
			var dist := Vector2(c - pcell.x, r - pcell.y).length()
			var b: float = clamp(1.25 - dist / (view + 2.5), 0.22, 1.0)
			var col := Color(base.r * b, base.g * b, base.b * b)
			draw_rect(Rect2(_origin + Vector2(c * TILE, r * TILE), Vector2(TILE, TILE)), col)
			if t == HIDE and b > 0.3:
				# alcove marker
				var cc := _origin + _cell_center(Vector2i(c, r))
				draw_arc(cc, TILE * 0.32, 0, TAU, 18, Color(0.6, 0.5, 0.25, b), 2.0)

	# exterminator light cone (occluded by walls)
	_draw_cone()

	# player
	var ppix := _origin + _player_pos
	if _player_hidden:
		draw_circle(ppix, 14.0, Color(C_PLAYER.r, C_PLAYER.g, C_PLAYER.b, 0.35))
		draw_arc(ppix, 17.0, 0, TAU, 20, Color(0.6, 0.8, 0.9, 0.5), 2.0)
	else:
		draw_circle(ppix, 14.0, C_PLAYER)
		draw_circle(ppix, 14.0, Color(1, 1, 1, 0.15))

	# detection pip over player
	if _detection > 0.02 and not _player_hidden:
		var col := Color(0.95, 0.8, 0.2).lerp(Color(0.95, 0.2, 0.2), _detection)
		draw_arc(ppix + Vector2(0, -28), 10.0, -PI / 2, -PI / 2 + TAU * _detection, 16, col, 4.0)

	# exterminator
	var epix := _origin + _ext_pos
	draw_circle(epix, 16.0, C_EXT)
	draw_circle(epix, 16.0, Color(0, 0, 0, 0.25))
	var look := epix + Vector2(cos(_ext_facing), sin(_ext_facing)) * 22.0
	draw_line(epix, look, Color(1, 0.9, 0.6), 3.0)

	# danger vignette
	var prox: float = clamp(1.0 - _ext_pos.distance_to(_player_pos) / (8.0 * TILE), 0.0, 1.0)
	prox = max(prox, _detection * 0.6)
	if _ext_state == 2:
		prox = max(prox, 0.55)
	if prox > 0.02:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.6, 0.05, 0.08, prox * 0.22))

func _draw_cone() -> void:
	var origin := _origin + _ext_pos
	var pts := PackedVector2Array()
	pts.append(origin)
	var rays := 26
	var rng := _vision_range * TILE
	for i in range(rays + 1):
		var a := _ext_facing - _cone_half + (2.0 * _cone_half) * (float(i) / rays)
		var dir := Vector2(cos(a), sin(a))
		var dist := rng
		var step := 8.0
		var t := step
		while t < rng:
			var cell := _pos_to_cell(_ext_pos + dir * t)
			if _is_wall_cell(cell):
				dist = t
				break
			t += step
		pts.append(origin + dir * dist)
	var tint := Color(C_LIGHT.r, C_LIGHT.g, C_LIGHT.b, 0.16 if _ext_state != 2 else 0.26)
	draw_colored_polygon(pts, tint)

# ── Audio ─────────────────────────────────────────────────────────────────────
func _update_audio(delta: float) -> void:
	var prox: float = clamp(1.0 - _ext_pos.distance_to(_player_pos) / (9.0 * TILE), 0.0, 1.0)
	if _ext_state == 2:
		prox = max(prox, 0.7)
	_heartbeat_timer -= delta
	if prox > 0.15 and _heartbeat_timer <= 0.0:
		_heartbeat_timer = lerp(1.1, 0.32, prox)
		_play_tone(70.0, 0.12, lerp(-16.0, -4.0, prox))

func _play_tone(freq: float, duration: float, volume_db: float = 0.0) -> void:
	var sample_rate := 44100
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	for i in num_samples:
		var t := float(i) / sample_rate
		var envelope := exp(-3.0 * t / duration)
		var sample := sin(t * freq * TAU) * envelope * 0.6
		var s16 := int(clamp(sample * 32767.0, -32768, 32767))
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _sting_caught() -> void:
	_play_tone(180.0, 0.25, -2.0)
	await get_tree().create_timer(0.12).timeout
	_play_tone(120.0, 0.4, -2.0)

## Sonar-like two-tone cue when the tracker ping reacquires you.
func _sfx_ping() -> void:
	_play_tone(990.0, 0.10, -7.0)
	await get_tree().create_timer(0.09).timeout
	_play_tone(1320.0, 0.14, -8.0)

# ── Overlays ──────────────────────────────────────────────────────────────────
func _show_intro() -> void:
	var v := _make_overlay()
	var title := Label.new()
	title.text = "THE EXTERMINATOR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 80)
	title.add_theme_color_override("font_color", Color(0.92, 0.28, 0.30))
	v.add_child(title)

	var who := Label.new()
	who.text = "%s has descended into the aqueducts. He has come for you." % EXTERMINATOR_NAME
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.add_theme_font_size_override("font_size", 34)
	who.add_theme_color_override("font_color", Color(0.85, 0.8, 0.8))
	v.add_child(who)

	var rules := Label.new()
	rules.text = "Survive as long as you can.\n\nWASD / Arrows to move   ·   Shift to sprint (LOUD)\nStand still on a glowing alcove (◯) to hide — but he can still walk into you.\nBreak his line of sight and stay quiet. The longer you last, the deadlier he gets."
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.add_theme_font_size_override("font_size", 30)
	rules.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	v.add_child(rules)

	var begin := Button.new()
	begin.text = "Enter the Sewers"
	begin.custom_minimum_size = Vector2(360, 70)
	begin.add_theme_font_size_override("font_size", 36)
	begin.pressed.connect(_start_run)
	v.add_child(begin)

	var leave := Button.new()
	leave.text = "Leave"
	leave.custom_minimum_size = Vector2(200, 50)
	leave.pressed.connect(_on_close)
	v.add_child(leave)

func _start_run() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	_generate_map()
	_place_actors()
	_elapsed = 0.0
	_detection = 0.0
	_countdown = 3.0
	_taunt_label.text = ""
	_state = S_COUNTDOWN

func _on_caught() -> void:
	if _state == S_CAUGHT:
		return
	_state = S_CAUGHT
	_best_time = max(_best_time, _elapsed)
	_sting_caught()
	_say(_pick([
		"And... SCÈNE. Magnifique. You die to thunderous applause.",
		"Curtains, mon cher. An exquisite performance.",
		"Bravo, bravo! But every show must end."]))
	var v := _make_overlay()
	var title := Label.new()
	title.text = "EXTERMINATED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.95, 0.2, 0.22))
	v.add_child(title)

	var score := Label.new()
	score.text = "You survived  %.1f seconds" % _elapsed
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 44)
	score.add_theme_color_override("font_color", Color(0.95, 0.9, 0.6))
	v.add_child(score)

	var best := Label.new()
	best.text = "Best this session:  %.1f s" % _best_time
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.add_theme_font_size_override("font_size", 30)
	best.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	v.add_child(best)

	# ── Prize (nudged a little by the player's daily luck) ──
	var luck: int = _player_luck()
	var luckf: float = clamp((luck - 50) / 50.0, -1.0, 1.0)   # -1 worst .. 0 neutral .. +1 best
	var tier1: float = PRIZE_TIER_1_SECONDS - luckf * 3.0     # ~47s (lucky) .. ~53s (unlucky)
	var tier3: float = PRIZE_TIER_3_SECONDS - luckf * 5.0     # ~85s .. ~95s
	var gem_count := _roll_gem_count(_elapsed, tier1, tier3, luckf)
	if gem_count > 0:
		var awarded := _grant_gems(gem_count)
		var hdr := Label.new()
		hdr.text = "★ Prize earned!"
		hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hdr.add_theme_font_size_override("font_size", 34)
		hdr.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35))
		v.add_child(hdr)
		for gem_name in awarded:
			var row := Label.new()
			row.text = "%s ×%d" % [gem_name, int(awarded[gem_name])]
			row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_theme_font_size_override("font_size", 28)
			row.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
			v.add_child(row)
	else:
		var hint := Label.new()
		hint.text = "Survive at least %d seconds to earn a prize\n(%d+ seconds earns three gems)." % [int(round(tier1)), int(round(tier3))]
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 26)
		hint.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
		v.add_child(hint)

	var retry := Button.new()
	retry.text = "Run Again"
	retry.custom_minimum_size = Vector2(320, 66)
	retry.add_theme_font_size_override("font_size", 34)
	retry.pressed.connect(_start_run)
	v.add_child(retry)

	var leave := Button.new()
	leave.text = "Leave the Sewers"
	leave.custom_minimum_size = Vector2(280, 54)
	leave.pressed.connect(_on_close)
	v.add_child(leave)

## The player's daily luck (0-100, 50 = neutral). Prefers the typed save (which
## applies the Bennett penalty) and falls back to the synced Characters table so
## it works on remote clients too. Unknown → neutral 50.
func _player_luck() -> int:
	var owner := str(Global.ACTIVE_USER_NAME)
	if owner == "":
		return 50
	if SaveManager.get_player(owner) != null:
		return Global.get_effective_luck(owner)
	var rid: String = str(Global.CHARACTERS_NAME.get(owner, ""))
	if rid != "" and Global.CHARACTERS.has(rid):
		return int(Global.CHARACTERS[rid].get("Daily_Luck", 50))
	return 50

## Decide how many gems to award. Base is 1 (>=tier1) or 3 (>=tier3); luck gives
## an extremely small chance at +1 (good) or a chance to drop one (bad). Always
## yields at least 1 when a tier is met.
func _roll_gem_count(elapsed: float, tier1: float, tier3: float, luckf: float) -> int:
	if elapsed >= tier3:
		if luckf > 0.0 and randf() < clamp(luckf, 0.0, 1.0) * 0.10:
			return 4                      # rare lucky bonus
		if luckf < 0.0 and randf() < clamp(-luckf, 0.0, 1.0) * 0.20:
			return 2                      # unlucky reduction (still generous)
		return 3
	elif elapsed >= tier1:
		if luckf > 0.0 and randf() < clamp(luckf, 0.0, 1.0) * 0.10:
			return 2                      # rare lucky bonus
		return 1
	return 0

## Roll `count` random 1★ gems, add them to the player's inventory (stacking with
## any they already own), and return {gem_name: quantity} for the results screen.
func _grant_gems(count: int) -> Dictionary:
	var rolled: Dictionary = {}
	for i in range(count):
		var g: String = GEM_ITEMS[randi() % GEM_ITEMS.size()]
		rolled[g] = int(rolled.get(g, 0)) + 1
	var owner: String = str(Global.ACTIVE_USER_NAME)
	if owner != "":
		for gem_name in rolled:
			_add_item_to_inventory(owner, gem_name, int(rolled[gem_name]))
	return rolled

## Stack onto an existing Character_Items row for this owner+item, else insert.
func _add_item_to_inventory(owner: String, item_name: String, qty: int) -> void:
	for rid in Global.CHARACTER_ITEMS:
		var rec: Dictionary = Global.CHARACTER_ITEMS[rid]
		if str(rec.get("Owner", "")) == owner and str(rec.get("Name", "")) == item_name:
			Global.Update_Records([{
				"table": "Character_Items",
				"record_id": int(rec.get("id", int(rid))),
				"field": "Quantity",
				"value": int(rec.get("Quantity", 0)) + qty,
			}])
			return
	Global.Insert("Character_Items",
		["Owner", "Name", "Quantity", "Type", "Description", "Rarity"],
		[owner, item_name, qty, "1-Star Gem", " ", "Common"])

## Builds a full-screen modal overlay, stores its root in `_overlay` (so callers
## can free it), and returns the centered content VBox to populate.
func _make_overlay() -> VBoxContainer:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var v := VBoxContainer.new()
	v.name = "V"
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 28)
	center.add_child(v)
	add_child(o)
	_overlay = o
	return v

# ── Close / save ──────────────────────────────────────────────────────────────
func _on_close() -> void:
	var best_secs := int(round(_best_time))
	if best_secs > 0 and not Global.ACTIVE_USER_NAME.is_empty():
		Global.Insert("Minigames_Results",
			["Player", "Minigame", "Score", "Date"],
			[Global.ACTIVE_USER_NAME, "Exterminator Hunt", best_secs,
			 Time.get_datetime_string_from_system()])
	game_finished.emit(best_secs)
	var win = get_parent()
	while win and not (win is Window):
		win = win.get_parent()
	if win and win is Window:
		win.queue_free()
