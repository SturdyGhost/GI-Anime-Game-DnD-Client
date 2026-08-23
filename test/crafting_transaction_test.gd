extends SceneTree
## Headless regression tests for the crafting transaction (2026-08-22).
## Run: godot --headless --script test/crafting_transaction_test.gd
## (No GdUnit4 in this project; this is a self-contained SceneTree assertion harness.)
## Exits 0 on PASS, 1 on FAIL.
##
## The bug: CraftingMenu._on_confirm_pressed read the target player from
## target_select.get_item_text() instead of get_item_metadata(). The dropdown
## labels the active player "Name (me)" for readability, so a player crafting
## for themselves — the default selection — produced target == "Dylan (me)".
## That name matches no Owner, so:
##   1. the "do I already have this?" scan never hit, and
##   2. Global.Insert created a fresh row owned by the phantom "Dylan (me)".
## _get_inventory_array() filters Owner == ACTIVE_USER_NAME, so the crafted item
## was invisible while the ingredients had already been decremented. Materials
## gone, product nowhere.
##
## Second half of the fix: crafting was not a transaction. On a client the
## product Insert and the ingredient Update_Records went out as two independent
## RPCs with no host-side validation, so a half-applied craft ate materials.
## Crafting now ships ONE request; the host validates everything before it
## mutates anything, then grants and consumes together.
##
## These tests pin both: the target resolves to a real name, and a craft the
## host rejects consumes nothing.

var _ran := false
var _fails: Array[String] = []

func _init() -> void:
	# Autoloads aren't attached during _init; run after the first process frame.
	process_frame.connect(_run)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)

func _run() -> void:
	if _ran:
		return
	_ran = true
	var g = root.get_node_or_null("Global")
	var nm = root.get_node_or_null("NetworkManager")
	if g == null or nm == null:
		print("CRAFTING TRANSACTION TESTS: FAIL (Global/NetworkManager autoload missing)")
		quit(1)
		return

	# Run the host handler through the offline path: it takes the same
	# _handle_craft_request branch as the host but skips disk persistence and
	# RPC broadcasts, neither of which exists in a headless one-process run.
	g.is_offline = true
	nm.is_host = false

	_test_target_resolves_to_real_name()
	_test_craft_grants_and_consumes(g, nm)
	_test_existing_stack_is_bumped(g, nm)
	_test_phantom_target_is_rejected(g, nm)
	_test_insufficient_materials_consume_nothing(g, nm)
	_test_duplicate_slots_are_aggregated(g, nm)
	_test_weapon_product_lands_in_weapons(g, nm)

	# Don't leave this run's writes in the dev machine's offline log.
	var oc = root.get_node_or_null("OfflineChanges")
	if oc != null:
		oc.clear()

	if _fails.is_empty():
		print("CRAFTING TRANSACTION TESTS: PASS")
		quit(0)
	else:
		print("CRAFTING TRANSACTION TESTS: FAIL")
		for f in _fails:
			print("  - ", f)
		quit(1)

# ── Helpers ────────────────────────────────────────────────────────────────

## Seed a minimal world: one crafter, one other party member, and an inventory.
## `items` is an array of {id, Owner, Name, Quantity}.
func _seed(g, items: Array) -> void:
	var chars := {}
	var i := 1
	for nm_ in ["Dylan", "Brian C."]:
		chars[str(i)] = {"id": i, "Name": nm_, "Role": "Blacksmith"}
		i += 1
	g._synced["Characters"] = chars

	var rows := {}
	for it in items:
		rows[str(it["id"])] = {
			"id": it["id"],
			"Owner": it["Owner"],
			"Name": it["Name"],
			"Quantity": it["Quantity"],
			"Type": "Material",
			"Rarity": "Common",
			"Description": "",
		}
	g._synced["Character_Items"] = rows
	g._synced["Character_Weapons"] = {}
	g.ACTIVE_USER_NAME = "Dylan"

## Quantity of a Character_Items row, or -1 if the row is gone.
func _qty(g, rid: int) -> int:
	var rec = g._synced.get("Character_Items", {}).get(str(rid), null)
	return -1 if rec == null else int(rec.get("Quantity", 0))

## Every row in `table` owned by `owner` whose name field equals `product`.
func _rows_for(g, table: String, owner: String, product: String) -> Array:
	var field := "Name" if table == "Character_Items" else "Weapon"
	var out := []
	for rec in g._synced.get(table, {}).values():
		if rec.get("Owner") == owner and rec.get(field) == product:
			out.append(rec)
	return out

