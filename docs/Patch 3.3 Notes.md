# Patch 3.3

# Patch 3.3

## Multiplayer Overhaul

The game no longer requires an internet connection or the external server to play. Multiplayer now works directly between your computers over your local network (or the internet if you enter an IP address). When the DM hits "Host Game" the client opens up for players to join, no server middleman involved.

* When you hit "Join" you'll now see any hosts on your network show up automatically in a list. Just pick one and you're in.
* You can also manually type in an IP address to connect to someone not on the same network. Any host you successfully connect to is automatically saved so you don't have to type it in again next time — saved hosts show up in the list labeled as `[Saved]`.
* If you get disconnected mid-session (say your wifi hiccups), the client will now automatically try to reconnect up to 5 times. If it reconnects, all your data syncs back up automatically. You'll see a "Reconnecting to host..." popup while it's working on it.

## Battle System

The way effects work in combat has been completely rebuilt from the ground up. All weapon effects, artifact set bonuses, companion passives, and enemy passives now run through one unified system. What this means for you:

* **Your weapon and artifact effects actually work now.** Previously a lot of these were either not applying or had to be manually tracked. Now things like "deal +2 damage on reaction" or "+30% HP from weapon passive" are automatically calculated when they should be.
* **Companion and enemy passives are active in battle.** For example, Bennett's "Benny's Luck" passive now properly gives the entire party the Unlucky status when he's in your party during a fight (as intended, sorry not sorry). Ruin Grader's Iron Plating (physical immunity) and Shock Absorbers (multi-hit nullification) also now function automatically.
* **Effects display on your battle cards.** You can see how many effects are active on any character or enemy, and hovering over them shows what they are, where they come from, and how long they last.
* **Luck now affects combat.** If your luck is high (85+) your crit threshold is easier to hit. If it's low (25 or below) crits become harder. If Bennett is your active companion, everyone's luck drops by 25% — and in battle, everyone gets the Unlucky status for the whole fight.
* **Battle end is now automatic.** When all enemies or all players hit 0 HP, the battle ends on its own. No more manually checking the "Killed" box — it detects it from health values. All cleanup (resetting cooldowns, restoring health, clearing elements, removing enemies) is handled automatically when the battle wraps up.
* **Stun is handled automatically.** If you're stunned, the client will skip your turn for you and tell the host. No more guessing if it worked.
* **Battle summary screen.** After every battle, everyone gets a summary showing per-combatant stats and who dealt the most damage.

## New Unified Battle Screen

The battle screen has been completely rebuilt into a single screen that works for both the DM and players. It's a 3-column layout with resizable panels — you can drag the dividers to customize how much space each section gets, and your layout saves between sessions.

* **Ability info chips** — when you pick an attack, you'll see chips below the dropdown telling you the element, which stat it rolls against, and any special effects it has.
* **Passive abilities are hidden from the attack dropdown.** You won't accidentally try to "use" a passive anymore.
* **DM Hub button in battle** — The DM now has a purple "DM HUB" button in the battle action bar that opens the DM tools as a floating window without leaving the battle screen. Enemy and party cards refresh when you close it.
* **Unspent points banner** — If you have unspent skill or base stat points, a gold banner shows up reminding you. You can dismiss it.

## DM Tools

* **Data Editor** — New tab in the DM Hub that lets the DM directly edit any record in the game. Pick a table (Characters, Companions, Weapons, Artifacts, etc.), pick a record, and edit any field. Includes the ability to create new records and delete existing ones.
* **Artifact Generator** — When giving out artifacts, the DM now enters the dice rolls (D10 for set, D12 for piece type, D20 for substat count, etc.) and the system automatically generates the artifact with the correct stats, piece type, and set. No more manually building artifact records.

## Artifact Forge (Artisan Role)

If you have the Artisan role, you now have access to the **Artifact Forge** in the Crafting menu. This lets you sacrifice artifacts you don't want to create new ones:

* **Random Set mode** — sacrifice 2 artifacts to get a random new one
* **Choose Set mode** — sacrifice 3 artifacts to pick which set it comes from

You'll enter your dice rolls for the piece type, substats, stat types, and values. The forge walks you through it step by step. There's a confirmation popup before any sacrifice so you don't accidentally trash something valuable.

## Crafting Updates

* **Gem crafting recipes** are now fully functional — upgrades (2-star to 3-star, 3-star to 4-star) and downgrades (4-star to 3-star, etc.) for all 7 elements.
* **Generic material matching** — some recipes now accept "any 2-Star Gem" rather than requiring a specific element, making crafting more flexible.
* **Recipe variants** — if an item can be crafted multiple ways, all recipe options are shown when you expand it. Filter chips let you quickly see what you can craft now vs what you're missing materials for.

## Sumeru Content

### New Enemies (26)

A bunch of new enemies have been added for Sumeru across all tiers:

**Epic**
* **Ruin Grader** — The first Epic-tier enemy in the game. 250 HP, takes up 2 tiles, has 7 abilities including a global attack that hits ALL players, and two passives: immune to Physical damage and multi-hit/AoE abilities only deal their first hit to it. Good luck.

**Rare**
* Ruin Drake, Eremite Floral Ring Dancer, Eremite Galehunter, Eremite Scorching Loremaster, Eremite Stone Enchanter — each with 3 abilities and a status effect they can inflict (Stun, Unlucky, Disadvantage, Overheated, and Slow respectively).

