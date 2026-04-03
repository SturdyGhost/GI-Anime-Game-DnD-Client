# Brian's Notes Backup on Exit

## Summary

When Brian F. closes the game client, intercept the close and prompt him to select his Word document notes file. The client reads the file, sends it over RPC to the host (DM), who saves it locally. The client only quits after host confirmation.

## Trigger Conditions

- `Global.ACTIVE_USER_NAME == "Brian F."`
- Client is closing via either:
  - The in-game exit button in `player_hub.gd`
  - The OS window close (X button)
- All other players get the existing quit confirmation dialog, unchanged.

## Popup UI

Built dynamically in code (matching existing pattern from `artifact_detail_scene.gd` — ColorRect overlay + PanelContainer + styled controls).

Layout (top to bottom):
1. **Label**: "Have you remembered to save the notes file?"
2. **HBoxContainer**: LineEdit (filepath, read-only) + "Browse" Button
3. **HBoxContainer**: "Cancel" Button + "Confirm and exit" Button

Behavior:
- **Browse** opens a `FileDialog` filtered to `*.doc;*.docx`, starting at the user's Desktop directory (`OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)`)
- **LineEdit** is pre-populated with Brian's last-used path if saved (from `user://brian_notes_path.cfg`)
- **Confirm and exit** is disabled unless the LineEdit contains a path to a file that exists (`FileAccess.file_exists()`)
- **Cancel** closes the popup without quitting (returns to game)

## File Transfer Flow

1. Brian clicks "Confirm and exit"
2. Client disables the confirm button (prevents double-click), shows "Sending..." feedback
3. Client reads the file as `PackedByteArray` via `FileAccess`
4. Client calls `NetworkManager.send_notes_file.rpc_id(1, filename, file_bytes)` (peer 1 = host)
5. Host receives, saves to `user://notes_backups/<filename>` (creates directory if needed)
6. Host calls `NetworkManager.notes_file_received.rpc_id(sender_peer, true)` as acknowledgment
7. Client receives ack → saves Brian's chosen path to `user://brian_notes_path.cfg` → calls `get_tree().quit()`

If the ack doesn't come (timeout/error), show an error message in the popup and re-enable the confirm button so Brian can retry.

## Project Settings Change

In `project.godot`, set `auto_accept_quit = false` so `NOTIFICATION_WM_CLOSE_REQUEST` can be intercepted. This affects all players but the `_notification` handler in `player_hub.gd` only shows the backup popup for Brian; everyone else gets the normal quit confirmation.

## Files to Modify

1. **`project.godot`** — Add `auto_accept_quit = false`
2. **`Scenes/player_hub.gd`** — Add `_notification()` handler, modify `_on_exit_button_pressed()`, add popup creation/management methods
3. **`Singletons/NetworkManager.gd`** — Add `send_notes_file` and `notes_file_received` RPCs

## Path Persistence

- Config file: `user://brian_notes_path.cfg`
- Format: `ConfigFile` with section `[notes]`, key `path`
- Loaded on popup creation, saved after successful transfer
- If the persisted path no longer points to an existing file, still show it in the LineEdit but keep confirm disabled (Brian can see what path he used last and re-browse)

## Edge Cases

- **File too large**: Word docs are typically small (< 1MB). No size limit enforced initially.
- **Brian quits from a scene other than player_hub**: The `_notification` handler needs to be on an autoload or the main scene tree. Since `player_hub` is the main gameplay scene, and the exit button is there, this covers the primary case. If Brian is in the lobby, the normal quit behavior applies (no notes backup needed since the game hasn't started).
- **Host disconnected**: RPC will fail. The timeout/error path handles this — Brian sees an error and can choose to cancel and quit normally.
