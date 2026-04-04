# Battle Turn Focus Alert

## Summary

When it's a player's turn to act in battle (their character, their companion, or enemy turn for host) and the window doesn't have focus, bring the window to the foreground. If the player still hasn't interacted (mouse hasn't moved) after 5 seconds, flash the screen red 1-2 times.

## Trigger

In `BattleScene._update_dock_visibility()`, after determining `should_show` is true:
- Check if the window has focus via `get_window().has_focus()`
- If not focused, restore/maximize and start the mouse-watch timer

## Two-Stage Behavior

### Stage 1: Immediate — Restore Window
- If window is minimized: `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)` to restore, then `DisplayServer.window_move_to_foreground()`
- If window is just unfocused (behind other windows): `DisplayServer.window_move_to_foreground()`
- Record `get_viewport().get_mouse_position()` as the baseline mouse position

### Stage 2: Delayed (5s) — Conditional Flash
- After 5 seconds, check current mouse position against baseline
- If mouse has NOT moved: flash the screen red twice
- If mouse has moved at all: do nothing (player is aware)

## Flash Effect

- Full-screen ColorRect (red, semi-transparent) added to the scene root at high z_index
- Tween: fade alpha from 0 → 0.3 → 0 twice (two pulses), then `queue_free()` the overlay
- Total flash duration ~1.5 seconds (two quick pulses)

## Guard Against Spam

- Track whether a focus alert is already pending (boolean flag) to avoid re-triggering on every `_update_dock_visibility()` call during the same turn
- Reset the flag when the turn changes (new `Current_Turn` value)

## Files to Modify

1. **`Scenes/BattleScene.gd`** — Add focus check in `_update_dock_visibility()`, add flash effect method, add mouse tracking variables and timer

## Edge Cases

- Player alt-tabs back within 5 seconds and moves mouse: no flash (correct)
- Multiple `_update_dock_visibility()` calls during same turn: guard flag prevents repeat alerts
- Window already focused: no action taken
