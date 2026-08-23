# Scaramouche / Shouki no Kami — Story Boss Design

**Status:** ✅ built — 1 enemy + 16 ability `.tres`, runtime-validated; 4 code changes applied
**Source fight:** Everlasting Lord of Arcane Wisdom (game8 archive 394329)
**Target difficulty:** genuine ~50% full-party wipe
**Calibrated against:** the 2026-07-25 Ruin Grader (Epic) battle — `turns.json` / `summary.json`

---

## 1. The numbers at a glance

| | Value |
|---|---|
| **Phase 1 — Divine Ingenuity** (upper body) | **350 HP**, ~4 rounds |
| **Phase 2 — Nirvana Engines** | **450 HP**, ~6 rounds |
| **Boss total** | **800 HP** |
| **Minions** | **No HP** — one Fire / Ice / Nature hit destroys one. 3 per wave. |
| Accuracy | **D20** (`story_boss` — code change applied, §12) |
| Damage per landed hit | 4 × `closest_die(diff)` + 15 → **21–31** |
| Hit rate vs this party | **~48%** |
| Expected boss damage | **~30–36 aggregate/round** |
| Fight length | **~12 rounds** (target) |
| Wipe chance | **~60%** (§9 — two insta-kill gates + attrition) |
| Electric | **Immune / absorbed** — heals him, applies no element |
| Passives | Arcane Absorption · Divine Threshold (100/action) · Retributive Circuit (10% reflect) |
| Kit size | **5 + gate** in P1 · **6 + gate** in P2 · **3** permanent passives = 16 |
| Insta-kill gates | **Arcane Annihilation** (P1, 140 dmg / 2 rnds) · **Setsuna Shoumetsu** (P2, 3 minions / 1 rnd) |

**Status: built.** 1 enemy + 16 ability `.tres` files, runtime-validated; 4 code changes applied (§12). The **minion / Akasha Charge layer that answers Setsuna is configured separately** and is intentionally not in these files (§8).

800 HP ÷ ~64–77 effective party damage/round (90–110 EV − ~30% action tax) = **~11–12 rounds**, which is the target. With the boss carrying real HP now, the old 25% barrier throttle is gone — it would have made P1 enormous.

---

## 2. Calibration — what the Ruin Grader log proves

**The fight:** Ruin Grader (Epic, 250 HP) vs Brian C. / Brian F. / Dylan / Yae Miko. 12 turns, ~2.5 rounds, 45 min real time, 494 damage, boss died.

### A — the table already runs the new tier formula

| Target | Atk | Def | diff | `closest_die` | Epic = 4d + 12 expected | **Observed** |
|---|---|---|---|---|---|---|
| Yae Miko | 14 | 12 | 2 | **D4** | avg **22** | **22** ✅ |
| Brian C. | 14 | 5 | 9 | **D8** (tie 8/10 → rounds down) | avg **30** | **42** ✅ |
| Dylan | 14 | 14 | 0 | — | miss | **0** ✅ |

Chase rolls `4 × closest_die(diff) + floor` by hand. **So `dice_count`/`dice_die`/`dice_flat` on enemy abilities are cosmetic** — in the sim *and* at the table. The levers that matter:

> **`tier` · `targeting_targets` · `hits_count` · `cooldown` · `weight` · phase HP**

### B — the observed 172/round was ~1.6× their expected rate

**Correction to an earlier draft:** players do *not* roll their ability's own dice. `dice_count`/`dice_die` on player abilities are placeholders — the real damage die comes from `difference_to_damage_dice(diff)` → `stat_to_dice(diff)` (`dice_roller.gd:41`), matching the combat-system reference. Brian F.'s `1d12` is decorative.

**Brian F.'s 175, decomposed** (elemental Nature kit → accuracy rolls off EM; "tiles travelled" is the *arrow's* flight, ~7–8, not his movement):

```
diff 10 (atk 20 − def 10) → D10 → roll ~10
+ 8 tiles travelled              = 18
× 2  (target Rooted)             = 36
× crit                           = 175   →  crit is worth ~5× for him
```

