# Battle Screen Redesign and Enhanced Combat Controls

## Goal

Implement the Baldur's Gate 1/2 inspired battle screen layout and combat interaction model specified in [`docs/battle-screen.md`](../../battle-screen.md):
1. **Two-tier movement range visualization**: Green range for move-and-attack reachable tiles; Yellow range for extended dash (move-only) tiles.
2. **Move-to-range-and-attack automation**: Targeting an enemy outside weapon attack range automatically pathfinds, moves into valid attack range/line-of-sight, and executes the attack if Action Points (AP) suffice.
3. **Bottom Action Bar and Action Modes**: Row of Move and Attack buttons, plus existing Item actions and End Turn, with button-only mode toggling and visual indicators.
4. **Dual unit inspection panel**: Right column displaying details for both the hovered unit (name, species, wound status/HP) and the selected unit (name, class, level, HP, AP, equipped weapon/attack).
5. **Baldur's Gate inspired layout**: Top header with battle/encounter title, left column party portrait stack with overlaid HP, full-width scrollable battle log that auto-scrolls to the bottom, and bottom action bar.

## Architecture and Design Contract

```
+--------------------------------------------------------------------+
|                 <Encounter Name> Battle                            |
+-----+---------------------------------------------+----------------+
| [1] |                                             | [Hovered Unit] |
|10/10|                 Grid (6x6)                  | Goblin Archer  |
| [2] |                                             | Wounded        |
| 8/10|       - Green: Move & Attack range          |----------------|
| [3] |       - Yellow: Move-only range             | [Selected Unit]|
| 8/10|       - Red/Target: Attackable enemies      | Warrior        |
| [4] |                                             | HP: 10/10      |
| 6/6 |                                             | AP: 3/9        |
|     |                                             | Longsword      |
+-----+---------------------------------------------+----------------+
| Warrior hits Goblin Archer for 8 points. (Log)                     |
+--------------------------------------------------------------------+
| Move  Attack  [Potion]  [Transfer]                    [End Turn]   |
+--------------------------------------------------------------------+
```

### 1. Range Calculations and Colors
- **Move-and-Attack Range (Green)**: Tiles reachable where `remaining_ap - move_distance * MOVE_AP_COST >= BASIC_ATTACK_ACTION_POINT_COST`.
- **Dash / Move-Only Range (Yellow)**: Tiles reachable where `remaining_ap >= move_distance * MOVE_AP_COST` but `remaining_ap - move_distance * MOVE_AP_COST < BASIC_ATTACK_ACTION_POINT_COST`.
- **Direct Attack Target (Red Highlight)**: Enemy units within active weapon attack range and line-of-sight.
- **Move-and-Attack Target (Orange Target Highlight)**: Enemy units reachable by moving to any green tile and attacking, but not directly attackable. This target overlay renders after green/yellow range fills and before the unit body so it is visible without hiding the unit.
- The origin tile is never returned by either movement-range method and is never painted as a movement tile: it is represented by the selection ring. Direct attacks from the origin are covered only by the red target overlay.

### 2. Auto Move-and-Attack Mechanics
- In Attack mode (or upon clicking an enemy target):
  - If the enemy is already in attack range and line-of-sight: spend attack AP (`BASIC_ATTACK_ACTION_POINT_COST`), execute the attack, and record the result.
  - If the enemy is not in attack range: search candidate movement tiles in green range that have line-of-sight and weapon range to the target. Choose the optimal tile (minimum movement path distance, reading order tie-break), move the unit, spend movement AP, and then execute the attack, spending attack AP.
  - The operation is atomic: a failed move-and-attack leaves position, AP, combat result, and board state unchanged except for the recorded targeting-feedback reason.
  - The battlefield has no terrain-obstacle model in this slice. Living units are the only path/line-of-sight blockers.
  - If the enemy cannot be reached, report one deterministic reason: `insufficient_ap` when a legal attack position exists but its move cost plus attack cost exceeds AP; `line_of_sight_blocked` when an affordable in-range position exists but every such line is blocked by a living unit; otherwise `out_of_range`.

