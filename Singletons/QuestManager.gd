extends Node
## Quests — DM-authored objectives that grant Mora + reputation on completion.
## Records live in the synced "Quests" table. Mutations route host-authoritatively
## through Global.Insert / Global.Update_Records.

signal quests_changed

const TABLE := "Quests"
const STATUSES := ["active", "offered", "completed", "failed"]

func all_quests() -> Array:
	return Global.QUESTS.values()

func _quest(quest_id) -> Dictionary:
	return Global.QUESTS.get(str(quest_id), {})

## Create a quest. `data` holds the field columns (Title, Description, Region,
## Giver, Owner, Objectives(json), Reward_Mora, Rep_Action, Status, ...).
func create_quest(data: Dictionary) -> void:
	if not data.has("Status"):
		data["Status"] = "active"
	var cols: Array = []
	var vals: Array = []
	for k in data:
		cols.append(k)
		vals.append(data[k])
	Global.Insert(TABLE, cols, vals)
	emit_signal("quests_changed")

func set_status(quest_id, new_status: String) -> void:
	var q := _quest(quest_id)
	if q.is_empty():
		return
	var was := str(q.get("Status", ""))
	Global.Update_Records([{"table": TABLE, "record_id": int(quest_id), "field": "Status", "value": new_status}])
	if new_status == "completed" and was != "completed":
		_grant_rewards(q)
	emit_signal("quests_changed")

func delete_quest(quest_id) -> void:
	Global.Update_Records([{"table": TABLE, "record_id": int(quest_id), "field": "Status", "value": "deleted"}])
	emit_signal("quests_changed")

func objectives_of(q: Dictionary) -> Array:
	var raw = q.get("Objectives", "[]")
	if raw is Array:
		return raw
	var parsed = JSON.parse_string(str(raw))
	return parsed if parsed is Array else []

func toggle_objective(quest_id, index: int) -> void:
	var q := _quest(quest_id)
	if q.is_empty():
		return
	var objs := objectives_of(q)
	if index < 0 or index >= objs.size():
		return
	objs[index]["done"] = not bool(objs[index].get("done", false))
	Global.Update_Records([{"table": TABLE, "record_id": int(quest_id), "field": "Objectives", "value": JSON.stringify(objs)}])
	emit_signal("quests_changed")

## On completion: grant Mora to the party and fire the quest's reputation reward.
func _grant_rewards(q: Dictionary) -> void:
	var mora := int(q.get("Reward_Mora", 0))
	if mora != 0:
		var party: Dictionary = Global.Current_Party
		var pid := int(party.get("id", 1))
		Global.Update_Records([{"table": "Party", "record_id": pid, "field": "Mora", "value": int(party.get("Mora", 0)) + mora}])
	var owner := str(q.get("Owner", "Party"))
	if owner == "":
		owner = "Party"
	var region := str(q.get("Region", ""))
	var rep_action := str(q.get("Rep_Action", ""))
	if rep_action != "" and rep_action != "None":
		ReputationManager.apply_action(rep_action, owner, region)
	var rscope := str(q.get("Rep_Scope_Type", ""))
	if rscope != "":
		ReputationManager.record_standing(owner, rscope, str(q.get("Rep_Scope", "")), float(q.get("Rep_Amount", 0)), float(q.get("Rep_Severity", 0.6)))
