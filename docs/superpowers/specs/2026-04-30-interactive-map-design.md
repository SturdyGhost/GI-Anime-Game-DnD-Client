# Interactive Map — Design Spec

**Date:** 2026-04-30
**Replaces:** Research Button / ResearchPanel

## Overview

A full-screen modal map of Teyvat that replaces the Research button in the player hub. Players can pan, zoom, place colored markers with notes, and see each other's markers. Regions are fogged based on the party's ascension level.

## Map Source

Start with a bundled hi-res image (`res://UI/Map/teyvat_map.png`). Can be swapped for a web embed later. The image needs to be large enough to support zooming in to sub-region detail.

## Scene Structure

```
InteractiveMap (Control, FULL_RECT)
├── MapViewport (SubViewportContainer + SubViewport)
│   └── MapCamera (Camera2D with zoom/pan)
│       └── MapImage (Sprite2D — the teyvat map)
│       └── MarkerContainer (Node2D — holds all marker nodes)
│       └── FogContainer (Node2D — fog overlays per region)
├── Sidebar (PanelContainer, left side, ~260px)
│   ├── ShapePicker (HBoxContainer of TextureButtons)
│   ├── RegionList (VBoxContainer — click to jump to region)
│   └── PlayerLegend (VBoxContainer — color dots per player)
├── MarkerPanel (PanelContainer, right side, hidden by default)
│   ├── NoteEdit (TextEdit)
│   ├── SaveButton
│   └── DeleteButton
├── PlacementBanner (Label, top center, hidden by default)
├── ZoomControls (VBoxContainer, bottom-right: +, -, reset)
└── CloseButton (top-right)
```

Opens as a modal `Window` (same pattern as ResearchPanel in `player_hub.gd:_on_research_button_pressed`).

## Fog of War

Derived at runtime from ascension level. No persistence.

| Ascension | Region Unlocked |
|-----------|----------------|
| 0 (always) | Mondstadt |
| 1 | Liyue |
| 2 | Inazuma |
| 3 | Sumeru |
| 4 | Fontaine |
| 5 | Natlan |
| 6 | Nod Krai |
| 7 | Snezhnaya |

Each region has a predefined polygon (in map-image coordinates). Fog is a semi-transparent dark overlay drawn over locked regions. Locked regions show a lock icon centered on them.

Ascension is read from `Player_data.get("Ascension_Rank", 0)` — the same value already used in `player_hub.gd:765`.

## Markers

### Data Model

Each marker is a dictionary:
```gdscript
{
    "id": "uuid-string",          # unique ID
    "owner": "Chase",             # player name
    "position": Vector2(x, y),    # map-image coordinates
    "shape": "circle",            # one of: circle, diamond, star, triangle, square, cross
    "note": "Some text here",     # user note, can be empty
}
```

### Player Colors

Assigned deterministically from a fixed palette based on player index in the party. Colors are defined in the map script, not stored per-player.

```gdscript
const PLAYER_COLORS = [
    Color("#e84545"),  # red
    Color("#4589e8"),  # blue
    Color("#45e87a"),  # green
    Color("#e8c845"),  # gold
    Color("#c845e8"),  # purple
    Color("#45c8e8"),  # cyan
]
```

### Shapes

Six shapes drawn as simple vector icons (polygon/line draws, not textures): circle, diamond, star, triangle, square, cross. Each rendered in the owner's color with a thin white outline for visibility.

### Placement Flow

1. Player selects a shape from the sidebar picker (or it defaults to circle)
2. Placement banner shows at the top: "Click to place [shape] — Right-click to cancel"
3. Click on an unlocked region → marker created at that position
4. Marker panel opens immediately for the new marker so the player can add a note
5. Right-click or pressing Escape cancels placement mode

### Marker Interaction

- **Hover** → tooltip appears near cursor showing owner name + note preview (first ~50 chars)
- **Click own marker** → marker panel opens on the right with full note in a TextEdit, Save and Delete buttons
- **Click other player's marker** → panel opens read-only (no edit/delete)

## Persistence

### Local Save

Markers are stored in `SaveData` as a new field:

```gdscript
# In save_data.gd
@export var map_markers: Dictionary = {}
# Structure: { "player_name": [ { "id": ..., "position_x": ..., "position_y": ..., "shape": ..., "note": ... }, ... ] }
```

Position stored as `position_x` / `position_y` floats since `Vector2` doesn't serialize cleanly in `.tres` dictionaries.

### Save/Load in SaveManager

- `_sync_to_save()` — writes current markers to `data.map_markers`
- `_apply_overrides()` — reads `data.map_markers` into a runtime dictionary on the map scene
- `mark_dirty()` triggers disk save as usual

### Network Sync

Markers ride the existing save sync mechanism — `serialize_for_network()` / `deserialize_from_network()` already send the full `SaveData` including any new fields. When a client connects:

