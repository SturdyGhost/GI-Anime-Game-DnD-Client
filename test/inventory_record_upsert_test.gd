extends SceneTree
## Regression test: a single-record broadcast (broadcast_record_update ->
## _apply_record_update) must UPSERT one record, never wipe the rest of the table.
## Guards the bulk/single transfer corruption where every inventory collapsed to
## the one transferred item. Run: godot --headless --script test/inventory_record_upsert_test.gd

var _done := false
func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	if _done:
		return
	_done = true
	var g = root.get_node_or_null("Global")
	if g == null:
		print("INVENTORY UPSERT TEST: FAIL (Global autoload missing)")
		quit(1)
		return
	var ok := true
	# Seed a table with several records owned by different players.
	g._synced["Character_Items"] = {
		"1": {"id": 1, "Owner": "Ava", "Name": "Sword", "Quantity": 1},
		"2": {"id": 2, "Owner": "Ava", "Name": "Shield", "Quantity": 2},
		"3": {"id": 3, "Owner": "Ben", "Name": "Rope", "Quantity": 4},
	}
	# Upsert a brand-new record (as a transfer insert would broadcast).
	g._apply_record_update("Character_Items", "4", {"id": 4, "Owner": "Ben", "Name": "Potion", "Quantity": 5})
	var t: Dictionary = g._synced.get("Character_Items", {})
	if t.size() != 4:
		ok = false
		print("FAIL: expected 4 records after upsert, got ", t.size(), " (table was wiped?)")
	for k in ["1", "2", "3", "4"]:
		if not t.has(k):
			ok = false
			print("FAIL: record ", k, " missing after upsert")
	if t.get("4", {}).get("Name") != "Potion":
		ok = false
		print("FAIL: upserted record not stored correctly")
	# Upsert an EXISTING record id — should replace just that one, keep the rest.
	g._apply_record_update("Character_Items", "2", {"id": 2, "Owner": "Ava", "Name": "Shield", "Quantity": 9})
	t = g._synced.get("Character_Items", {})
	if t.size() != 4:
		ok = false
		print("FAIL: existing-id upsert changed table size to ", t.size())
	if int(t.get("2", {}).get("Quantity", 0)) != 9:
		ok = false
		print("FAIL: existing-id upsert didn't update the record")
	print("INVENTORY UPSERT TEST: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
