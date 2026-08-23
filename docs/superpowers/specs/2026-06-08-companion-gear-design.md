# Companion Gear (Artifacts + Weapons) — Design Spec

**Date:** 2026-06-08
**Status:** Approved for implementation
**Related:** [enemy damage formula](../../../) (encounter scaling note), artifact baseline/region-scaling discussion (economy motivation)

---

## 1. Summary

Companions become fully gearable: each equips its **own 5 artifacts (full parity with players) and its own weapon**. A companion's stats are derived from the **average of the party's player base points** (mapped through the stat map + scaling), **plus** its own artifact and weapon stats. **Companions get no skill points** — that is the intentional cap that keeps their ceiling below a fully-invested player.

On a companion's turn, and when a companion is attacked, **all players roll the companion's stat die and the best (highest) of those rolls is used** (currently 3 players → best-of-3). No skill points means even a best-of-3 result tops out below a skill-invested player's die.

This is primarily an **artifact-economy feature**: it multiplies the number of slots that want good artifacts (driving the "farm more / pursue new sets" goal) and gives surplus/off-set pieces a home.

---

## 2. Locked decisions

| Decision | Value |
|---|---|
| Artifact slots | **5 (full parity)** — Flower, Feather, Sands, Goblet, Circlet. 2pc/4pc set bonuses fully available. |
| Weapon | **1 weapon slot**, swappable. Weapon is a pure stat/effect stick — companion abilities are **not** weapon-gated. |
| Base stats | **Average of all active player characters' base points** (per stat), via the stat map + scaling. Computed **live/dynamic** (recomputes as players grow). |
| Skill points | **None.** Companions never receive skill points. |
| Roll mechanic | **Best-of-N** (N = player count, currently 3) for **both attack and defense** rolls. Each player rolls the *companion's* stat die; take the max. |
| Gear permission | A player may gear **only companions they own** (`companion.owner == active player`). |

---

## 3. Stat formula

Mirror `CharacterManager._calculate_from_synced`, but with two differences: base comes from the **player average**, and there are **no skill points**.

For each stat `s` in `EntityStats.stat_names()`:

```
companion_raw(s)   = average over active player characters of player.<s>_base   # base points only, NOT skill
companion_value(s) = companion_raw(s) * SCALING[s]
                   + sum(equipped companion artifact stat_1/stat_2 matching s)
                   + weapon stat contributions matching s
                   + artifact set-bonus stat modifiers (2pc/4pc)
                   + weapon stat modifier
                   + effect stat mods (existing _apply_effect_stat_mods path)
```

- `SCALING` is the existing `EntityStats.SCALING` (health ×2.0, energy_recharge ×0.1, crit_damage ×0.1, others ×1.0).
- "Average of player base points" = **player characters only** — never other companions (avoids recursion) and never enemies.
- New entry point: **`CharacterManager.calculate_companion_stats(companion) -> CalculatedStats`**. Every place that currently reads companion stats routes through this (live battle build, profile display, battle simulator).

---

## 4. Roll mechanic (best-of-N)

The rule: the companion's relevant stat (Attack, or EM for catalyst / elemental skill / burst; Defense when defending) → die tier via `DiceRoller.stat_to_dice`. Each of the N players rolls that die; the companion's roll = **max** of the N rolls. Applies to **both attack and defense**. N = current player count (3 today). No skill points caps the die below a skill-invested player's.

**Live combat is a TABLE rule, not code.** The players physically roll and agree on the best-of-N result themselves, then enter it — exactly as rolls are entered today. So the **live path (`turn_processor.gd` / `BattleScene.gd`) does NOT auto-roll**; it accepts the manual companion roll as it already does. The only helpful addition is a **UI hint** showing the companion's die tier (e.g. "roll D10 ×3, take best") so players know what to roll. No averaging/auto-roll logic in live.

**Simulator DOES auto-roll** (no humans). `battle_sim_engine.gd` `_execute_attack` currently *averages* each player rolling their *own* stat — change it to roll the **companion's** stat die, **best-of-N**, for both the companion's attack roll and its defense roll.

- Crit: best-of-N raises the odds of reaching the crit threshold somewhat — acceptable; the no-skill-points die cap keeps it in check.

---

## 5. Data model changes

### 5.1 Ownership disambiguation
Add `owner_type: String` to **`OwnedArtifact`** and **`OwnedWeapon`** (`"Character"` default | `"Companion"`). Existing rows migrate to `"Character"`. Companion-owned gear stores `owner = companion.name`, `owner_type = "Companion"`.

- Reuse the **same tables** (`Character_Artifacts` and the weapon table) so all existing logic (set counting, `ArtifactEffects`, `WeaponEffects`, the simulator) works uniformly — only the owner filter widens to `(owner, owner_type)`.
- Management permission is derived separately: a player may edit a companion's gear iff `companion.owner == active player`.

### 5.2 CompanionSaveData
- Companions equip an `OwnedWeapon` (owner = companion name, owner_type = Companion) like a player. The legacy `weapon: String` becomes the **default/starting weapon**, migrated into an `OwnedWeapon` on first load (or used as the fallback until the player equips something).
- `stats: EntityStats` keeps only **base points populated by the averaging rule at runtime**; skill fields stay zero permanently.

