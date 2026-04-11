# Battle Simulator Design

## Problem

Battles are fully manual — the DM calculates all dice rolls, damage formulas, and enters values into spinboxes. Players have no visibility into whether their damage was above or below average. There's no way to test encounter balance before playing, and no way for players to experiment with different loadouts without actually changing their equipment.

## Solution Overview

Four interconnected systems sharing a core battle engine:

1. **Shared Battle Engine** — Headless battle simulator with full damage formula, smart AI, effect system integration, and spatial distance model. Runs off-thread for bulk simulations.
2. **Post-Turn Damage Panel** — After every turn in real battles, shows the acting player what the system calculated as possible outcomes for each damage roll value. Purely informational.
3. **Player Hub Simulator** — Sandbox battle simulator accessible from the player hub. Test any encounter with loadout overrides (companion, weapon, artifacts, kit, food). Run 10–10,000 battles with comprehensive statistical results.
4. **DM Encounter Balancer** — Similar simulator on the DM hub focused on tuning enemy stats to match target difficulty tier profiles. Provides advisory suggestions for stat adjustments.

---

## Phase 1: Shared Battle Engine

### DiceRoller Utility

Static helper class for all dice operations.

**Core functions:**
- `roll(die_size: int) -> int` — Roll a single die (1 to die_size inclusive)
- `stat_to_dice(stat_value: float) -> Array[int]` — Map a calculated stat to dice sizes using the stat-to-dice table
- `roll_stat(stat_value: float) -> int` — Map stat to dice, roll all, return total
- `difference_to_damage_die(diff: int) -> Array[int]` — Map attack-defense difference to damage dice using the same table
- `roll_damage(diff: int, hits: int, flat_mods: float, mult_mods: float) -> int` — Full damage pipeline: difference to damage die, roll, apply flat mods, apply mult mods, multi-hit reduction, return total
- `roll_escalation(hp_budget: int) -> Dictionary` — Brian C.'s nature escalation chain. Returns `{damage: int, hp_spent: int, succeeded: bool}`
- `multi_hit_reduce(base_damage: int, hits: int) -> int` — Apply 1/3 reduction per successive hit (min 1), return total across all hits

**Stat-to-Dice table:**

| Stat/Difference | Dice |
|----------------|------|
| 1-3 | miss (0) |
| 4-5 | D4 |
| 6-7 | D6 |
| 8-9 | D8 |
| 10-11 | D10 |
| 12-19 | D12 |
| 20-23 | D20 |
| 24-25 | D20 + D4 |
| 26-27 | D20 + D6 |
| 28+ | D20 + D8, etc. |

### BattleSimEngine

Headless battle runner. No UI, no networking, pure logic. Thread-safe for bulk runs.

**Input config:**
```
{
  party: [
    {
      name: String,
      character_data: Dictionary,      # From _synced Characters
      weapon_override: Dictionary,      # null = use current equipped
      artifact_overrides: Array,        # null = use current equipped
      companion_override: Dictionary,   # null = use current
      kit_override: {element, weapon_type},  # null = use current
      food_buff: String                 # "None" or buff name
    }
  ],
  enemies: [
    {enemy_id: int, count: int}        # GameDB enemy ID + how many
  ],
  damage_modifier_players: float,       # Default 1.0
  damage_modifier_enemies: float,       # Default 1.0
  arena_size: int                       # Default 20
}
```

**Per-battle lifecycle:**
1. Clone all battler data from config (no mutation of real data)
2. Build battler states — stats, abilities, equipped gear, companions
3. Register effects — weapon effects, artifact set bonuses, ability passives, status effects
4. Place combatants — players at position 0, enemies at position `arena_size`
5. Determine turn order from party config
6. Loop turns until win or loss:
   a. Smart AI selects ability + targets for current battler
   b. Check spatial constraints — is target in range? Move if needed.
   c. Roll accuracy dice (stat-based, with additive/multiplicative effect mods)
   d. For each target: roll defense dice, compute difference
   e. If difference > 0: roll damage die, apply flat mods, mult mods, multi-hit reduction
   f. Apply side damage modifier (player or enemy)
   g. Route through effect triggers (ON_HIT, ON_CRIT, ON_REACTION, etc.)
   h. Apply damage to HP (respecting shields)
   i. Apply status effects from ability
   j. Manage cooldowns, burst charges
   k. Check for downs — trigger revive AI if needed
   l. Advance turn, tick effect durations
