---
title: Artifact Set Count & Set Bonus Integration
date: 2026-03-29
tags: [feature, stats, artifacts]
scope: Global.gd, character_manager.gd
status: complete
---

# Artifact Set Count & Set Bonus Integration

## Problem

`Global.set_count` was referenced by `artifact_button.gd` and `stat_summary.gd` but
never defined. Accessing it crashed with "Invalid access to property or key 'set_count'".

Artifact set bonuses (2-piece and 4-piece) were calculated in `CharacterManager` for the
host path but not the client path.

## Solution

### `Global.set_count` (UI display)

Added as a computed property on Global for backward compatibility with existing UI code:

```gdscript
var set_count: Dictionary:
    get:
        var counts := {}
        for artifact in CHARACTER_ARTIFACTS.values():
            if artifact.get("Owner") == ACTIVE_USER_NAME and artifact.get("Equipped") == true:
                var sn = artifact.get("Artifact_Set", "")
                if sn != "":
                    counts[sn] = counts.get(sn, 0) + 1
        return counts
```

This is a display-only convenience. The actual stat bonuses are applied in CharacterManager.

### Set Bonuses in `_calculate_from_synced()` (client stat calc)

The client stat calculation path now counts artifact sets and applies bonuses:

1. While iterating artifacts for stat values, also builds `set_pieces` dict
2. For each set with 2+ pieces, queries `GameDB.get_artifact_bonus(set_name, bonus_type)`
3. Checks conditions (e.g., element match)
4. Adds `stat_modifier_value` to the relevant stat

This mirrors the existing `_calculate_from_resources()` host path.
