# Ninguang's Golden Slots & Minigame Selector Redesign

## Summary

Rebuild the MinigamesMenu as a proper card-grid game selector showing scores, and add a Ninguang-themed slot machine minigame that uses Mora as currency.

## Minigame Selector (MinigamesMenu rebuild)

### Layout
- Full-screen overlay (same Window pattern as all other panels)
- Title at top: "Minigames"
- Card grid below — each minigame is a styled PanelContainer card
- Close button in corner

### Card Contents
Each card displays:
- Game title (Label)
- Brief description (Label, smaller/dimmer)
- Overall high score across all players (Label: "Best: X")
- Personal best score for this player (Label: "Your Best: X")
- Entire card is clickable to launch the game

### Score Tracking
- Scores stored via existing `MinigameResult` system in SaveManager
- Each minigame result has: `minigame_key`, `player_name`, `score`, `timestamp`
- Overall high score = max score across all players for that game
- Personal best = max score for `Global.ACTIVE_USER_NAME` for that game
- Scores synced to host via `Global.Update_Records()` so all players see the same high scores

### Games Listed
1. **Klee's Fish Blasting** — existing game, needs score tracking wired in if not already
2. **Ninguang's Golden Parlor** — new slot machine (see below)

## Slot Machine: Ninguang's Golden Parlor

### Visual Theme
- Gold and jade color scheme (dark background, gold borders, jade accents)
- Title: "Ninguang's Golden Parlor"
- Ninguang-inspired luxury aesthetic

### Grid
- 3x3 grid of element symbols
- Uses existing element icons from the asset folder
- 7 symbols: Anemo, Geo, Pyro, Electro, Cryo, Dendro, Hydro

### Bet Tiers
- **50 Mora** — 1 payline (middle row only)
- **100 Mora** — 3 paylines (all 3 horizontal rows)
- **150 Mora** — 8 paylines (3 horizontal + 3 vertical + 2 diagonal)

Player selects bet tier before spinning. Bet buttons disabled if not enough Mora.

### Paylines (8 total at max bet)
- Row 0 (top): [0,0] [1,0] [2,0]
- Row 1 (mid): [0,1] [1,1] [2,1]
- Row 2 (bot): [0,2] [1,2] [2,2]
- Col 0: [0,0] [0,1] [0,2]
- Col 1: [1,0] [1,1] [1,2]
- Col 2: [2,0] [2,1] [2,2]
- Diag TL-BR: [0,0] [1,1] [2,2]
- Diag BL-TR: [0,2] [1,1] [2,0]

### Payout Table (per matching line)
| Match | Payout |
|-------|--------|
| 2x any element on a line | 10 Mora |
| 3x Anemo or Geo | 50 Mora |
| 3x Pyro or Electro | 100 Mora |
| 3x Cryo or Dendro | 200 Mora |
| 3x Hydro (jackpot) | 500 Mora |

Multiple winning lines on the same spin stack. Total winnings = sum of all winning line payouts.

### Reel Weights (per symbol)
Weighted random selection to make rare symbols less common:
- Anemo: weight 20
- Geo: weight 20
- Pyro: weight 15
- Electro: weight 15
- Cryo: weight 10
- Dendro: weight 10
- Hydro: weight 5 (rarest — jackpot symbol)

Total weight pool: 95. Each reel cell picks independently from these weights.

### Spin Animation
- All 3 columns start scrolling vertically simultaneously
- Columns stop left-to-right with ~0.3s delay between each
- Each column scrolls through ~8-12 random symbols before landing on the final result
- Brief bounce/settle effect when stopping
- After all columns stop, winning lines are highlighted (brief flash or glow on the winning cells)

### UI Layout
- Title at top: "Ninguang's Golden Parlor"
- Current Mora display (top right or below title)
- 3x3 grid centered (the reels)
- Payout table displayed on one side for reference
- Bet tier buttons below the grid: "50", "100", "150" — selected tier is highlighted
- "SPIN" button below bet selection — disabled during spin animation and if insufficient Mora
- Winnings display after spin resolves (e.g., "Won 260 Mora!" that fades after a moment)
- Close/back button to return to minigame selector

### Score Tracking
- "Score" for the slot machine = total Mora won in a single session (from opening to closing the game)
- Saved as MinigameResult on close, same as Klee's Fish Blasting
- Displayed on the minigame selector card

### Mora Transactions
- Deduct bet amount on spin start
- Add winnings on spin complete
- Use `Global.Update_Records()` with table "Party", field "Mora" — same pattern as Market purchases
- Mora display updates in real-time during play

## Files

### New
- `Scenes/NinguangSlots.tscn` — slot machine scene
- `Scenes/NinguangSlots.gd` — slot machine logic

### Modified
- `Scenes/MinigamesMenu.tscn` — rebuilt as card grid selector
- `Scenes/MinigamesMenu.gd` — rebuilt with score display, card layout, game launching

### Existing (reference only)
- `Scenes/KleeFishBlast.tscn` / `.gd` — existing minigame, may need score wiring
- `Scripts/resources/minigame_data.gd` — minigame metadata resource
- `Scripts/save/minigame_result.gd` — score result resource
