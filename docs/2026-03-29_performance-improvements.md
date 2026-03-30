---
title: Client Load Performance Improvements
date: 2026-03-29
tags: [performance, networking, ui]
scope: Global.gd, player_hub.gd, NetworkManager.gd
status: complete
---

# Client Load Performance Improvements

## Problem

When the host clicked "start game", clients froze for ~60 seconds before the player_hub
became responsive.

## Root Causes

### 1. `data_load_complete` fired on every table (13+ times)
`_process_table()` emitted `data_load_complete` after every single table was stored.
During initial sync of 13 tables, this signal fired 13+ times. `player_hub._on_data_load_complete`
connected to this signal and called `set_ui()` each time — rebuilding all stat buttons,
artifact displays, portraits, etc. 13+ times during load.

**Fix:** Removed `emit_signal("data_load_complete")` from `_process_table()`. The signal
now only fires from:
- `NetworkManager` line 88: after host finishes loading all data
- `NetworkManager` line 333: after client finishes receiving all tables
- `Global.Refresh_Data()`: after explicit data refresh
- `Global._apply_record_update()`: after single-record updates
- `NetworkManager._receive_field_updates()`: after delta sync

### 2. `_ready()` ran expensive setup before data existed
`player_hub._ready()` called `set_ui()`, `role_check()`, `restore_health()`, and
`Market.Refresh_Stock()` synchronously. On a client, data hadn't been synced yet, so
these either crashed or did wasted work — then ran AGAIN when `data_load_complete` fired.

**Fix:** All setup moved to `_try_initial_setup()`:
- Guards on `_initial_setup_done` flag (runs once)
- Guards on `Global.CHARACTERS_NAME.has(ACTIVE_USER_NAME)` (data must exist)
- `_on_data_load_complete` triggers it if not yet done; otherwise just refreshes `set_ui()`
- `Market.Refresh_Stock()`, luck popup, `restore_health()` only run once during initial setup

### 3. Full table re-broadcast on every field change
`host_update_records()` and `request_update()` called `broadcast_table_update()` which
serialized and sent the entire Characters table (all players, all fields) for a single
field change.

**Fix:** Replaced with `broadcast_field_updates()` which sends only the changed fields
as a small JSON array. Clients apply each field individually via `_apply_update_to_save()`.

## Result

- Initial sync: 1 `data_load_complete` instead of 13+
- Scene load: setup runs once when data is ready, not before
- Field updates: send bytes instead of kilobytes per change
