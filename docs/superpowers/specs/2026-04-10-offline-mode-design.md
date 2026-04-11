# Offline Mode Design

## Problem

When connectivity issues prevent players from connecting to the host, the entire client is bricked and useless. There is no fallback — it's all or nothing. Players and the DM need a way to continue playing locally when the network isn't cooperating, with changes merging automatically when everyone reconnects in a future session.

## Solution Overview

An explicit offline mode activated from the lobby via a "Play Offline" button. The client uses a local save snapshot (auto-saved on each successful sync, with a bundled default for first-time use) to provide a functional experience. Players manage their own character — equipment, items, gathering, market, region. The DM manages battles — enemy setup, turn processing, battle history. On reconnect, each client submits its offline changes to the host, who applies them without conflict thanks to a clean ownership partition.

## Offline Mode Activation

### Entry Points

- **"Play Offline" button in the lobby** — new button alongside "Host Game (DM)" and "Join Game (Player)". This is the only way to enter offline mode. No auto-detection from failed connections.
- **Players** click it, select their character (same flow as joining), then enter the hub in offline mode.
- **DM** clicks it, skips character selection, enters DM Hub in offline mode.

### Disconnect While Online

- If the connection drops mid-session and reconnect fails, the client returns to the lobby. From there the player can try to reconnect or choose to go offline. No auto-reconnect loop from the hub or battle scenes.

### Offline is Sticky

- Once in offline mode, the client stays offline. No background reconnect attempts, no prompts to go online. Local play continues until the user deliberately returns to the lobby and chooses to connect in a future session.

## Local Data Storage

### Auto-Snapshot

Every successful full sync writes the current `_synced` dictionary to `user://last_sync.json`. This happens silently after the `all_data_received` signal fires. This file represents the most recent known-good state from the host.

### Bundled Default

The project ships with `res://data/default_sync.json` — a baseline save built from the current session's data. This is the fallback when no `user://last_sync.json` exists (first-time use or fresh install). This file is committed to the repo and updated as needed.

### Offline Changes Log

During offline play, all mutations are appended to `user://offline_changes.json` — a structured log of what changed:

```json
[
  {
    "table": "Character_Weapons",
    "record_id": "12",
    "action": "insert",
    "data": {"Name": "Skyward Blade", "Owner": "3", "Equipped": true},
    "timestamp": "2026-04-10T19:30:00"
  },
  {
    "table": "Character_Artifacts",
    "record_id": "5",
    "action": "update",
    "field": "Equipped",
    "old": false,
    "new": true,
    "timestamp": "2026-04-10T19:31:00"
  },
  {
    "table": "Characters",
    "record_id": "3",
    "action": "update",
    "field": "Region",
    "old": "Mondstadt",
    "new": "Liyue",
    "timestamp": "2026-04-10T19:35:00"
  },
  {
    "table": "Character_Weapons",
    "record_id": "8",
    "action": "delete",
    "timestamp": "2026-04-10T19:40:00"
  }
]
```

Actions: `insert` (new record), `update` (field change), `delete` (record removal).

### Loading Priority

When entering offline mode, the client loads data in this order:
1. `user://last_sync.json` (most recent successful sync)
2. `res://data/default_sync.json` (bundled default — always available)

The loaded data populates `Global._synced` and `CharacterManager.recalculate_all()` runs normally.

## Player Offline Experience

### What Works As-Is

- **Player Hub** — renders from `_synced`, works without changes
- **Equipment swapping** — swap weapons/artifacts between owned items
- **Gathering** — resource collection
- **Market** — buy/sell from shops
- **Companion kit viewer** — read-only reference
- **Other players' data** — visible (read-only from local save) but potentially stale

### New: Management Sub-Panel (Offline Only)

A new panel accessible only in offline mode that gives players self-service control over their own character:

- **Add/Remove Weapons** — pick from the full GameDB weapon list, add to inventory or remove owned ones
- **Add/Remove Artifacts** — pick from the full GameDB artifact list
- **Add/Remove Items** — pick from the full GameDB items list
- **Edit Mora** — adjust their own mora balance

This mirrors the DM Hub's first tab but scoped to only the player's own character. Hidden when connected online (host authority handles this normally).

### What's Editable

- **Region** — editable locally, saves to offline changes log

### What's Disabled

- **Combat / Turn Order button** — fully disabled (greyed out or hidden). DM manages all combat.

## DM Offline Experience

### What Works

