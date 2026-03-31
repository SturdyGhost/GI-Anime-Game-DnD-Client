---
title: Effect Processor Wired into Combat
date: 2026-03-30
tags: [feature, combat, effects, networking]
scope: Global.gd, effect_processor.gd, player_hub_mid_battle.gd, enemy_hub_mid_battle.gd, Player_Battle_Scene.gd, Enemy_Battle_Scene.gd, party_member_template.gd, enemy_card_template.gd
status: complete
---

# Effect Processor Wired into Combat

## Overview

The universal effect system (GameEffect/EffectProcessor/EffectState) is now the
single authority for all combat effects. Runs host-only, syncs to all clients.

## Battle Lifecycle

### Battle Start
- `Global.start_battle_effects(battler_data)` called from `set_battlers()` (player)
  and `_build_battlers()` (enemy scene), host-only
- Registers all battlers with their effects:
  - Characters: weapon effects (WeaponEffects), artifact set bonuses (ArtifactEffects),
    ability effects (AbilityEffects)
  - Companions/Enemies: ability effects (future-proofed for gear)
- Serializes and broadcasts to all clients via `sync_active_effects()`

### During Turns
- **Turn start**: `on_turn_start(battler_name, context)` fires START_OF_TURN effects
- **Damage**: `sum_flat_damage()` + `damage_multiplier()` for ON_HIT and ON_CRIT
- **Reactions**: `process_trigger("ON_REACTION")` applies reaction damage bonuses
- **Status application**: Uses `StatusEffectsMap.get_effects()` -> `add_effect()` on
  target instead of DB inserts into Active_Status_Effects
- **Turn end**: `on_turn_end(battler_name)` ticks durations for THAT battler only

### Battle End
- `Global.end_battle_effects()` clears processor and synced data
- Broadcasts empty ActiveEffects to clients

## Network Sync

Active effects serialized to `_synced["ActiveEffects"]` as:
```
{ battler_name: [ { source_type, source_name, effect_type, effect_stat,
  trigger, description, value, turns_remaining, stacks, max_stacks,
  target, element } ] }
```

Special handling in `_apply_update_to_save`: `table=="ActiveEffects"` with
`field=="_all"` replaces the entire dict.

## Effects Display (3 locations)

1. **Battle cards** (party_member_template, enemy_card_template):
   - "X effect(s)" label with tooltip showing all active effects
   - Reads from `Global.get_battler_effects(battler_name)`

2. **Mid-battle popup** (player_hub_mid_battle, enemy_hub_mid_battle):
   - StatusEffectList now reads from processor synced data
   - Shows source, type, duration, stacks, description per effect

## Serialization (effect_processor.gd)

Added `serialize_all()` and `serialize_battler()` methods that convert
active EffectStates to display-friendly dicts for network transmission.
