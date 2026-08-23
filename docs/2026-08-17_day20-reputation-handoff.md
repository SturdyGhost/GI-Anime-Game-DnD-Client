# Day 20 Reputation Update — Session Handoff

**Date:** 2026-08-17
**Task:** Read `C:\Users\White\Downloads\DND summary.docx` (the latest copy, Aug 9) and update the
reputation system with last session's events.
**Status:** ✅ **SUPERSEDED — the work is done.** See `2026-08-17_day20-reputation-applied.md`.
> This document is kept as the research record (docx findings, system walkthrough, open questions).
> All 11 questions below have since been answered and applied.

---

## 📋 Task scope

- The docx contains DAY 1 → **DAY 20** as `Heading1` sections.
- **Day 19 is already in the data** (`uncovered_eremite_supplier`, `slaughtered_deserets_relics`,
  `took_sleazy_family_deal`). ← *unconfirmed with user, but verified in the data*
- So the work is **DAY 20 — "The Day of Spanking"** (docx paragraphs 1850–1948).
- Max `Campaign_Day` currently in the seed = **816**. Campaign clock = **835** (`DEFAULT_START_DAY`).

---

## 🗂️ How the reputation system works (verified)

### Catalogs — `data/reputation/*.json`
Plain JSON, read directly by `ReputationManager._load_catalogs()` via `FileAccess`.
**Not** GameDB `.tres`, so the project's "never add new data to JSON" rule does **not** apply here —
editing these JSONs is the intended path.

| File | Contents |
|---|---|
| `traits.json` | 225 traits, 19 categories, each with `Valence` |
| `factions.json` | 27 factions: `Region`, `Parent`, `Status`, `Region_Sensitivity`, `Weights{trait: n}` |
| `npcs.json` | 43 NPCs: `Faction`, `Personal_Weights{}`, optional `Region_Sensitivity` |
| `regions.json` | 9 nations: `Element`, `Visited`, `Profile{trait: n}` |
| `actions.json` | 121 actions: `Id`, `Label`, `Category` (Generic/Campaign), `Region`, `Actor`, `Emissions[{Trait, Points, Severity}]` |

### Events — `data/Reputation_Events.json`
159 records, append-only ledger. Two record shapes:
- **Trait emission:** `{Actor, Region, Trait, Points, Severity, Campaign_Day, Source_Action}`
- **Standing event:** `{Actor, Scope_Type, Scope, Standing, Severity, Campaign_Day, Note}`
  (`Scope_Type` ∈ `Region` | `Faction` | `Individual`)

`Actor` is `"Party"` (shared baseline) or a player name: `Brian C.`, `Brian F.`, `Dylan`.

### Generator — `tools/gen_default_reputation.ps1`
**Regenerates `Reputation_Events.json` wholesale.** Never hand-edit the events file — edit the
generator + `actions.json`, then re-run:
```
pwsh tools/gen_default_reputation.ps1
```
- Expands every `Category: "Campaign"` action into per-actor trait records.
- Assigns `Campaign_Day` as `regionBase[Region] + (index * 8)`.
  Bases: Mondstadt 60, Liyue 250, Inazuma 480, Khaenri'ah 680, **Sumeru 760**.
  Sumeru currently has 8 actions → days 760…816. New Sumeru actions continue 824, 832, …
- Then appends a hand-authored `$standing` array of grudges/favors.

### Engine — `Singletons/ReputationManager.gd` (558 lines)
- **Decay:** `Severity` → half-life. `0.0→14d`, `0.2→180d`, `0.4→600d`, `0.7→1825d`, `0.95→3650d`, `1.0→5475d`.
  **Severity is the "how permanent is this" lever.**
- `trait_vector(region, actor)` — actor view = Party deeds **+** that member's own, never a teammate's.
- `_align()` normalizes to [-1,1]; `_standing_nudge()` = `standing_total / 50`, clamped ±2.5.
- **Important propagation quirk:** the *normalized* `faction_standing()` / `npc_standing()` do **NOT**
  inherit `Region`-scoped standing nudges — only the raw `*_opinion()` functions do.
  ➜ To make something hit *everyone* in a region, use **trait emissions** (they flow through every
  faction/NPC lens automatically), not a Region standing record alone.
- Labels: `Honored ≥0.6`, `Friendly ≥0.2`, `Neutral ≥-0.2`, `Wary ≥-0.6`, else `Hostile`.

### UI
`Scenes/reputation_window.gd` (777 lines). `ReputationManager.reseed_from_defaults()` is host-only
and wipes + reloads the seed — that's how the DM picks up seed edits.

