# Pending Changes

## UI Style Fixes

- [x] **Player Inventory — "Give" button**: Updated to match artifact style (dark bg, gold text, border).
- [x] **Weapon Detail — buttons**: Updated non-primary buttons to match artifact_detail style.

## Battle Screen

- [x] **Attack info tags — panel overflow**: Changed HBoxContainer to HFlowContainer so tags autowrap within panel size.
- [x] **My Stats panel — Crit DMG and ER display**: Removed percentage suffix, now shows raw values.
- [x] **My Stats panel — Burst display**: Now shows `current / max` where max = highest burst cost ability.
- [x] **DM enemy turn — screen goes grey**: Replaced transparent Window with inline overlay for damage breakdown panel. Added proper dark background and mouse blocking.

## Offline Mode

- [x] **Manage Inventory scene — sizing**: Replaced Window wrapper with direct child overlay (same fix as damage breakdown).
- [ ] **Manage Inventory — search broken**: Likely was invisible due to quarter-screen sizing. Needs testing after sizing fix. If still broken, GameDB loading in export builds may need investigation.
- [x] **Manage Inventory — artifact selection**: Added artifact detail fields (slot type, stat1, stat2) that appear when Artifacts category is selected.
- [x] **Brian C. region defaulting to Inazuma**: Fixed `calculate_all_stats()` to prefer synced snapshot over stale .tres files in offline mode. Also fixed region field name from "Region" to "Current_Region" in offline panel.