7. Determine outcome — win (all enemies dead), loss (all players/companions dead)

**Per-battle output:**
```
{
  outcome: "win" | "loss",
  total_rounds: int,
  per_battler: {
    name: {
      damage_dealt: int,
      damage_taken: int,
      damage_absorbed: int,
      healing_done: int,
      abilities_used: {ability_name: count},
      damage_per_ability: {ability_name: {total: int, uses: int}},
      times_downed: int,
      times_revived: int,
      times_reviving_others: int,
      deaths: int,
      crits: int,
      misses: int
    }
  },
  revives_used: int,
  items_used: int
}
```

**Bulk run output (aggregated across N battles):**
```
{
  battles_run: int,
  wins: int,
  losses: int,
  total_wipes: int,
  avg_rounds: float,
  min_rounds: int,
  max_rounds: int,
  per_battler: {
    name: {
      avg_damage_dealt: float,
      avg_damage_taken: float,
      avg_damage_absorbed: float,
      avg_healing_done: float,
      abilities: {ability_name: {avg_uses: float, avg_damage: float, total_damage: int}},
      total_downs: int,
      total_deaths: int,
      total_revives_given: int,
      total_revives_received: int,
      total_crits: int,
      total_misses: int
    }
  },
  avg_revives_per_battle: float,
  avg_items_per_battle: float,
  battles_with_zero_deaths: int,
  battles_with_perma_death: int,
  battles_all_revives_burned: int,
  damage_distribution: {name: float}  # Percentage of total damage per battler
}
```

### Spatial Model

Simplified distance-based positioning (not full grid).

- Each combatant has `position: float` (0 = player start, arena_size = enemy start)
- Distance between two = `abs(a.position - b.position)`
- Multi-tile enemies: `effective_distance = distance - floor(size / 2)` (larger enemies are easier to reach)
- Enemy `size` field is in their resource data (size N = NxN tile creature)

**Movement:**
- Per turn, can move up to movement allowance (default 7 for players, varies for enemies)
- AI moves toward optimal target if out of range
- Root status: prevents all movement
- Slow status: halves effective movement

**Range checks:**
- Melee/adjacent: effective distance <= 1
- Ranged: effective distance <= ability's `targeting_length`
- AoE: hits all combatants within `targeting_radius` of target position
- Melee enemy rooted out of range: cannot attack, wastes turn

### Smart AI

Priority-based decision making. Same logic framework for players and enemies with different priorities.

**Player AI priority (highest to lowest):**
1. **Revive** a downed ally (if have revive available and someone is down)
2. **Burst** if charges full and ability off cooldown — highest damage option
3. **Skill or Charged Attack** — whichever deals more expected damage, if off cooldown
4. **Basic Attack** — default combat action, provides mobility
5. **Move only** — last resort, full movement (7 tiles) toward nearest target

**Enemy AI priority:**
1. Use strongest available ability off cooldown
2. Target lowest HP player/companion
3. Prioritize finishing downed targets

**Target selection:**
- Damage abilities: target lowest HP enemy (players target enemies, enemies target players)
- Revive: target downed ally
- AoE: position to hit maximum targets
- Healing: target lowest HP ally

**Ability damage estimation:**
The AI estimates expected damage for each available ability using:
- Ability's dice_count and dice_die → average roll value
- Character's relevant stat (attack for physical, EM for elemental) → accuracy dice average
- Estimate defense average based on target tier
- Apply known flat/mult modifiers
- Factor in hits_count with multi-hit reduction
- Pick the ability with highest expected damage output

### Threading

- Single battles: run on main thread (fast enough)
- Bulk runs (100+): spawn a background `Thread`, collect results, emit `simulation_complete` signal
- Progress reporting: emit `simulation_progress(completed, total)` periodically for UI progress bar
- Cancellation: check `_cancel_requested` flag between battles

