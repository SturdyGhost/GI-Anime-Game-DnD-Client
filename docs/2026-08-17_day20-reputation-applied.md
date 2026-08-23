# Day 20 Reputation Update — Applied

**Date:** 2026-08-17
**Supersedes:** `2026-08-17_day20-reputation-handoff.md` (research + open questions)
**Status:** ✅ **Done and verified.** All 11 open questions answered; catalogs, generator and seed updated.

---

## ✅ What shipped

| File | Change |
|---|---|
| `tools/gen_default_reputation.ps1` | 2 new generator capabilities + 17 Day-20 standing records (+3 debias) |
| `data/reputation/actions.json` | 121 → **137** actions (15 Day-20 + 1 debias split) |
| `data/reputation/factions.json` | 27 → **29** factions (`Desert Tribes`, `Deseret's Relics`) |
| `data/reputation/npcs.json` | 43 → **46** NPCs (`Dottore`, `Dehya`, `Ayaka`) |
| `data/Reputation_Events.json` | 159 → **246** records (regenerated, never hand-edited) |

A second pass followed — see **[Narrator-bias correction](#-narrator-bias-correction)** at the
bottom. The source notes are accurate on events but written in Brian F.'s voice, so the wording
favoured him and leaned on Brian C. and Dylan.

**To load it in game:** host-only `ReputationManager.reseed_from_defaults()` from the reputation window.

---

## 🔧 Generator changes (`gen_default_reputation.ps1`)

Two capabilities the Day-20 data needed and the generator didn't have:

1. **`Campaign_Day` override per action.** The old rule (`regionBase[Region] + index * 8`) would have
   pushed the 7th new Sumeru action to day 872 — past the campaign clock at 835. Day 20 was *one day*,
   so all 15 new actions pin `"Campaign_Day": 835` explicitly. Actions without the field still slot
   into the old 8-day arc, and because overridden actions no longer consume a region index, **every
   pre-existing record kept its original day** (verified — Sumeru still ends at 816).

2. **`Actors` array.** `Actor` only ever took one name, so a deed shared by *some* of the party had no
   representation. `brians_let_ayaka_fall` uses `"Actors": [ "Brian C.", "Brian F." ]`.

---

## 📖 Day 20 as encoded

### Sumeru — Suristana (party-wide)
| Action | Reads as |
|---|---|
| `refused_to_massacre_crowd` | Selfless 32, Protector 28, Merciful 26, Principled 22, Liberator 20, Brave 15 |
| `refused_to_kill_nahida` | Honorable 30, Loyal 26, Steadfast 22, Reverent 18, Fearless 14 |
| `branded_outlaws_of_sumeru` | Outlaw 60, Fugitive 50, Insurgent 32 — **all at Severity 0.20** |
| `allied_with_desert_tribes` | Warmonger 42, Insurgent 36, Ruthless 26 — **all at Severity 0.00** |
| `struck_deshret_relic_bargain` | Negotiator 18, Resourceful 14, Treasure-Hunter 12 |
| `slew_epic_ruin_guardian` | Combat Expert 28, Brave 22, Fearless 16, Explorer 10 |

### Inazuma — Ayaka
| Action | Actor | Reads as |
|---|---|---|
| `dylan_pyrrhic_hero_of_ayakas_death` | Dylan | Valiant 29, Honorable 27, Loyal 23, Steadfast 20, Beloved 18 (Sev 0.80–0.85) |
| `dylan_called_inazuma_to_war` | Dylan | Bold 23, Loyal 18, Inspiring 14, Warmonger 23 |
| `brians_let_ayaka_fall` | **both Brians** | Unreliable 29, Callous 22, Reckless 20, Cowardly 17 |

### The desert pitch (your ruling: Dylan carries it, the party's association is temporary)
| Action | Actor | Reads as |
|---|---|---|
| `dylan_rallied_tribes_with_bloodshed` | Dylan (Sumeru) | Warmonger 48, Ruthless 36, Charismatic 35, Silver-Tongued 30, Insurgent 30, Bold 20 — **Sev 0.60, permanent** |
| `dylan_warmonger_word_spreads_liyue` | Dylan (Liyue) | Warmonger 28, Ruthless 20, Insurgent 16 |
| `dylan_warmonger_word_spreads_mondstadt` | Dylan (Mondstadt) | Warmonger 26, Ruthless 18, Insurgent 14 |
| `brian_f_peace_appeal_rebuffed` | Brian F. | Peacemaker 20, Diplomat 14 |
| `brian_f_felled_ruin_guardian` | Brian F. | Marksman 28, Combat Expert 20 |
| `brian_c_struck_the_guardian` | Brian C. | Daring 22, Foolish 20, Bold 14 |

### Standing ledger (17 Day-20 records)
```
Dylan     Region      Inazuma                            +10  sev 0.85   pyrrhic hero, personally
Brian C.  Region      Inazuma                            -34  sev 0.70   blamed nation-wide
Brian F.  Region      Inazuma                            -34  sev 0.70   ...and it was his arrow
Brian C.  Faction     Yashiro Commission                 -90  sev 0.80   offsets the marriage favour
Brian F.  Faction     Yashiro Commission                 -90  sev 0.80
Brian C.  Individual  Kamisato Ayato                     -70  sev 0.80
Brian F.  Individual  Kamisato Ayato                     -70  sev 0.80
Party     Region      Sumeru                             -15  sev 0.20   TEMPORARY outlaw brand
Party     Individual  Dottore                           -180  sev 0.95
Party     Faction     Dottore's Researchers             -120  sev 0.85
Party     Individual  Nahida                             +60  sev 0.90
Party     Faction     Followers of Kusanali              +55  sev 0.45   split 1/2: refused to kill her
Party     Faction     Followers of Kusanali              -45  sev 0.45   split 2/2: she's captive, they aren't
Party     Faction     Desert Tribes                      +45  sev 0.50   bargain agreed, NOT fulfilled
Dylan     Faction     Desert Tribes                      +85  sev 0.55   he personally won them
Party     Faction     Deseret's Relics                  -250  sev 0.90   (Day 19 backfill)
Party     Individual  Dehya                              +50  sev 0.55
Brian C.  Individual  Dehya                              -45  sev 0.50   unwanted advances
```

---

## 📊 Verified outcome (engine math simulated against the new seed)

|  | PARTY | Dylan | Brian C. | Brian F. |
|---|---|---|---|---|
| **Region: Inazuma** | −0.15 Neutral | **+0.75 Honored** | **−1.02 Hostile** | **−1.00 Hostile** |
| **Region: Sumeru** | −1.44 Hostile | −1.47 Hostile | −1.50 Hostile | −0.69 Hostile |
| Region: Liyue | −0.14 Neutral | −0.03 Neutral | −0.14 Neutral | −0.14 Neutral |
| Region: Mondstadt | +0.48 Friendly | +0.71 Honored | +0.67 Honored | +0.40 Friendly |
| Yashiro Commission | +1.50 Honored | +1.50 Honored | +1.03 Honored | +1.04 Honored |
| Kamisato Ayato | +1.50 Honored | +1.50 Honored | +1.41 Honored | +1.42 Honored |
| Kujou Sara | +0.05 Neutral | +0.23 Friendly | −0.42 Wary | −0.41 Wary |
| Desert Tribes | +1.50 Honored | +1.50 Honored | +1.50 Honored | +1.50 Honored |
| Dottore | −1.50 Hostile | −1.50 Hostile | −1.50 Hostile | −1.50 Hostile |
| Dottore's Researchers | −1.50 Hostile | −1.50 Hostile | −1.50 Hostile | −1.50 Hostile |
| Followers of Kusanali | +0.57 Friendly | +0.55 Friendly | +0.57 Friendly | +0.66 Honored |

**Overall, across 5 regions / 29 factions / 42 NPCs:**
Dylan **+0.28 Friendly** · Brian F. **+0.20** · party baseline **+0.18** · Brian C. **+0.17 Neutral**.

**Inazuma is the headline result:** Dylan Honored at **+0.75** (deliberately off the ceiling), both
Brians in disgrace at **−1.00**, the party as a whole slightly negative. See the Inazuma rebalance
section below for how that was distributed.

**Numbers were tuned against the ±1.50 clamp.** First pass had the Brians at −1.50 and the party at
−1.50 in Sumeru — both hard-floored, where no future event can move them. Standings were pulled back
(Inazuma −60 → −38 → −17, Sumeru −90 → −45 → −15, Dylan +55 → +30) so everything except the
deliberate extremes (Dottore, Desert Tribes, Dylan-in-Inazuma) sits inside the range with headroom.
Only **1 of 16** region views now sits at the clamp (Brian C. in Sumeru, a hunted outlaw).

### Validation run
- 246 records, max `Campaign_Day` **835**, nothing over the clock ✅
- All 9 region profiles: no unknown traits, no overwritten weights ✅
- Every `Trait` / `Region` / `Faction` / `Individual` reference in the seed resolves ✅
- No unknown traits in any new action, faction weight or NPC weight ✅
- No duplicate action IDs, no dangling faction `Parent` refs ✅
- All four JSON files still valid UTF-8, no BOM, parse cleanly ✅
- Pre-existing records: **zero day drift** ✅

---

## 🌍 Region profiles rebuilt (the fix for both earlier gaps)

Investigating why Dylan read **+1.00 Honored in Liyue** exposed the root cause of the Sumeru
outlaw-brand gap too: **region `Profile`s were far too narrow to see most of what the campaign
generates.** Liyue weighted just **2** of ~36 accumulated traits — both positive — so alignment pinned
at the `+1.0` ceiling, and 9 of its 11 actions contributed literally nothing.

| Region | Coverage before | Coverage after |
|---|---|---|
| Liyue | **5%** | **72%** |
| Sumeru | 11% | **84%** |
| Inazuma | 28% | **92%** |
| Mondstadt | 34% | **85%** |
| Khaenri'ah | **0%** | **100%** |

All nine regions gained Violence / Law / Order / Compassion / Social dimensions — **93 → 596 total
weights**, add-only (a guard aborted on 4 collisions; authored values were kept). The **signs** differ
per nation on purpose, so regions stay distinct lenses rather than converging on one "bad is bad" list:

| Trait | | | |
|---|---|---|---|
| Rebel | Mondstadt **+2** | Inazuma −1 | Liyue −1 |
| Ruthless | Snezhnaya **+2** | Mondstadt −1 | Sumeru −2 |
| Heretical | Khaenri'ah **+2** | Nod-Krai +1 | Inazuma −2 |
| Killer | Natlan **0** | Liyue −1 | Sumeru −2 |
| Pacifist | Natlan **−2** | Sumeru +1 | |

Mondstadt was founded by overthrowing a tyrant, so rebellion is a virtue there. Natlan is a war nation
and doesn't score killing. Snezhnaya rewards ruthlessness and reads mercy as weakness. Godless
Khaenri'ah rewards heresy and penalises reverence. **Sumeru deliberately got no Devout/Reverent
positives** — the populace does not favour Kusanali, so piety must not pay out there.

### Two over-corrections caught in simulation and fixed
- **Liyue crashed to −0.31 Wary.** Warmonger/Killer/Looter/Plunderer at −2 buried the party for a
  Fatui lab raid the Qixing had asked them to investigate. Halved those four to −1 (contract crimes
  — Outlaw, Bandit, Smuggler, Forger — stay at −2, that being Liyue's real axis). Now **−0.14 Neutral**.
- **Sumeru floored everyone at −1.50.** The outlaw brand was counted twice: the −45 standing record
  existed purely as a workaround for traits not propagating, and `Outlaw 60` / `Fugitive 50` now
  register properly. Record cut to **−15**; the traits carry it.

The Brians' Inazuma figure also had to be restored to the agreed **−0.55** — once their *positive*
traits began registering it drifted up to −0.31, so their standing record went −5 → −17.

### Knock-on effects worth knowing
- `dylan_warmonger_word_spreads_liyue` **now actually works.** Before the rebuild it was inert (Liyue
  weighted none of Warmonger/Ruthless/Insurgent). Dylan is now the only member whose Liyue figure
  moves on it.
- **The Shogunate self-corrected.** It had drifted −0.18 → +0.09 without the war-call being answered
  (second-order, from Dylan's honour traits lifting the party view). It now sits at −0.20, near its
  original value — no offsetting record needed.
- Only **1 of 16** region views sits at the ±1.50 clamp, down from 4 (Brian C. in Sumeru).

---

## 🔁 Reversibility (as requested — Ayaka's death is encoded to be undoable)

Nothing about Day 20 is baked in deeply. To unwind:

| To undo | Delete from | What |
|---|---|---|
| Ayaka's death | generator `$standing` + `actions.json` | 6 standing records + `brians_let_ayaka_fall`, `dylan_pyrrhic_hero_of_ayakas_death`; set `Ayaka` NPC `Status` back to `active` |
| Outlaw brand (when Dottore falls) | both | `branded_outlaws_of_sumeru` action + the `Region Sumeru −45` record |
| Party's tribe association (1–2 sessions out) | `actions.json` | `allied_with_desert_tribes` only — Dylan's `dylan_rallied_tribes_with_bloodshed` **stays** |

Both temporary entries carry a `"Notes"` field in `actions.json` saying exactly this. Then re-run:
```
pwsh tools/gen_default_reputation.ps1
```
**No companion, party or battle data was touched.** Reputation catalogs + seed only.

---

## 📌 Still open for next session

- **Did Inazuma answer the war-call?** Unresolved by design — decides whether the Shogunate's −30
  moves and whether Dylan reads as the man who rallied a nation.
- **Did they get the King Deshret relic?** `struck_deshret_relic_bargain` is logged as agreed-not-
  fulfilled; the Desert Tribes' +45 is provisional until they return to the tribes.
- **Nahida's fate.** Alive but captured, status unknown — her +180 total standing assumes she stays
  fond of them.
- **Dylan's Tenryou claim** — you called it a slip in the notes, so nothing was encoded. No Kujou
  Sara consequence is pending.

---

## 🗣️ Narrator-bias correction

The `DND summary.docx` is an accurate record of *events*, but it is written in **Brian F.'s voice**.
The wording flattered him and editorialised against the other two. Corrected in a second pass.

### Language neutralised (no point changes for Brian C. or Dylan)
"Smart Brian" / "Dumb Brian" are the narrator's epithets, not facts — replaced with `Brian F.` /
`Brian C.` everywhere: **9 action labels, 7 action ids, 5 NPC notes, 7 standing-record notes.**
Loaded verbs went with them:

| Was | Now |
|---|---|
| `dumb_brian_gambling` — "Chronic gambling habit (Dumb Brian)" | `brian_c_gambling` — "Gambled heavily and habitually in Liyue (Brian C.)" |
| `dumb_brian_creepy_advances` — "Creepy advances on Dehya" | `brian_c_unwanted_advances` — "Made persistent unwanted advances toward Dehya" |
| `dumb_brian_dubious_substances` — "Guzzled Sleazy-family substances" | `brian_c_dubious_substances` — "Consumed untested Sleazy-family substances" |
| `dumb_brian_spanked_the_guardian` — "Spanked an epic Ruin Guardian" | `brian_c_struck_the_guardian` — "Closed to melee against the epic Ruin Guardian" |
| Dehya: "Tolerates Dumb Brian at best." | "Guarded toward Brian C. after his repeated unwanted advances." |
| Liyue: "known as a gambling, substance-guzzling lout" | "known for heavy gambling and habitual substance use" |

**Brian C.'s and Dylan's numbers are byte-for-byte unchanged** — verified: Liyue +0.72 / +1.00,
Mondstadt +0.61 / +0.90, Sumeru −1.50 / −0.99 — all identical before and after the debias pass. (Their
Inazuma figures moved later, in the third pass below, and only for the Brians.)
Action ids were safe to rename (grepped — nothing outside the regenerated seed references them).

### Brian F.'s two soft-pedalled incidents
He undersold both. The session record was checked against the docx rather than taken on trust:

**Liyue — the librarian.** Logged as `wooed_the_librarian` with *nothing but* Charming 18 +
Charismatic 12, plus a `+18` standing record calling him "fondly remembered as the charming scholar."
The docx has him going to the library and finding **he is on a list among the librarians** — unpaid
late fees he couldn't cover, and the party openly ribbing him for how hard he pursued them
(*"gets put on one list and he goes crazy"* / *"he had a lot of energy for the librarians"*).
→ `brian_f_liyue_librarians`: Charming 12, Charismatic 8, **Off-putting 20, Unreliable 16, Creepy 12**.
The `+18` was split into `+12` (genuinely well regarded as a scholar) and `−28` (on the list).

**Mondstadt — the predator.** Logged only as the party-wide `released_dragonspine_predator`. The
docx has **Brian F. personally** opening on the man with a mock come-on and then degradation
(*"strike one… strike two"*), then winning him over on a nat 20 — after which the man walks away
toward work on children's television.
→ New `brian_f_freed_dragonspine_predator` (Callous 21, Off-putting 16, Reckless 14, Boorish 12) plus
a `−22` Mondstadt standing record. **The party-wide record was left untouched on purpose** — moving
it to him alone would have lifted Brian C.'s and Dylan's Mondstadt scores, which you ruled out.

### Result
| | Before | After |
|---|---|---|
| Brian F. — Liyue | +1.23 Honored *(best in party)* | **+0.76 Honored** |
| Brian F. — Mondstadt | +0.75 Honored *(tied best)* | **+0.33 Friendly** |

He stays comfortably ahead of Brian C. overall (Sumeru −0.40 vs −1.50, Liyue +0.76 vs +0.72) and
keeps every deed that genuinely reflects well on him. Two knock-ons worth knowing: the **party-wide**
Mondstadt figure slipped +0.75 → +0.62 and Liyue Qixing +1.00 → +0.85, because the party view
aggregates every member's personal deeds — same mechanism that let Dylan's honour traits lift the
Inazuman lenses. And the Qixing now read Brian C. (+1.00) above Brian F. (+0.85), since they weight
`Unreliable` and a delinquency list is exactly that signal.

---

## ⚖️ Ayaka fallout — softened for the Brians (third pass)

Dylan's side of the ruling is **untouched** (+1.50 Honored in Inazuma). The Brians' share was too
severe and, worse, was almost entirely *invisible*: the old traits (Unreliable 42, **Faithless 32**,
Callous 22, Reckless 20) were weighted by **no Inazuman lens at all**, so Tenryou, the Shogunate,
Sara and Commonfolk read exactly as they had before Day 20. The −1.21 came from the raw standing
record alone.

Rebuilt as **broader but shallower** — every remaining trait is weighted by a real Inazuman lens:

| Trait | Points | Who actually registers it |
|---|---|---|
| Unreliable | 24 | Adventurers' Guild (−2) |
| Callous | 18 | Commonfolk (−1) |
| Reckless | 16 | Kokomi (−2) |
| Cowardly | 14 | The Shogunate (−2), Kujou Sara (−2), Gorou (−1) |

`Faithless` was dropped outright — nothing on the Inazuman side weights it, so it was pure severity
with zero reach. The Region standing record went **−38 → −5**.

> **On `Cowardly`:** it is the honour-culture *perception* of the two who walked away alive, not a
> finding of fact — Brian F. loosed the arrow at a Harbinger. It is deliberately the smallest of the
> four, and the action's `Notes` field says so.

### Result

|  | Before Day 20 | First pass | **Now** |
|---|---|---|---|
| Both Brians — Inazuma region | −0.45 Wary | −1.21 Hostile | **−0.55 Wary** |
| The Shogunate | −0.25 Wary | −0.25 *(no change)* | **−0.46 Wary** |
| Raiden Shogun | −0.32 Wary | −0.32 *(no change)* | **−0.44 Wary** |
| Kujou Sara | −0.37 Wary | −0.37 *(no change)* | **−0.40 Wary** |

They're now cold-shouldered across Inazuma rather than treated as pariahs, and the institutions that
prize honour actually feel it. Two lenses still don't move: **Tenryou Commission** (−0.58) weights
only Rebel/Insurgent/Treacherous/Oathbreaker/Ruthless — none of which is an honest charge here — and
**Commonfolk** (−0.45) sits at `Region_Sensitivity 0.95`, so it just echoes the region.

The family's own grief was left alone (Yashiro −90, Ayato −70 each): both still read Honored (+0.98 /
+1.35) because the marriage favour dominates, so they were never the severe part.

**Side benefit:** the party-wide Shogunate figure moved +0.09 → **−0.15**, back near its original
−0.18. The earlier concern about the Shogunate drifting upward without the war-call being answered is
now largely self-correcting.

### Second neutralisation pass — all player-facing text

The first pass only caught the explicit "Smart/Dumb Brian" epithets. A full sweep of **every** action
label, action note, NPC note, faction note, region description and standing note followed. The DM then
scoped it: correct loaded verbs and pre-judging labels, but **keep the table jokes and narrator
asides** — they are factual, and the ribbing lands on Brian F. as often as on Brian C., so they were
never the bias problem. **No point value was touched** — all four region figures are byte-identical.

**Corrected — loaded verbs on real events:**

| Was | Now |
|---|---|
| "**Massacred** & looted the Fatui research lab" | "Killed the staff of the Fatui research lab and looted it" |
| "**Mouthed off** to the Hiiragi clan head" | "Insulted the Hiiragi clan head" |
| "**Massacred** Fatui personnel across the Liyue lab…" | "Killed Fatui personnel across the Liyue lab…" |
| "**Slaughtered** rank-and-file skirmishers" | "Killed rank-and-file skirmishers" |
| "Refused to **massacre his crowd**" | "Refused to kill the crowd he controlled" |

**Corrected — labels that pre-judged on the system's behalf:**

| Was | Now |
|---|---|
| "Refused Ningguang's **exploitative** deal" | "Turned down Ningguang's terms" |
| "**Reckless** cloud-riding stunts (Dylan)" | "High-risk cloud-riding stunts (Dylan)" |
| "Took up **devoted fatherhood** for Vivienne" | "Took an active role raising his daughter Vivienne" |
| "**Bought** a desert-tribe army with promises of bloodshed" | "Allied with the desert tribes against the city" |
| "Won the desert tribes with **violence-rhetoric**" | "Won the desert tribes over by promising bloodshed" |
| "**Failed to keep Ayaka alive** against Dottore (the Brians)" | "Blamed for Ayaka's death at Suristana (Brian C., Brian F.)" |
| "**Bore** Ayaka's death with full honour (Dylan)" | "Conducted himself with honour after Ayaka's death (Dylan)" |

The judgement still lives where it belongs — in the **traits**. `dylan_reckless_cloud_stunts` still
emits `Reckless 20`; `brian_c_gambling` still emits `Reckless 22 / Hedonistic 14`. The label simply
stops editorialising ahead of the math.

**Kept as-is — table jokes and narrator asides.** Ningguang's `('Ning Wong')` and "Cheated the party
on rewards", Celestia's `('management')`, Collei's `'questionable'` alazar treatments, Azar as
"dismissive tyrant of knowledge", Amber "baffled by Brian C.", Hiiragi Shinzuki's "grumpy hardass who
threw Brian F. out for snark", "the party ribs him for it", Mona "bruised her over a 2-gold
valuation", and the generic DM verbs ("Was creepy / harassed someone", "sketchy substance"). Region
descriptions were already lore-neutral.

**Player names stay mapped everywhere** — grep confirms zero instances of "Dumb Brian" or "Smart
Brian" across the catalogs, the generator, or the generated seed.

### 🐛 One factual contradiction fixed along the way
The Sumeru `−55` standing note read *"souring the region's official reception **even as the populace
stays fond**."* That contradicted two rulings — the populace does not favour Kusanali, and the party
are currently branded outlaws. It now states the ruling positively:

> "…souring the region's official reception. **The populace is no warmer: Sumerans do not regard
> Lesser Lord Kusanali favourably, so standing as her champions wins the party little here.**"

### ⚠️ One thing still outstanding
You said Brian F. should rate best reputationally as the most morally good of the three. After the
softened Ayaka fallout and the region rebuild he sits **2nd overall at +0.22**, now **above the party
baseline (+0.20)** and ahead of Brian C. (+0.19) — but still behind **Dylan (+0.30)**.

That gap is entirely the Ayaka ruling, not narrator bias: Dylan holds +1.50 Honored in Inazuma while
both Brians sit at −0.55 Wary. Those numbers were set deliberately and were left alone.

The two Brians are also close enough to be near-indistinguishable in most of the world — head-to-head
across all 76 lenses, Brian F. leads in 20, Brian C. in 13, and they are level in 43. The separation
is essentially Sumeru (−0.69 vs −1.50), partly clawed back by Brian C. in Mondstadt (+0.67 vs +0.40).

**If you want Brian F. clearly on top, the lever is splitting the Ayaka blame asymmetrically** rather
than reversing anything here — he shot at Dottore and Brian C. didn't, so an identical penalty for
both is arguably the odd part.

---

## ⚖️ Inazuma rebalance — final pass

The DM set cumulative targets for Inazuma: **both Brians around −1.00**, and **Dylan around +0.75**
rather than hard-maxed at the ceiling. The instruction was explicit that Day 20 alone should not carry
this — *all* events to date should sum to those figures — so **every one of the 19 Inazuma records was
nudged slightly in the direction it needed**, rather than yanking one or two levers.

### Traits — 57 emission values across 19 actions
Party-wide history: negatives raised, positives eased. `slew_hiiragi_guards` Killer 25→30 /
Ruthless 12→15 · `looted_tepehs_corpse` Looter 18→22 · `destroyed_delusion_factory` Despoiler
25→29, Killer 20→24 · `challenged_raiden_shogun` Reckless 30→34, Insurgent 20→24 ·
`smuggled_into_inazuma` Outlaw 18→22 · `insulted_the_hiiragi` Tactless 18→22, Abrasive 10→13 ·
`joined_watatsumi_rebellion` Rebel 30→34 — against trims to `restored_starving_village`,
`freed_thoma_from_decree`, `executed_signora_by_duel`, `calmed_the_raiden`, `ran_chisatos_errand`.

Per-player: Dylan's `dylan_pyrrhic_hero_of_ayakas_death` eased (Valiant 35→29, Honorable 32→27,
Loyal 28→23, Steadfast 24→20, Beloved 22→18), `dylan_called_inazuma_to_war` Warmonger 18→23 with
Bold/Loyal/Inspiring trimmed, `dylan_reckless_cloud_stunts` Reckless 20→26, `dylan_devoted_father`
eased. The Brians' `brians_let_ayaka_fall` raised (Unreliable 24→29, Callous 18→22, Reckless 16→20,
Cowardly 14→17) and `brian_c_dubious_substances` Reckless 18→22.

