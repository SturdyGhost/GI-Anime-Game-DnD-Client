extends SceneTree
## Headless tests for effect permanence by SOURCE.
## Run: godot --headless --script test/effect_permanence_test.gd
## (No GdUnit4 in this project; self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## The rule: standing traits (weapon / artifact / passive / food / gear) last the
## whole battle and must never leave the effects tab. Applied instances (status
## effects, move-applied ability effects like stuns and roots) keep their authored
## duration and come and go.
##
## Before this rule, permanence was decided by TRIGGER (`trigger == "PASSIVE"`),
## which silently expired every weapon effect and 22 of 36 artifact set bonuses at
## the holder's first turn end — plus the Ruin Grader's Shock Absorbers, a passive
## that uses ON_DAMAGE_TAKEN to describe when it applies.

var _ran := false
var _fails: Array[String] = []

func _init() -> void:
	process_frame.connect(_run)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _run() -> void:
	if _ran:
		return
	_ran = true
	_test_standing_traits_are_permanent()
	_test_instances_still_expire()
	_test_explicit_durations_are_honoured()
	_test_grader_passives()

	if _fails.is_empty():
		print("EFFECT PERMANENCE TESTS: PASS")
		quit(0)
	else:
		print("EFFECT PERMANENCE TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)

func _mk(trigger: String, duration: int) -> GameEffect:
	var e = GameEffect.new()
	e.trigger = trigger
	e.duration = duration
	e.effect_type = "STAT_BONUS"
	return e

## Every persistent source survives repeated turn ends, whatever its trigger.
func _test_standing_traits_are_permanent() -> void:
	for src in ["weapon", "artifact", "passive", "food", "gear"]:
		for trig in ["PASSIVE", "ON_DAMAGE_TAKEN", "ON_HIT", "ON_SKILL_USE"]:
			var st = EffectState.from_effect(_mk(trig, 0), src, "Test Source")
			_check(st.turns_remaining == -1,
				"%s/%s is permanent at creation" % [src, trig])
			# Five turn ends must not kill a standing trait.
			var alive := true
			for i in range(5):
				alive = st.tick_turn()
			_check(alive, "%s/%s survives 5 turn ends" % [src, trig])
			_check(st.is_active, "%s/%s stays active" % [src, trig])

## Applied instances with duration 0 still expire — unchanged behaviour.
func _test_instances_still_expire() -> void:
	for src in ["status", "ability", ""]:
		var st = EffectState.from_effect(_mk("ON_HIT", 0), src, "Stun")
		_check(st.turns_remaining == 0, "%s instance is not made permanent" % src)
		_check(not st.tick_turn(), "%s instance expires on turn end" % src)
		_check(not st.is_active, "%s instance is deactivated" % src)

## A deliberately timed buff keeps its authored duration even from a gear source.
func _test_explicit_durations_are_honoured() -> void:
	var st = EffectState.from_effect(_mk("ON_HIT", 3), "artifact", "Timed Set Buff")
	_check(st.turns_remaining == 3, "explicit duration is preserved on a gear source")
	_check(st.tick_turn() and st.turns_remaining == 2, "tick 1 of 3")
	_check(st.tick_turn() and st.turns_remaining == 1, "tick 2 of 3")
	_check(not st.tick_turn(), "timed gear buff still expires on the final tick")

	var perm = EffectState.from_effect(_mk("ON_HIT", -1), "status", "Explicit Perm")
	_check(perm.turns_remaining == -1, "explicit -1 is permanent even from a status source")
	_check(perm.tick_turn(), "explicit -1 survives a tick")

## The two Ruin Grader passives specifically: classified as passives in the
## catalog, and permanent once registered through the passive source path.
func _test_grader_passives() -> void:
	var specs := {
		"iron_plating": "res://data/resources/abilities/ruin_grader_physical_iron_plating.tres",
		"shock_absorbers": "res://data/resources/abilities/ruin_grader_physical_shock_absorbers.tres",
	}
	for label in specs:
		var a = load(specs[label])
		_check(a != null, "%s loads" % label)
		if a == null:
			continue
		_check(str(a.ability_type) == "Passive", "%s is classified ability_type=Passive" % label)
		_check(a.effects.size() > 0, "%s carries at least one GameEffect" % label)
		for e in a.effects:
			var st = EffectState.from_effect(e, "passive", a.name)
			_check(st.turns_remaining == -1, "%s effect is permanent" % label)
			var alive := true
			for i in range(5):
				alive = st.tick_turn()
			_check(alive, "%s effect survives 5 turn ends" % label)