### Effect System Integration

The simulator creates its own `EffectProcessor` instance per battle (not the global one used in live battles). This ensures:
- No contamination of live battle state
- Thread safety for parallel simulations
- Full effect lifecycle: register → trigger → tick → expire

Effects integrated:
- Weapon effects (from WeaponEffects definitions)
- Artifact set bonuses (2pc/4pc from GameDB)
- Ability effects (from AbilityEffects definitions)
- Status effects (from StatusEffectsMap)
- Food buffs (mapped to effect definitions)
- Reaction effects (element interactions)

### Enemy Attack/Defense Dice

**Defense dice scale by tier:**
- Common: D12
- Uncommon: D16
- Rare: D16
- Epic: D20
- Boss: D20
- Legendary: D20

**Attack dice:**
- If an enemy ability specifies dice (dice_count/dice_die), use those
- If not specified, use tier-based defaults matching defense dice scaling
- Boss/Legendary abilities typically specify unique dice per ability

---

## Phase 2: Post-Turn Damage Panel

### When It Appears

- After every turn is processed in real battles (online and offline)
- Shown to the acting player only (their turns + companions they control)
- DM sees it for enemy turns
- In offline mode, DM sees all turns
- Dismissible via close button, no auto-timeout

### Panel Layout

Per target in the turn:

**Header section:**
- Target name
- Attack roll vs defense roll, difference value
- Damage die determined from difference (e.g., "D8")
- Active modifiers summary (flat +X, mult xY)
- Hits count
- **Actual damage dealt** — large, prominent number (what the DM entered)

**Roll breakdown table:**
- One row per possible roll value (1 through die max)
- Columns: Roll Value | + Flat Mods | x Mult Mods | Final Damage (after multi-hit reduction if applicable)
- **Estimated actual roll highlighted** — back-calculate which roll value produces the closest match to actual damage dealt. Mark as "ESTIMATED" not as fact, since we may be missing some active modifiers

**Footer:**
- Disclaimer: "Showing calculated possible outcomes — actual damage dealt is what was entered"

### Calculation

Uses DiceRoller functions but does NOT run the full simulator. For each target:
1. Take attack_roll and defense_roll from turn input
2. Compute difference
3. Map to damage die via `DiceRoller.difference_to_damage_die()`
4. Query `EffectProcessor` for acting battler's active damage modifiers (flat and mult)
5. For each possible roll value (1 to die_max):
   - Apply flat mods: `roll + flat_total`
   - Apply mult mods: `result * mult_total`
   - If multi-hit: apply `multi_hit_reduce(result, hits_count)` and show final total only
6. Find the roll value whose final damage is closest to actual damage dealt → highlight as estimated

### Integration Point

Hooks into the existing turn submission flow. After `TurnProcessor.process_turn()` returns, the panel receives:
- The turn input dict (attack_roll, per-target defense_rolls, hits)
- The battler's active effects from EffectProcessor
- The actual damage values entered by the DM

The panel is a new scene (`Scenes/UI/damage_breakdown_panel.tscn`) opened as a modal Window (same pattern as other hub popups).

---

## Phase 3: Player Hub Battle Simulator

### Access

New button on the player hub hotbar. Opens as a full-screen modal Window matching the existing pattern (exclusive, transparent, full viewport size).

### Single-Screen Layout

**Left Panel — Setup (fixed width ~340px):**

**Encounter Setup:**
- Enemy list with per-enemy count spinbox and remove button
- Add enemy dropdown with search/filter (type to filter GameDB enemy list)
- Each enemy shows its tier badge (Common/Uncommon/Rare/Epic/Boss/Legendary)

**Loadout Overrides (sandbox only, never touches real data):**

- **Kit Selection:** Dropdown showing valid element + weapon type combinations for this character. Only shows combinations that exist in their ability data. E.g., "Nature / Catalyst", "Electric / Sword", "Earth / Claymore". Validates the combination exists before allowing selection.

