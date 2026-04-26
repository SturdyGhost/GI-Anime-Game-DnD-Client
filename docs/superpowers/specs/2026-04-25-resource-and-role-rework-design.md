# Resource Gathering, Role, and Reward System Rework

**Date:** 2026-04-25
**Status:** Approved

## Problem Statement

Two related pain points from player feedback:

1. **Resource gathering feels lackluster** — pure D4+D12 dice rolls with no decision-making. No player agency, no tension, forgettable compared to the combat system players love.
2. **Battle buff items are forgotten/ignored** — food buffs aren't wired into combat via GameEffect, so crafting has no visible payoff. The entire gather-craft-use loop is inert.
3. **Roles feel forced** — Artisan/Blacksmith/Scribe feel transplanted from Genshin without fitting the tabletop context. The Scribe's timed memorization mechanic competes with natural note-taking and feels clunky.

## Design Overview

Four interconnected changes:

1. **Replace standalone gathering with automated combat loot**
2. **Add challenge quests as optional battle objectives with bonus rewards**
3. **Rotate roles randomly after each battle instead of fixed assignments**
4. **Add companion expeditions for idle companions**

Plus a prerequisite: wire up food buff effects into combat via GameEffect.

---

## 1. Automated Combat Loot

### What Changes

Standalone gathering (D4 cache selection + D12 quantity + luck modifier) is removed entirely. Materials now come from combat rewards.

### How It Works

- After every battle, each player receives **individual loot** displayed on the battle summary screen in a new loot section at the bottom.
- Loot is auto-generated based on:
  - **Region** — pulls from material caches for the region the battle took place in (data already exists in GameDB)
  - **Difficulty score** — each enemy has a score based on tier, summed across the encounter:
    | Enemy Tier | Score |
    |---|---|
    | Common | 1 |
    | Uncommon | 2 |
    | Rare | 5 |
    | Epic | 8 |
    | Boss | 25 |
    | Legendary | 40 |
  - Total score maps to a loot tier. "Qty Per Material" is how many of EACH material in the cache(s) the player receives:
    | Difficulty Score | Loot Tier | Qty Per Material | Caches Rolled |
    |---|---|---|---|
    | 1-2 | Nothing | 0 | 0 |
    | 3-5 | Scraps | 2-3 | 1 |
    | 6-15 | Light | 4-6 | 1 |
    | 16-24 | Moderate | 7-10 | 1 |
    | 25-39 | Rich | 11-15 | 2 |
    | 40+ | Abundant | 16-20 | 2 |
  - Each cache contains 4 material types, so Rich/Abundant tiers yield 8 distinct material types
  - **Individual player luck stat** — applied after base quantities are determined. Uses existing luck tier system (85+ bonus, 70-84 small bonus, 11-25 penalty, 1-10 large penalty)

### What Is Removed

- The gathering scene (`gathering.gd` / `gathering.tscn`)
- Per-player once-per-town gathering limit
- D4+D12 gathering roll mechanics
- Constellation cache override (may be repurposed elsewhere)

---

## 2. Challenge Quests

### Overview

System-generated optional objectives that give combat encounters a secondary goal beyond "win the fight." Completing the challenge earns bonus loot for the entire party.

### Quest Lifecycle

1. **Generation** — System randomly generates a challenge quest for the next battle encounter
2. **Visibility** — Challenge is displayed in the hub / battle prep screen. Players see the challenge description and quest giver name/personality, but NOT the reward
3. **During Battle** — Players attempt to complete the challenge while fighting
4. **Post-Battle DM Confirmation** — After battle ends but before the battle summary screen, the DM gets a popup:
   - Shows the challenge description as a reminder
   - Yes/No buttons for whether the party completed it
5. **Loot Generation** — If completed, quest loot is added to every party member's rewards

### Challenge Types (example pool)

- Trigger a specific elemental reaction (e.g., "Trigger a Melt reaction")
- Defeat an enemy with a specific attack type (e.g., "Defeat an enemy with a charged attack")
- Defensive challenges (e.g., "No party member takes a crit")
- Tactical challenges (e.g., "Apply 3 different status effects")
- Speed challenges (e.g., "Win within 8 turns")