## Pick a real product name out of the loaded recipe catalog for the given
## destination table, so _recipe_exists() and the master-catalog lookup both
## resolve without hardcoding campaign data that may be rebalanced later.
##
## Global.ITEMS / Global.WEAPONS are property getters that rebuild the whole
## dictionary on every read, so snapshot them once and cache the answer rather
## than touching them inside a loop.
var _product_cache: Dictionary = {}

func _pick_product(g, want_weapon: bool) -> String:
	if _product_cache.has(want_weapon):
		return _product_cache[want_weapon]
	_product_cache[want_weapon] = ""

	var gdb = root.get_node_or_null("GameDB")
	if gdb == null:
		return ""

	var catalog_names := {}
	if want_weapon:
		for w in g.WEAPONS.values():
			catalog_names[str(w.get("Name", ""))] = true
	else:
		for it in g.ITEMS.values():
			catalog_names[str(it.get("Item", ""))] = true
			catalog_names[str(it.get("Name", ""))] = true

	for r in gdb.crafting_recipes.values():
		var prod: String = str(r.product)
		if prod != "" and catalog_names.has(prod):
			_product_cache[want_weapon] = prod
			return prod
	return ""

func _craft(nm, product: String, target: String, table: String, qty: int, consume: Array) -> void:
	nm._handle_craft_request(1, "test-corr", {
		"product": product,
		"target": target,
		"table": table,
		"qty": qty,
		"consume": consume,
	})

# ── Tests ──────────────────────────────────────────────────────────────────

## The original bug, at the source: the dropdown labels the active player
## "Name (me)", and the target must come from item metadata, not that label.
func _test_target_resolves_to_real_name() -> void:
	var script = load("res://Scenes/CraftingMenu.gd")
	if script == null:
		_fails.append("target-resolve: CraftingMenu.gd failed to load")
		return
	var menu = script.new()  # never enters the tree, so _ready() doesn't run
	var g = root.get_node_or_null("Global")
	g.ACTIVE_USER_NAME = "Dylan"

	var opt := OptionButton.new()
	opt.add_item("Dylan (me)")
	opt.set_item_metadata(0, "Dylan")
	opt.add_item("Brian C.")
	opt.set_item_metadata(1, "Brian C.")
	menu.target_select = opt

	opt.select(0)
	_check(menu._get_selected_target() == "Dylan",
		"crafting for yourself must resolve to 'Dylan', got '%s'" % menu._get_selected_target())

	opt.select(1)
	_check(menu._get_selected_target() == "Brian C.",
		"crafting for another player must resolve to 'Brian C.', got '%s'" % menu._get_selected_target())

	# An entry added without metadata still must not leak the "(me)" suffix.
	var bare := OptionButton.new()
	bare.add_item("Dylan (me)")
	bare.select(0)
	menu.target_select = bare
	_check(menu._get_selected_target() == "Dylan",
		"metadata-less fallback must strip ' (me)', got '%s'" % menu._get_selected_target())

	opt.free()
	bare.free()
	menu.free()

## A valid craft consumes the materials AND grants the product, to the right owner.
func _test_craft_grants_and_consumes(g, nm) -> void:
	var product := _pick_product(g, false)
	if product == "":
		_fails.append("grant-and-consume: no craftable item product found in the catalog")
		return
	_seed(g, [{"id": 10, "Owner": "Dylan", "Name": "Iron Chunk", "Quantity": 5}])

	_craft(nm, product, "Dylan", "Character_Items", 1, [{"id": 10, "take": 2}])

	_check(_qty(g, 10) == 3, "materials should drop 5 -> 3, got %d" % _qty(g, 10))
	var got := _rows_for(g, "Character_Items", "Dylan", product)
	_check(got.size() == 1, "expected exactly 1 '%s' row for Dylan, got %d" % [product, got.size()])
	if got.size() == 1:
		_check(int(got[0].get("Quantity", 0)) == 1,
			"crafted quantity should be 1, got %d" % int(got[0].get("Quantity", 0)))
	_check(_rows_for(g, "Character_Items", "Dylan (me)", product).is_empty(),
		"no row may be created under the phantom owner 'Dylan (me)'")

## Crafting something you already hold bumps the stack instead of adding a row.
func _test_existing_stack_is_bumped(g, nm) -> void:
	var product := _pick_product(g, false)
	if product == "":
		return
	_seed(g, [
		{"id": 10, "Owner": "Dylan", "Name": "Iron Chunk", "Quantity": 5},
		{"id": 11, "Owner": "Dylan", "Name": product, "Quantity": 4},
	])

	_craft(nm, product, "Dylan", "Character_Items", 3, [{"id": 10, "take": 1}])

	var got := _rows_for(g, "Character_Items", "Dylan", product)
	_check(got.size() == 1, "stack should stay a single row, got %d rows" % got.size())
	_check(_qty(g, 11) == 7, "existing stack should go 4 -> 7, got %d" % _qty(g, 11))