So the "mystery multiplier" is mostly **artifact-stacked Crit Damage**, not an unknown system. Which matters: it makes his output **bimodal on crit** — ~30 on a normal hit, ~175 on a crit. Brian C.'s 220 had *no* crit, so his ~3.7× over a 60-max escalation chain is gear-multiplicative and therefore reliable.

**Reactions are not multipliers in this system.** Checked all 40 entries in `data/resources/reactions/` — they're flat effects and statuses (`nature_electric` = "D8 Nature damage", `electric_nature` = "D6 + Root"), never damage scalars. So reactions don't inflate the numbers above. See §2.D for the one that matters anyway.

Both spikes were near-ceiling outcomes:

- **Brian C.'s escalation is a 50/50 six times over.** Chain `[4,6,8,10,12,20]` vs thresholds `[3,4,5,6,7,11]` — every link is *exactly* 50%. Unpaid, the full chain is `0.5⁶ =` **1.6%**. Buying every failed link at 2 HP/point costs **~18 HP expected** (worst case 60 — his whole bar). The 220 cost real resources and still busts to **0** whenever he won't pay.
- **Brian F. needed the crit** — `1d20+4` × 1.6.

**Expected output, hit-rate weighted (~48% vs a D20-defending boss):**

| Actor | Payload on hit | × 0.48 |
|---|---|---|
| Brian C. (escalation, HP paid — reliable) | ~124 | 60 |
| Brian F. (~30 normal / ~175 on crit) | ~37 blended | 18 |
| Dylan | ~17 | 8 |
| Yae Miko | ~15 | 7 |
| | | **~93 / round** |

⚠️ That 93 is sensitive to **Brian F.'s crit threshold**. At a base 20-only crit (5%) he blends to ~37; if a weapon lowers him to 18+ (15%) he blends to ~52 and the party total rises to ~110. So treat **~90–110/round** as the working band.

**The distribution is the design problem, not the average:**

| Round type | P | Damage |
|---|---|---|
| Both spikes land | 23% | ~210 |
| Only Brian C. | 25% | ~139 |
| Only Brian F. | 25% | ~87 |
| **Neither** | **27%** | **~16** |

**~13× spread between worst and best round.** Tune HP to the ceiling → the median fight is a slog. Tune to the floor → one good round erases a phase. §4 handles this with a mechanic instead of an HP number.

### C — round count is the pacing target, not wall-clock

The Ruin Grader session logged 2,689s / 12 turns = 3.7 min/turn, but that included setup and table overhead that won't scale linearly — a 12-round boss won't run 4 hours. **Target is 12 rounds**, confirmed, and every HP number below is sized to that.

### D — the Electric/Nature reaction problem, and the ruling that closes it

`data/resources/reactions/electric_nature.tres` is **UNFAVORABLE**: *"The vine reflects back at the attacker dealing D6 Nature damage and rooting them for 1 turn."* Electric applied first, then hit by Nature → **the attacker** eats D6 and a Root.

With all three players on Nature kits, a permanently Electric-applied boss would have rooted the attacker on *every* player action for the whole 12-round fight — effectively invalidating the kits they're running.

✅ **Ruled out.** Scaramouche is **Electric-immune** (`res_electro = 0.0`) and **absorbs** Electric — it deals no damage and **applies no element to him**. He never carries an Electric aura, so neither `electric_nature` nor `nature_electric` can fire in either direction. The all-Nature party takes no reaction tax and needs no off-element insurance.

Two follow-ons:

- His own Electric attacks still **apply Electric to players**. That's inert against Nature kits under this ruling, but if anyone swaps to Water mid-campaign, `water_electric` (electrocution, 2 damage per action for 5 actions) becomes live.
- Brian F.'s Nature Charged Attack does **+5 or ×2 vs a Rooted target**, so the party still wants the *boss* rooted — and with `electric_nature` off the table, the only root sources are player abilities. Worth deciding whether a `size_tiles = 3` mech can be Rooted at all; it's worth ~35 damage/hit to him.