### 5.3 Host-authority / sync & turn processing
Companion gear rows sync through the existing host-authoritative table flow (same as character gear). No new authority rules — the host owns the tables; clients render. Equip/unequip is a record update through the existing path.

**Turn processing is UNCHANGED.** The companion's turn already runs from its owner's client; no turn/peer code changes. The *only* requirement: on the companion's turn, the **updated stats and the active set-bonus/weapon effects must display correctly** (the battle UI must read `calculate_companion_stats` + the companion's registered effects, not stale/averaged values).

---

## 6. UI changes

### 6.1 `artifact_detail_scene.gd` — make it subject-parameterized
Today it hardcodes the subject to `Global.ACTIVE_USER_NAME` (e.g. line ~966, ~981). Introduce a **subject** (`_subject_owner: String`, `_subject_type: String`), defaulting to the active player. All owner filters, equip writes, and set-bonus calculations read the subject instead of `ACTIVE_USER_NAME`.

- Add a **target selector** (dropdown/tabs at the top) listing: the active player + each companion the player owns. Selecting a companion re-scopes the whole scene (currently-equipped, candidate list, equip/unequip, set-bonus preview) to that companion's gear.
- New API: `open_for_subject(owner: String, owner_type: String, slot_type := "")`.

### 6.2 `weapon_detail_scene.gd` — same subject-parameterization
Identical pattern: subject + target selector + `open_for_subject(...)`. Weapon equips for a companion write `owner = companion.name`, `owner_type = "Companion"`.

### 6.3 Companion profile (`CompanionsOverview.gd` companion detail view)
Add two buttons to the companion's profile view:
- **Artifacts** → `artifact_detail_scene.open_for_subject(companion.name, "Companion")`
- **Weapon** → `weapon_detail_scene.open_for_subject(companion.name, "Companion")`

Both pre-scope the detail scene to that specific companion (skipping the target selector or pre-selecting it). Buttons only appear/enable for companions the active player owns.

---

## 7. Simulator parity (`battle_sim_engine.gd`)

- Build companion battlers using `calculate_companion_stats` (avg player base + companion gear), not the current averaged-final-stats shortcut.
- Load each companion's equipped artifacts + weapon into the sim config (so set bonuses / weapon effects register via the existing `_register_effects` path).
- Replace the companion attack-roll averaging with **best-of-N of the companion's stat die**, and apply the same best-of-N to the companion's **defense** roll.

---

## 8. Balance note (must plan for)

Geared companions + best-of-N on **both** offense and defense materially raise party power *and* survivability (best-of-N defense makes companions notably harder to hit). Combined with already-strong parties, this dilutes enemy threat further. **Encounters will need scaling up** (more enemies and/or higher tiers) to keep the new enemy-damage formula meaningful. The no-skill-points cap limits, but does not eliminate, the swing.

---

## 9. Test Plan (contract)

**Unit**
- `calculate_companion_stats` = average of player base points (skill ignored) × scaling + companion gear + set/weapon mods. Verify changing a player's *skill* points does **not** move companion stats; changing a player's *base* points does.
- Average uses player characters only (add a second companion; confirm it doesn't affect the first's stats).
- Best-of-N roll returns the max of N die rolls; N tracks player count.
- `owner_type` filtering: a companion's artifacts never leak into a player's set count and vice-versa.

**Scene**
- `artifact_detail_scene` scoped to a companion lists/equips/unequips that companion's artifacts; set-bonus preview reflects the companion's pieces.
- Target selector lists only companions owned by the active player.
- Weapon scene equivalents.

**Integration**
- A geared companion in live battle uses the new stats and best-of-N for attack and defense; simulator produces matching behavior.
- Migration: existing artifacts/weapons gain `owner_type = "Character"`; legacy companion `weapon` string resolves to an equipped weapon.

**Headless**
- Run a sim with a geared companion; confirm no parse/runtime errors and companion damage/defense reflect gear + best-of-N.

---

## 10. Implementation phases

1. **Data + migration** — `owner_type` on OwnedArtifact/OwnedWeapon; migration; companion weapon migration.
2. **Stat calc** — `CharacterManager.calculate_companion_stats`; route all companion-stat reads through it.
3. **Roll mechanic** — best-of-N for companion attack + defense in the **simulator** (auto). Live combat gets only a **UI hint** of the companion's die tier; players roll + resolve best-of-N at the table and enter the result (no auto-roll code).
4. **Artifact UI** — subject-parameterize `artifact_detail_scene`; target selector; `open_for_subject`.
5. **Weapon UI** — same for `weapon_detail_scene`.
6. **Companion profile** — Artifacts + Weapon buttons (owned-companions only).
7. **Sim parity + headless validation.**
8. **Encounter scaling pass** (separate, follows from §8).

---

## 11. Resolved assumptions (confirmed 2026-06-08)

- ✅ "Average of base points" = **all active characters in the party** (player characters).
- ✅ Best-of-N is a **table rule the players resolve themselves** — live combat takes the manual roll, no auto-roll code. Only the simulator auto-computes best-of-N. N = current player count.
- ✅ Companion artifact **set bonuses (and weapon effects) apply on the companion's turn**, processed from the **owner's view** (owner's client drives the companion's turn under the host-authority peer mapping).
