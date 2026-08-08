# Task 16: Screenshot tour and `code-map.md` updates

## Objective

Extend the developer screenshot tour and the Camp Navigation section of
`docs/dev/code-map.md` to cover the new Trade screens, per each doc's own
stated maintenance convention.

## Files

- Modify: `scripts/tools/screenshot_tour.gd`, `docs/dev/code-map.md`

## Depends on

Tasks 12-15 (every Trade screen must exist for the tour to route to it).

## Steps

1. **Add tour steps.** `scripts/tools/screenshot_tour.gd`'s own doc comment
   says to extend `_build_steps()` whenever a new scene or UI state is
   added. Add these entries to the array right after the existing
   `"guild_hall"` entry:

   ```gdscript
   			{"name": "trade", "action": func() -> void:
   				GameManager.go_to_trade()},
   			{"name": "stores", "action": func() -> void:
   				GameSession.banked_gear = {"shortsword_iron": 1}
   				GameSession.mana_crystals = {1: 2}
   				GameManager.go_to_stores()},
   			{"name": "trading_post", "action": func() -> void:
   				GameSession.gold = GameSession.TRADING_POST_PURCHASE_COST
   				GameSession.purchase_trading_post()
   				GameManager.go_to_trading_post()},
   ```

2. **Update `docs/dev/code-map.md`'s Camp navigation section.** Replace:

   ```
   It renders six
   buttons, but the Trade button is permanently `disabled` in
   the `.tscn` and has no `_on_trade_button_pressed()` handler; there's no
   Trade screen yet for it to route to.
   ```

   with:

   ```
   It renders six
   buttons, all enabled and routing through `GameManager` — Trade opens
   `scenes/ui/trade.tscn`, which lists Stores and (once purchased) Trading
   Post (see `docs/plans/2026-08-08-trade-equipment-loot-and-ui/`).
   ```

3. **Run the full suite.**

   ```bash
   make test
   ```

   Expected: `---- All tests passed! ----`, exit code 0.

4. **Commit** only this task's files:

   ```bash
   git add scripts/tools/screenshot_tour.gd docs/dev/code-map.md
   git commit -m "docs: add Trade screens to the screenshot tour and code map"
   ```

## Milestone

The screenshot tour visits Trade, Stores (pre-seeded with sample loot for a
representative screenshot), and Trading Post; `docs/dev/code-map.md` no
longer describes the Trade button as disabled. Phase C is complete.
