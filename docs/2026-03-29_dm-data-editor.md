---
title: DM Data Editor Tab
date: 2026-03-29
tags: [feature, dm-tools, ui, data-management]
scope: DMHub.gd, DMHub.tscn
status: complete
---

# DM Data Editor Tab

## Overview

New tab in DMHub that gives the DM direct edit access to any synced record.
Replaces the unused ActiveBattle and ResearchProgression tabs.

## Tab Structure (after cleanup)
- Tab 0: Party Management
- Tab 1: Battle Prep (default on load)
- Tab 2: Data Editor

## Features

### Record Browser
- **Table selector** dropdown: Characters, Companions, Party, Character_Weapons,
  Character_Artifacts, Character_Items, BattleEnemies, Active_Status_Effects, Game_Config
- **Record selector** dropdown: shows `id — Name` (or Weapon/Artifact_Set/Item as applicable)
- Records sorted numerically by ID

### Dynamic Field Editor
- Reads selected record from `_synced`, generates input controls per field type:
  - `CheckBox` for bools
  - `SpinBox` for ints (min -999999, max 999999)
  - `SpinBox` for floats (step 0.01)
  - `LineEdit` for strings
  - `LineEdit` with comma-separated parsing for Arrays
- `id` field is always read-only
- Fields sorted: id first, Name second, then alphabetical

### Actions
- **Confirm Changes**: builds `Update_Records` array with only changed fields,
  sends through standard host broadcast path
- **Revert**: restores all inputs to snapshot taken when record was loaded
- **New Record**: creates blank record using first existing record as field template,
  inserts via `Global.Insert()`, refreshes and selects the new record
- **Delete Record**: removes via `Global.Remove_Record()`, refreshes list
- **Status label**: shows feedback ("Saved 3 field(s)", "Reverted", "Deleted record 5", etc.)

### Type Preservation
- Reads original value type from `_synced` record
- SpinBox returns `int` if original was int, `float` if float
- LineEdit parses back to Array if original was Array
- String fields with numeric content parsed to int/float if original was int/float
