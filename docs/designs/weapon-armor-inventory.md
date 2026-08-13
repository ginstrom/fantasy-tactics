# Weapon and Armor Inventory

## Scope

Both weapons and armor are per-unit inventories. A unit only ever
*fights* with one weapon and wears one armor piece at a time — the
"active" item in each slot — but it can carry others alongside without
losing them.

No cap on how many items a unit can carry per slot (matches this project's
"connected loop before system depth" principle — a cap can be added later
if it turns out to matter).

Combat itself is unaffected: a unit still fights with exactly one weapon
for the whole battle (unchanged from today — no in-battle weapon
switching), it just comes from a richer bookkeeping model on the campaign
side.

## Data model

### Data Representation and Stacking

All items share a uniform data representation. Unimproved base weapons and armor simply have empty enhancement slots and can be stacked in Stores and Shops. Improved gear populates its enhancement slots (`smithing`, `enchantment`, `runes`). In Shops and Stores, items stack like-with-like:

```text
Item                         Type     Qty   Sale Price
Iron Longsword               Weapon   3     10
Sharpened Iron Longsword     Weapon   1     10
```

`adventurer.equipment` has two array fields alongside the existing
scalar pointers, which keep their exact current meaning:

```gdscript
"equipment": {
    "weapon": "longsword_iron",              # active weapon — unchanged meaning
    "weapon_inventory": ["longsword_iron"],  # everything carried; always includes the active id
    "armor": "leather_armor",                # active armor — unchanged meaning
    "armor_inventory": ["leather_armor"],    # everything carried; always includes the active id
}
```

**Invariant:** `equipment.weapon` is always a member of
`equipment.weapon_inventory` (same for armor) — never a dangling pointer to
an item the unit doesn't actually carry.

A fresh Warrior starts with both inventories containing just its one
starting item (`get_default_warrior()`'s existing
`{"weapon": DEFAULT_WEAPON_ID, "armor": DEFAULT_ARMOR_ID}"` becomes
`{"weapon": DEFAULT_WEAPON_ID, "weapon_inventory": [DEFAULT_WEAPON_ID],
"armor": DEFAULT_ARMOR_ID, "armor_inventory": [DEFAULT_ARMOR_ID]}`).

**Why keep the scalar pointers at all, instead of just an array per slot
with "active" as a convention (e.g. index 0)?** Every existing combat and
display function —
`get_effective_weapon_damage_range`/`get_effective_weapon_name`/
`get_effective_armor_name`/`get_effective_defense`/
`get_effective_resistance`, `battle_controller.gd`'s unit-spawning code,
Unit Details' stat display — reads `adventurer.equipment.weapon`/
`adventurer.equipment.armor` directly today. Keeping those fields with
their current meaning means **none of that code changes at all**; only the
mutation logic (equip/activate/unequip) and the new inventory-browsing UI
need to know the array fields exist. The alternative (array-only, active =
index 0) is a cleaner single source of truth in principle, but it means
rewriting every one of those call sites — a much bigger, riskier diff for
a feature that's fundamentally about bookkeeping, not combat.

## GameSession API

Three methods replace today's single swap-based `equip_item_from_bank`:

### `equip_item_from_bank(adventurer_id: String, item_id: String) -> bool`

Requires `item_id` to currently be in `banked_gear` (same precondition as
today — an item a row's own screen no longer lists, because its bank count
already hit zero, is never reachable here). Makes `item_id` the active
item for its slot. If the unit doesn't already carry `item_id`, one unit
is taken from the bank and added to the matching slot's inventory array.
If the unit *already* carries that exact item — e.g. a second copy sits in
the bank while the first is already equipped — the bank is left untouched
and this call just re-activates the already-carried copy. Rejects (mutates
nothing) for an unknown item id or an unknown adventurer, exactly as
today. This replaces the current "previous item returns to the bank"
behavior entirely — nothing auto-unequips anymore.

### `activate_carried_item(adventurer_id: String, slot: String, item_id: String) -> bool`

Switches the active pointer (`equipment.weapon` or `equipment.armor`,
selected by `slot`) to `item_id`, which must already be present in that
slot's inventory array. No bank interaction. Rejects an item not carried
in that slot, an unknown slot, or an unknown adventurer.

### `unequip_to_bank(adventurer_id: String, slot: String, item_id: String) -> bool`

Removes `item_id` from that slot's inventory array and returns one unit to
`banked_gear`. Rejects if `item_id` is the slot's *active* item (the
player must activate something else first — a unit can never end up with
an empty active slot), if `item_id` isn't carried in that slot at all, or
for an unknown slot/adventurer.

## UI

### Assign Equipment

No visible change. Activating a row still equips that item to the
selected unit in one click and returns to wherever the screen was opened
from — it just calls the new `equip_item_from_bank` (add + activate,
never evicting anything) instead of the old swap.

### Unit Details

The current single `EquipmentLabel` line (one line of weapon+armor names
and stats) becomes two small sections, "Weapons" and "Armor" — each a
plain list of the adventurer's carried items in that slot, not the
Tree-based `TableView`. (`TableView`'s per-row buttons are icon-only —
Godot's `Tree` control has no way to show real text on a cell button, which
is exactly the problem `LootDetailPanel` was built to work around for
Stores' loot table. Unit Details' lists are typically 2-4 items, so a
hand-rolled `VBoxContainer` of rows — each a `Label` plus real `Button`
nodes — is simpler than pulling in `TableView` and hitting the same
limitation again.)

Each row shows the item's display name, an "(equipped)" marker on
whichever is currently active, and — for every *non-active* row only —
two real, text-labeled buttons: **[Activate]** and **[Unequip]**. The
active row shows neither button (there's nothing to activate, and it can't
be unequipped until another item takes its place).

## Testing approach

- `GameSession` gets direct unit tests for all three methods: adding a new
  item activates it without touching other carried items; equipping an
  already-carried item is a no-op on the bank but still (re-)activates it;
  activating a carried item requires no bank interaction and rejects an
  uncarried id; unequip rejects the active item and an uncarried item, and
  succeeds otherwise, returning exactly one unit to the bank.
- `unit_details.gd` gets tests for both sections rendering carried items
  correctly, the active marker, button visibility (present only on
  non-active rows), and that pressing Activate/Unequip calls through to
  the right `GameSession` method and refreshes the screen.
- Existing tests that assume swap-and-rebank semantics (search
  `equip_item_from_bank` across `tests/unit/`) need updating to the new
  add-and-activate behavior — this is expected to touch
  `test_game_session.gd`, `test_assign_equipment.gd`, and
  `test_full_trade_loop_integration.gd` at minimum.

## Out of scope (explicitly deferred, not silently dropped)

- **No carry cap.** Revisit if playtesting shows unlimited carrying is a
  problem (e.g. hoarding every dropped weapon "just in case").
- **No in-battle weapon switching.** A unit still fights with whichever
  weapon was active when the battle started, for the whole battle — this
  design only changes campaign-side bookkeeping.
- **No party-wide inventory view.** Carried items are only visible per-unit
  in Unit Details, not aggregated anywhere else.
