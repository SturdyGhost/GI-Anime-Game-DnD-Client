---
title: Region & Element Button Sync
date: 2026-03-29
tags: [networking, ui, bugfix, feature]
scope: player_hub.gd, Global.gd, NetworkManager.gd, party_save_data.gd
status: complete
---

# Region & Element Button Sync

## Region: Moved to Party-Wide Value

### Problem
Region was stored per-character on the Characters table. The region handler hardcoded
player names `["Dylan", "Brian F.", "Brian C."]` and changed all of them. Changes didn't
sync to other players because `Global.Current_Region` is a local property that was never
updated on receiving clients.

### Solution
Region is now a party-wide value stored on the Party record.

**Changes:**
- **party_save_data.gd**: Added `current_region: String = "Mondstadt"`
- **Global._party_to_dict()**: Includes `Current_Region` in serialized output
- **Global._set_party_field()**: Handles `Current_Region` — updates both resource and
  `Global.Current_Region` local property
- **Global._apply_update_to_save()**: Special case — when `Party.Current_Region` is
  updated, also sets `Global.Current_Region` (ensures clients sync)
- **player_hub._on_region_button_item_selected()**: Now writes to `Party` table with
  the party record ID, not Characters table
- **NetworkManager**: Host/client startup reads region from `Current_Party` instead of
  Characters
- **Party.json**: Added `"Current_Region": "Mondstadt"` field
- **migration.gd**: Populates `party.current_region` from legacy data
- **Enemy_Battle_Scene.gd**: Reads region from `Current_Party` instead of iterating
  Characters

### Sync Flow
1. Player selects new region in OptionButton
2. Handler calls `Global.Update_Records([{table: "Party", field: "Current_Region", ...}])`
3. If client: RPC to host, host applies + `broadcast_field_updates` to all clients
4. If host: applies locally + `broadcast_field_updates` to all clients
5. Receiving clients: `_receive_field_updates` -> `_apply_update_to_save` -> sets
   `Global.Current_Region` -> `data_load_complete` signal -> `set_ui()` refreshes

## Element: Fixed Non-Functional Button

### Problem
Element changes silently failed. The ability matching check compared `Entity_ID` from
JSON (a float like `409.0`) against `ACTIVE_USER_RECORD_ID` (an int `409`) using `str()`.
`"409.0" != "409"` so no abilities ever matched, `has_matching_ability` was always false,
and the handler returned without doing anything.

Additionally, the "local apply" line `Global.CHARACTERS[rid]["Element"] = new_element`
wrote to a temporary dict returned by the property getter, not to actual data.

### Solution
- **Entity_ID comparison**: Changed from `str(ability.get("Entity_ID")) == str(Global.ACTIVE_USER_RECORD_ID)`
  to `int(eid) == Global.ACTIVE_USER_RECORD_ID` with null guard
- **Same fix** applied to `set_element_button_options()` ability counting loop
- **Removed dead write**: The `Global.CHARACTERS[rid]["Element"] = ...` line was deleted;
  `Update_Records` -> `_apply_update_to_save` handles the real update to `_synced`
- **Safe access**: All `Global.CHARACTERS[Global.CHARACTERS_NAME[...]]` bracket chains
  replaced with `.get()` or reading from `Player_data`

### Sync Flow
1. Player selects new element
2. Ability check validates at least one ability exists for this element + weapon type
3. `Update_Records` sends to host and applies locally to `_synced`
4. Host broadcasts field update to all clients
5. All clients recalculate stats and refresh UI
