# Battle Host-Authority + Cooldown Rebuild Design

> Status: **DRAFT for review** — no implementation started (baseline committed at `efa923c` on `master`).
> Companion memory: `project_battle_host_authority_refactor`.

## Problem

Combat is supposed to be **host-authoritative** (host owns all logic; clients are shells that send input and render synced state). Today it is not:

1. **Turn resolution runs on the acting client.** `BattleScene._on_end_turn_pressed` builds a turn `input`, calls `TurnProcessor.process_turn(input)` **locally**, detects kills, logs, and `_advance_turn()` picks the next turn from the **`_turn_list` UI**. Only then does `Global.Update_Records()` ship the computed changes to the host, which merely **persists + echoes** them. A malicious/desynced/buggy client therefore authors combat outcomes.
2. **`BattleManager` is dormant.** `start_battle()` is never called, so `BattleManager.active` is never true and `Global.BattlerData` / `BATTLEENEMIES` always use the table-driven fallback rebuilt by `BattlerState.build_all`. Battle "state" is really just a re-derivation from synced tables on every `data_load_complete`.
3. **Cooldown rides a fragile junction.** Remaining cooldown lives in the synced `Active_Abilities` table, bridged to the `.tres` catalog by `active_ability_id` (or a synthetic `id + 100000` fallback in `GameDB.build_active_abilities_table`). This dual-sourcing + brittle key is what silently dropped Brian C.'s Basic/Burst from the attack dropdown (empty `kit_element`).

## Goals

- Host owns **all** battle logic and state. Clients send raw turn **input** and render **broadcast** state only.
- `BattleManager` (host) is the live source of truth for: spawned enemies, turn order, current turn, per-battler data, ability cooldowns, and the effect processor.
- Ability `.tres` is the source of truth for ability data (duplication across files is acceptable; abilities need not be shared across entities).
- Static cooldown **length** lives on the `.tres` (`cooldown`). **Remaining** cooldown is host-tracked per `(battler, ability_id)`, decremented by 1 only at the end of **that battler's own turn**, cleared at battle end.
- The `Active_Abilities` table is **removed** entirely (no persistence, no sync-as-table, no `active_ability_id`).

## Non-Goals

- No change to the damage formula, effect (`GameEffect`) semantics, or the combat math in `TurnProcessor`/`ability_effects`.
- No change to ability *definitions* beyond removing the assignment/runtime fields the host no longer needs.
- Not redesigning the battle UI layout (the recent dropdown fix stays).

## Current Flow (as-is)

```
Acting peer (host OR client):
  _on_end_turn_pressed()
    input = {battler, attack, rolls, targets, ...}
    updates = TurnProcessor.process_turn(input)        # LOCAL compute
    Global.Update_Records(updates)                      # client -> host RPC; host applies+echoes
    kill detection (from updates)
    logging (host direct / client -> host RPC)
    _advance_turn()                                     # next turn from _turn_list UI -> Party.Current_Turn update

Every peer, on data_load_complete:
  _on_data_load_complete()
    Current_Turn = Party.Current_Turn
    _setup_turn_order()   # Party.Turn_Order + BATTLEENEMIES
    _build_battlers()      # BattlerState.build_all(...) from synced tables
    _refresh_all(); _update_dock_visibility()
    if host/offline: check_battle_end()
```

## Target Flow (to-be)

```
Client (acting):
  _on_end_turn_pressed()
    input = {...}
    NetworkManager.request_process_turn(input)          # raw INPUT only -> host

Host (authoritative, also the path for host-acting + offline):
  BattleManager.process_turn(input)
    1. validate it is `input.battler`'s turn and the action is legal
    2. TurnProcessor.process_turn(input) -> updates       # unchanged math, host-run
    3. apply updates to authoritative state (enemies/characters/effects)
    4. cooldowns: set used ability to its static `cooldown`
    5. tick the acting battler's other cooldowns by 1
    6. advance_turn() from BattleManager.turn_order (NOT UI)
    7. broadcast authoritative battle state to all peers
    8. broadcast damage breakdown to the acting player; log the turn

Client (any), on receiving battle-state broadcast:
  apply snapshot -> render. No local combat compute, no build_all-from-tables.
```