- **Companion:** Dropdown of companions available to this player (from their owned companions in _synced). Shows current companion as default.

- **Weapon:** Dropdown filtered to weapons in the player's inventory that match the selected kit's weapon type. Shows currently equipped weapon as default. Updates when kit changes.

- **Artifacts (5 slots):**
  - Flower of Life: currently equipped → dropdown of other Flowers in inventory
  - Feather of Death: currently equipped → dropdown of other Feathers in inventory
  - Sands of Time: currently equipped → dropdown of other Sands in inventory
  - Goblet of Space: currently equipped → dropdown of other Goblets in inventory
  - Circlet of Principles: currently equipped → dropdown of other Circlets in inventory
  - Each dropdown only shows artifacts of the matching Type from the player's inventory
  - Set bonus preview updates as artifacts change

- **Food Buff:** Dropdown of available food buffs or "None"

**Simulation Config:**
- Number of battles: spinbox (10–10,000, default 1000)
- Player damage modifier: slider 0.5x–1.5x (default 1.0x)
- Enemy damage modifier: slider 0.5x–1.5x (default 1.0x)

**Run / Stop buttons**

**Right Panel — Results (scrollable):**

**Summary bar (3 stat boxes):**
- Win Rate % (green)
- Total Wipes % (red)
- Avg Rounds (blue)

**Damage Distribution:**
- Horizontal stacked bar showing each party member's share of total damage
- Color-coded per battler

**Party Performance Table:**
- Columns: Battler, Avg Dmg, Avg Taken, Absorbed, Downs, Deaths, Revives, Crits
- Each value shows whether it's above or below the party average (with visual indicator — e.g., green arrow up if above avg, red arrow down if below)

**Ability Breakdown:**
- Dropdown to select which battler to view
- Table: Ability, Uses, Avg Dmg, Total Dmg, Crits, Misses
- **Graph view toggle:** Switch between table and bar chart visualization
- Bar chart shows avg damage per ability with average line overlay

**Battle Statistics:**
- Grid of key metrics: avg revives/battle, avg items/battle, min/max rounds, battles with 0 deaths, battles with full wipe, all revives burned %, perma-death %

**Graphs:**
- Damage per battler bar chart with party average line
- Damage taken per battler bar chart
- Win rate over simulation progress (convergence chart — shows how win rate stabilizes as more battles run)

**Progress bar** while simulations run (shows X/N completed, with cancel button)

**Footer:** "Simulated N battles in Xs — Results are hypothetical"

### Iteration Flow

Change any setup value → hit "Run Again" → results update in place. No navigation.

---

## Phase 4: DM Encounter Balancer

### Access

New button/tab on the DM Hub (alongside BattlePrep and DataEditor). Opens in the existing tab structure or as a full-screen Window.

### Layout

**Left Panel — Enemy Editor + Config:**

