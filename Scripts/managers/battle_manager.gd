extends Node
## Manages battle state: spawned enemies, turn order, effects, combat resolution.
## Exists only during combat. Created at battle start, cleared at battle end.

signal battle_started
signal turn_advanced(battler_name: String)
signal battle_ended(all_enemies_dead: bool)

# ── Runtime Battle State ─────────────────────────────────────────────────────
var active: bool = false
var battle_id: String = ""
var turn_no: int = 0

var enemies: Dictionary = {}          # id → BattleEnemy resource
var turn_order: Array = []            # Array of battler labels
var current_turn: String = ""

var effect_processor: EffectProcessor = null
var battler_data: Dictionary = {}     # battler_label → Dictionary (same shape as old BattlerData)

# ── Lifecycle ────────────────────────────────────────────────────────────────

func start_battle(enemy_list: Array, party_turn_order: Array) -> void:
	active = true
	battle_id = str(Time.get_unix_time_from_system())
	turn_no = 0
	enemies.clear()
	effect_processor = EffectProcessor.new()

	# Spawn enemies
	for e in enemy_list:
		if e is BattleEnemy:
			enemies[e.id] = e
		elif e is Dictionary:
			var be = BattleEnemy.from_dict(e)
			enemies[be.id] = be

	# Build turn order
	turn_order = party_turn_order.duplicate()
	for e in enemies.values():
		if not turn_order.has(e.battle_label):
			turn_order.append(e.battle_label)

	if turn_order.size() > 0:
		current_turn = turn_order[0]

	# Register effects for all battlers
	_register_all_effects()

	# Build battler data
	_rebuild_battler_data()

	emit_signal("battle_started")

func end_battle() -> void:
	var all_dead = true
	for e in enemies.values():
		if not e.killed:
			all_dead = false
			break

	active = false
	effect_processor.clear_all()
	enemies.clear()
	battler_data.clear()
	turn_order.clear()

	emit_signal("battle_ended", all_dead)

## Advance to the next turn.
func advance_turn() -> void:
	if turn_order.is_empty():
		return

	# Tick effects for current battler
	effect_processor.on_turn_end(current_turn)
	turn_no += 1

	# Rotate
	var idx = turn_order.find(current_turn)
	var next_idx = (idx + 1) % turn_order.size()
	current_turn = turn_order[next_idx]

	# Process start-of-turn effects for new battler
	effect_processor.on_turn_start(current_turn)

	PartyManager.advance_turn(current_turn)
	emit_signal("turn_advanced", current_turn)

# ── Enemy Access ─────────────────────────────────────────────────────────────

func get_enemy(enemy_id: int) -> BattleEnemy:
	return enemies.get(enemy_id, null)

func get_all_enemies() -> Array:
	return enemies.values()

func get_living_enemies() -> Array:
	var result = []
	for e in enemies.values():
		if not e.killed:
			result.append(e)
	return result

# ── Battle Checks ────────────────────────────────────────────────────────────

func all_enemies_dead() -> bool:
	for e in enemies.values():
		if not e.killed:
			return false
	return true

func all_players_down() -> bool:
	for name in PartyManager.get_player_names():
		var player = SaveManager.get_player(name)
		if player and player.current_health > 0:
			return false
	return true

func should_end() -> bool:
	return all_enemies_dead() or all_players_down()

# ── Effect Registration ──────────────────────────────────────────────────────

func _register_all_effects() -> void:
	# Register weapon + artifact effects for each player
	for name in PartyManager.get_player_names():
		var weapon = SaveManager.get_equipped_weapon(name)
		if weapon:
			var wdef = weapon.get_definition()
			if wdef and wdef.effects.size() > 0:
				effect_processor.register_battler(name, wdef.effects)

		# Artifact set effects
		var artifacts = SaveManager.get_equipped_artifacts(name)
		var sets = {}
		for a in artifacts:
			sets[a.artifact_set] = sets.get(a.artifact_set, 0) + 1
		for set_name in sets:
			for bonus_type in [2, 4]:
				if sets[set_name] >= bonus_type:
					var bonus = GameDB.get_artifact_bonus(set_name, bonus_type)
					if bonus and bonus.effects.size() > 0:
						effect_processor.register_battler(name, bonus.effects)

	# Register companion effects (from abilities)
	for name in PartyManager.get_companion_names():
		pass  # Companions inherit from their abilities during battle

func _rebuild_battler_data() -> void:
	battler_data = BattlerState.build_all(turn_order)
