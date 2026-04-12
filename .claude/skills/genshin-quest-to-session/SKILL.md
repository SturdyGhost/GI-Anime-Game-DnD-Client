---
name: genshin-quest-to-session
description: Use when the DM provides a Genshin Impact wiki URL, PDF, or HTML of a previous session and asks for a printer-friendly DM session guide for running a 4-hour tabletop session adapting that content
---

# Genshin Quest to DM Session Guide

## Overview

Convert Genshin Impact quest content (wiki pages, PDFs, prior session notes) into a printer-friendly HTML session guide tailored for a ~4-hour tabletop session run on the Genshin DnD client in this project. The guide must give the DM exact narration to read, beats to improvise around, real combat encounters using project enemy data, working tabletop puzzles, and meaningful player choices that allow campaign variance from the source material.

## Hard Requirements

**The output MUST contain ALL of:**

1. **Single self-contained HTML file** with inline CSS, printer-friendly (`@page` rules, serif body, proper page breaks, letter size)
2. **Session header** — quest name, estimated runtime, scene count, prep checklist
3. **Cast sheet** — every NPC the DM speaks for, with voice/personality/role notes
4. **Time-budgeted scenes** — every scene tagged with start/end time and total runtime ≈ 4 hours
5. **Read-aloud boxes** — visually distinct, marked "READ ALOUD" — used for openings, key vision moments, dramatic reveals
6. **DM beats** — bullet outlines for what to cover with improv flexibility
7. **At least one physical puzzle** — something the DM can actually run at a table (riddle on a card, tile sliding, code-breaking, sealed envelope reveal, etc.)
8. **At least 3 meaningful player choices** that branch the session — explicitly marked with "PLAYER CHOICE" boxes showing options and how each branches
9. **Combat encounters using the project's actual enemy data** — pull real enemy names from `data/Enemies.json` or `data/resources/enemies/`, not generic "boss tier" placeholders. Suggest specific tier (Common/Uncommon/Rare/Epic/Boss/Legendary).
10. **Prep checklist** — what to print, what props to gather, what to set up before the session
11. **Player handouts section** — explicit list of things to print and hand to players at specific scenes
12. **Cut and expand sections** — what to drop if running short, what to add if running long
13. **Lead-in to next session** — cliffhanger and prep notes for the DM's next prep cycle

## How to Fetch Source Material

### Genshin Wiki URLs (fandom.com)

**The fandom wiki blocks direct WebFetch with Cloudflare.** Use the MediaWiki API instead:

```bash
# For a page like https://genshin-impact.fandom.com/wiki/Through_Mists_of_Smoke_and_Forests_Dark
curl -s "https://genshin-impact.fandom.com/api.php?action=parse&page=Through_Mists_of_Smoke_and_Forests_Dark&format=json&prop=wikitext"
```

The `wikitext` field contains the raw quest content uncontested. Parse it to extract: quest name, summary, characters, dialogue, locations, objectives, rewards.

### PDFs

Use the Read tool with the PDF path. For PDFs over 10 pages, use the `pages` parameter to read in chunks (e.g., `pages: "1-10"`, `pages: "11-20"`).

### HTML files

Use the Read tool. For session note HTMLs from previous sessions, look for: what happened last session, NPCs introduced, current party location, unresolved threads, character development beats.

## How to Identify Project Enemies

**Don't invent enemies.** Read `data/Enemies.json` (or scan `data/resources/enemies/` for `.tres` files) to find enemies that match the quest's intended encounters.

For each combat scene, pick:
- An enemy whose **name fits the quest setting** (e.g., Sumeru forest → "Withered Mitachurl", "Shroomboar"; ruin → "Ruin Guard")
- The **right tier** for the encounter difficulty (use TierProfiles: Common = trivial, Uncommon/Rare = moderate, Epic/Boss = climax, Legendary = brutal)
- The **count** appropriate for party size (1 boss, 3-4 commons, etc.)

When listing the encounter, give the DM the enemy name verbatim so they can drop it directly into the battle prep tab in the DM Hub.

## Combat Encounter Format

```html
<div class="callout combat">
  <h4>Encounter — [name]</h4>
  <p><strong>Setup:</strong> [where, why, narrative hook]</p>
  <p><strong>Enemies:</strong> 1× <code>Withered Mitachurl</code> [Rare], 3× <code>Forest Hilichurl</code> [Common]</p>
  <p><strong>Goal:</strong> [defeat all? survive 5 rounds? reach the objective?]</p>
  <p><strong>Twist:</strong> [environmental effect, status, terrain hazard, or mid-fight reveal]</p>
  <p><strong>Reward:</strong> [items, lore, story progress]</p>
</div>
```

## Puzzle Format

Puzzles must be **physically runnable at a tabletop in under 5 minutes of setup**. Good options:

