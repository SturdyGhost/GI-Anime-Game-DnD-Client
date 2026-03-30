---
title: Artifact Generation System
date: 2026-03-29
tags: [feature, dm-tools, artifacts, rng]
scope: DMHub.gd
status: complete
---

# Artifact Generation System

## Overview

Artifacts are randomly generated based on player dice rolls at the table.
The DM enters the roll results into the UI and the system computes + creates
the artifact record.

## Location

Party Management tab in DMHub. Appears when "Artifacts" is selected in the
category dropdown. Hides the normal quantity/specifics controls.

## UI Layout

1. **Two artifact set dropdowns** — populated from all unique set names in game data
2. **Piece Determination** (3 dice inputs):
   - D10: Which set (1-5 = Set 1, 6-10 = Set 2)
   - D12: Piece type (1-3 Flower, 4-6 Feather, 7-8 Sands, 9-10 Goblet, 11-12 Circlet)
   - D20: Substat count (13+ = two substats, <13 = one substat)
3. **Substat 1** (3 dice inputs):
   - D8/D10: Stat type (see mapping below)
   - D12: Sign (7+ = positive, <7 = negative)
   - D20: Value (multiplied by 0.1)
4. **Substat 2** (same as Substat 1, only visible when D20 >= 13)
5. **Generate button** + status label

## Stat Type Mapping

### Flower of Life / Feather of Death (D8)
| Roll | Stat |
|------|------|
| 1-2 | Health |
| 3-4 | Attack |
| 5-6 | Defense |
| 7-8 | Elemental_Mastery |

### Sands of Time / Goblet of Space / Circlet of Principles (D10)
| Roll | Stat |
|------|------|
| 1-2 | Health |
| 3-4 | Attack |
| 5-6 | Defense |
| 7-8 | Elemental_Mastery |
| 9-10 | Unique (see below) |

### Unique Stats by Piece
| Piece | Unique Stat |
|-------|-------------|
| Sands of Time | Energy_Recharge |
| Goblet of Space | Universal_Added_Damage_Bonus |
| Circlet of Principles | Critical_Damage |

## Value Calculation

```
stat_value = sign * D20_roll * 0.1
sign = +1 if D12_roll >= 7, else -1
```

## Record Created

Inserted into `Character_Artifacts` with:
- Artifact_Set, Owner, Type (piece name), Equipped = false, Rarity = 5
- Stat_1_Type, Stat_1_Value (always present)
- Stat_2_Type, Stat_2_Value (only if D20 >= 13 in piece determination)

## Example

Rolls: Set D10=4, Type D12=7, Substats D20=12, Stat1 D10=1 D12=5 D20=12, Stat2 D10=10 D12=8 D20=10

Result: Sands of Time from Set 1, two substats:
- Health: -1.2 (negative from D12=5, value 12*0.1=1.2)
- Energy_Recharge: +1.0 (unique from D10=10, positive from D12=8, value 10*0.1=1.0)
