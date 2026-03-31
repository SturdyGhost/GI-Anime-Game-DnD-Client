---
title: Auto-Reconnect, Hub Loading Performance, Market Threading
date: 2026-03-30
tags: [networking, performance, bugfix]
scope: NetworkManager.gd, player_hub.gd, Market.gd, daily_luck.gd, player_hub_loading.gd
status: complete
---

# Auto-Reconnect, Hub Loading, Market Threading

## Client Auto-Reconnect

### Problem
No `server_disconnected` handler existed. When clients lost connection to host
(e.g., during battle-end transition), they silently died and RPCs stopped working.

### Solution
- Connected `multiplayer.server_disconnected` signal in NetworkManager._ready()
- On disconnect: auto-reconnect attempts (5 tries, 3s timeout each) to saved host IP/port
- Host sends full table sync to reconnecting peers via `_send_full_sync_to_peer()`
- Saved `_last_host_ip`/`_last_host_port` during `join_game()`

## Reconnect Popup in Player Hub

### Problem
Clients loaded player_hub before reconnection completed, showing stale data.

### Solution
- `_try_initial_setup()` checks `NetworkManager.is_connected_to_host` before proceeding
- If disconnected: shows "Reconnecting to host..." panel overlay
- Polls every 0.5s until connection restored, then continues setup

## Background Image After Battle

### Problem
Region background didn't update when returning from battle.

### Solution
- `set_background()` now called in both `_try_initial_setup()` and `_on_data_load_complete()`

## Market Performance

### Lookup Caches
- `_item_value_cache`: item_name -> value (was O(n) per lookup, now O(1))
- `_weapon_recipe_cache`: weapon_name -> recipe (was O(recipes) per weapon, now O(1))
- Both built once at start of `Refresh_Stock`

### Background Thread
- `Market.Refresh_Stock()` now runs entirely on a background `Thread`
- All generation (weapons, artifacts, consumables, gems, artisan, blacksmith,
  sorting, price variance) happens off the main thread
- Main thread returns immediately — no UI freeze
- Emits `stock_ready` signal when complete via `call_deferred`
- Guard prevents double-generation if called while already running
- Thread-safe: reads from Global dicts, writes to local Stock arrays

### Double Progress Bar Fix
- `player_hub_loading.gd` incremented `Tables_Processed` twice per table
  (once in `_on_table_loaded` and again in `update_progress_bar`)
- Removed duplicate increment

## Beacon Interval
- Reduced from 2.0s to 0.5s for faster host discovery when multiple
  players join simultaneously

## Enemy Health Fix
- `enemy_line_item.gd`: `hp_per_phase=0` was not treated as unset
- Old: null check passed for 0, used 0 HP -> clamped to 1
- New: checks `int(hpp) > 0` before using hp_per_phase, falls back to
  phase-specific HP (e.g., phase1_hp=50)