1. Host sends full save (already includes all players' markers)
2. Client applies and sees everyone's markers
3. When a client places/edits/deletes a marker, it sends an RPC to the host
4. Host updates its save data and broadcasts the updated markers to all clients

New RPCs in NetworkManager:

```gdscript
# Client → Host: send my updated markers
@rpc("any_peer", "reliable")
func _sync_markers_to_host(player_name: String, markers_json: String)

# Host → All: broadcast all markers
@rpc("authority", "reliable")
func _receive_markers_sync(all_markers_json: String)
```

### Offline Behavior

- Offline clients read/write markers to local save only
- When they reconnect, their markers are included in the sync
- Conflict resolution: per-player ownership means no conflicts — each player's array is authoritative for their own markers

## Navigation

### Pan & Zoom

- **Pan**: Click-and-drag on the map (not on markers/UI)
- **Zoom**: Mouse scroll wheel, or +/- buttons in bottom-right
- **Zoom range**: ~0.3x (see full map) to ~3.0x (zoomed in detail)
- **Bounds**: Camera clamped to map image bounds so you can't pan into empty space
- **Region jump**: Clicking a region name in the sidebar pans/zooms the camera to center on that region

### Close

Close button (top-right) or Escape key closes the map and returns to player hub.

## Button Wiring

In `player_hub.gd`:
- Rename "Research Button" to "Map" in `button_config` (line ~201)
- Change handler to `_on_map_button_pressed`
- New handler opens `InteractiveMap.tscn` in a modal Window (same pattern as current research button)

## Files to Create

| File | Purpose |
|------|---------|
| `Scenes/InteractiveMap.tscn` | Scene file with the full UI tree |
| `Scenes/interactive_map.gd` | Main script: pan/zoom, fog, marker management, sidebar |
| `UI/Map/teyvat_map.png` | Placeholder — user will supply the actual hi-res map image |

## Files to Modify

| File | Change |
|------|--------|
| `Scripts/save/save_data.gd` | Add `@export var map_markers: Dictionary = {}` |
| `Scripts/managers/save_manager.gd` | Add markers to `_sync_to_save()` and `_apply_overrides()` |
| `Singletons/NetworkManager.gd` | Add marker sync RPCs |
| `Scenes/player_hub.gd` | Rename Research → Map, change handler |

## Out of Scope

- Mini-map (can add later if wanted)
- Map tile streaming / web embed (future option)
- DM-only markers or marker permissions beyond own/others
- Custom marker colors (uses fixed palette by player index)

---

## Implementation Plan

### Phase 1: Data Layer

**Task 1.1 — SaveData field**
Add `map_markers` dictionary to `Scripts/save/save_data.gd`.

**Task 1.2 — SaveManager integration**
Add marker read/write to `_sync_to_save()` and `_apply_overrides()` in `save_manager.gd`. Add helper methods `get_map_markers()` and `set_map_markers(player_name, markers)`.

### Phase 2: Core Map Scene

**Task 2.1 — Scene + script skeleton**
Create `Scenes/InteractiveMap.tscn` and `Scenes/interactive_map.gd` with the scene tree described above. Use a placeholder colored rect for the map image initially.

**Task 2.2 — Pan & zoom**
Implement Camera2D-based pan (drag) and zoom (scroll wheel + buttons). Clamp to image bounds. Add zoom controls UI.

**Task 2.3 — Fog of war**
Define region polygons (hardcoded coordinates mapped to the map image). Draw fog overlays based on ascension level. Show lock icons on fogged regions.

**Task 2.4 — Region list sidebar**
Populate region list from the ascension mapping. Show lock/unlock status. Click to pan camera to that region.

### Phase 3: Markers

**Task 3.1 — Shape rendering**
Create a helper function that draws each of the 6 shapes as a simple Node2D with `_draw()` override, colored by owner.

**Task 3.2 — Placement flow**
Implement shape picker, placement mode banner, click-to-place on map, right-click cancel.

**Task 3.3 — Marker interaction**
Hover tooltip, click to open detail panel, edit note, save, delete. Read-only for other players' markers.

**Task 3.4 — Load/save markers**
Wire markers to SaveManager — load on map open, save on place/edit/delete.

### Phase 4: Network Sync

**Task 4.1 — Marker RPCs**
Add `_sync_markers_to_host` and `_receive_markers_sync` RPCs to NetworkManager.

**Task 4.2 — Sync flow**
Client sends markers to host on place/edit/delete. Host broadcasts merged set to all clients. Initial sync already handled by existing save sync.

### Phase 5: Integration

**Task 5.1 — Button wiring**
Replace Research button with Map button in player_hub.gd. Open InteractiveMap in modal Window.

**Task 5.2 — Placeholder map image**
Add a placeholder `UI/Map/teyvat_map.png` (can be a simple labeled rectangle) so the scene loads. User supplies real image later.
