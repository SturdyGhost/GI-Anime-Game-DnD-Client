class_name SimSpatial extends RefCounted
## Simplified distance-based spatial model for battle simulation.
## Tracks positions as floats on a 1D line (0 = player start, arena_size = enemy start).

var _positions: Dictionary = {}
var _sizes: Dictionary = {}
var arena_size: int = 20

func setup(player_names: Array, enemy_names: Array, enemy_sizes: Dictionary, p_arena_size: int = 20) -> void:
	arena_size = p_arena_size
	_positions.clear()
	_sizes.clear()
	for name in player_names:
		_positions[name] = 0.0
		_sizes[name] = 1
	for name in enemy_names:
		_positions[name] = float(arena_size)
		_sizes[name] = enemy_sizes.get(name, 1)

func get_position(name: String) -> float:
	return _positions.get(name, 0.0)

## Get effective distance between two combatants (accounts for size).
func distance(a: String, b: String) -> float:
	var raw := absf(_positions.get(a, 0.0) - _positions.get(b, 0.0))
	var size_a: int = _sizes.get(a, 1)
	var size_b: int = _sizes.get(b, 1)
	var reach_bonus := float(maxi(size_a, size_b) / 2)
	return maxf(0.0, raw - reach_bonus)

## Check if a can reach b with a melee attack (distance <= 1).
func in_melee_range(a: String, b: String) -> bool:
	return distance(a, b) <= 1.0

## Check if a can reach b with a ranged ability.
func in_range(a: String, b: String, attack_range: int) -> bool:
	if attack_range <= 0:
		return in_melee_range(a, b)
	return distance(a, b) <= float(attack_range)

## Move battler toward target by up to movement_budget tiles.
## Returns tiles actually moved.
func move_toward(name: String, target: String, movement_budget: float) -> float:
	var my_pos := _positions.get(name, 0.0)
	var target_pos := _positions.get(target, 0.0)
	var dir := signf(target_pos - my_pos)
	var dist := absf(target_pos - my_pos)
	var move := minf(movement_budget, dist)
	_positions[name] = my_pos + dir * move
	return move

## Move battler away from target by up to movement_budget tiles.
func move_away(name: String, target: String, movement_budget: float) -> float:
	var my_pos := _positions.get(name, 0.0)
	var target_pos := _positions.get(target, 0.0)
	var dir := -signf(target_pos - my_pos)
	var move := minf(movement_budget, float(arena_size))
	var new_pos := clampf(my_pos + dir * move, 0.0, float(arena_size))
	var actual := absf(new_pos - my_pos)
	_positions[name] = new_pos
	return actual

## Get all combatants within radius of a position.
func get_in_radius(center_name: String, radius: float, all_names: Array) -> Array:
	var result: Array = []
	for name in all_names:
		if name == center_name:
			continue
		if distance(center_name, name) <= radius:
			result.append(name)
	return result

## Remove a combatant (dead/removed from battle).
func remove(name: String) -> void:
	_positions.erase(name)
	_sizes.erase(name)