---

## 📖 DAY 20 events (docx ¶1850–1948)

1. Nahida speaks through Katherine; reveals the Sabzeruz festival was a **samsara dream loop**,
   Acacia terminals harvesting dreams for the Akademiya.
2. The whole city walks to Suristana. Crowd recognizes the party — **"THE HEROES OF SUMERU."**
3. **Dottore** (Fatui Harbinger #2) reveals himself. Dylan introduces himself as *"a representative
   of importance from the Tenryou Commission"* and tries to charm him / shit-talk Harbinger #1.
4. Dottore mind-controls ~100,000 civilians via the terminals, pressing the party toward a cliff:
   *kill the crowd or be pushed off.*
5. Party **refuses to harm innocents** — knocks terminals off non-lethally so Nahida can warp people
   to safety. Nahida tells them point-blank not to hurt anyone.
6. Dottore's terms: **murder Nahida** and bring him the Nosus to prove loyalty. Party **refuses**.
7. Party grabs Nahida and **jumps off the cliff**; Nahida stays behind to hold the warp.
8. Smart Brian shoots at Dottore — Dottore catches the arrow, blinks to **Ayaka**, and drives it into
   her chest. Dylan rolls 19/20 and burns his burst.
9. **Ayaka dies.** Party drags her body out of the city. Smart Brian shapes the arrowhead into a
   necklace for Dylan. Dylan writes to **Ayato and the Raiden calling Inazuma to war**; a trusted
   merchant carries her body + the letter to Inazuma.
10. Party flees to the desert with **Dehya ("Dea")**; meets **Alhaitham** en route.
11. Needing numbers against a city, they court the **desert tribes**. Smart Brian's peaceful appeal
    fails; **Dylan wins them with violence-rhetoric** — *"Blood spill causes rivers to flow"*,
    *"show the god what it means when your demands are not appeased."*
12. Deal struck around **King Deshret** — retrieve a relic from his desert temple.
13. In the temple: **epic-tier Ruin Guardian** (first epic enemy). Dumb Brian spanks it; Smart Brian
    throat-shots it dead. **Session ends here.**

---

## ✅ Answers received from the user

### Ayaka
- **She died.**
- **Dylan** receives *full commendation* for handling it as well as he could have — he is regarded as
  a **pyrrhic hero in Inazuma, as an individual.**
- **Brian C. and Brian F.** take a hit **with everyone in Inazuma** — region-wide, all factions and
  NPCs, not just the family — for letting Ayaka die. *"Only Dylan keeps his high status essentially."*
- **Do NOT touch her companion/party/mechanical data.** The user has already flagged her dead on his
  laptop and made other client updates. Reputation-only. A resurrection mechanic may or may not come
  later, so encode her death as **authored standing events** (easy to reverse) rather than something
  baked deep into trait actions.

### Sumeru / Dottore
- Dottore currently has the **entire population mind-controlled** to do his bidding.
- The party are effectively **"outlaws"** in Sumeru right now.
- Separately and genuinely: **the population does not view Lesser Lord Kusanali favorably at all**,
  even when not mind-controlled. (So being Nahida's champions earns the party little with ordinary
  Sumerans.)

### Nahida
- **Sacrificed herself** to let the party escape — her choice, no blame on the party.
- **Alive but captured**; overall status unknown.

---

## ❓ OPEN QUESTIONS — resume here

### Answered: 1 ✅, 2 ✅. Still open:

**3. Did the war-call land?** Dylan wrote to Ayato and the Raiden calling Inazuma to war. Is Inazuma
actually mobilizing? Decides whether Dylan reads to the Shogunate/Tenryou as *the man who rallied a
nation* or *the outlander who dragged Inazuma into a foreign war* — and whether the Shogunate's
current **−30** moves.

**4. How permanent is the outlaw brand?** No "temporary" flag exists, but `Severity` controls decay.
Proposal: **heavy points, low severity (~0.15–0.25)** so it fades in months once Dottore is dealt
with, rather than scarring permanently. Confirm or override.

**5. Populace vs. Kusanali — catalog change or event?** This is a state of the world, not a party
deed. Cleanest is editing `regions.json` / `factions.json` so Sumeru's profile stops rewarding
Nahida-alignment. Want the catalogs touched, or keep everything as party-facing events?

**6. Do Kusanali's actual followers blame the party?** `Followers of Lesser Lord Kusanali` is a
distinct faction from the populace. Do they resent the party for their god's capture, or revere them
as the ones who stood with her against a Harbinger?

### Queued behind those (raised, not yet discussed):

**7. Missing catalog entries.** No `npcs.json` entry for **Dottore**, **Dehya/Dea**, or **Ayaka**.
No `factions.json` entry for **Deseret's Relics** (only generic `Eremites`) or the **desert tribes**.
`Dottore's Researchers` faction exists with no face attached. Add them?

**8. Dylan's Tenryou claim.** He announced himself as Tenryou Commission; he married into **Yashiro**.
In-character bluff or a slip in the notes? If a bluff, there's a Kujou Sara consequence if it surfaces.

**9. The desert pitch.** Dylan won the tribes by promising violence. Emit as *Charismatic/Bold*
(Dylan personally), or also *Warmonger/Ruthless* with everyone who heard it?

**10. Did they get the relic?** Session cut on the Ruin Guardian kill. Determines whether the Eremite
deal counts as fulfilled.

**11. Scope confirmation.** "Last session" = **Day 20 only**, correct? (Day 19 is already in the data.)

---

## 🔧 Planned implementation (once questions close)

1. Add Day-20 `Campaign` actions to `data/reputation/actions.json` — likely:
   `refused_to_massacre_crowd`, `refused_to_kill_nahida`, `ayaka_died_to_dottore`,
   `called_inazuma_to_war`, `branded_outlaws_of_sumeru`, `won_over_desert_tribes`,
   `slew_epic_ruin_guardian`, plus per-actor variants for Dylan / the Brians.
2. Add standing events to the `$standing` array in `tools/gen_default_reputation.ps1`:
   - `Region Inazuma` **+** for `Dylan` (pyrrhic hero, high severity — this should stick)
   - `Region Inazuma` **−** for `Brian C.` and `Brian F.` (moderate)
   - `Region Sumeru` **−−** party-wide, **low severity** (outlaw brand, pending Q4)
   - `Individual Dottore` **−−−** high severity (new NPC, pending Q7)
   - Possibly narrow/offset the existing party-wide `Yashiro Commission +140` / `Ayato +95`
3. Re-run `pwsh tools/gen_default_reputation.ps1`.
4. Verify: record count, `Campaign_Day` range, and that Sumeru's new days stay ≤ 835.

### ⚠️ Design note on the Brians' Inazuma hit
Because normalized `faction_standing()`/`npc_standing()` ignore Region standing nudges, a
Region-scoped record alone will **not** make Inazuman factions and NPCs turn on them. Use
**per-actor trait emissions in region Inazuma** (which flow through every lens) *plus* a Region
standing record for the headline number.

### Useful trait vocabulary (verified present in `traits.json`)
- **Honor:** Honorable+2, Principled+1, Loyal+1, Steadfast+1, Dutiful+1 / Treacherous−2, Oathbreaker−2, Faithless−1
- **Reliability:** Dependable+1 / Unreliable−1
- **Courage:** Brave+1, Valiant+1, Bold+1, Fearless+1 / Cowardly−1, Craven−1
- **Compassion:** Selfless+2, Kind+2, Compassionate+2, Merciful+1 / Callous−1, Heartless−2, Cruel−2
- **Violence:** Protector+2, Guardian+1, Defender+1, Peacemaker+1, Liberator+1 / Warmonger−1, Ruthless−1, Butcher−2
- **Social:** Beloved+2, Charismatic+1, Inspiring+1, Silver-Tongued+1 / Abrasive−1, Boorish−1
- **Faith:** Devout+1, Reverent+1 / Heretical−1, Blasphemous−1, Sacrilegious−1
- **Order:** Stabilizing+1, Peacekeeper+1, Rebel 0, Revolutionary 0 / Insurgent−1, Agitator−1
- **Law:** Lawful+1, Incorruptible+2 / **Outlaw−1**, **Fugitive−1**, Bandit−1

---

## 🧭 Environment notes for the next session

- Working in `C:\Users\White\Documents\Godot\Projects\genshin-dnd-client` (overseer routing rule:
  sessions start in `Projects\`, then switch).
- Branch **`battle-host-authority`**, with **128 uncommitted paths** (54 tracked files, +1938/−331)
  already in flight — unrelated to this work. Don't sweep them into a reputation commit.
- Extracted docx text is at:
  `C:\Users\White\AppData\Local\Temp\claude\C--Users-White\6b53efa9-9c3c-4d6c-a7e1-80bc5ab59d16\scratchpad\dnd_summary.txt`
  (regenerate by unzipping the docx and pulling `<w:t>` runs out of `word/document.xml`).
