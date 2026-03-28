# ENet Multiplayer Migration

**Branch:** `rebuild/enet-multiplayer`
**Date:** 2026-03-28
**Version:** 0.1.0-enet

## Summary

Replaced the entire HTTP API + PostgreSQL backend architecture with peer-to-peer ENet multiplayer. The DM hosts the game session locally, players connect via LAN discovery or direct IP. All game data is stored as local JSON files on the host machine. No external server or database required.

## What Changed

### New Architecture

| Before | After |
|--------|-------|
| Flask API server (`api.mydndbackend.party`) | No server needed |
| PostgreSQL database | Local JSON files (`res://data/`) |
| HTTP polling every 100ms | ENet RPC push updates |
| Email-based login | Host/Join lobby with character selection |
| Stateless REST calls | Persistent peer-to-peer connections |

### Data Flow

- **Host (DM):** Loads JSON from disk on startup. All mutations save to disk and broadcast deltas to connected players via RPC.
- **Players:** Receive full data sync on connect. Send change requests to host via RPC. Host validates, saves, and broadcasts the update to all peers.
- **Sync model:** Only changed tables are broadcast, not full state. Saves happen per-change, only for affected files.

### New Files

| File | Purpose |
|------|---------|
| `Singletons/DataStore.gd` | JSON file I/O. Host reads/writes `user://data/`, falls back to bundled `res://data/` |
| `Singletons/NetworkManager.gd` | ENet server/client, UPNP port forwarding, UDP LAN discovery, RPC sync, pause-on-disconnect |
| `Scenes/Lobby.tscn` + `lobby.gd` | Host/Join UI with waiting room. Replaces login screen |
| `data/*.json` (27 files) | Full database export: all 23 game tables + logs + research + dev |

### Modified Files

| File | Changes |
|------|---------|
| `Singletons/Global.gd` | Removed: `API_BASE`, all `HTTPRequest` code, polling timer, stale-data guards, `_check_modified_batch`, `_on_*_response` callbacks. Added: network-aware `Update_Records`/`Insert`/`Remove_Record` (host saves+broadcasts, client sends RPC), local mutation helpers (`_apply_local_update`, `_insert_record`, `_remove_record`), `_get_dict_for_table`, robust `_process_table` with type guards |
| `Singletons/ResearchAPI.gd` | Rewritten from HTTP endpoints to local JSON via DataStore |
| `Scenes/player_hub.gd` | Removed polling timer setup and HTTP `_check_characters_update` |
| `Scenes/DMHub.gd` | Removed polling timer setup, fixed z_index overflow (10000 -> 4096) |
| `Scenes/player_hub_loading.gd` | Loads from DataStore instead of API. Mostly bypassed now since lobby loads data before navigating |
| `Scenes/player_hub_mid_battle.gd` | Removed polling timer setup and HTTP check |
| `Scenes/enemy_hub_mid_battle.gd` | Removed polling timer setup and HTTP check |
| `Scenes/settings_popup.gd` | Shows connection info instead of server URL config |
| `project.godot` | Added `DataStore` and `NetworkManager` autoloads. Main scene changed to `Lobby.tscn` |
| `.gitignore` | Added `!*.json` to track data files |

### Removed Dependencies

- Flask backend server (`api.mydndbackend.party`)
- PostgreSQL database
- All HTTP request infrastructure
- Email-based authentication
- Server-side polling for changes

## Lobby Flow

### Hosting (DM)
1. Click "Host Game (DM)"
2. Automatically selects Chase as DM character
3. Data loads from local JSON files
4. ENet server starts on port 7777
5. UPNP attempts auto port forwarding
6. UDP beacon broadcasts on LAN every 2 seconds
7. Waiting room shows connected players
8. Click "Start Game" to begin (RPCs all clients)

### Joining (Player)
1. Click "Join Game (Player)"
2. Select your character from the list
3. Either pick a discovered LAN host or enter IP manually
4. Click "Connect"
5. Receive full data sync from host (chunked per table)
6. Enter waiting room, see who else is connected
7. Wait for host to click "Start Game"

## Networking Details

- **Protocol:** ENet (Godot built-in `ENetMultiplayerPeer`)
- **Port:** 7777 (game), 7778 (LAN discovery)
- **UPNP:** Attempts automatic port forwarding for internet play
- **LAN Discovery:** UDP broadcast beacon with game name and player count
- **Disconnect handling:** Game pauses until the disconnected player reconnects
- **RPC channels:** All RPCs are `reliable`. Authority RPCs for host->client sync, `any_peer` RPCs for client->host requests.

## Data Files

All 27 tables exported from PostgreSQL to `data/` directory:

**Game tables (23):** Abilities, Active_Abilities, Active_Status_Effects, Artifacts, BattleEnemies, Character_Artifacts, Character_Items, Character_Weapons, Characters, Companions, Constellations, Crafting_Recipes, Enemies, Game_Config, Items, Material_Caches, Minigames, Minigames_Results, Party, Reactions, Status_Effects, Talents, Weapons

**Log/system tables (4):** battle_log, log, Development, research_sessions

## Bug Fixes During Implementation

1. **`total_records` Nil crash** — Variable was uninitialized, caused `Nil + int` when processing tables
2. **UPNP mapping crash** — Called `add_port_mapping` on wrong object. Now calls on device with null guards
3. **Game_Config parsing crash** — Records stored as `key->value` strings broke `get_table_as_array`. Now stores full record dicts keyed by id
4. **Gray screen after Start** — Loading screen had nothing to trigger since data was already loaded. Lobby now navigates directly to hub
5. **z_index overflow** — DMHub suggest panel used 10000, max is 4096
6. **Uninitialized stat variables** — `Current_Health`, `Current_Attack`, etc. were Nil. Initialized to 0.0
7. **`_process_table` crash on missing id** — Added type + `.has("id")` guard to every record loop