### 3. Action Mode State Machine
- `ActionMode { CONTEXTUAL, MOVE, ATTACK }`
- `CONTEXTUAL` is the opening and reset mode. Selecting a player unit, returning control to the player, or completing a move/attack resets to it. It preserves current behavior: an empty legal tile moves, an enemy attempts auto move-and-attack, and a friendly unit selects.
- Clicking the **Move** button activates `MOVE`. In this mode, a legal empty tile moves; clicking an enemy only inspects it and reports move-mode feedback; clicking a friendly unit selects it.
- Clicking the **Attack** button activates `ATTACK`. In this mode, an enemy attempts direct/auto move-and-attack; an empty tile is a no-op with attack-mode feedback; clicking a friendly unit selects it.
- The Move and Attack buttons have **no keyboard shortcuts**. Existing WASD direct-step movement and `1`–`5` selection remain unchanged.

### 4. Dual Right-Hand Inspection Panel
- The right panel shows both:
  - **Hovered section**: Unit under mouse cursor (name, wound tier for enemies, HP/class for allies).
  - **Selected section**: Active unit (name, HP `%d/%d`, AP `%d/%d`, weapon/attack name, class, level).
- When hovered and selected units are identical or no hover is active, the panel focuses cleanly on the selected unit.

### 5. Layout and UI Hierarchy
- **Header Bar**: Displays `<Expedition Name> Battle` (e.g. "Goblin Camp Battle", "Orc Outpost Battle") and round indicator.
- **Left Portrait Panel**: Stack of party unit portraits with overlaid HP, selection indicator, and click-to-select.
- **Bottom Panel**: Full-width auto-scrolling combat log sitting above the action button row.

---

## Ordered Steps

| Step | Plan File | Milestone |
|---|---|---|
| 1 | [step-1-two-tier-range-visualization.md](step-1-two-tier-range-visualization.md) | Grid calculates and renders Green (move+attack) and Yellow (dash/move-only) ranges based on remaining AP. |
| 2 | [step-2-automated-move-and-attack.md](step-2-automated-move-and-attack.md) | Targeting an enemy outside weapon range automatically moves the unit into range and executes the attack if AP permits. |
| 3 | [step-3-action-modes-and-action-bar.md](step-3-action-modes-and-action-bar.md) | Button-only Move and Attack modes dispatch their defined board interactions without changing existing keyboard controls. |
| 4 | [step-4-dual-unit-inspection-panel.md](step-4-dual-unit-inspection-panel.md) | Right-hand unit panel displays both hovered and selected unit details (HP, AP, weapon name, wounds). |
| 5 | [step-5-battle-header-log-and-layout.md](step-5-battle-header-log-and-layout.md) | Battle header title, full-width auto-scrolling log, and Baldur's Gate inspired screen layout are fully integrated. |
| 6 | [step-6-end-to-end-verification-and-docs.md](step-6-end-to-end-verification-and-docs.md) | Full regression test suite (`make check`), documentation updates, and manual verification via `make play` are completed. |

---

## Acceptance Criteria

- Green range highlights every *destination* reachable where the unit retains enough AP to attack (`>= 3 AP` remaining after movement); the origin is represented only by its selection ring.
- Yellow range highlights all reachable tiles where the unit can move but has `< 3 AP` remaining after movement.
- Clicking an enemy out of weapon range automatically pathfinds to the closest valid attack tile and executes the attack if the combined AP cost is within budget.
- Action Bar renders Move and Attack buttons; clicking buttons switches modes and updates UI state, while existing WASD and `1`–`5` keyboard behavior stays unchanged.
- Right-hand inspection panel simultaneously displays hovered target info and selected unit info (including AP and equipped weapon).
- Combat log spans full width above the action bar and automatically scrolls to the bottom on every new entry.
- Header displays `<Expedition Name> Battle` for the active encounter.
- All unit and integration tests pass cleanly with `make check`.
- Non-interactive and headless tools (`make test`, `make simulate`) remain fully operational.

---

## Workflow

Each step is implemented on a dedicated branch off `main` using red/green TDD. After automated checks and manual verification with `make play`, the branch is merged locally into `main` and deleted upon user sign-off.
