extends Control
## A custom-drawn American roulette wheel: 38 colored pockets laid out in the true
## physical wheel sequence, with a ball that orbits the rim, decelerates, and drops
## into the winning pocket. Purely visual — the game decides the result and passes
## it to spin(); the wheel just performs the show and reports when it settles.

signal spin_complete
signal tick                       # emitted each time the ball crosses into a new pocket

# Physical pocket order on a double-zero American wheel (0 at top, going clockwise).
# 37 is the internal id for the "00" pocket.
const WHEEL_ORDER: Array = [
	0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1,
	37, 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2,
]
const POCKET_00: int = 37

# Element membership (must stay in sync with NingguangRoulette.gd).
const PYRO_NUMBERS: Array    = [1, 5, 9, 14, 18, 21, 25, 30, 34]
const HYDRO_NUMBERS: Array   = [2, 6, 10, 13, 17, 22, 26, 29, 33]
const ELECTRO_NUMBERS: Array = [3, 7, 12, 16, 19, 23, 27, 32, 36]
const CRYO_NUMBERS: Array    = [4, 8, 11, 15, 20, 24, 28, 31, 35]
const ELEM_CELL: Array = [
	Color(0.55, 0.16, 0.12),   # Pyro
	Color(0.13, 0.30, 0.58),   # Hydro
	Color(0.36, 0.20, 0.52),   # Electro
	Color(0.16, 0.42, 0.50),   # Cryo
]

const COL_GREEN := Color(0.15, 0.62, 0.40)
const COL_GOLD  := Color(1.00, 0.82, 0.35)
const COL_JADE  := Color(0.40, 0.82, 0.66)

const IDLE_SPEED: float = 0.22     # gentle resting rotation (rad/sec)
const WHEEL_TURNS: float = 4.0     # full turns the head makes during a spin
const BALL_TURNS: float = 7.0      # net turns the ball makes (opposite direction)

var _wheel_rot: float = 0.0
var _ball_rot: float = 0.0
var _ball_visible: bool = false

var _spinning: bool = false
var _elapsed: float = 0.0
var _duration: float = 4.5
var _base_wheel: float = 0.0
var _base_ball: float = 0.0
var _wheel_total: float = 0.0
var _ball_total: float = 0.0
var _result: int = 0
var _result_idx: int = -1
var _show_result: bool = false
var _last_pocket: int = -1

func _ready() -> void:
	# Only fall back to a default if the host scene didn't set an explicit size.
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(360, 360)

## Begin a spin that lands the ball in `result`'s pocket after `duration` seconds.
func spin(result: int, duration: float = 4.5) -> void:
	_result = result
	_result_idx = WHEEL_ORDER.find(result)
	_duration = max(0.1, duration)
	_elapsed = 0.0
	_spinning = true
	_ball_visible = true
	_show_result = false
	_last_pocket = -1

	var sector := TAU / WHEEL_ORDER.size()
	_base_wheel = _wheel_rot
	_base_ball = _ball_rot
	_wheel_total = WHEEL_TURNS * TAU           # head always turns a fixed amount clockwise

	# The ball must finish at the result pocket's centre RELATIVE to the (rotated) wheel.
	# Find just that landing fraction, then add a FIXED number of full counter-clockwise
	# turns so every spin sweeps the same powerful distance — regardless of where the
	# previous spin and the idle drift left things. (Previously this was derived from the
	# accumulated absolute angle, so each successive spin swept less and felt weaker.)
	var pocket_rel := (_result_idx + 0.5) * sector
	var needed := fposmod(pocket_rel - (_base_ball - _base_wheel), TAU)
	_ball_total = _wheel_total + needed - BALL_TURNS * TAU

func _process(delta: float) -> void:
	if _spinning:
		_elapsed += delta
		var t: float = clamp(_elapsed / _duration, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)       # ease-out cubic: fast then settling
		_wheel_rot = _base_wheel + _wheel_total * e
		_ball_rot = _base_ball + _ball_total * e
		_emit_ticks()
		queue_redraw()
		if t >= 1.0:
			_spinning = false
			_show_result = true
			spin_complete.emit()
	else:
		# Idle drift — keep the ball nested in its pocket so the read stays valid.
		_wheel_rot += IDLE_SPEED * delta
		if _ball_visible:
			_ball_rot += IDLE_SPEED * delta
		queue_redraw()

func _emit_ticks() -> void:
	var sector := TAU / WHEEL_ORDER.size()
	var rel := fposmod(_ball_rot - _wheel_rot, TAU)
	var pocket := int(rel / sector)
	if pocket != _last_pocket:
		_last_pocket = pocket
		tick.emit()

# ── Drawing ───────────────────────────────────────────────────────────────────
func _polar(c: Vector2, r: float, ang: float) -> Vector2:
	# Angle measured clockwise from straight up.
	return c + Vector2(sin(ang), -cos(ang)) * r