- **Battle prep tab** — add enemies from GameDB, configure enemy instances
- **Table editor** — direct edit of local save data
- **Full battle management:**
  - Add enemies to battle
  - Start battle
  - Input each player's turns manually (ability used, target, etc.)
  - Turn processor runs locally, calculates damage/effects/reactions
  - Battle progresses and ends normally — health, status effects, KOs, battle summary
  - Battle history/results saved locally

### What's Disabled

- **First tab (item management)** — disabled in offline mode. Players self-manage their own inventory/equipment. DM should not be making changes that can't be broadcast.

## Data Ownership Partition

Clean separation ensures no conflicts during merge:

### Player Owns (their character only)

| Table | Scope |
|-------|-------|
| Characters | Own character's Region field |
| Character_Weapons | Own character's weapons (add/remove/equip) |
| Character_Artifacts | Own character's artifacts (add/remove/equip) |
| Character_Items | Own character's items (add/remove/quantity) |
| Companions | View only (kit reference) |

### DM Owns (everything else)

| Table | Scope |
|-------|-------|
| BattleEnemies | Full control (add/remove/configure) |
| Party | Turn order, current turn, party-level state |
| Active_Abilities | Battle state |
| Active_Status_Effects | Battle state |
| Minigames_Results | If applicable |
| Game_Config | Settings |

### No Overlap

- Battle results are self-contained and temporary — they don't mutate player stats/health in a way that overlaps with player-side equipment/inventory changes
- Battle history syncs as new records added by the DM, not edits to player data
- Player equipment/inventory changes are authoritative for their own character
- DM battle data is authoritative for battle records

## Merge & Reconnect Flow

### Player Side

1. Player connects to host normally from the lobby
2. During the connection handshake (before receiving full sync), the client checks for `user://offline_changes.json`
3. If offline changes exist, client sends them to the host via new RPC: `_submit_offline_changes.rpc_id(1, player_name, changes_json)`
4. Client waits for host acknowledgment before proceeding with normal full sync

### Host Side

1. Host receives offline changes from each player as they connect
2. Ownership partition guarantees no conflicts — each player only changed their own data
3. Host applies each player's changes to the host save
4. Host persists the merged state via `DataStore.persist_table()`
5. Normal full sync broadcasts the merged state to all connected clients
6. All clients now have the unified, up-to-date save

### DM Side

- DM's changes are already in the host save (SaveManager writes locally during offline play)
- Battle results from offline sessions are already persisted
- No merge step needed for DM — they are the host

### Post-Merge Cleanup

- `user://offline_changes.json` is cleared on the client after successful merge acknowledgment
- `user://last_sync.json` gets updated with the fresh full sync
- Everyone is back in sync

## UI Changes

### Lobby

- New **"Play Offline"** button (alongside Host/Join buttons)
- Clicking it follows the character selection flow (for players) then enters offline hub

### Hub Status Indicator

- A persistent label showing **"Offline"** when in offline mode
- Connected mode shows nothing — online is the default state

### Disabled Elements

- **Players (offline):** Combat/turn order button disabled or hidden. Management sub-panel visible.
- **Players (online):** Management sub-panel hidden. Normal host-authority flow.
- **DM (offline):** First tab (item management) disabled. Battle and table editor work normally.
- **DM (online):** Everything works normally.

## Global / NetworkManager Changes

- `Global.is_offline: bool = false` — set when entering offline mode
- `Global.Update_Records()` checks `is_offline`:
  - If true: applies changes locally to `_synced` and appends to `user://offline_changes.json`
  - If false: existing RPC flow (unchanged)
- NetworkManager connection state exposed for lobby/hub to react
- New RPC: `_submit_offline_changes` (client → host) and `_ack_offline_changes` (host → client)
- Auto-snapshot logic added to the full sync completion handler

## File Manifest

| File | Change |
|------|--------|
| `res://data/default_sync.json` | New — bundled baseline save from current session |
| `Singletons/Global.gd` | `is_offline` flag, offline mutation path in `Update_Records()`, auto-snapshot on sync |
| `Singletons/NetworkManager.gd` | `_submit_offline_changes` / `_ack_offline_changes` RPCs, remove auto-reconnect from hub |
| `Scenes/lobby.gd` + `Lobby.tscn` | "Play Offline" button, offline entry flow |
| `Scenes/player_hub.gd` | Offline indicator, disable combat button, show management sub-panel |
| `Scenes/dm_hub.gd` (or equivalent) | Offline indicator, disable first tab |
| New: `Scenes/UI/offline_management_panel.tscn` + `.gd` | Player self-service panel (add/remove weapons/artifacts/items) |