---

## 3. Your directives, costed

### (i) D20 accuracy ✅ — but it's a *double* nerf

`dice_roller.gd:69` lumps `story_boss` with `boss/world_boss/legendary` → **D32**. Because the damage die derives from the *margin*, cutting accuracy also cuts damage:

| Accuracy | Avg roll | Hit rate vs ~10.5 def | Typical diff | Dmg die | Per hit | **Expected/target** |
|---|---|---|---|---|---|---|
| D32 (current) | 23 | ~93% | ~17 | D16 | ~49 | **~45** |
| **D20 (your call)** | 10.5 | **~48%** | ~5–8 | **D4–D8** | ~25–31 | **~13.5** |

A **3.3× drop** — which is why directive (ii) is needed. Observed player defence rolls: 12, 5, 14, 12 (avg **10.75**), so ~48% is measured, not guessed.

Bonus: the `+15` floor now dominates, so every landed hit is a consistent **21–31**. Variance moves out of the damage roll and into hit/miss — the texture you liked.

### (ii) Multi-hit or multi-target ✅ — multi-target is ~4× the lever

`multi_hit_total` decays ⅓ per hit: `hits_count` 2 = 1.33×, 3 = **1.44×**, 4 = 1.48× (asymptote 1.5×). So `hits_count = 3` is **+44%**, while `targeting_targets = 3` is **+200%**. Missile Storm's teeth were the 3 targets.

Per-target expected = 28 × 0.48 = **13.5**; with `hits_count = 2` → **~18**.

| Shape | Aggregate/round |
|---|---|
| 2 targets, 1 hit | **27** ✅ baseline |
| 2 targets, 2 hits | 36 |
| 4 targets, 1 hit | 54 |
| 4 targets, 2 hits | 72 ⚠️ wipes in ~3 rounds |

**Budget ~30–36/round.** Rotation abilities hit 2, cooldown AoEs hit 3–4, full-party 2-hit AoEs are once-per-phase.

### (iii) 800 HP ✅ — split 350 / 450

At ~78 effective/round that's ~10.2 rounds, ~4 in P1 and ~6 in P2 (P2 is longer because the boss is untargetable between minion waves).

---

## 4. The three permanent passives

Active in **both phases**. Built as `phase_idx = 0`, `weight = 0.0`, `targeting_type = "none"` so they're never rolled as actions — they're standing rules Chase reads off the card.

### 1. Arcane Absorption

> **Immune to Electric — he absorbs it.** Electric damage dealt to him **heals him for that amount** instead. No Electric element is ever applied to him.

Knock-ons:
- **Electric/Nature reactions cannot fire in either direction**, so the all-Nature party takes no reaction tax (§2.D).
- 🚨 **An Electro companion heals the boss on every hit** — Yae Miko, Raiden Shogun, Keqing, Lisa, Cyno, Razor. The warning is baked into the ability's `description` field so it's visible in-client.

### 2. Divine Threshold

> **No single action or ability may deal more than 100 damage to him.** Excess is lost.

This is the pacing control, and it lands squarely on the two spikes from §2.B — Brian C.'s ~124-average escalation and Brian F.'s ~175 crit both clip to 100. Party EV/round drops from ~93 to **~79**, and the ceiling round drops from ~210 to ~200. A lucky round can no longer erase a phase.

### 3. Retributive Circuit

> **Reflects 10% of all damage dealt to him** back at the dealer, rounded down. Unblockable, ignores defence.

Across the whole fight this is 10% of 800 = **~80 damage** returned, concentrated on whoever hits hardest and most often — i.e. Brian C., who is *already* paying ~18 HP per escalation chain. A round where he escalates and connects costs him ~18 + 10 = **~28 of his 60 HP**. The party's damage dealer is now also its most fragile member, which is a genuinely good tension and the main reason the wipe estimate below sits above 50%.

