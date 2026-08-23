extends SceneTree
var _ran := false
func _init() -> void:
	process_frame.connect(_run)
func _tally(label: String, effects: Array, zero: Dictionary, pos: Dictionary, neg: Dictionary) -> void:
	for e in effects:
		if e == null: continue
		if e.duration == 0: zero[label] = zero.get(label, 0) + 1
		elif e.duration > 0: pos[label] = pos.get(label, 0) + 1
		else: neg[label] = neg.get(label, 0) + 1
func _run() -> void:
	if _ran: return
	_ran = true
	var gdb = root.get_node_or_null("GameDB")
	var zero := {}; var pos := {}; var neg := {}
	# weapons
	for w in gdb.weapons.values():
		_tally("weapon", WeaponEffects.get_effects(w.name), zero, pos, neg)
	# artifact sets (2pc and 4pc)
	for s in gdb.artifact_sets.values():
		for bt in [2, 4]:
			_tally("artifact", ArtifactEffects.get_effects(s.name, bt), zero, pos, neg)
	# passives
	for a in gdb.abilities.values():
		var is_p = (str(a.ability_type).to_lower() == "passive") or a.weight <= 0.0
		if is_p:
			_tally("passive", a.effects, zero, pos, neg)
			_tally("passive", AbilityEffects.get_effects(a.id), zero, pos, neg)
	print("duration == 0 (would become permanent): ", zero)
	print("duration >  0 (timed, left alone):      ", pos)
	print("duration <  0 (already permanent):      ", neg)
	quit(0)