- **Index card riddles** — write 3-4 lines of cryptic verse, players solve verbally
- **Token arrangement** — give players 5-6 tokens (coins, dice, paper squares) to arrange in a specific pattern
- **Sealed envelope reveal** — pre-written clue sealed, opens when players make the right deduction
- **Symbol matching** — print a small grid of symbols, players match to a key
- **Physical dexterity** — stack dice, balance objects (rare, only for character moments)
- **Logic grid** — print a small "who/what/where" grid, players fill in
- **Word/anagram** — scrambled letters or words spelling a key phrase

For each puzzle, specify:
1. **What the DM needs to print/prepare beforehand**
2. **The exact text/visuals to put on the prop**
3. **The solution**
4. **What unlocks when solved** (information, item, scene transition)
5. **Hint progression** (3 escalating hints if players are stuck)

## Player Choice Format

```html
<div class="callout choice">
  <h4>PLAYER CHOICE — [decision name]</h4>
  <p><strong>Setup:</strong> [the situation]</p>
  <ul>
    <li><strong>Option A:</strong> [what they say/do] → [consequence, narrative branch]</li>
    <li><strong>Option B:</strong> [what they say/do] → [consequence]</li>
    <li><strong>Option C:</strong> [what they say/do] → [consequence]</li>
  </ul>
  <p><strong>Persistent impact:</strong> [how this affects the campaign going forward]</p>
</div>
```

Choices should not be cosmetic. Each option must change SOMETHING tangible:
- An NPC's attitude
- Available paths in the next scene
- Items received or lost
- Combat encounters added or removed
- Future story beats unlocked or closed off

## HTML Template Structure

