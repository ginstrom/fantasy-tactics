# Weapon and Armor Inventory — Plan Index

**Goal:** Let an adventurer carry multiple weapons and multiple armor
pieces instead of exactly one of each — equipping a new item no longer
ejects the old one back to the bank. A unit still fights with exactly one
active weapon and wears one active armor piece per battle (unchanged); the
player can switch which carried item is active, or send a non-active one
back to the bank, from Unit Details.

**Design reference:** [`docs/designs/weapon-armor-inventory.md`](../../designs/weapon-armor-inventory.md)
— read it first. The decisions below fill in presentation details that
doc doesn't pin down; don't re-litigate them mid-implementation:

- `EquipmentLabel` (Unit Details' existing single-line "Weapon: X (dmg) —
  Armor: Y (defense/resistance)" summary) is **unchanged** — it already
  reads `adventurer.equipment.weapon`/`.armor`, which keep their exact
  current meaning (the *active* item), so it needs no edits at all. The
  new carried-items lists are **added below it**, not a replacement.
- Weapons/Armor rows are built at runtime in `unit_details.gd` (there's no
  static `.tscn` layout for a variable-length list) as plain
  `HBoxContainer`s of real `Label`/`Button` nodes — no `Tree`/`TableView`,
  for the same reason `LootDetailPanel` exists: `Tree`'s per-row buttons
  are icon-only. Each row's `Label` is named `NameLabel` and its buttons
  `ActivateButton`/`UnequipButton` so tests can address them by path.

## Steps

1. [GameSession: inventory data model and API](01-game-session-inventory-api.md)
   — `weapon_inventory`/`armor_inventory` fields, `equip_item_from_bank`
   rewritten to add-and-activate instead of swap, plus new
   `activate_carried_item`/`unequip_to_bank`. Do this first — Step 2's UI
   calls these methods.
2. [Unit Details: carried-items lists](02-unit-details-inventory-ui.md) —
   depends on Step 1's API.

## Shared workflow (every step)

Per `AGENTS.md`:

1. `git checkout main && git pull`
2. `git checkout -b <branch-name>` (branch name given in each step)
3. Implement with TDD (red/green), verify with `make check`.
4. Manual verification via `make play` (each step lists what to look at).
5. Commit.
6. `git checkout main && git merge <branch-name>`, then delete the branch.
   Only push to `origin` or open a PR if the user asks.

Do not start Step 2's branch until Step 1 is merged to `main`.

## Full-suite regression check

After both steps are merged, run `make check` once more from `main`, and
manually play through: recruit a Warrior, buy two weapons from the Trading
Post, equip both onto the same unit one after another, confirm neither
disappears from the unit's carried list, switch which is active from Unit
Details, and unequip the inactive one back to Stores.
