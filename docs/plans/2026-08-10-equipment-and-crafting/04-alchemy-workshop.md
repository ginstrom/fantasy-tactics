# Step 4 — Alchemy Workshop

## Milestone

The Alchemy Workshop crafts Healing Potions into Encampment Stores after seven
World Map Turns. Adventurers carry up to ten items, can transfer a carried
item in battle for 2 AP, and consume a held healing potion with a separate
2-AP action.

## Contract

- Build Level 1 for 50 gold; upgrade to Level 2 for 50 gold.
- Exactly one workshop job may run at a time. Completion after seven World
  Map Turns is snapshot-safe and puts the result in Stores.
- Level 1 crafts a 1-6 HP Healing Potion for 10 gold and one mana crystal.
- Level 2 additionally crafts a 2-8 HP Greater Healing Potion for 20 gold
  and one tier-2-or-higher mana crystal.
- Each adventurer carries at most ten individual items, including weapon,
  armor, and potions. Stores are virtual loot storage, not battle inventory.
- A living active player unit transfers an item it carries to a living ally
  with capacity for 2 AP. The action is atomic on failure.
- A living active player unit uses a held potion on itself for 2 AP. Healing
  is capped at maximum health; successful use consumes exactly one potion;
  failed/full-health attempts consume neither AP nor an item; potions cannot
  revive.
- Level 3, tonics, permanent alchemical enhancements, and timed effects are
  deferred until their own approved design.

## Red/green delivery

Branch as `feat/alchemy-workshop`. Add failing tests first for workshop
cost/material/job gates, job persistence/completion, per-adventurer item
capacity and snapshot persistence, transfer validation, and potion action
atomicity/healing bounds. Implement durable inventory and workshop APIs in
`GameSession`, then battle legality in `BattleController`, then the workshop
and inventory UI. Run focused GUT tests after each red/green cycle, then
`make check`, `godot --headless --path . --editor --quit`, mixed combat
simulations, and `git diff --check`. Use `make play` to craft each potion,
equip it before deployment, transfer one item, and use each potion. After
user signoff, commit, merge locally, delete the branch, and do not push.

## Implementation tasks

### Task 1: Durable workshop and carried-inventory contract

**Files:**

- Modify: `scripts/autoload/game_session.gd`
- Modify: `scripts/save/campaign_snapshot.gd`
- Test: `tests/unit/test_game_session.gd`

1. Add failing `GameSession` tests for build/upgrade/recipe resource gates,
   one job, seven-turn completion, and a snapshot round trip/rejection case.
   Run the selected tests and observe missing alchemy APIs.
2. Add failing tests for a ten-item total carried limit across existing weapon
   and armor arrays plus a new potion inventory; test Store-to-inventory
   transfer and snapshot validation before coding those APIs.
3. Add `alchemy_workshop_level`, `alchemy_craft_job`, the two potion catalog
   definitions, recipe lookups, atomic build/upgrade/start APIs, and the
   completion advancement beside the Blacksmith implementation. Add durable
   snapshot fields and all-or-nothing import validation.
4. Add a single `get_carried_item_ids()` capacity helper plus Store
   equip/unequip support for the `potion` slot. Preserve existing active
   weapon and armor semantics.
5. Re-run the focused tests until green and commit the durable-model change.

### Task 2: Battle transfer and healing actions

**Files:**

- Modify: `scripts/battle/battle_controller.gd`
- Modify: `scripts/battle/battlefield.gd`
- Modify: `scenes/battle/battlefield.tscn`
- Test: `tests/unit/test_battle_controller.gd`

1. Add failing controller tests that show transfer costs 2 AP only when the
   acting player owns the item and the living allied recipient has capacity.
   Include inactive/dead/full recipient and insufficient-AP atomicity cases.
2. Add failing tests for held-potion use: 2 AP, deterministic range, cap at
   maximum health, one-time consumption, and no-op attempts at full health,
   no stock, wrong side, death, or insufficient AP.
3. Add public controller actions that validate before decrementing AP, call
   the `GameSession` carried-item transfer/consumption APIs, update the live
   `Unit.health`, and publish a structured last-action result.
4. Add the smallest Battlefield controls necessary to select a held potion
   and a recipient for transfer; refresh them from controller state after an
   action. Do not add a parallel action pool.
5. Run selected controller/UI tests until green and commit the battle change.

### Task 3: Workshop and Stores UI

**Files:**

- Create: `scripts/ui/alchemy_workshop.gd`
- Create: `scenes/ui/alchemy_workshop.tscn`
- Modify: `scripts/ui/buildings.gd`
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `translations/en.tres`
- Modify: `scripts/ui/assign_equipment.gd`
- Test: `tests/unit/test_alchemy_workshop.gd`
- Test: `tests/unit/test_buildings.gd`
- Test: `tests/unit/test_game_manager.gd`
- Test: `tests/unit/test_assign_equipment.gd`

1. Add failing routing/UI tests for the Alchemy Workshop Buildings row, build
   and upgrade prices, recipe availability by level/materials, and countdown.
2. Add failing assignment-screen tests proving potions may be equipped from
   Stores only when an adventurer has a free total item slot.
3. Add the scene, controller, routing constant/method, building row, and
   translations. Follow the Blacksmith refresh/selection pattern; the screen
   only invokes `GameSession` validation.
4. Extend the existing assignment flow to show a potion item as a carried
   item rather than selecting an active equipment pointer.
5. Run focused UI tests until green and commit the presentation change.

### Task 4: Full verification and handoff

1. Run `make check`, `godot --headless --path . --editor --quit`, and `git
   diff --check`; resolve any failures with a new red test before a fix.
2. Run the relevant mixed combat simulation/smoke route without changing
   campaign state in the simulator.
3. Ask the user to run `make play`: build and upgrade the workshop, craft
   each potion, wait seven World Map Turns, equip it from Stores, transfer it
   in a party battle, then consume it.
4. After explicit user signoff, commit any final changes, merge
   `feat/alchemy-workshop` into local `main`, delete the branch, and do not
   push.
