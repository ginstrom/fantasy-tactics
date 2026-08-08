# Trade: Equipment, Loot, and UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development`
> (recommended) or `superpowers:executing-plans` to implement this plan
> task-by-task.

**Goal:** Replace the game's fixed combat-damage constants and flat
per-expedition gold reward with a full equipment and loot economy: player
damage is rolled from the equipped weapon's range and reduced/mitigated by
armor, enemies drop gold/mana crystals/gear per kill instead of a flat
reward, and a new Trade destination (Stores, Trading Post, Assign Equipment)
lets the player bank, sell, buy, and equip everything that system produces.

**Architecture:** This plan combines three previously separate specs — this
directory supersedes `docs/plans/trade-equipment-and-combat-plan.md`,
`docs/plans/trade-loot-system-plan.md`, and `docs/plans/trade-ui-plan.md`,
which were single flat files rather than the directory-per-plan,
file-per-task structure `AGENTS.md` calls for; their content lives on here,
resequenced into one dependency-ordered task list. `docs/plans/trading-system.md`
remains the authoritative design source for every number in this plan
(damage ranges, prices, defense/resistance, loot tables) — do not deviate
from its documented constants without checking back with the user. The
implementation itself has three architectural layers, delivered in three
phases:

- **Phase A — Equipment & Combat** (Tasks 01-05): `GameSession` gains
  `WEAPONS`/`ARMORS` content-table consts (matching the existing
  `EXPEDITIONS`/`STAR_ENEMY_COMPOSITIONS` convention of plain `Dictionary`
  consts) and an `equipment` field on every adventurer record, with derived
  `get_effective_*` getters mirroring the existing pattern. `BattleController`
  reads those getters when fielding the player's `Unit`s instead of the
  hardcoded `WARRIOR_ATTACK_DAMAGE` constant, and gains an injectable
  `damage_roll` callable (mirroring the existing `hit_roll` callable) so
  damage rolls are deterministic in tests. Enemies are **not** migrated onto
  the weapon/armor system in this plan — `GOBLIN_ENEMY_STATS`/
  `ORC_ENEMY_STATS` keep their existing fixed `attack_damage`/`hit_chance`,
  so existing enemy balance and every enemy-only test is unaffected. Only
  the player side gains weapon-driven damage and armor-driven
  defense/resistance; enemies default to `defense=0`/`resistance=0`
  (unarmored).
- **Phase B — Loot** (Tasks 06-08): depends on Phase A's `GameSession.WEAPONS`
  catalog for gear-drop item ids. All new logic lives in `GameSession`,
  following the same shape as the existing `pending_reward` →
  `deposit_pending_reward()` flow: `complete_current_encounter()` rolls loot
  into new `pending_*` fields instead of adding a flat `reward` to
  `pending_reward`, and `deposit_pending_reward()` moves every pending field
  into its permanent counterpart. Two new injectable `Callable`s
  (`loot_gold_roll`, `loot_gear_roll`) mirror the existing `hit_roll`/
  `enemy_composition_roll` pattern. `InformationPanel` gains one new
  always-present row read directly from `GameSession` state. **Scope
  boundary:** the design doc's loot table lists four enemy types (kobold,
  goblin, orc, hobgoblin), but only goblin and orc are currently fightable
  (`GameSession.STAR_ENEMY_COMPOSITIONS` never resolves to kobold or
  hobgoblin). This plan defines all four loot-table rows as data so the
  table matches the design doc exactly, but only the goblin and orc rows are
  reachable through actual gameplay today — that gap is deliberate, not a
  bug.
- **Phase C — Trade UI** (Tasks 09-16): depends on both Phase A
  (`WEAPONS`/`ARMORS`/`get_item_definition`/`equipment` field) and Phase B
  (`banked_gear`/`mana_crystals`) being in place. Every new screen follows
  the codebase's existing camp-screen skeleton exactly (`Body: HBoxContainer`
  → `CampNav` instance + `Center: CenterContainer` → `VBox`, per
  `docs/UI-Layout-Design-Guidelines.md`), and every "list + pick one + act on
  it" screen follows `recruitment.gd`'s row-selection-drives-a-gated-action-
  button pattern. All new gameplay rules (purchase/sell/buy/equip
  validation) live on `GameSession`, matching `docs/dev/code-map.md`'s
  "GameSession owns rules, screens are thin views" split. **Scope boundary:**
  the design doc's "will be able to upgrade the trading post over time" is
  future tense with no specified tiers — this plan ships a Trading Post with
  fixed income and a fixed catalog; upgrade tiers are a follow-up.
- **Task 17** closes the plan: full regression sweep, editor sanity check,
  manual verification, and merge back to `main`.

**Tech Stack:** Godot 4 / GDScript, GUT 9.7.1 test framework.

---

## Scope and sequencing

Read [`docs/plans/trading-system.md`](../trading-system.md) first — it is
the approved design spec this plan implements. Also keep
[`docs/plans/first-playable-campaign/game-design.md`](../first-playable-campaign/game-design.md)
in view: this plan delivers "Next work" item 1 from that document (a second
gold-funded, expedition-facing decision beyond party size — here, weapons,
armor, and the Trading Post).