### Combined effect on the numbers

| | Before passives | With all three |
|---|---|---|
| Party EV/round | ~93 | **~79** |
| Ceiling round | ~210 | ~200 |
| Total party HP loss | ~396 (attrition) | **~476** (attrition + 80 reflect) |
| Fight length | ~11–12 rounds | **~11–12 rounds** (holds — Aegis and Terminal Blast damage are each ≤100, so uncapped in practice) |
| Wipe estimate | ~54% | **~60–70%** |

⚠️ The wipe figure runs hotter than the original 50/50 target. **Kit rates kept as-is at your call** — the attrition is unchanged and the double-action-below-50%-HP escalation stays in. If it plays too brutal, §10 lists the dials in order; reflect 10% → 5% is the gentlest.

---

## 5. Boss record — `data/resources/enemies/scaramouche_shouki_no_kami.tres`

```
id = 128
name = "Shouki no Kami, the Prodigal"
tier = "story_boss"
size_tiles = 3
phase_count = 2
hp_per_phase = 0
phase1_hp = 350
phase2_hp = 450
phase3_hp = 0
phase4_hp = 0
phase1_name = "Divine Ingenuity"
phase2_name = "Nirvana Engines"
phase3_name = ""
phase4_name = ""
turn_structure = "players_all_then_boss"
defense_scale_per_asc = 0.5
res_pyro = 1.0
res_hydro = 1.0
res_electro = 0.0
res_cryo = 1.0
res_anemo = 1.0
res_geo = 1.0
res_dendro = 1.0
```

The `notes` field on the resource is the DM-facing summary and is **authoritative** — read it from the `.tres` rather than this doc, so the two can't drift. It covers: D20 accuracy, the three permanent passives, the P1 matrix/hazard layer with the below-50%-HP double action, the P2 rotation plus Setsuna, and an explicit marker that the minion / Akasha Charge layer lives elsewhere.

