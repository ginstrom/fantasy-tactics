# Minor Fixes and Encounter Loot — Plan Index

**Goal:** Implement every section of [`docs/plans/minor-fixes.md`](../minor-fixes.md)
— random name choice, Warrior hit points, the Encampment's starting
location, the Selling Loot dialog, and the new Encounter Loot section (a
per-encounter gold bonus plus a shared, reusable loot table used by the
victory summary and the World Map's Party Details screen).

**Design reference:** `docs/plans/minor-fixes.md` is the durable spec these
steps implement; read it first. The decisions below fill in the details
that spec doesn't spell out — don't re-litigate them mid-implementation:

- The encounter gold bonus's "level" is the expedition's existing 1-3 star
  `difficulty` field (`EXPEDITIONS[id].difficulty`), not adventurer level —
  `randi_range(0, 5) * difficulty`, rolled once per encounter clear.
- "Same format as the Stores screen" becomes one new reusable component,
  `LootTable` (`scenes/ui/loot_table.tscn` / `scripts/ui/loot_table.gd`),
  wrapping a data-only `TableView` (Name/Type/Count/Price) plus a
  `[View]` button that opens `LootDetailPanel` — a real `PanelContainer`
  with real, text-labeled `[Sell]`/`[Equip]` buttons, not per-row `Tree`
  buttons (Godot's `Tree` control is icon-only, discovered during Step 4's
  manual verification). Stores, the victory summary, and the World Map's
  Party Details screen all instance it instead of each hand-rolling their
  own table + button glue. Gold is never a row in this table (it isn't in
  `banked_gear`/`mana_crystals` either) — every screen that shows loot
  gold keeps showing it as a separate label alongside the table.
- Only Stores and World Map Party Details ever offer `[Equip]`; the
  victory summary shows a **read-only** loot table (`configure(false,
  false)`, no `[Sell]`, no `[Equip]`) — it's a frozen snapshot of one
  battle's own drops, never re-read after it's shown, so letting the
  player mutate live state through it would silently desync the two
  (discovered during Step 6's manual verification). Equipping gear from
  Party Details opens the existing `assign_equipment.tscn` screen scoped
  to one party's `member_ids` instead of the full roster, and returns to
  whichever screen sent it there. This needs two small `GameManager`
  additions — `assign_equipment_party_id` and `assign_equipment_origin`
  (`{ STORES, PARTY_DETAILS }`) — mirroring the existing `add_member_
  return_party_id` pattern.
- `GameSession.pending_gear` is a `Dictionary` (item id → count), the same
  shape `banked_gear` uses — not the `Array[String]` it started as. Party
  Details' party-scoped Equip always draws from this "party store" via
  `equip_item_from_party_store()`, never from the (encamped, often
  unreachable) bank — freshly-dropped battle loot isn't banked until the
  party actually returns home. This was discovered and fixed during Step
  6's manual verification, alongside the decision to drop Equip from the
  victory screen entirely rather than make its frozen snapshot track live
  state; see that step's fix notes for the full rationale.
- The World Map's Party Details table reads `GameSession.pending_gear`/
  `pending_mana_crystals` (everything the deployed party is carrying,
  itemized) — never `banked_gear`/`mana_crystals` (Stores' inventory).
  Party Details for an *encamped* party shows no loot table at all, because
  `deposit_pending_reward()` has already moved that loot into
  `banked_gear`/`mana_crystals` by the time a party is back at the
  Encampment.
- `GoldLabel` on Party Details keeps showing `GameSession.gold` (banked
  gold), unchanged — this plan does not touch that label's meaning, only
  adds the loot table beside it. Fixing it to show pending gold while
  deployed is out of scope here.

## Steps

Do these **in order** — later steps depend on fields/components earlier
steps add.

1. [Random name choice](01-random-name-choice.md) — independent, do first
   to warm up on this codebase's conventions.
2. [Warrior hit points](02-warrior-hit-points.md) — independent, a config
   constant change.
3. [Encampment location](03-encampment-location.md) — independent, touches
   `GameSession`, `world_map.gd`, and a wide set of tests that hardcode the
   old settlement position.
4. [Selling Loot: the shared LootTable component](04-selling-loot-and-shared-loot-table.md)
   — the foundational step. Adds `TableColumn.button_visible`, the
   `LootTable` component, the Rimworld-style sell quantity dialog, and
   migrates Stores onto all three. Steps 6 and 7 depend on `LootTable` and
   `GameSession.build_loot_rows()` from this step.
5. [Encounter bonus gold](05-encounter-bonus-gold.md) — independent of
   Step 4; touches only `GameSession.complete_current_encounter()`.
6. [Victory summary loot table](06-victory-summary-loot-table.md) —
   depends on Step 4's `LootTable`/`build_loot_rows()` and adds the
   `assign_equipment_party_id`/`assign_equipment_origin` scoping Step 7
   reuses.
7. [World Map Party Details loot table](07-party-details-loot-table.md) —
   depends on Step 4's `LootTable` and Step 6's Assign Equipment scoping.

## Shared workflow (every step)

Per `AGENTS.md`:

1. `git checkout main && git pull`
2. `git checkout -b <branch-name>` (branch name given in each step)
3. Implement with TDD (red/green), verify with `make check`.
4. Manual verification via `make play` (each step lists what to look at;
   the debug menu — **FN+F9** from any campaign screen — has scenario
   shortcuts referenced per step; see
   [docs/dev/running-the-game.md](../../dev/running-the-game.md)).
5. Commit.
6. `git checkout main && git merge <branch-name>`, then delete the branch.
   Only push to `origin` or open a PR if the user asks.

Do not start a step's branch until the previous step is merged to `main`.

## Full-suite regression check

After all seven steps are merged, run `make check` once more from `main` to
confirm nothing regressed end-to-end, and manually play a full loop (new
game → create + name a party → deploy → clear the Goblin Camp → view the
victory summary's loot table → return to the World Map → View Party → check
its loot table → return to the Encampment → check Stores and that Party
Details no longer shows a loot table there).