That alone moved the alignment scores most of the way: Dylan **+0.28 → +0.13**, Brian C.
**−0.21 → −0.34**, Brian F. **−0.19 → −0.32**.

### Standing records — the remainder
| Record | Was | Now |
|---|---|---|
| Dylan — Kamisato marriage (pre-existing) | +40 | **+22** |
| Dylan — Day-20 commendation | +30 | **+10** |
| Both Brians — Day-20 blame | −17 | **−34** |

The marriage record had to move: decayed to 38.1 it was worth a **+0.76 nudge by itself**, which
floored Dylan near +1.0 no matter what else changed. Its note now reflects why the reduction is
justified in-fiction — Ayaka is dead, so he is a widower rather than a newly-made son of the clan,
though he remains Ayato's brother-in-law.

### Result
| | Before | **Now** | Target |
|---|---|---|---|
| Dylan — Inazuma | +1.50 *(clamped)* | **+0.75 Honored** | +0.75 |
| Brian C. — Inazuma | −0.55 Wary | **−1.02 Hostile** | ~−1.00 |
| Brian F. — Inazuma | −0.53 Wary | **−1.00 Hostile** | ~−1.00 |
| Party — Inazuma | +0.01 | **−0.15 Neutral** | — |

Dylan is now **off the clamp entirely**, so future Inazuman events can still move him in either
direction. Region views sitting at the ±1.50 clamp are down to **1 of 16** (Brian C. in Sumeru, where
he is actively hunted). The fallout also propagated as intended: the Shogunate now reads −0.54 for
the Brians (from −0.25 originally), Raiden −0.52, Kujou Sara −0.42.

---

## 🧭 Environment

Branch **`battle-host-authority`**. The entire reputation system (`data/reputation/`,
`data/Reputation_Events.json`, `tools/gen_default_reputation.ps1`) is **untracked** — it has never
been committed. The branch also carries ~128 unrelated uncommitted paths; don't sweep them into a
reputation commit.