## State Ownership Model

`BattleManager` (host) holds the authoritative battle state and is activated at battle start:

| Field | Meaning | Lifetime |
|---|---|---|
| `active`, `battle_id`, `turn_no` | battle lifecycle | start → end |
| `enemies: {id: BattleEnemy}` | spawned enemy state | start → end |
| `turn_order: Array[String]` | battler labels in order | start → end |
| `current_turn: String` | whose turn | start → end |
| `battler_data: {label: Dict}` | per-battler view (`BattlerState`) | rebuilt on change |
| `cooldowns: {label: {ability_id: turns_left}}` | **new** — remaining cooldowns | start → end (cleared at end) |
| `effect_processor` | effects | start → end |

**Broadcast.** Host pushes an authoritative battle-state snapshot to clients over a dedicated reliable RPC (`@rpc("authority","reliable")`), replacing the "clients re-derive from synced tables" model for battle. Snapshot carries: `turn_no`, `current_turn`, `turn_order`, per-battler display data, `cooldowns`, and enemy HP/status deltas. Persistent entity facts (Characters/Companions/BattleEnemies rows) continue to flow through the existing table-sync; the battle snapshot is transient and never written to `CanonicalSave`.

**Clients** keep a read-only mirror of the snapshot (in `BattleManager` on the client, or a client-side holder) and render from it. `BattlerState.build_all` is reused **on the host** to assemble `battler_data`; clients consume the broadcast result rather than rebuilding.

## Cooldown Model

- `ability_data.gd`: keep static `cooldown`. **Remove** `ability_cooldown` (runtime) and `active_ability_id` (bridge).
- `BattleManager.cooldowns` keyed by stable `(label, ability_id)`. Helpers: `put_on_cooldown(label, ability_id, turns)`, `tick_battler(label)`, `remaining(label, ability_id) -> int`, `clear()`.
- `TurnProcessor` (host-run): step 6 "put on cooldown" → `BattleManager.put_on_cooldown(label, ability_id, ability.cooldown)`; `_process_cooldowns(label)` → `BattleManager.tick_battler(label)`. **Ordering preserved**: tick reads the snapshot taken before the just-used set, so a freshly-used ability is not double-decremented (identical to current semantics).
- `battler_state.build_all`: source remaining cooldown from `BattleManager.cooldowns` and write it into the per-ability dict under the existing `Ability_Cooldown` key, so `BattleScene._setup_attacks` keeps working unchanged.
- Cooldown reaches clients via the battle-state broadcast (not a table).

## Active_Abilities Removal

- `Global.ACTIVE_ABILITIES` → pure `.tres` mapping via `GameDB.build_active_abilities_table()`; drop the `_synced` merge, the cooldown overlay, and the `id + 100000` fallback. Re-key by a stable id (ability id or `entity_type|entity_id|ability_id`).
- Remove `"Active_Abilities"` from `Global.TABLES`, `TABLES_TO_SAVE`, `TABLES_TO_SYNC_OFTEN`, `CanonicalSave` (both lists), and `DataStore`'s table switch.
- Delete `Scripts/resources/active_ability.gd` if unused after the above.
- Keep `GameDB._validate_kit_abilities()`; drop its `active_ability_id` check once the field is gone.

## Implementation Phases

Each phase compiles, runs the kit-ability validation, and passes a battle smoke test before the next.