func _draw() -> void:
	var c := size * 0.5
	var R: float = min(size.x, size.y) * 0.5
	# Proportional geometry so the wheel reads cleanly at any size.
	var rim_r := R * 0.985
	var ball_track := R * 0.93
	var pocket_outer := R * 0.86
	var hub_r := pocket_outer * 0.42
	var number_r := (hub_r + pocket_outer) * 0.5
	var ball_r := R * 0.028
	var sector := TAU / WHEEL_ORDER.size()
	var font := get_theme_default_font()
	var fs := max(12, int(R * 0.058))

	var dark := Color(0.05, 0.06, 0.06)

	# Dark backing disc (antialiased rim).
	draw_circle(c, rim_r, dark, true, -1.0, true)

	# Pockets — many arc segments for a smooth curved outer edge, slightly overfilled
	# so the dark ball-track ring drawn next can hide the seam behind a clean AA edge.
	for i in WHEEL_ORDER.size():
		var id: int = WHEEL_ORDER[i]
		var a0 := _wheel_rot + i * sector
		var a1 := a0 + sector
		draw_colored_polygon(_sector_points(c, pocket_outer + R * 0.01, a0, a1, 16), _pocket_color(id))

	# Smooth dark ball-track ring laid over the pocket rims (antialiased both edges).
	var track_w := rim_r - pocket_outer
	var track_mid := (pocket_outer + rim_r) * 0.5
	draw_arc(c, track_mid, 0.0, TAU, 220, dark, track_w, true)

	# Frets (gold dividers) + numbers.
	var fret_w := max(1.5, R * 0.004)
	for i in WHEEL_ORDER.size():
		var a0 := _wheel_rot + i * sector
		draw_line(_polar(c, hub_r, a0), _polar(c, pocket_outer, a0), Color(0.85, 0.7, 0.35, 0.6), fret_w, true)

		var id: int = WHEEL_ORDER[i]
		var amid := _wheel_rot + (i + 0.5) * sector
		var npos := _polar(c, number_r, amid)
		var s := "00" if id == POCKET_00 else str(id)
		var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_set_transform(npos, amid, Vector2.ONE)
		draw_string(font, Vector2(-tw * 0.5, fs * 0.4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Winning pocket highlight (after the ball settles).
	if _show_result and _result_idx >= 0:
		var a0 := _wheel_rot + _result_idx * sector
		var a1 := a0 + sector
		var ring := _sector_points(c, pocket_outer, a0, a1, 16)
		ring.remove_at(0)  # drop the center point, leaving just the arc outline
		draw_polyline(ring, COL_GOLD, max(2.0, R * 0.006), true)

	# Rim rings (high segment count + AA for clean circles).
	draw_arc(c, rim_r, 0.0, TAU, 220, COL_GOLD, max(3.0, R * 0.012), true)
	draw_arc(c, pocket_outer, 0.0, TAU, 220, Color(0.7, 0.58, 0.3, 0.85), max(1.5, R * 0.004), true)

	# Hub — jade core, gold ring, rotating spokes for a sense of motion.
	draw_circle(c, hub_r, Color(0.10, 0.14, 0.13), true, -1.0, true)
	draw_arc(c, hub_r, 0.0, TAU, 160, COL_GOLD, max(2.0, R * 0.006), true)
	var spoke_w := max(1.5, R * 0.004)
	for k in 4:
		var sa := _wheel_rot + k * (TAU / 4.0)
		draw_line(c, _polar(c, hub_r * 0.9, sa), Color(0.75, 0.62, 0.32, 0.8), spoke_w, true)
	draw_circle(c, hub_r * 0.34, COL_JADE, true, -1.0, true)
	draw_circle(c, hub_r * 0.18, COL_GOLD, true, -1.0, true)

	# Ball.
	if _ball_visible:
		var bpos := _polar(c, ball_track, _ball_rot)
		draw_circle(bpos + Vector2(ball_r * 0.2, ball_r * 0.25), ball_r * 1.05, Color(0, 0, 0, 0.4), true, -1.0, true)
		draw_circle(bpos, ball_r, Color(0.97, 0.97, 0.98), true, -1.0, true)
		draw_circle(bpos - Vector2(ball_r * 0.25, ball_r * 0.3), ball_r * 0.35, Color(1, 1, 1), true, -1.0, true)

func _sector_points(c: Vector2, r: float, a0: float, a1: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c)
	for s in segs + 1:
		var a: float = lerp(a0, a1, float(s) / segs)
		pts.append(_polar(c, r, a))
	return pts

func _pocket_color(id: int) -> Color:
	if id == 0 or id == POCKET_00:
		return COL_GREEN
	return ELEM_CELL[_element_index(id)]

## Element index (0=Pyro 1=Hydro 2=Electro 3=Cryo) for a number.
func _element_index(n: int) -> int:
	if n in PYRO_NUMBERS: return 0
	if n in HYDRO_NUMBERS: return 1
	if n in ELECTRO_NUMBERS: return 2
	return 3