### Quest Givers

- Each quest has an NPC quest giver with a name and personality
- Personality determines reward generosity: generous, fair, stingy, etc.
- Quest givers could rotate or be tied to region/story
- Players see the quest giver and their personality trait but not the actual loot values

### DM Override

- System generates challenges automatically (option C)
- DM has full override capability on any aspect: challenge type, quest giver, reward level
- Override is available from the DM side of the client at any time before the battle

---

## 3. Role Rotation

### What Changes

Roles are no longer permanently assigned. After each battle scenario, the client randomly assigns one role to each player.

### The Three Roles

- **Artisan** — Crafts food/consumables + artifact forge (existing crafting system)
- **Blacksmith** — Crafts weapons (existing crafting system)
- **Scout** — Replaces the Scribe. Receives intel from the DM about upcoming threats, enemy weaknesses, dungeon details. Intel delivery happens verbally at the table; the client simply shows the player that they are the Scout for this town session.

### Rotation Mechanics

- Random assignment happens automatically when a battle scenario ends
- With 3 players and 3 roles, each player gets exactly one role per rotation
- The client displays each player's current role prominently in the hub

### What Is Removed

- Fixed role assignments (Brian C. = Artisan, Dylan = Blacksmith, Brian F. = Scribe)
- The Scribe's timed memorization / research panel mechanic
- Role field on player data becomes a per-session assignment, not a permanent attribute

### What Stays

- All existing crafting recipes (362 .tres files) remain unchanged
- Artisan and Blacksmith crafting UI and mechanics stay the same
- Recipe role-gating stays — but which player is gated to which role changes each rotation

---

## 4. Companion Expeditions

### Overview

Unlocked but inactive companions can be sent on expeditions between sessions to gather materials and resources.

### Expedition Slots

- Number of available slots equals the **party's ascension level**
- Scales naturally with progression

### Expedition Pool

- Each time the party enters town, a **random pool of available expeditions** is generated
- Pool varies each visit — different missions, different optimal companions
- Party chooses which expeditions to pursue from the available pool and assigns companions

### Companion Traits (affect expedition results)

Companions have traits that make them better or worse at specific expedition types:

- **Region affinity** — companions get bonuses in their home region
- **Weapon type** — claymore users better at mining/ore expeditions, bow users at hunting/foraging, catalyst users at research-type expeditions, etc.
- **Element** — Pyro bonus in volcanic/desert areas, Hydro in coastal, Dendro in forests, etc.
- **Personality traits** — derived from companion descriptions. Examples:
  - Enthusiastic/diligent: more materials overall
  - Lazy/carefree: less materials but occasional rare finds
  - Scholarly/curious: bonuses on research/intel expeditions
  - Shrewd/mercantile: bonuses on trade expeditions

### Results

- Delivered next session
- Primarily materials, with occasional rare finds
- Trait bonuses increase quantity and/or quality of returns

---

## 5. Wire Up Food Buffs (Prerequisite)

### Problem

Food buff effects (e.g., "+3 ATT all party", "-2 damage taken per hit") are defined in item data and displayed in UI, but are NOT applied during combat. The GameEffect system exists and handles weapons, artifacts, and status effects, but food buffs are not integrated.

### Solution

- Create GameEffect definitions for each food buff type
- Register active food buff effects in EffectProcessor when battle starts
- Track buff_duration (battles remaining) and decrement on battle end
- Effects to wire up:
  - Stat bonuses (+ATT, +EM)
  - Roll bonuses (+attack rolls)
  - Flat damage bonuses (+damage all attacks)
  - Damage reduction (-damage taken per hit)
  - HP regeneration (HP/turn)
  - Burst charge restoration
  - Double gathering (deprecated — replace with expedition bonus or combat loot bonus)

---

## Migration Notes

- Gathering scene files can be removed or archived
- Existing material inventories are unaffected — players keep what they have
- Crafting recipes unchanged — only who can craft what rotates
- The "Role" field on character data becomes a session-level assignment rather than permanent
- Scribe/Research Panel UI replaced by Scout indicator
- "Tahchin" food item (double gathering materials) needs its effect reworked since gathering is removed — could become double expedition returns or bonus combat loot for one battle