Deliver the tasks in order — later tasks assume every earlier task's
interfaces already exist, and several steps below rely on that fixed
ordering (e.g. Task 06 assumes Task 01's `WEAPONS` const already exists at a
known location, rather than hedging for either order):

**Phase A — Equipment & Combat**
1. [01-weapon-and-armor-catalogs.md](01-weapon-and-armor-catalogs.md) —
   `GameSession.WEAPONS`/`ARMORS` content tables and `get_item_definition()`.
2. [02-adventurer-equipment-field.md](02-adventurer-equipment-field.md) —
   adventurer `equipment` field and effective-equipment getters/setters.
3. [03-unit-damage-range-and-armor.md](03-unit-damage-range-and-armor.md) —
   `Unit` carries a damage range plus defense/resistance instead of a fixed
   damage int.
4. [04-battle-controller-weapon-damage-and-armor.md](04-battle-controller-weapon-damage-and-armor.md)
   — `BattleController` rolls weapon damage and applies defense/resistance.
5. [05-equipment-code-map-update.md](05-equipment-code-map-update.md) —
   update `docs/dev/code-map.md`'s domain-model section.

**Phase B — Loot**
6. [06-loot-tables-and-roll-callables.md](06-loot-tables-and-roll-callables.md)
   — loot-table data and injectable roll callables on `GameSession`.
7. [07-roll-and-bank-loot.md](07-roll-and-bank-loot.md) — roll loot on
   encounter completion and bank it on deposit.
8. [08-carried-loot-information-panel.md](08-carried-loot-information-panel.md)
   — show carried (unbanked) mana crystals and gear in the party's
   `InformationPanel`.

**Phase C — Trade UI**
9. [09-trading-post-and-item-rules.md](09-trading-post-and-item-rules.md) —
   `GameSession` trading-post and item buy/sell/equip rules.
10. [10-game-manager-trade-routing.md](10-game-manager-trade-routing.md) —
    `GameManager` routing for Trade, Stores, Trading Post, Assign Equipment.
11. [11-camp-nav-trade-button.md](11-camp-nav-trade-button.md) — enable the
    Trade button in `CampNav`.
12. [12-trade-screen.md](12-trade-screen.md) — Trade screen (Stores +
    Trading Post purchase gate).
13. [13-stores-screen.md](13-stores-screen.md) — Stores screen.
14. [14-trading-post-screen.md](14-trading-post-screen.md) — Trading Post
    screen.
15. [15-assign-equipment-screen.md](15-assign-equipment-screen.md) — Assign
    Equipment screen.
16. [16-screenshot-tour-and-code-map.md](16-screenshot-tour-and-code-map.md)
    — screenshot tour and `code-map.md` updates for the new screens.

**Close-out**
17. [17-integration-regression-and-merge.md](17-integration-regression-and-merge.md)
    — full regression sweep, manual verification, merge to `main`.

Phase A Tasks 01-04 have an expected mid-phase red state: Task 03 rewrites
`Unit` alone, which leaves `test_battle_controller.gd`/`test_debug_menu.gd`/
`test_game_manager.gd` failing until Task 04 updates every call site — this
is called out explicitly in both task files so it isn't mistaken for a
regression.

## Shared delivery protocol

Per `AGENTS.md`'s branching workflow — one regular branch off `main` for the
whole plan, no worktree:

1. `git checkout main && git pull`, then
   `git checkout -b feat/trade-equipment-loot-and-ui`.
2. Work the tasks in the order above. For every behavior change, add the
   named GUT test, run it red, implement the smallest code path, and rerun
   it green — each task file's own steps already sequence this. Commit each
   completed task separately, staging only that task's files, using the
   commit message given at the end of that task file.
3. Run the full suite before moving to the next task:

   ```bash
   make test
   ```

   (equivalently `godot --headless -s addons/gut/gut_cmdln.gd -gexit`). A
   focused run against one file looks like:

   ```bash
   godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_session.gd -gexit
   ```
4. Do not skip ahead to Task 17's manual verification and merge until Tasks
   01-16 are all committed and `make test` is green.

## Definition of done

- Player damage is rolled from the equipped weapon's range each attack;
  equipped armor reduces incoming to-hit chance and incoming damage.
  Enemies are unaffected (still fixed damage/hit chance, unarmored).
- Completing an encounter queues rolled gold, a mana crystal, and a chance
  of gear per kill instead of a flat reward; the party's `InformationPanel`
  shows what's carried but not yet banked; returning to the Encampment banks
  everything.
- The Trade button in `CampNav` is enabled and routes to a Trade screen
  listing Stores (always) and Trading Post (once purchased for 50 gold).
  Stores lists every banked gear item and mana crystal stack with sell
  (Trading-Post-gated) and assign actions. Trading Post lists the full
  weapon/armor catalog with a gold-gated buy action. Assign Equipment swaps
  a banked item onto a chosen adventurer, returning the previously-equipped
  item to the bank.
- `make test` prints `---- All tests passed! ----` and exits 0. The
  screenshot tour and `docs/dev/code-map.md` reflect the new screens.
- The branch is merged into `main` after the user has manually verified the
  full loop via `make play`.