⚠️ DM-adjudicated (schema can't express them): `turn_structure` is stored but never read; one `res_*` set for all phases; no 2D grid in the client (`sim_spatial.gd` is 1-D, `BattleScene` just has a *Tiles Moved* spinbox), so all shapes below are written for a human reading the mat.

---

## 6. Shared mechanic — the Neo Akasha Terminal

**Akasha Charge** — one shared party pool, **0–8**, starts at 0, carries between phases.

| Income | Amount |
|---|---|
| **Energy Blocks** — every resolved boss ability drops 2 tiles; pickup costs **movement only, not an action**; fade after 3 rounds | +1 each |
| **Nirvana Engine destroyed** (P2) | **+2 each** (max +6/wave) |

| Spend | Cost | Effect |
|---|---|---|
| Light a Matrix | 1 | Activates one of the 5 P1 matrix tiles |
| Terminal Blast | 3 | 40 damage to the boss (works through P2 untargetability) |
| **Terminal Aegis** | **6** | **Free reaction.** Survives Setsuna Shoumetsu. |

⭐ **A full 3-engine wave gives exactly +6 — precisely one Aegis.** Energy Blocks are the only margin. But see the element rule in §8: with the party's current all-Nature attunement they can only destroy **one engine per wave (+2)**, so 4 of every 6 charge has to come from Blocks — which means leaving cover to grab them while hazards are up. That is the intended pressure, and it's a decision they control by spreading attunements.

### Elemental Matrices (P1 only — 5 fixed tiles)

| Matrix | Lit effect (2 rounds) |
|---|---|
| **Fire** | Clears all *Raw Frost* |
| **Ice** | Clears all *Remnant Flame* |
| **Wind** | Updraft — immune to the next tornado/wave pull, +2 movement |
| **Water** | Heals 2d8 at the start of each turn while on/adjacent |
| **Electric** | Costs **2** — boss skips its next action |

Matrix tiles are the **only** safe tiles during Laser Belt.

### Ground hazards — stack, never expire on their own

| Hazard | From | Effect | Cleared by |
|---|---|---|---|
| **Remnant Flame** | Fire Slam | radius 2; end turn inside → **2d8 Fire** | Ice Matrix |
| **Raw Frost** | Ice Slam | radius 2; inside → **1d8 Ice** + `slow` (id 6) | Fire Matrix |
| **Scorched Line** | Chest Laser | 8×1, 2 rnds; inside → **1d12 Electric** | expires |

Ignore the matrices and the arena is unwalkable by round 6. That's the skill floor.

---

## 7. Phase 1 — "Divine Ingenuity" (350 HP, ~4 rounds)

The upper body. Fully targetable. **Cadence:** 1 ability/round, `weight`-rolled; **2/round below 50% HP** (DM-adjudicated).

**5 weight-rolled abilities + 1 insta-kill gate.**

| id | Name | Element | `targeting_type` | `targets` | `hits` | CD | order | Geometry / notes |
|---|---|---|---|---|---|---|---|---|
| 1 | Left Pyro Slam | Fire | `circle` | **2** | 1 | 0 | 1 | radius 2, `selector = closest`. Leaves **Remnant Flame** (`effect_tile_dmg` 2d8). `weight 1.5` |
| 2 | Right Cryo Slam | Ice | `circle` | **2** | 1 | 0 | 2 | radius 2, `selector = closest`. Leaves **Raw Frost**; `effect_status = 6` (slow), 2 rnds. `weight 1.5` |
| 4 | Electro Rain | Electric | `global_rain` | **all** | 1 | 3 | 3 | Drops **3** Energy Blocks — the boss feeds you |
| 5 | Hydro-Anemo Tornado | Water | `radial_tornadoes` | **2** | 1 | 4 | 4 | 3 tornado tiles, 2 rnds; start of round pull all players 2 tiles toward nearest. Wind Matrix negates |
| 6 | **Laser Belt** | Electric | `ring_sweep` | **all** | **2** | 4 | 5 | radius 6. ⚠️ **Safe only on a lit Matrix tile or adjacent to the boss.** Telegraphed 1 round |
| 3 | 🔴 **Arcane Annihilation** | Electric | `global` | **all** | 1 | 4 | **99** | **Insta-kill gate — see below.** `weight 0`, never weight-rolled |

### 🔴 Gate A — Arcane Annihilation

> Begins charging the first time the boss drops **below 60% of Phase 1 HP (210)**. Charges for **2 full rounds**, telegraphed the whole time — the core glows brighter each round.
> The party must deal **140 damage to the boss** across those 2 rounds.
> **Fail → every player dies.** No save, defence ignored.
> **Succeed → the charge shatters** (no damage) and the boss is **Stunned for 1 round**, losing its next action.

`trigger_type = "round_action"`, `trigger_window_rounds = 2` (charge length), `trigger_threshold_int = 140` (damage required), `bypass_defense = true`, `effect_status = 1` on `self` (the stun reward).

**Why 140.** Modelled off the §2.B per-round distribution with the 100/action cap applied. Two-round sums are lumpy, so the dial has cliffs:

| Threshold | P(fail) |
|---|---|
| 130 | 20.8% |
| **140** | **27.0%** ✅ |
| 150 | 40.5% |
| 200 | 53.0% |

Expected 2-round output is **198**, so 140 is comfortably clearable on a normal stretch and fails on a bad one — it bites exactly when Brian C. busts his chain *and* Brian F. doesn't connect. Note 150 jumps straight to 40%: don't nudge this one casually.

**Swapped out to make room:** *Chest Laser*. Its Scorched Line was a third hazard type on top of the two slams (which fire at `weight 1.5`), and "telegraphed line, step out of it" was the least load-bearing verb in the pool. Keeping Laser Belt preserves the matrix payoff and keeping the Tornado preserves the Wind Matrix's purpose. Every matrix still answers something: Fire ← Raw Frost, Ice ← Remnant Flame, Wind ← tornado pull, Water ← healing, Electric ← skipped action.

P1 isn't meant to wipe. It decides whether they enter P2 with charge banked and HP intact — that's Gate 1.

---

## 8. Phase 2 — "Nirvana Engines" (450 HP, ~6 rounds)

The boss lifts off and is **untargetable** until all 3 Nirvana Engines are destroyed. Terminal Blast is the one exception — it reaches him regardless.

**Nirvana Engines: no HP.** A single hit of the *matching* element destroys one outright; everything else does nothing. Destroying one = **+2 Akasha Charge**.

⭐ **Each wave spawns one Fire engine, one Ice engine, and one Nature engine** — matching the source fight, where the engines are weak to Pyro *and* Cryo *and* Dendro. This is load-bearing: with 3–4 actors all on Nature kits, a single-element rule would mean the wave dies every round without fail, +6 charge would be automatic, Terminal Aegis always affordable, and both Setsuna gates would collapse to ~0% (dropping the whole fight to ~34% wipe). The three-element rule is what keeps Gate 2 uncertain.

Telegraph it in fiction — *"the three engines pulse with different light"* — so it reads as preparation, not ambush.

**The cycle (~3 rounds):**
1. Wave of 3 engines spawns → the party destroys whichever they have elements for (1 action each)
2. Boss **exposed for 2 rounds** — full damage, capped at 180/round
3. New wave spawns, repeat

Engines left alive when the next wave spawns simply vanish — no penalty beyond the charge they didn't give.

**Setsuna Shoumetsu countdown:** starts at **4**, −1/round.
- At **0**: `bypass_defense`, `global` → **every player dies. Full wipe. No save.**
- **Unless** 6 charge is spent on Terminal Aegis (free reaction) → ~30 to all instead, and the boss takes **100**.
- After each cast the counter resets **shorter**: **4 → 3**. Expect **2 casts**.

**6 rotation abilities + Setsuna Shoumetsu.**

| id | Name | Element | `targeting_type` | `targets` | `hits` | CD | Geometry / notes |
|---|---|---|---|---|---|---|---|
| 7 | Stomp & Punch → Discharge | Electric | `scripted_combo` | **2** then **all** | 3 | 2 | 2× closest, then a global discharge |
| 8 | Elemental Bomblets | Fire/Water/Ice | `projectiles_at_player` | **all** | 1 | 2 | 1 bomb tile adjacent to each player; explodes end of round **unless destroyed** (movement, or a matching-element hit) |
| 9 | Double Electro Spear | Electric | `line` | **3** | 2 | 3 | 2 lines, 10×2, telegraphed 1 round; may overlap |
| 10 | Pyro & Cryo Dash | Fire + Ice | `dash` | **2** | 2 | 3 | 1-wide line across the arena; leaves a Remnant Flame **or** Raw Frost trail |
| 11 | Anemo & Hydro Waves | Water / Wind | `half_arena_sweep` | **3** | 1 | 3 | 2 waves on marked tiles; knocks players 3 tiles — can shove them into hazards |
| 12 | Electro Barrage | Electric | `timed_radials` | **3** | 1 | 2 | 4 marked tiles resolving next round. Overlapping markers **stack** (separate markers ≠ multi-hit, no ⅓ decay) |
| 13 | 🔴 **Setsuna Shoumetsu** | Electric | `global` | **all** | 1 | 0 | **Insta-kill gate — see below.** `order = 99`, `weight = 0`, never weight-rolled |

`phase_idx = 2`, `order` 1–6 for the rotation, 99 for Setsuna.

### 🔴 Gate B — Setsuna Shoumetsu

> The boss summons a wave of **3 Nirvana Engine minions** and begins the cast.
> The party has **one round** to destroy **all 3**.
> **One still standing when the boss's turn comes round → every player dies.** No save, defence ignored.
> **All 3 destroyed → the cast breaks**, a fresh wave spawns, and the check repeats.

`trigger_type = "round_action"`, `trigger_window_rounds = 1` (the round they get), `trigger_threshold_int = 3` (minions that must die), `bypass_defense = true`.

### 🔌 Configured separately — the minions

The **minions themselves are not in these files** — no HP, one Fire / one Ice / one Nature, each killed outright by a matching-element hit. Setsuna's `description` points at that layer rather than defining it. What the boss record assumes:

- The boss is **untargetable** until the wave is cleared, which is what stretches P2 to ~6 rounds against 450 HP
- The **three-element rule** is what keeps Gate B uncertain against an all-Nature party — with a single-element rule and 3–4 Nature actors the wave dies every round without fail and the gate collapses to ~0%

### The two gates read as a matched pair

Deliberate symmetry, and worth telling the players so the second one lands:

| | Gate A (P1) | Gate B (P2) |
|---|---|---|
| Question | *can you burn him down in time?* | *can you clear the adds in time?* |
| Window | 2 rounds | 1 round |
| Requirement | 140 damage | all 3 minions |
| Fail | everyone dies | everyone dies |
| Succeed | charge shatters, boss stunned 1 round | wave breaks, next wave spawns |
| Recurs | on cooldown 4 | every cycle |

Gate A is the rehearsal; Gate B is the real thing on half the timer. Since Arcane Annihilation is explicitly *"the Phase 1 precursor to Setsuna Shoumetsu"* in its description, the party learns the grammar of the mechanic before it turns lethal-on-repeat.

**Also cut from P2** (last pass): *Kyougen no Ma*, *Rending Vortex*, *Sublimation of Doubt*, *Arcane Wisdom*, *Final Reckoning*. Final Reckoning's "deal 80 or die" role is now served — better, and earlier — by Gate A.

---

## 9. Why this lands at ~50% wipe

Attrition (~33/round × ~10 rounds ≈ **330** vs a ~360 effective pool: 158 base + ~60 revives + ~80 healing + ~60 mitigation) leaves them near empty for the endgame. Attrition alone rarely wipes — it makes the gates lethal.

| Gate | Where | Check | Fail = | P(fail) |
|---|---|---|---|---|
| **1** | End of P1 | ≥4 charge **and** ≥60% HP into P2 | not a wipe — makes Gate 2 near-unwinnable | soft |
| **A** | P1, below 60% phase HP | 140 damage in a 2-round charge | **instant full wipe** | **~27%** (modelled, §7) |
| **B1** | P2, wave 1 | all 3 minions in 1 round | **instant full wipe** | ~15% |
| **B2** | P2, wave 2 | all 3 minions in 1 round | ~~~~ | ~20% |

```
Survive Gate A       = 0.73
Survive both Gate Bs = 0.85 × 0.80 = 0.68
Gates alone          = 0.73 × 0.68 = 0.50   →  ~50% wipe from gates
+ attrition: ~476 party damage vs a ~360–450 effective pool
                                            →  ~60% wipe overall
```

Gate A is the one number here that's genuinely modelled rather than estimated — it comes straight from the two-round damage distribution (§7). The Gate B figures are estimates and will firm up once the minion layer's element rule is settled.

Gate B assumes the **three-element rule** and the party's all-Nature attunement. If they spread to cover Fire and Ice too, Gate B drops toward ~5% per wave and overall wipe falls to ~40%. **That swing is the intended reward for prep** — if you want ~50–60% regardless of how they attune, the lever is in the separate minion layer (a fourth minion, or a shorter window).

Two properties worth protecting:

1. **The variance is legible.** They watch the countdown and the charge total. A wipe reads as *"we didn't bank enough"*, not *"the dice hated us."*
2. **The gates are causally linked.** Sloppy P1 hazard play → actions spent walking around fire → fewer Energy Blocks → Gate 2b fails. Skill compresses the failure rate, which is what you want from a story boss over a flat coin flip.

---

## 10. Tuning dials, by leverage

| Dial | Default | Effect |
|---|---|---|
| **Terminal Aegis cost** | **6 charge** | Biggest single dial. 5 = easier, 7 = brutal |
| **Charge per engine** | **2** (+6/wave = exactly one Aegis) | Raise to 3 and Gate 2 nearly always passes |
| **Engine element rule** | one Fire, one Ice, one Nature per wave | ⭐ Load-bearing. Single-element = wave always cleared = Gate 2 collapses (~34% wipe) |
| **Setsuna counter** | 4 → 3 | Shorten for pressure, 5 → 4 to soften |
| **Arcane Annihilation threshold** | **140 dmg / 2 rnds** | Gate A. ⚠️ Lumpy dial: 130 ≈ 21%, 140 ≈ 27%, **150 jumps to 40%** |
| **Setsuna window** | 1 round / 3 minions | Gate B. A 4th minion or a shared-action limit tightens it |
| Energy Blocks per boss attack | 2 | Their only margin beyond engines |
| **Retributive Circuit reflect** | 10% | Gentlest wipe-rate dial — 5% removes ~40 party damage over the fight |
| **Divine Threshold cap** | 100/action | Controls the *lucky* case only. Lower = longer fight |
| Engines per wave | 3 | Action tax on the Fire/Ice/Nature holders |
| `targeting_targets` on rotation | mostly 2 | Straight aggregate-damage multiplier |
| Phase HP | 350 / 450 | **Pacing, not lethality** |

---

## 11. Open questions

1. ~~What is the damage multiplier stack?~~ **Answered** (§2.B): elemental Nature kit → EM-based accuracy, diff-derived damage die, `+tiles travelled` = the arrow's flight (~7–8), ×2 vs Rooted, then artifact Crit Damage worth ~5×. No mystery system. **800 HP stands.** The residual unknown is only Brian F.'s **crit threshold** — 20-only vs weapon-lowered — which sets whether the party runs at ~93 or ~110/round, i.e. 12 rounds vs 11.
2. ~~Arcane Overcharge, or permanent Electro?~~ **Answered** (§2.D): Electric-immune and absorbed, never applied to him — so Electric/Nature reactions can't fire in either direction. No stance mechanic needed; the all-Nature party takes no reaction tax.
3. **Can a `size_tiles = 3` mech be Rooted?** Brian F.'s Nature Charged Attack does ×2 vs Rooted, so this is worth ~35 damage/hit to him. Affects the ~93–110 band directly.
4. **Confirm D20 accuracy** knowing it also cuts per-hit damage to D4–D8 dice (§3i). The alternative — keep D32, boss attacks every *other* round — hits the same budget with fewer, scarier hits.
5. **Revives — how many, full or half HP?** The ~360 effective pool and the ~54% both move on this.
6. ~~Do the players have Fire / Ice / Nature attunement?~~ **Answered:** all 3 players are on Nature kits, and the companion can be swapped to a matching element — so 3–4 engine-capable actors. This is *why* §8 uses the three-element engine rule; with a single-element rule the waves would clear automatically and Gate 2 would vanish.
7. **`companion_limit = 1` but `turn_order` lists Ayaka *and* Yae Miko** — which is live? Changes damage/round and so fight length.

---

## 12. Code changes this design needs

| File | Change | Why |
|---|---|---|
| `dice_roller.gd:63` | Split `story_boss` → `[20]` | Directive (i) |
| `dice_roller.gd:74` | Give `story_boss` its own case (`4 / 15` unchanged) | So it stops riding the boss case |
| `battle_sim_engine.gd:1096` | `story_boss` → `20` | Display-only accuracy readout |
| `tier_profiles.gd:5` | **Add a `story_boss` profile** | ⚠️ Falls through to `common` today — the balancer grades all 5 existing story bosses at 99% win / 0.5% wipe |

Suggested profile: `win_rate 50`, `wipe_rate 40`, `rounds_per_enemy [8, 12]`, `revives_needed_rate 100`, `defense_die 20`, `attack_die 20`, `damage_formula "4d + 15"`.

The `TierProfiles` gap is pre-existing and independent of this boss.
