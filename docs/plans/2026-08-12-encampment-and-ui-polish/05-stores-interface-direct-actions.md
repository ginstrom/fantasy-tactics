# Step 5: Stores Direct Actions

> **Branch:** `feat/stores-direct-actions` (off updated local `main`)

## Setup

```bash
git checkout main && git pull
git checkout -b feat/stores-direct-actions
```

## Goal

Give Stores a direct `[View] [Sell] [Equip]` action row whose enabled states
match the selected item and the Shop's available cash, without changing action
presentation in Party Details or victory LootTables.

## Files

- Modify: `scripts/ui/loot_table.gd`, `scenes/ui/loot_table.tscn`, `scripts/ui/stores.gd`
- Test: `tests/unit/test_loot_table.gd`, `tests/unit/test_stores.gd`

## Contract and TDD

1. Extend `LootTable.configure()` with an explicit direct-action-bar mode.
   Stores enables it; Party Details and victory keep their current View/detail
   presentation, with unavailable direct actions hidden rather than shown as
   irrelevant disabled controls.
2. Add failing Stores tests: no selection disables all buttons; equippable gear
   enables View/Equip and enables Sell only when the Shop can afford the full
   sale price; mana crystals disable Equip; selection removal after refresh
   disables all controls.
3. Add failing handler tests: View opens detail, Equip emits the same item id,
   one-item Sell updates player gold, Shop gold, and Stores rows; multi-item
   sale waits for quantity confirmation; an underfunded/invalid sale leaves all
   state and rows unchanged.
4. Implement one selection-refresh method that recalculates all three buttons
   after rows, selection, Shop funds, or a successful sale change. Route all
   mutations through `GameSession`; the UI must never decrement Shop funds.
5. Run focused red/green tests, editor refresh, `make check`, and `git diff
   --check`. In `make play`, verify the three selection states and the
   cash-limited sale state; obtain signoff, merge locally, delete branch.