**Enemy Configuration:**
- Enemy selector dropdown (from GameDB enemies, with search/filter)
- Editable stat fields:
  - HP (spinbox)
  - Attack Die / Defense Die (dropdowns: D4 through D20+D8)
  - Size (spinbox, 1-5)
  - Movement (spinbox)
  - Abilities (read from enemy's ability data, shown for reference)
- Count in encounter (spinbox)
- Can add multiple different enemy types to one encounter

**Target Tier Selection:**
- Button bar: Common | Uncommon | Rare | Epic | Boss | Legendary
- Selecting a tier loads the target profile

**Tier Profiles (fixed, scaling with encounter composition):**

**Common (per enemy):**
- Win rate: ~99%
- 1 enemy dies in 1-2 rounds
- No items/revives needed
- Party takes minimal damage
- Defense dice: D12, Attack dice: D12 (or ability-specified)

**Uncommon (per enemy):**
- Win rate: ~95%
- 3-5 rounds per enemy
- Occasional item use, revives almost never
- Moderate damage taken
- Defense dice: D16, Attack dice: D16 (or ability-specified)

**Rare (per enemy):**
- Win rate: ~85%
- 5-8 rounds
- Items likely, revives occasionally
- Someone downed in ~30% of fights
- Defense dice: D16, Attack dice: D16 (or ability-specified)

**Epic:**
- Win rate: ~80%
- 8-12 rounds
- Items expected, all revives burned in most fights
- Downing is normal, permanent deaths rare (~10%)
- Defense dice: D20, Attack dice: D20 (or ability-specified)

**Boss:**
- Win rate: ~75%
- Full party wipe ~25%
- Of wins: all revives burned ~50%, someone perma-dead ~25%
- Long fight, all abilities cycled multiple times
- Defense dice: D20, Attack dice: ability-specified (varies per ability)

**Legendary:**
- Win rate: ~50%
- Full party wipe ~40%
- Of wins: someone perma-dead in most, clean wins rare (~10%)
- Revives burned immediately, items essential
- Longest fights, every resource exhausted
- Defense dice: D20, Attack dice: ability-specified

**Encounter Scaling:**
When multiple enemies of the same tier are in an encounter, the profile scales:
- Expected rounds increase proportionally
- Resource usage (revives, items) increases
- Win rate may decrease slightly for higher counts
- The balancer compares simulation results against the scaled profile, not the per-enemy baseline

**Simulation Config:**
- Number of battles (spinbox, 10-10,000)
- Player damage modifier (slider 0.5x-1.5x)
- Enemy damage modifier (slider 0.5x-1.5x)
- True RNG

**Run / Stop buttons**

**Right Panel — Results + Suggestions:**

**Verdict Banner:**
- One-line assessment: "TOO EASY", "SLIGHTLY TOO EASY", "BALANCED", "SLIGHTLY TOO HARD", "TOO HARD"
- Color-coded (green/yellow/red)
- Shows actual win rate vs target

**Summary stat boxes:** Win Rate, Total Wipes, Avg Rounds

**Profile Comparison:**
- Horizontal bars for each metric (win rate, wipes, revives burned, perma-deaths)
- Each bar shows actual value with a gold target line from the tier profile
- Color indicates whether actual is above or below target

**Advisory Suggestions:**
- Cards with specific stat change recommendations
- Each card: what to change, from → to values, reasoning, expected impact
- Badge: "Advisory Only" — changes are never auto-applied
- Suggestions generated by comparing simulation results to tier profile targets:
  - Win rate too high? → suggest increasing HP or attack dice
  - Not enough downs? → suggest increasing attack dice or adding abilities
  - Fights too short? → suggest increasing HP or defense
  - Not enough resource drain? → suggest multi-hit abilities or status effects

**Party Performance Table:**
- Same format as player simulator: per-battler avg damage, taken, downs, deaths

**Footer:** "Simulated N battles in Xs — Suggestions are advisory only"

---

## Aesthetic Direction

Match the HTML mockup styling as closely as possible in Godot:
- Dark theme: background #1a1f2e, cards #1e2438, borders #2a3048
- Gold accent for headers/labels: #c9a84c
- Green for positive/wins: #4ada7e
- Red for negative/losses: #ef4444
- Blue for neutral/info: #60a5fa
- Muted text: #7a83a0, #8b93b0
- Clean card-based layout with consistent spacing
- Tables with subtle hover highlights
- Progress bars with rounded corners

---

## File Manifest

| File | Purpose |
|------|---------|
| `Scripts/battle/dice_roller.gd` | Static dice utility (roll, stat mapping, damage calc) |
| `Scripts/battle/battle_sim_engine.gd` | Headless battle runner (single + bulk) |
| `Scripts/battle/sim_ai.gd` | Smart AI for ability selection and targeting |
| `Scripts/battle/sim_spatial.gd` | Distance-based spatial model |
| `Scripts/battle/tier_profiles.gd` | Fixed difficulty tier definitions |
| `Scripts/battle/balance_advisor.gd` | Advisory suggestion generator |
| `Scenes/UI/damage_breakdown_panel.gd` + `.tscn` | Post-turn damage panel |
| `Scenes/UI/battle_simulator.gd` + `.tscn` | Player hub simulator UI |
| `Scenes/UI/encounter_balancer.gd` + `.tscn` | DM hub encounter balancer UI |