## The phantom owner the old code produced is now refused outright, and — the
## part that matters — refusing it consumes nothing.
func _test_phantom_target_is_rejected(g, nm) -> void:
	var product := _pick_product(g, false)
	if product == "":
		return
	_seed(g, [{"id": 10, "Owner": "Dylan", "Name": "Iron Chunk", "Quantity": 5}])

	_craft(nm, product, "Dylan (me)", "Character_Items", 1, [{"id": 10, "take": 2}])

	_check(_qty(g, 10) == 5, "a rejected craft must consume nothing, got %d (was 5)" % _qty(g, 10))
	_check(_rows_for(g, "Character_Items", "Dylan (me)", product).is_empty(),
		"'Dylan (me)' must never receive a record")

## The transaction property the whole rewrite exists for.
func _test_insufficient_materials_consume_nothing(g, nm) -> void:
	var product := _pick_product(g, false)
	if product == "":
		return
	_seed(g, [
		{"id": 10, "Owner": "Dylan", "Name": "Iron Chunk", "Quantity": 2},
		{"id": 12, "Owner": "Dylan", "Name": "White Iron Chunk", "Quantity": 9},
	])

	# Slot 2 is satisfiable, slot 1 is not — neither may be touched.
	_craft(nm, product, "Dylan", "Character_Items", 1,
		[{"id": 10, "take": 5}, {"id": 12, "take": 1}])

	_check(_qty(g, 10) == 2, "short ingredient must be untouched, got %d (was 2)" % _qty(g, 10))
	_check(_qty(g, 12) == 9, "the OTHER ingredient must be untouched too, got %d (was 9)" % _qty(g, 12))
	_check(_rows_for(g, "Character_Items", "Dylan", product).is_empty(),
		"a rejected craft must not grant the product")

## Two slots drawing on the same stack are summed before the check, so the pair
## can't overdraw a row that satisfies each slot on its own.
func _test_duplicate_slots_are_aggregated(g, nm) -> void:
	var product := _pick_product(g, false)
	if product == "":
		return
	_seed(g, [{"id": 10, "Owner": "Dylan", "Name": "Iron Chunk", "Quantity": 5}])

	# 3 + 3 = 6 > 5, though either slot alone would pass.
	_craft(nm, product, "Dylan", "Character_Items", 1,
		[{"id": 10, "take": 3}, {"id": 10, "take": 3}])

	_check(_qty(g, 10) == 5, "overdrawing pair must consume nothing, got %d (was 5)" % _qty(g, 10))

	# And a pair that does fit takes the full sum, not just one slot's worth.
	_craft(nm, product, "Dylan", "Character_Items", 1,
		[{"id": 10, "take": 2}, {"id": 10, "take": 2}])
	_check(_qty(g, 10) == 1, "fitting pair should take 4 (5 -> 1), got %d" % _qty(g, 10))

## Blacksmith products are weapons and must land in Character_Weapons, built
## from the host's own catalog rather than anything the client sent.
func _test_weapon_product_lands_in_weapons(g, nm) -> void:
	var product := _pick_product(g, true)
	if product == "":
		_fails.append("weapon-product: no craftable weapon product found in the catalog")
		return
	_seed(g, [{"id": 10, "Owner": "Dylan", "Name": "Iron Chunk", "Quantity": 5}])

	_craft(nm, product, "Brian C.", "Character_Weapons", 1, [{"id": 10, "take": 2}])

	_check(_qty(g, 10) == 3, "crafter pays the materials even when giving away, got %d" % _qty(g, 10))
	var got := _rows_for(g, "Character_Weapons", "Brian C.", product)
	_check(got.size() == 1, "expected 1 '%s' weapon row for Brian C., got %d" % [product, got.size()])
	if got.size() == 1:
		_check(str(got[0].get("Type", "")) != "",
			"weapon Type must be filled from the host catalog, got empty")
		_check(int(got[0].get("Refinement", -1)) == 0, "new weapon should start at Refinement 0")
		_check(got[0].get("Equipped") == false, "new weapon should start unequipped")
	_check(_rows_for(g, "Character_Weapons", "Dylan", product).is_empty(),
		"the product must go to the target, not the crafter")