Use this exact CSS skeleton for consistency. Inline everything — no external files.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Session Guide — [Quest Name]</title>
<style>
  @page { size: letter; margin: 0.6in; }
  * { box-sizing: border-box; }
  html, body { background: #fdfcf7; color: #1a1a1a; }
  body { font-family: "Georgia", "Palatino Linotype", serif; font-size: 11pt; line-height: 1.45; max-width: 7.3in; margin: 0 auto; padding: 0.4in 0.3in; }
  h1 { font-size: 22pt; color: #2d5e3e; border-bottom: 2px solid #2d5e3e; padding-bottom: 4pt; margin: 0 0 4pt 0; }
  h2 { font-size: 15pt; color: #2d5e3e; border-bottom: 1px solid #c7c2b4; padding-bottom: 2pt; margin: 18pt 0 4pt 0; page-break-after: avoid; }
  h3 { font-size: 12.5pt; color: #8a6d1f; margin: 10pt 0 3pt 0; page-break-after: avoid; }
  h4 { font-size: 11pt; margin: 8pt 0 2pt 0; page-break-after: avoid; }
  .subtitle { color: #555; font-style: italic; margin-bottom: 12pt; }
  .meta { background: #e8f1ea; border-left: 3px solid #2d5e3e; padding: 8pt 10pt; margin: 8pt 0 14pt 0; font-size: 10pt; }
  .callout { border: 1px solid #c7c2b4; background: #fff; padding: 8pt 10pt; margin: 8pt 0; border-radius: 3px; page-break-inside: avoid; }
  .callout.read { background: #f5f0e1; border-left: 4px solid #8a6d1f; font-style: italic; }
  .callout.read::before { content: "READ ALOUD"; display: block; font-family: sans-serif; font-style: normal; font-size: 8.5pt; letter-spacing: 1pt; color: #8a6d1f; margin-bottom: 4pt; }
  .callout.dm { background: #fff6f1; border-left: 4px solid #b05a2c; }
  .callout.combat { background: #fbeaea; border-left: 4px solid #a33; }
  .callout.lore { background: #eef0f8; border-left: 4px solid #3a4a8a; }
  .callout.puzzle { background: #fdf6e3; border-left: 4px solid #b58900; }
  .callout.puzzle::before { content: "PUZZLE"; display: block; font-family: sans-serif; font-size: 8.5pt; letter-spacing: 1pt; color: #b58900; margin-bottom: 4pt; }
  .callout.choice { background: #f0e6f8; border-left: 4px solid #6b3fa0; }
  .callout.choice::before { content: "PLAYER CHOICE"; display: block; font-family: sans-serif; font-size: 8.5pt; letter-spacing: 1pt; color: #6b3fa0; margin-bottom: 4pt; }
  .callout.handout { background: #e8f4f8; border-left: 4px solid #2c7c8a; }
  .tag { display: inline-block; font-family: sans-serif; font-size: 8pt; text-transform: uppercase; letter-spacing: 0.5pt; padding: 1pt 5pt; border-radius: 2px; margin-right: 4pt; }
  .tag.time { background: #2d5e3e; color: #fff; }
  .tag.rp { background: #6b3fa0; color: #fff; }
  .tag.combat { background: #a33; color: #fff; }
  .tag.puzzle { background: #b58900; color: #fff; }
  .tag.lore { background: #3a4a8a; color: #fff; }
  table { width: 100%; border-collapse: collapse; margin: 6pt 0 12pt 0; font-size: 10pt; }
  th, td { border: 1px solid #c7c2b4; padding: 4pt 6pt; text-align: left; vertical-align: top; }
  th { background: #e8f1ea; }
  ul, ol { margin: 4pt 0 8pt 18pt; padding: 0; }
  li { margin: 2pt 0; }
  code { background: #f0eee6; padding: 1pt 4pt; border-radius: 2px; font-family: "Consolas", monospace; font-size: 10pt; }
  hr { border: none; border-top: 1px dashed #c7c2b4; margin: 14pt 0; }
  .mini { font-size: 9pt; color: #555; }
</style>
</head>
<body>

<h1>[Quest Name]</h1>
<p class="subtitle">[One-line session pitch]</p>

<div class="meta">
  <p><strong>Runtime:</strong> ~4 hours | <strong>Scenes:</strong> N | <strong>Combats:</strong> N | <strong>Puzzles:</strong> N | <strong>Player Choices:</strong> N</p>
  <p><strong>Source:</strong> [URL or document path]</p>
</div>

<h2>Prep Checklist (Before the Session)</h2>
<ul>
  <li>☐ Print this guide</li>
  <li>☐ Print player handouts (see Handouts section)</li>
  <li>☐ Set up enemies in DM Hub Battle Prep: [list specific enemies]</li>
  <li>☐ [Other physical props needed]</li>
  <li>☐ Review the [load-bearing scene name] — it carries the session</li>
</ul>

<h2>Cast</h2>
[NPC blocks with name, role, voice notes]

<h2>Player Handouts</h2>
[Each handout in its own .callout.handout box, ready to cut out and hand to players]

<h2>Scene 1 — [Title]</h2>
<p><span class="tag time">0:00-0:15</span> <span class="tag rp">RP</span></p>
[Read-aloud, beats, callouts]

<!-- ... more scenes ... -->

<h2>If You Run Short</h2>
<ul>[cut list]</ul>

<h2>If You Have Extra Time</h2>
<ul>[expand list]</ul>

<h2>Lead-In to Next Session</h2>
[Cliffhanger and prep notes]

</body>
</html>
```

## Workflow

1. **Identify the source.** URL → use MediaWiki API. PDF/HTML → use Read tool.
2. **Read the source thoroughly.** Extract: quest name, summary, all NPCs, all locations, key dialogue, objectives, items, lore reveals, combat encounters in the source.
3. **Identify the load-bearing beats** — the 3-5 moments that MUST happen for the story to land. Mark these as protected from cuts.
4. **Scan project enemy data.** Read `data/Enemies.json` or list `data/resources/enemies/` to find enemies matching the quest setting. Note their tier and any special abilities.
5. **Design 8-12 scenes** totaling ~4 hours. Mix RP, combat, and at least one puzzle. Include at least 3 player choices.
6. **Write the puzzle(s).** Make them physically simple to set up but cognitively engaging.
7. **Identify handouts** — anything the DM should print and physically hand to players (key phrases, riddles, maps, NPC letters).
8. **Write the HTML** using the template above. Save to `docs/session-[quest-slug].html`.
9. **Verify** — every hard requirement is present, total runtime ≈ 4 hours, every combat references real enemy names, every puzzle has clear setup/solution/hints.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Generic enemy placeholders ("low-tier", "boss template") | Read `data/Enemies.json`, use real names |
| No puzzles, just skill checks | Design at least one physical puzzle the DM can run at a table |
| Linear plot, no choices | Add at least 3 PLAYER CHOICE boxes with branching consequences |
| Vague read-aloud ("describe the scene") | Write the exact words the DM should speak |
| Walls of lore | Use bullet "lore dump" callouts, never paragraphs of exposition |
| Missing prep checklist | Always include — DM needs to know what to gather before the session |
| Forgetting handouts | If the guide says "hand them an index card", list it in the Handouts section |
| Trying WebFetch on fandom URLs first | Use MediaWiki API directly — Cloudflare blocks WebFetch |
| Output runs >5 hours or <3 hours | Re-budget scenes, cut subplots or add side beats |
| Choices that don't matter | Each option must change something tangible (NPC attitude, future scene, item, encounter) |

## Output Location

Save to `docs/session-[quest-slug].html` where `quest-slug` is the quest name lowercased with hyphens. Example: `docs/session-through-mists-of-smoke-and-forests-dark.html`.