- **Phase 0 — Branch.** Create `battle-host-authority` off `master` (done after spec approval).
- **Phase 1 — Host turn submission.** Add `request_process_turn` RPC; `_on_end_turn_pressed` sends input (client) / runs host path (host+offline). Move kill-detection, logging, and turn-advance host-side; advance from a data source, not `_turn_list`. Behavior parity, still table-synced.
- **Phase 2 — Activate BattleManager.** Call `start_battle` on the host at battle entry; make `BattleManager` own enemies/turn_order/current_turn/battler_data/effects; add the battle-state broadcast + client mirror; route `_on_data_load_complete` rendering through the snapshot on clients.
- **Phase 3 — Cooldown model.** `ability_data.gd` field changes; `BattleManager.cooldowns` + helpers; `TurnProcessor` + `battler_state` rewire; cooldown rides the broadcast.
- **Phase 4 — Remove Active_Abilities.** Getter, table lists, CanonicalSave, DataStore, resource deletion, validation trim.
- **Phase 5 — Cleanup + tests.** Remove dormant fallbacks made dead by Phase 2; GdUnit4 coverage; full smoke pass (host, 2-client, offline).

## Test Plan

Authoritative contract (rule #2 — Claude runs these headless):

1. **Cooldown unit (GdUnit4):** put_on_cooldown sets remaining = static `cooldown`; tick decrements only the acting battler; a freshly-used ability is not double-ticked; `clear()` empties; usable again exactly when remaining hits 0.
2. **Turn submission (host path):** `request_process_turn` with a valid input produces the same `updates`/state a local `process_turn` did pre-refactor (golden compare against baseline `efa923c`).
3. **Authority guard:** a client submitting a turn for a battler whose turn it isn't is rejected by the host.
4. **Mapping integrity:** `Global.ACTIVE_ABILITIES` after removal lists exactly the `.tres`-derived entity abilities; `_validate_kit_abilities()` passes; Brian C. resolves Basic/Skill/Charged/Burst.
5. **Broadcast/render:** a client mirror reflects host `current_turn`, `turn_no`, and `cooldowns` after a turn; dropdown shows correct "N turns left"/disabled states from the broadcast.
6. **Smoke (manual + headless launch):** host + client battle: act, cooldown counts down on the actor's own turns only, battle ends host-authoritatively; offline battle works end to end.

## Risks & Rollback

- **Risk:** broadcast/echo ordering causes a client to render stale turn/cooldown. Mitigate with reliable RPC + monotonic `turn_no` guard on the client mirror.
- **Risk:** offline mode (host == local) must keep working; every host path must also be the offline path.
- **Risk:** scope is the combat core; regressions are high-impact. Mitigation: phased, each phase smoke-tested; full work on `battle-host-authority`.
- **Rollback:** `git reset --hard Genshin-DnD-Client/master` (baseline `efa923c`) restores the current working state at any time.

## `@rpc` / Multiplayer Notes (universal rule #4)

- `request_process_turn` is `@rpc("any_peer","reliable","call_remote",1)` (client → host=peer 1), mirroring `request_update`.
- The battle-state broadcast is `@rpc("authority","reliable")` (host → clients), mirroring `_receive_field_updates`/`broadcast_battle_summary`.
- Every new state-mutating function carries an inline `@rpc` migration comment documenting decoration + call-site change.

## File Manifest

- `Singletons/NetworkManager.gd` — `request_process_turn`, battle-state broadcast + receiver.
- `Scripts/managers/battle_manager.gd` — activation, ownership, `cooldowns` + helpers, `process_turn` host entry, broadcast assembly.
- `Scenes/BattleScene.gd` — `_on_end_turn_pressed` (send input vs host-run), drop UI-based `_advance_turn`, render from broadcast/mirror.
- `Scripts/battle/turn_processor.gd` — cooldown via BattleManager; host-run only.
- `Scripts/battle/battler_state.gd` — cooldown source = BattleManager.
- `Scripts/resources/ability_data.gd` — drop `ability_cooldown`, `active_ability_id`.
- `Singletons/Global.gd` — `ACTIVE_ABILITIES` getter, table lists, `BattlerData`/`BATTLEENEMIES` getters.
- `Singletons/GameDB.gd` — re-key `build_active_abilities_table`; trim validation.
- `Singletons/DataStore.gd`, `Singletons/CanonicalSave.gd` — remove `Active_Abilities`.
- `Scripts/resources/active_ability.gd` — delete if unused.
- `test/` — GdUnit4 cooldown + turn-submission tests.