**Uncommon**
* Ruin Defender, Ruin Destroyer, Eremite Sword Dancer, Eremite Desert Clearwater, Eremite Linebreaker, Eremite Ravenbeak Halberdier, Eremite Sunfrost, Grounded Earth Shroom, Grounded Water Shroom, Winged Ice Shroom, Winged Nature Shroom

**Common**
* Floating Nature/Water/Wind Fungus, Stretchy Earth/Electric/Fire/Wind Fungus, Whirling Electric/Fire/Ice Fungus — the small fry fungus enemies you'll encounter in Sumeru's wilderness.

### New Weapons (21)

**Craftable (Rare)**
* Sapwood Blade (Sword), Forest Regalia (Claymore), Moonpiercer (Polearm), Kings Squire (Bow), Fruit of Fulfillment (Catalyst) — all craftable from Sumeru materials.

**Epic** (from Sumeru Epic Weapon Billet)
* Xiphos Moonlight, Makhaira Aquamarine, Missive Windspear, End of the Line, Wandering Evenstar, Toukabou Shigure, Mailed Flower, Ibis Piercer

**Legendary** (from Sumeru Legendary Weapon Billet)
* Key of Khaj-Nisut, Light of Foliar Incision, Staff of the Scarlet Sands, Tulaytullahs Remembrance, A Thousand Floating Dreams, Jadefalls Splendor, Beacon of the Reed Sea, Hunters Path

**Player Signature Weapons** — Dylan, Brian C., and Brian F. each have a Legendary weapon tailored specifically to their builds. You'll know them when you find them.

### New Materials (16) & Caches (4)

Four new gathering caches for Sumeru: Rainforest, Desert, Fungal/Foraging, and Ruins & Eremite. Each has 4 unique materials. If you're gathering in Sumeru you'll be rolling from these tables.

### New Food (8 dishes)

Eight new Sumeru dishes with various effects:
* **Candied Ajilenakh Nut** — +3 ATT for entire party for 1 battle
* **Padisarah Pudding** — +3 EM for entire party for 1 battle
* **Lambad Fish Roll** — 2 HP/turn healing for 10 turns
* **Tahchin** — Double gathering materials
* **Aaru Mixed Rice** — +2 to all attack rolls for 1 battle
* **Biryani** — +2 damage on all attacks for entire party for 1 battle
* **Shawarma Wrap** — -2 damage taken per hit for entire party for 1 battle
* **Sabza Meat Stew** — Restore 1d12 Burst Charges instantly

### New Artifact Sets (8)

Deepwood Memories, Desert Pavilion Chronicle, Echoes of an Offering, Flower of Paradise Lost, Gilded Dreams, Nymphs Dream, Vermillion Hereafter, Vourukashas Glow

## Luck System Updates

Luck has been expanded to affect more things:

* **Market prices** — Good luck gives you small discounts when buying. Bad luck inflates prices.
* **Gathering yields** — High luck (85+) gives +2 extra materials per slot. Low luck (10 or below) gives -2. Scaled in between.
* **Combat crits** — As mentioned above, luck now makes crits easier or harder.
* **Bennett's passive** — Having Bennett as your active companion reduces everyone's luck by 25%. In battle, this also applies the Unlucky status to the whole party.

## Minigames

### Minigame Selector

The minigames menu has been rebuilt as a card grid showing each available minigame with a preview image and your high score.

### Ninguang's Golden Parlor (New)

A new slot machine minigame has been added. Bet Mora across three tiers and spin for payouts. Has color-coded paylines that light up on wins and coin cascade sound effects. The return rates are balanced per bet tier so you won't get rich but you won't go broke either — it's gambling, you know how it works.

### Klee's Fish Blast

Score threshold rewards have been added — do well enough and you earn materials. Fish timing has been tightened up so it feels more responsive.

## Quality of Life

* **Font scaling** — New setting to scale all text from 50% to 150% of default size. Accessible from the Settings menu.
* **Volume control** — Separate Music and SFX volume sliders that save between sessions. You can mute one without muting the other.
* **Resizable panels everywhere** — Battle screen, crafting menu, weapons/artifacts detail views, and companions overview all have draggable panel dividers now. Your layout preferences save automatically.
* **Battle turn alert** — When it's your turn in battle, the game window comes to the foreground. If you still haven't done anything after 5 seconds it flashes the screen red to get your attention. You're welcome, Brian.
* **Brian's notes backup** — When Brian F. closes the client, it now prompts to back up his notes file. The notes get sent to the host automatically via the network so nothing gets lost.

## Market Performance

The market no longer freezes the game while it loads stock. All stock generation now happens in the background — you can keep using the client while it loads. The market also no longer needlessly refreshes every time you open it; stock only refreshes when you come back from a battle.

## Bug Fixes

* Companions set as "Always Active" by the DM now properly show up in battle (previously required being manually player-chosen)
* Fixed several crashes caused by null values in burst charges, ability IDs, and target IDs
* Shield damage calculation now correctly triggers Shield-Break when damage exactly equals shield health (was off by 1)
* Status effects from abilities now properly apply to ALL selected targets instead of just the first one
* Fixed burst charge race condition where burst cost could be double-subtracted
* Ability cooldowns now properly reset for ALL characters when battle ends, not just the person who ended it
* Fixed various weapon and artifact stat calculation errors
